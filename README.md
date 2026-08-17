<table border="0">
  <tr>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/f98adb1d-dfc3-4b4d-b701-52c3850687a1" width="160" alt="iPhone Screenshot 1" />
    </td>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/91a1f964-1597-4324-96a9-89620100738b" width="160" alt="iPhone Screenshot 3" />
    </td>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/5f02594a-e2bb-4347-9fb6-97d265b0d4bd" width="160" alt="iPhone Screenshot 2" />
    </td>
  </tr>
</table>

# Tardi

> **Tardi** is a high-stakes, location-first habit and punctuality tracker that holds you accountable through real financial forfeits. Set your destination, choose your mode of transit, and arrive by the deadline—if you're not inside the geofence on time, your streak resets and you lose real money. Powered by live travel ETAs and departure countdowns, Tardi ensures you show up on time when excuses are too costly.

---

## 📋 Feature Specification Matrix

### 1. Functional Features (User-Facing Capabilities & Mechanics)

| ID | Feature Category | Feature Description | Behavior & User Value | Associated Source Files |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | **Map Canvas & POI Filtering** | Lo-Fi Real Geographic Map | Strips commercial POIs, road names, and traffic colors to present a clean, architectural lo-fi map with real terrain. | [`LofiMapView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/LofiMapView.swift) |
| **F-02** | **Habit Node Creation** | Tap & Search Node Placement | Users can tap anywhere on the map or use the top search bar (with reverse-geocoding) to drop a draft pin. | [`RadarHomeView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/RadarHomeView.swift), [`NewCommitmentView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/NewCommitmentView.swift) |
| **F-03** | **Location Customization** | Custom Location Naming & Geofence Radius | Custom naming (e.g. *"Gym"*, *"Work"*, *"Home"*) and interactive radius slider (25m–1000m) with preset pills (`50m`, `100m`, `250m`, `500m`). | [`NewCommitmentView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/NewCommitmentView.swift), [`CommitmentDetailView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/CommitmentDetailView.swift) |
| **F-04** | **Multi-Modal Transit** | Per-Node Transportation Assignment | Assigns specific travel mode (Walk, Skateboard, Scooter, Bicycle, Bus, Train, Car) per node with dedicated speed profiles and boarding overheads. | [`TravelMode.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Models/TravelMode.swift), [`NewCommitmentView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/NewCommitmentView.swift) |
| **F-05** | **Route Streaming** | Radial Live Vector Connection Lines | Direct animated connector lines streaming continuously from the user's live coordinates to each active habit node. | [`LofiMapView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/LofiMapView.swift) |
| **F-06** | **Node Status Tags** | Live Countdown & Distance in Miles | Node cards display deadline time, time remaining (e.g. `⏳ 42m`), travel duration (e.g. `🚲 14m`), distance in miles (`1.4 mi` / `350 ft`), and streak flame. | [`Components.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/Components.swift) |
| **F-07** | **View Density Mode** | Minimal vs. Detailed Card Toggle | A map control button toggles top info cards on/off to prevent overlap in dense node clusters, showing only the node dot, radius, fuse ring, and name. | [`LofiMapView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/LofiMapView.swift), [`Components.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/Components.swift) |
| **F-08** | **Countdown Clock** | Elaborate Burning-Fuse Clock in Node View | Live ticking digital timer (`HH : MM : SS`), circular progress ring, and an animated burning ember spark particle at the arc tip. | [`Components.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/Components.swift), [`CommitmentDetailView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/CommitmentDetailView.swift) |
| **F-09** | **Departure Advisor** | "Time to Leave" (Latest Departure Calculation) | Calculates `deadline - travelTime` to recommend latest departure time, time until departure (`"Leave in 18 min"`), and dynamic urgency feedback. | [`Commitment.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Models/Commitment.swift), [`CommitmentDetailView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/CommitmentDetailView.swift) |
| **F-10** | **Early Check-In** | Early Arrival Check-In & Node Clearing | Prominent action in node view to check in early, increment streak (`🔥 +1`), insert pass record, and clear active streaming route for the day. | [`Commitment.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Models/Commitment.swift), [`CommitmentDetailView.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Views/CommitmentDetailView.swift) |
| **F-11** | **Geofence Scoring** | Passive Deadline Check & Streak Management | Automatically evaluates deadline pass/fail against CoreLocation region state; streaks increment on arrival or reset on absence with financial forfeits. | [`CommitmentEvaluator.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Managers/CommitmentEvaluator.swift), [`LocationManager.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Managers/LocationManager.swift) |
| **F-12** | **Notifications** | Local Deadline & Result Notifications | Schedules local notifications for upcoming check-ins and delivers instant feedback upon evaluation or early check-in. | [`NotificationManager.swift`](file:///Users/user2/Documents/Projects/tardi/Tardi/Managers/NotificationManager.swift) |

---

### 2. Non-Functional Features (Performance, Architecture & Quality Attributes)

| ID | Quality Attribute | Technical Specification / Implementation | Impact & Benefit |
| :--- | :--- | :--- | :--- |
| **NF-01** | **Rendering Performance** | Hardware-Accelerated Metal `Canvas` Overlay | Decouples vector line animations from SwiftUI `Map` using screen-space `Canvas` at 60/120 FPS ProMotion with zero dropped frames. |
| **NF-02** | **Visual Quality & Vector Scalability** | Zoom-Adaptive Dash Scaling & `.aboveLabels` Level | Polylines and geofences render in crisp GPU vector space without rasterization pixelation; dash frequency dynamically adapts to zoom distance. |
| **NF-03** | **Battery & Power Efficiency** | Passive CoreLocation Circular Region Monitoring | Uses low-power `CLCircularRegion` geofencing instead of continuous foreground GPS tracking, preserving battery life throughout the day. |
| **NF-04** | **Data Persistence & Resilience** | SwiftData with Automatic Store Recovery | Robust `@Model` schema with inline default values and fallback `ModelContainer` recovery to prevent database migration crashes. |
| **NF-05** | **Design Aesthetics** | Minimalist Lo-Fi & Premium Micro-Interactions | Flat cards, subtle frosted glass materials (`.ultraThinMaterial`), haptic feedback (`UIImpactFeedbackGenerator`), and harmonious colors. |
| **NF-06** | **Privacy & Local-First Architecture** | Zero Cloud Dependence / 100% On-Device | Location data, check-in history, and habit schedules remain entirely on-device; no third-party analytics or server tracking. |
| **NF-07** | **Build Reproducibility** | Declarative XcodeGen Spec (`project.yml`) | Complete Xcode project is declaratively defined in `project.yml`, ensuring clean, automated builds and git friendly configuration. |

---

## 🛠️ Project Structure

```
Tardi/
├── TardiApp.swift               # App entry point with safe SwiftData migrations
├── Info.plist                   # Location & notification permissions
├── Models/
│   ├── Commitment.swift         # Habit node model, schedule logic & departure math
│   ├── CheckInRecord.swift      # Pass/fail deadline records
│   └── TravelMode.swift         # Multi-modal urban transit speed models & ETAs
├── Managers/
│   ├── LocationManager.swift    # CoreLocation wrapper for geofencing & live coordinates
│   ├── CommitmentEvaluator.swift# Deadline evaluation & streak calculation
│   └── NotificationManager.swift# Local notifications & reminders
├── Views/
│   ├── RadarHomeView.swift      # Primary screen with search and sheet navigation
│   ├── LofiMapView.swift        # Lo-fi map canvas with 120 FPS Canvas vector routes
│   ├── NewCommitmentView.swift  # Location name editor, travel mode picker & schedule sheet
│   ├── CommitmentDetailView.swift# Burning fuse clock, Time to Leave advisor & early check-in
│   ├── Components.swift         # NodeMarkerView, ElaborateCountdownTimerView, TimeToLeaveCard
│   └── ScheduleControls.swift   # Drag-to-paint weekday selector & time slider
└── Assets.xcassets/             # App icon & accent colors
```

---

## 🚀 How to Build and Run

1. Open the project in Xcode:
   ```sh
   open /Users/user2/Documents/Projects/tardi/Tardi.xcodeproj
   ```
2. Select an iOS Simulator (e.g., iPhone 15/16 Pro) or your connected physical iPhone.
3. Press **Run (⌘R)**.
4. When prompted, allow Location and Notification permissions to enable geofencing and departure alerts.
