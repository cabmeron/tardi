package scheduler

import (
	"context"
	"testing"
	"time"

	"tardi-backend/config"
)

func TestSchedulerServiceLifecycle(t *testing.T) {
	cfg := &config.Config{
		RedisAddr:      "localhost:6379",
		PollIntervalMs: 10,
		IsTestMode:     true,
	}

	sched := NewService(cfg)
	ctx := context.Background()

	// 1. Health check
	health := sched.GetHealth(ctx)
	if health.Status != "healthy" {
		t.Fatalf("expected healthy, got %s", health.Status)
	}

	// 2. Schedule future task (due in 1 hour)
	futureDeadline := time.Now().Add(1 * time.Hour)
	task1 := ScheduledDeadline{
		TaskID:            "task_test_1",
		UserID:            "user_1",
		CustomerID:        "cus_test",
		PledgeAmountCents: 2500,
		TaskTitle:         "Morning Run",
		LocationName:      "Park",
		DeadlineDate:      futureDeadline,
		DeadlineTimestamp: futureDeadline.Unix(),
	}

	if err := sched.Schedule(ctx, task1); err != nil {
		t.Fatalf("failed to schedule task: %v", err)
	}

	// Verify pending count is 1
	status := sched.GetStatus(ctx)
	if status.PendingTasksCount != 1 {
		t.Fatalf("expected 1 pending task, got %d", status.PendingTasksCount)
	}

	// 3. Schedule expired task (due 10 seconds ago)
	pastDeadline := time.Now().Add(-10 * time.Second)
	task2 := ScheduledDeadline{
		TaskID:            "task_test_2",
		UserID:            "user_1",
		CustomerID:        "cus_test",
		PledgeAmountCents: 1000,
		TaskTitle:         "Gym Session",
		LocationName:      "Gym",
		DeadlineDate:      pastDeadline,
		DeadlineTimestamp: pastDeadline.Unix(),
	}

	if err := sched.Schedule(ctx, task2); err != nil {
		t.Fatalf("failed to schedule task2: %v", err)
	}

	// 4. Pop due tasks
	due, err := sched.popDueTasks(ctx, time.Now().Unix())
	if err != nil {
		t.Fatalf("popDueTasks failed: %v", err)
	}

	if len(due) != 1 {
		t.Fatalf("expected 1 due task, got %d", len(due))
	}
	if due[0].TaskID != "task_test_2" {
		t.Fatalf("expected task_test_2 to be popped, got %s", due[0].TaskID)
	}

	// 5. Cancel remaining future task (Goal Met!)
	if err := sched.Cancel(ctx, "task_test_1"); err != nil {
		t.Fatalf("failed to cancel task: %v", err)
	}

	statusAfterCancel := sched.GetStatus(ctx)
	if statusAfterCancel.PendingTasksCount != 0 {
		t.Fatalf("expected 0 pending tasks after cancel, got %d", statusAfterCancel.PendingTasksCount)
	}
}
