# SaxTrack

<div align="center">
  <h3>📊 Instagram Follower Tracker for iOS 21</h3>
  <p>Track your Instagram community with complete privacy</p>
</div>

---

## ✨ Features

### 📈 **Comprehensive Tracking**
- **Non-Followers Detection**: See exactly who you're following that doesn't follow back
- **Unfollow Notifications**: Get alerted when someone unfollows you
- **Follow Tracking**: Know when new people start following you
- **Historical Timeline**: View your complete follower change history
- **Statistics Dashboard**: Beautiful overview of your Instagram metrics

### 🎨 **Modern Design**
- **iOS 21 Glassmorphism**: Stunning glass card effects throughout
- **Adaptive UI**: Seamless dark mode support
- **Smooth Animations**: Buttery smooth transitions and effects
- **SF Symbols**: Native iOS iconography
- **Accessibility**: Full support for Dynamic Type and VoiceOver

### 🔒 **Privacy First**
- **100% Local Storage**: All data stored on your device with SwiftData
- **No Cloud Sync**: Your data never leaves your phone
- **No API Access**: We never connect to Instagram
- **No Analytics**: Zero tracking or telemetry
- **No Credentials**: We never ask for your Instagram password

## 📱 Screenshots

*Coming soon!*

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.0+** (for iOS 17+ support)
- **iOS 17.0+** deployment target
- **macOS 14.0+** (for development)
- **Swift 5.9+**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/SaxTrack.git
   cd SaxTrack
   ```

2. **Open in Xcode**
   ```bash
   open SaxTrack.xcodeproj
   ```

3. **Build and Run**
   - Select your target device (iPhone or iPad)
   - Press `⌘R` to build and run
   - The app will launch with an empty state

### First Time Setup

Since this is a standalone project (no Xcode project file yet), you'll need to:

1. **Create Xcode Project**:
   - Open Xcode
   - File → New → Project
   - Choose "iOS" → "App"
   - Product Name: `SaxTrack`
   - Interface: SwiftUI
   - Life Cycle: SwiftUI App
   - Language: Swift
   - Storage: SwiftData
   - Minimum iOS: 17.0

2. **Add Source Files**:
   - Drag all `.swift` files from this repo into your Xcode project
   - Make sure "Copy items if needed" is checked
   - Add to target: SaxTrack

3. **Configure Info.plist**:
   - Use the provided `Info.plist` file

## 📖 How to Use

### Exporting Instagram Data

1. Open **Instagram** app or website
2. Go to **Settings** → **Privacy** → **Security**
3. Select **Download Your Information**
4. Choose **Some of your information**
5. Check both:
   - ☑️ Followers
   - ☑️ Following
6. Click **Next** and **Submit Request**
7. Wait for email (can take up to 48 hours)

### Importing Data

#### Method 1: Instagram JSON Export (Recommended)
1. Tap **Import Data** on dashboard
2. Choose **Instagram Export File**
3. Select `followers_1.json` or `following.json` from your Instagram export
4. App automatically detects format and imports

**Supports:**
- Instagram's 2024+ JSON format
- Legacy 2023 and earlier formats
- Automatic format detection

#### Method 2: Clipboard Detection (Easiest)
1. Copy Instagram usernames anywhere (app, web, notes)
2. Open SaxTrack
3. App detects clipboard data automatically
4. Tap "Import" on the prompt

#### Method 3: iOS Shortcuts (Automated)
1. Create a shortcut with URL: `saxtrack://import?type=followers&data=user1,user2`
2. Run manually or set up automation
3. Schedule weekly imports for automatic tracking

**See [SHORTCUTS.md](SHORTCUTS.md) for detailed automation guide**

#### Method 4: Manual Entry (Quick Testing)
1. Tap **Import Data** on dashboard
2. Choose **Manual Entry**
3. Paste usernames (one per line)
4. Tap **Import**

#### Method 5: Sample Data (Testing)
1. Tap **Import Data** on dashboard
2. Choose **Import Sample Data**
3. This creates demo data to explore features

### Using the App

**Dashboard Tab**
- View key statistics
- See follower counts and ratios
- Quick access to all features

**Non-Followers Tab**
- List of people you follow who don't follow back
- Tap to view profile
- Consider unfollowing to balance your ratio

**Activity Tab**
- Timeline of all follower changes
- Filter by follows/unfollows
- Mark changes as read
- See when people unfollowed you

**Settings Tab**
- View detailed statistics
- Clear all data
- Read privacy information
- Get usage tips

## 🏗️ Architecture

### Tech Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI (iOS 17+)
- **Architecture**: MVVM (Model-View-ViewModel)
- **Data**: SwiftData (Apple's new persistence framework)
- **Concurrency**: async/await
- **Minimum iOS**: 17.0

### Project Structure

```
SaxTrack/
├── SaxTrackApp.swift          # App entry point
├── ContentView.swift           # Main tab view
├── Models/
│   ├── InstagramUser.swift    # User model (@Model)
│   ├── FollowerSnapshot.swift # Historical snapshot
│   └── FollowerChange.swift   # Change record
├── ViewModels/
│   └── FollowerTrackingViewModel.swift  # Business logic
└── Views/
    ├── DashboardView.swift     # Main dashboard
    ├── NonFollowersView.swift  # Non-followers list
    ├── ChangesView.swift       # Activity timeline
    ├── ImportDataView.swift    # Data import
    └── SettingsView.swift      # Settings screen
```

### Data Models

**InstagramUser** (@Model)
```swift
- username: String (unique)
- displayName: String
- profilePictureURL: String?
- isFollower: Bool
- isFollowing: Bool
- dateAdded: Date
- lastSeen: Date
```

**FollowerSnapshot** (@Model)
```swift
- date: Date
- followerCount: Int
- followingCount: Int
- mutualCount: Int
- nonFollowersCount: Int
```

**FollowerChange** (@Model)
```swift
- username: String
- displayName: String
- changeType: ChangeType (enum)
- date: Date
- isRead: Bool
```

## 🎨 Design System

### Colors
- **Primary**: System Blue
- **Success**: Green (new followers)
- **Warning**: Orange (non-followers)
- **Danger**: Red (unfollowers)
- **Adaptive**: Automatic dark mode support

### Typography
- **Titles**: SF Pro Rounded
- **Body**: SF Pro
- **Dynamic Type**: Full support

### Components
- **Glass Cards**: Frosted glass effect with blur
- **Stat Cards**: Gradient icons with metrics
- **User Cards**: Profile previews with status badges
- **Change Rows**: Timeline items with icons

## 🔧 Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/SaxTrack.git

# Open in Xcode
cd SaxTrack
open SaxTrack.xcodeproj

# Build
xcodebuild -scheme SaxTrack -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Running Tests

*Unit tests coming soon!*

### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistency
- Document public APIs
- Use meaningful variable names
- Prefer composition over inheritance

## 🛣️ Roadmap

### v1.1 (Coming Soon)
- [ ] JSON file import support
- [ ] Export reports (CSV/PDF)
- [ ] Charts and graphs
- [ ] Push notifications for changes
- [ ] Widget support

### v1.2 (Future)
- [ ] Multiple accounts
- [ ] Cloud sync (optional, end-to-end encrypted)
- [ ] iPad optimization
- [ ] macOS version
- [ ] Shortcuts support

### v2.0 (Vision)
- [ ] AI insights and recommendations
- [ ] Engagement analytics
- [ ] Best time to post suggestions
- [ ] Follower quality scoring

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Powered by [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- Inspired by the need for privacy-focused social media tools

## 📧 Contact

**Questions or feedback?** Open an issue or reach out!

---

<div align="center">
  <p>Built with ❤️ for privacy-conscious Instagram users</p>
  <p>© 2026 SaxTrack. All rights reserved.</p>
</div>
