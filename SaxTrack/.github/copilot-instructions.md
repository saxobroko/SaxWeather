<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# SaxTrack - Instagram Follower Tracker

## Project Overview
This is an iOS 21 SwiftUI application for tracking Instagram followers and detecting changes over time.

## Architecture
- **Pattern:** MVVM (Model-View-ViewModel)
- **Data Persistence:** SwiftData (iOS 17+)
- **UI Framework:** SwiftUI with iOS 21 design patterns
- **Minimum iOS:** iOS 17.0

## Code Style Guidelines
- Use Swift 5.9+ features
- Follow Apple's Swift API Design Guidelines
- Use async/await for asynchronous operations
- Prefer SwiftUI over UIKit
- Use @Observable macro for ViewModels (iOS 17+)
- Implement proper error handling with Result types

## Design Guidelines
- iOS 21 glassmorphism aesthetic
- SF Symbols for icons
- System colors with semantic naming
- Smooth animations and transitions
- Dark mode support
- Accessibility labels for all interactive elements

## Key Features
1. Import Instagram follower data (JSON/CSV)
2. Track who doesn't follow back
3. Detect unfollowers over time
4. Show follower change history
5. Local notifications for changes
6. Export reports

## Data Models
- **InstagramUser:** Represents a follower/following with username, name, profile URL
- **FollowerSnapshot:** Historical record of followers/following at a point in time
- **FollowerChange:** Records when someone follows/unfollows

## Security & Privacy
- All data stored locally (no cloud sync)
- No Instagram API access required (user provides data export)
- No credentials stored
- Privacy-focused design
