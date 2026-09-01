package scheduler

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"tardi-backend/config"
	"tardi-backend/crypto"

	"github.com/redis/go-redis/v9"
	"github.com/stripe/stripe-go/v78"
	"github.com/stripe/stripe-go/v78/paymentintent"
)

const (
	RedisKeyScheduled  = "tardi:deadlines:scheduled"
	RedisKeyTaskLookup = "tardi:deadlines:lookup"
)

// Service manages the high-precision deadline poller and Redis Sorted Set lifecycle.
type Service struct {
	cfg       *config.Config
	rdb       *redis.Client
	useMock   bool
	isRunning bool

	// In-memory fallback sandbox state (used when Redis is not running locally)
	mockMu        sync.RWMutex
	mockDeadlines map[string]ScheduledDeadline // Keyed by TaskID

	// Telemetry Metrics
	startTime                 time.Time
	lastPollTime              time.Time
	totalProcessedCount       atomic.Int64
	totalForfeituresCount     atomic.Int64
	totalForfeitedAmountCents atomic.Int64

	stopChan chan struct{}
	doneChan chan struct{}
}

// NewService initializes the Redis client or transparent sandbox fallback.
func NewService(cfg *config.Config) *Service {
	s := &Service{
		cfg:           cfg,
		mockDeadlines: make(map[string]ScheduledDeadline),
		startTime:     time.Now(),
		stopChan:      make(chan struct{}),
		doneChan:      make(chan struct{}),
	}

	// Attempt real Redis connection
	s.rdb = redis.NewClient(&redis.Options{
		Addr:         cfg.RedisAddr,
		Password:     cfg.RedisPassword,
		DB:           cfg.RedisDB,
		DialTimeout:  1 * time.Second,
		ReadTimeout:  500 * time.Millisecond,
		WriteTimeout: 500 * time.Millisecond,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	if err := s.rdb.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️  [REDIS SCHEDULER] Could not connect to Redis at %s: %v", cfg.RedisAddr, err)
		log.Printf("🧪 [REDIS SCHEDULER] Running in High-Precision In-Memory Simulation Mode (0ms latency, thread-safe)")
		s.useMock = true
	} else {
		log.Printf("✅ [REDIS SCHEDULER] Connected to Redis cluster at %s! (Polling: %dms)", cfg.RedisAddr, cfg.PollIntervalMs)
		s.useMock = false
	}

	return s
}

// Start launches the continuous high-precision deadline worker loop.
func (s *Service) Start() {
	s.isRunning = true
	pollInterval := time.Duration(s.cfg.PollIntervalMs) * time.Millisecond
	if pollInterval < 10*time.Millisecond {
		pollInterval = 100 * time.Millisecond
	}

	log.Printf("🚀 [REDIS SCHEDULER] Deadline Worker started (Interval: %v)", pollInterval)

	go func() {
		defer close(s.doneChan)
		ticker := time.NewTicker(pollInterval)
		defer ticker.Stop()

		for {
			select {
			case <-s.stopChan:
				log.Println("🛑 [REDIS SCHEDULER] Deadline Worker shutting down...")
				return
			case t := <-ticker.C:
				s.lastPollTime = t
				s.pollAndExecute(context.Background(), t.Unix())
			}
		}
	}()
}

// Stop gracefully terminates the background worker loop.
func (s *Service) Stop() {
	if !s.isRunning {
		return
	}
	s.isRunning = false
	close(s.stopChan)
	<-s.doneChan
	if s.rdb != nil {
		_ = s.rdb.Close()
	}
	log.Println("✅ [REDIS SCHEDULER] Service stopped.")
}

// Schedule adds a habit task deadline into the sorted set with its Unix timestamp as score.
func (s *Service) Schedule(ctx context.Context, item ScheduledDeadline) error {
	if item.DeadlineTimestamp == 0 {
		item.DeadlineTimestamp = item.DeadlineDate.Unix()
	}
	if item.CreatedAt.IsZero() {
		item.CreatedAt = time.Now()
	}

	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("failed to marshal deadline payload: %w", err)
	}

	if s.useMock {
		s.mockMu.Lock()
		s.mockDeadlines[item.TaskID] = item
		s.mockMu.Unlock()
		log.Printf("📌 [SCHEDULER MOCK] Scheduled deadline for %q (%s) at %s (Timestamp: %d)", item.TaskTitle, item.TaskID, item.DeadlineDate.Format(time.RFC3339), item.DeadlineTimestamp)
		return nil
	}

	pipe := s.rdb.Pipeline()
	// 1. ZSET: Sorted by exact Unix timestamp score
	pipe.ZAdd(ctx, RedisKeyScheduled, redis.Z{
		Score:  float64(item.DeadlineTimestamp),
		Member: string(data),
	})
	// 2. Hash: Fast O(1) task lookup by TaskID for instant cancellation
	pipe.HSet(ctx, RedisKeyTaskLookup, item.TaskID, string(data))

	_, err = pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("redis zadd failed: %w", err)
	}

	log.Printf("📌 [REDIS ZSET] Scheduled task %q (%s) for timestamp %d (Stake: $%.2f)", item.TaskTitle, item.TaskID, item.DeadlineTimestamp, float64(item.PledgeAmountCents)/100.0)
	return nil
}

// Cancel removes a task from the scheduled queue upon early arrival / goal achieved.
func (s *Service) Cancel(ctx context.Context, taskID string) error {
	if s.useMock {
		s.mockMu.Lock()
		delete(s.mockDeadlines, taskID)
		s.mockMu.Unlock()
		log.Printf("🎉 [SCHEDULER MOCK] Task %s canceled! Arrived on time ($0.00 charged)", taskID)
		return nil
	}

	// 1. Retrieve stored JSON payload from Lookup Hash
	rawJson, err := s.rdb.HGet(ctx, RedisKeyTaskLookup, taskID).Result()
	if err != nil && err != redis.Nil {
		return fmt.Errorf("lookup failed: %w", err)
	}

	pipe := s.rdb.Pipeline()
	if rawJson != "" {
		pipe.ZRem(ctx, RedisKeyScheduled, rawJson)
	}
	pipe.HDel(ctx, RedisKeyTaskLookup, taskID)
	_, _ = pipe.Exec(ctx)

	log.Printf("🎉 [REDIS ZSET] Task %s canceled from queue! Arrived on time ($0.00 charged)", taskID)
	return nil
}

// pollAndExecute checks Redis for expired tasks and triggers forfeiture charges.
func (s *Service) pollAndExecute(ctx context.Context, nowUnix int64) {
	dueTasks, err := s.popDueTasks(ctx, nowUnix)
	if err != nil {
		log.Printf("❌ [REDIS SCHEDULER] Poll error: %v", err)
		return
	}

	if len(dueTasks) == 0 {
		return
	}

	for _, task := range dueTasks {
		s.totalProcessedCount.Add(1)
		go s.executeForfeiture(task)
	}
}

// popDueTasks atomically fetches and removes all tasks where Score <= nowUnix.
func (s *Service) popDueTasks(ctx context.Context, nowUnix int64) ([]ScheduledDeadline, error) {
	if s.useMock {
		s.mockMu.Lock()
		defer s.mockMu.Unlock()

		var due []ScheduledDeadline
		for id, item := range s.mockDeadlines {
			if item.DeadlineTimestamp <= nowUnix {
				due = append(due, item)
				delete(s.mockDeadlines, id)
			}
		}
		return due, nil
	}

	// Atomic Lua Script: ZRANGEBYSCORE + ZREM
	luaScript := `
		local expired = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, 50)
		if #expired > 0 then
			redis.call('ZREM', KEYS[1], unpack(expired))
			for _, item in ipairs(expired) do
				local decoded = cjson.decode(item)
				if decoded and decoded.taskId then
					redis.call('HDEL', KEYS[2], decoded.taskId)
				end
			end
		end
		return expired
	`

	res, err := s.rdb.Eval(ctx, luaScript, []string{RedisKeyScheduled, RedisKeyTaskLookup}, nowUnix).StringSlice()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, err
	}

	var tasks []ScheduledDeadline
	for _, item := range res {
		var d ScheduledDeadline
		if err := json.Unmarshal([]byte(item), &d); err == nil {
			tasks = append(tasks, d)
		}
	}
	return tasks, nil
}

// executeForfeiture performs the off-session Stripe payment charge for an expired deadline.
func (s *Service) executeForfeiture(task ScheduledDeadline) {
	log.Printf("\n⚡ [FORFEITURE TRIGGERED] Task %q (%s) expired at %s!", task.TaskTitle, task.TaskID, task.DeadlineDate.Format(time.RFC3339))
	log.Printf("   • Customer: %s", task.CustomerID)
	log.Printf("   • Stake:    $%.2f (%d cents)", float64(task.PledgeAmountCents)/100.0, task.PledgeAmountCents)

	s.totalForfeituresCount.Add(1)
	s.totalForfeitedAmountCents.Add(task.PledgeAmountCents)

	if s.cfg.IsTestMode || task.CustomerID == "" {
		log.Printf("🧪 [SANDBOX FORFEITURE] Mock charge of $%.2f completed for %s", float64(task.PledgeAmountCents)/100.0, task.TaskTitle)
		return
	}

	// Verify HMAC signature if present
	if task.StoredHMACSeal != "" {
		if !crypto.VerifyPledgeIntegrity(task.TaskID, task.UserID, task.PledgeAmountCents, task.StoredHMACSeal, s.cfg.PledgeHMACSecret) {
			log.Printf("🚨 [SECURITY ALERT] HMAC mismatch for task %s! Forfeiture aborted.", task.TaskID)
			return
		}
	}

	// Live Stripe Execution: Off-Session PaymentIntent Direct Charge
	params := &stripe.PaymentIntentParams{
		Amount:      stripe.Int64(task.PledgeAmountCents),
		Currency:    stripe.String("usd"),
		Customer:    stripe.String(task.CustomerID),
		Confirm:     stripe.Bool(true),
		OffSession:  stripe.Bool(true),
		Description: stripe.String(fmt.Sprintf("Tardi Forfeiture: Missed deadline for %s", task.TaskTitle)),
	}
	params.AddMetadata("taskId", task.TaskID)
	params.AddMetadata("deadlineTimestamp", fmt.Sprintf("%d", task.DeadlineTimestamp))

	pi, err := paymentintent.New(params)
	if err != nil {
		log.Printf("❌ [STRIPE FORFEITURE FAILED] Error charging customer %s: %v", task.CustomerID, err)
		return
	}

	log.Printf("✅ [STRIPE FORFEITURE SUCCEEDED] PaymentIntent: %s (Status: %s)", pi.ID, pi.Status)
}

// GetHealth returns lightweight health check telemetry.
func (s *Service) GetHealth(ctx context.Context) HealthResponse {
	redisOk := false
	if !s.useMock && s.rdb != nil {
		redisOk = s.rdb.Ping(ctx).Err() == nil
	} else if s.useMock {
		redisOk = true // In-memory simulation is fully operational
	}

	count := s.getPendingCount(ctx)

	status := "healthy"
	if !redisOk {
		status = "degraded"
	}

	return HealthResponse{
		Status:         status,
		WorkerRunning:  s.isRunning,
		RedisConnected: redisOk,
		PendingTasks:   count,
		Timestamp:      time.Now(),
	}
}

// GetStatus returns comprehensive telemetry metrics for monitoring dashboards.
func (s *Service) GetStatus(ctx context.Context) SchedulerStatus {
	pingStart := time.Now()
	redisOk := false
	latency := 0.0

	if !s.useMock && s.rdb != nil {
		if err := s.rdb.Ping(ctx).Err(); err == nil {
			redisOk = true
			latency = float64(time.Since(pingStart).Microseconds()) / 1000.0
		}
	}

	statusStr := "HEALTHY"
	msg := "Redis Sorted Set Poller running at optimal performance"
	if s.useMock {
		statusStr = "SANDBOX_MOCK"
		msg = "Running in-memory deadline simulator (Set REDIS_ADDR for live cluster)"
	} else if !redisOk {
		statusStr = "DEGRADED"
		msg = "Redis connection lost. Check REDIS_ADDR network connectivity."
	}

	pending := s.getPendingCount(ctx)
	nextDeadline, nextTaskID := s.getNextUpcoming(ctx)

	return SchedulerStatus{
		Service:                   "tardi-deadline-scheduler",
		Status:                    statusStr,
		RedisConnected:            redisOk,
		RedisAddress:              s.cfg.RedisAddr,
		RedisPingLatencyMs:        latency,
		WorkerRunning:             s.isRunning,
		PollIntervalMs:            s.cfg.PollIntervalMs,
		PendingTasksCount:         pending,
		TotalProcessedCount:       s.totalProcessedCount.Load(),
		TotalForfeituresCount:     s.totalForfeituresCount.Load(),
		TotalForfeitedAmountCents: s.totalForfeitedAmountCents.Load(),
		UptimeSeconds:             int64(time.Since(s.startTime).Seconds()),
		LastPollTimestamp:         s.lastPollTime,
		NextUpcomingDeadline:      nextDeadline,
		NextUpcomingTaskID:        nextTaskID,
		Message:                   msg,
	}
}

func (s *Service) getPendingCount(ctx context.Context) int64 {
	if s.useMock {
		s.mockMu.RLock()
		defer s.mockMu.RUnlock()
		return int64(len(s.mockDeadlines))
	}
	count, _ := s.rdb.ZCard(ctx, RedisKeyScheduled).Result()
	return count
}

func (s *Service) getNextUpcoming(ctx context.Context) (*time.Time, string) {
	if s.useMock {
		s.mockMu.RLock()
		defer s.mockMu.RUnlock()

		var earliest *ScheduledDeadline
		for _, item := range s.mockDeadlines {
			if earliest == nil || item.DeadlineTimestamp < earliest.DeadlineTimestamp {
				cp := item
				earliest = &cp
			}
		}
		if earliest != nil {
			t := time.Unix(earliest.DeadlineTimestamp, 0)
			return &t, earliest.TaskID
		}
		return nil, ""
	}

	items, err := s.rdb.ZRangeWithScores(ctx, RedisKeyScheduled, 0, 0).Result()
	if err != nil || len(items) == 0 {
		return nil, ""
	}

	t := time.Unix(int64(items[0].Score), 0)
	var d ScheduledDeadline
	_ = json.Unmarshal([]byte(items[0].Member.(string)), &d)
	return &t, d.TaskID
}
