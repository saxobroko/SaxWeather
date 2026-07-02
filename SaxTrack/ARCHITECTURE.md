# 🏗️ SaxTrack Architecture

## System Overview

```
┌─────────────────────────────────────────────────────┐
│                   SaxTrack App                       │
│                  (SwiftUI + SwiftData)               │
└─────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    ┌───▼───┐        ┌────▼────┐      ┌────▼────┐
    │ Views │        │ViewModel│      │ Models  │
    └───┬───┘        └────┬────┘      └────┬────┘
        │                 │                 │
        │                 │                 │
        └────────► ◄──────┴─────► ◄────────┘
                   Data Flow
```

---

## Layer Architecture

### 1. Presentation Layer (Views)
```
┌────────────────────────────────────────┐
│           SwiftUI Views                │
├────────────────────────────────────────┤
│                                        │
│  ┌──────────────┐  ┌──────────────┐  │
│  │  Dashboard   │  │ Non-Followers│  │
│  │    View      │  │     View     │  │
│  └──────────────┘  └──────────────┘  │
│                                        │
│  ┌──────────────┐  ┌──────────────┐  │
│  │   Changes    │  │   Settings   │  │
│  │     View     │  │     View     │  │
│  └──────────────┘  └──────────────┘  │
│                                        │
│  ┌──────────────┐                     │
│  │ImportDataView│                     │
│  └──────────────┘                     │
│                                        │
└────────────────────────────────────────┘
```

### 2. Business Logic Layer (ViewModel)
```
┌────────────────────────────────────────┐
│    FollowerTrackingViewModel           │
│         (@Observable)                  │
├────────────────────────────────────────┤
│                                        │
│  Properties:                           │
│  • users: [InstagramUser]             │
│  • recentChanges: [FollowerChange]    │
│  • snapshots: [FollowerSnapshot]      │
│  • isLoading: Bool                    │
│  • error: String?                     │
│                                        │
│  Computed:                            │
│  • followers                          │
│  • following                          │
│  • nonFollowers                       │
│  • mutualFollowers                    │
│  • stats                              │
│                                        │
│  Methods:                             │
│  • loadData()                         │
│  • importFollowers()                  │
│  • importFollowing()                  │
│  • recordChange()                     │
│  • createSnapshot()                   │
│  • clearAllData()                     │
│                                        │
└────────────────────────────────────────┘
```

### 3. Data Layer (Models)
```
┌────────────────────────────────────────┐
│          SwiftData Models              │
│            (@Model)                    │
├────────────────────────────────────────┤
│                                        │
│  ┌──────────────────────────────┐    │
│  │     InstagramUser             │    │
│  ├──────────────────────────────┤    │
│  │ • username: String            │    │
│  │ • displayName: String         │    │
│  │ • profilePictureURL: String?  │    │
│  │ • isFollower: Bool            │    │
│  │ • isFollowing: Bool           │    │
│  │ • dateAdded: Date             │    │
│  │ • lastSeen: Date              │    │
│  └──────────────────────────────┘    │
│                                        │
│  ┌──────────────────────────────┐    │
│  │    FollowerSnapshot           │    │
│  ├──────────────────────────────┤    │
│  │ • date: Date                  │    │
│  │ • followerCount: Int          │    │
│  │ • followingCount: Int         │    │
│  │ • mutualCount: Int            │    │
│  │ • nonFollowersCount: Int      │    │
│  │ • followerUsernames: [String] │    │
│  │ • followingUsernames: [String]│    │
│  └──────────────────────────────┘    │
│                                        │
│  ┌──────────────────────────────┐    │
│  │     FollowerChange            │    │
│  ├──────────────────────────────┤    │
│  │ • username: String            │    │
│  │ • displayName: String         │    │
│  │ • changeType: String          │    │
│  │ • date: Date                  │    │
│  │ • isRead: Bool                │    │
│  └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

---

## Data Flow Diagram

### Import Flow
```
User Action
    │
    ▼
┌─────────────┐
│ Import View │
└──────┬──────┘
       │ importFollowers([usernames])
       ▼
┌──────────────┐
│  ViewModel   │ ──┐
└──────┬───────┘   │
       │           │ For each username:
       │           │ • Check if exists
       │           │ • Update or create
       │           │ • Detect changes
       │           └───────┐
       ▼                   │
┌──────────────┐          │
│  SwiftData   │ ◄────────┘
│ ModelContext │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Database   │
│ (On Device)  │
└──────────────┘
```

### Change Detection Flow
```
New Import
    │
    ▼
┌──────────────────┐
│ Compare Current  │
│ vs Previous Data │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌─────────┐
│ Added  │ │ Removed │
└───┬────┘ └────┬────┘
    │           │
    ▼           ▼
┌────────────────────┐
│  Create Change     │
│  Record            │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Save to Database   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Update UI          │
│ (Activity Tab)     │
└────────────────────┘
```

### View Update Flow
```
Data Change
    │
    ▼
┌──────────────┐
│  SwiftData   │
│   Update     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  ViewModel   │
│  loadData()  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ @Observable  │
│  Property    │
│   Change     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  SwiftUI     │
│  Auto Update │
└──────────────┘
```

---

## Component Interactions

### Dashboard View ↔ ViewModel
```
DashboardView
    │
    ├─► viewModel.stats          (Read)
    ├─► viewModel.recentChanges  (Read)
    ├─► viewModel.loadData()     (Call)
    └─► showingImportSheet       (State)
```

### Non-Followers View ↔ ViewModel
```
NonFollowersView
    │
    ├─► viewModel.nonFollowers   (Read)
    ├─► filteredUsers            (Computed)
    └─► searchText               (State)
```

### Changes View ↔ ViewModel
```
ChangesView
    │
    ├─► viewModel.recentChanges       (Read)
    ├─► viewModel.markChangeAsRead()  (Call)
    ├─► viewModel.markAllAsRead()     (Call)
    └─► filterType                    (State)
```

### Import View ↔ ViewModel
```
ImportDataView
    │
    ├─► viewModel.importFollowers()  (Async Call)
    ├─► viewModel.importFollowing()  (Async Call)
    ├─► viewModel.isLoading          (Read)
    └─► importType                   (State)
```

---

## State Management

### SwiftUI State (@State)
```
Local view state:
• showingImportSheet: Bool
• searchText: String
• filterType: Enum
• showingAlert: Bool
```

### Observable State (@Observable)
```
Shared app state:
• users: [InstagramUser]
• recentChanges: [FollowerChange]
• snapshots: [FollowerSnapshot]
• isLoading: Bool
• error: String?
```

### Persistent State (SwiftData)
```
Database records:
• InstagramUser (@Model)
• FollowerSnapshot (@Model)
• FollowerChange (@Model)
```

---

## Threading Model

```
┌─────────────────────────────────┐
│         Main Thread             │
│      (UI Updates Only)          │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│      async/await Tasks          │
│    (Background Work)            │
├─────────────────────────────────┤
│ • importFollowers()             │
│ • importFollowing()             │
│ • fetchFreshData()              │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│      SwiftData Context          │
│   (Background Operations)       │
└─────────────────────────────────┘
```

---

## Dependency Graph

```
SaxTrackApp
    │
    ├─► ContentView
    │       │
    │       ├─► DashboardView
    │       │       └─► ViewModel
    │       │
    │       ├─► NonFollowersView
    │       │       └─► ViewModel
    │       │
    │       ├─► ChangesView
    │       │       └─► ViewModel
    │       │
    │       └─► SettingsView
    │               └─► ViewModel
    │
    └─► ModelContainer
            │
            ├─► InstagramUser
            ├─► FollowerSnapshot
            └─► FollowerChange
```

---

## File Organization

```
SaxTrack/
│
├── App Layer
│   ├── SaxTrackApp.swift       (Entry point)
│   └── ContentView.swift       (Tab controller)
│
├── Presentation Layer
│   └── Views/
│       ├── DashboardView.swift
│       ├── NonFollowersView.swift
│       ├── ChangesView.swift
│       ├── ImportDataView.swift
│       └── SettingsView.swift
│
├── Business Logic Layer
│   └── ViewModels/
│       └── FollowerTrackingViewModel.swift
│
├── Data Layer
│   └── Models/
│       ├── InstagramUser.swift
│       ├── FollowerSnapshot.swift
│       └── FollowerChange.swift
│
└── Resources
    ├── Assets.xcassets/
    └── Info.plist
```

---

## Design Patterns Used

### 1. MVVM (Model-View-ViewModel)
- **Model**: SwiftData entities
- **View**: SwiftUI views
- **ViewModel**: Observable business logic

### 2. Repository Pattern
- ViewModel acts as repository
- Abstracts data access
- Single source of truth

### 3. Observer Pattern
- @Observable macro
- Automatic UI updates
- Reactive programming

### 4. Factory Pattern
- Timeline entries
- User cards
- Change records

---

## Performance Considerations

### Optimization Techniques
```
✅ Lazy loading: LazyVStack for lists
✅ Computed properties: Filtered data
✅ Background threads: async/await
✅ Efficient queries: SwiftData predicates
✅ Minimal re-renders: Targeted updates
```

### Memory Management
```
✅ No retain cycles: [weak self]
✅ Proper cleanup: onDisappear
✅ Efficient storage: SwiftData
✅ Lazy initialization: @State
```

---

## Security & Privacy

### Data Protection
```
Local Storage
    ↓
SwiftData
    ↓
Encrypted Container
    ↓
iOS Keychain/Files
    ↓
Device Only
```

### No External Communication
```
❌ No network requests
❌ No cloud sync
❌ No analytics
❌ No crash reporting
✅ 100% local
```

---

**This architecture ensures:**
- ✅ Separation of concerns
- ✅ Testable components
- ✅ Maintainable code
- ✅ Scalable structure
- ✅ Privacy-first design
