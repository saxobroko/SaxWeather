# 🚀 SaxTrack Setup Guide

## Quick Start - Create Xcode Project

Since Xcode projects can't be easily generated from the command line with all configurations, follow these steps to set up the project:

### Step 1: Create New Xcode Project

1. **Open Xcode** (15.0 or later)

2. **File → New → Project** or press `⇧⌘N`

3. **Choose iOS → App**
   - Click "Next"

4. **Configure Project:**
   - **Product Name:** `SaxTrack`
   - **Team:** Select your team (or leave as "None")
   - **Organization Identifier:** `com.yourdomain` (or keep default)
   - **Bundle Identifier:** Will auto-generate as `com.yourdomain.SaxTrack`
   - **Interface:** SwiftUI ✅
   - **Language:** Swift ✅
   - **Storage:** SwiftData ✅ (Important!)
   - **Include Tests:** ☑️ (Optional)

5. **Choose Location:**
   - Navigate to: `/Users/saxonbrooker/Documents/SaxWeather/`
   - Create folder: `SaxTrack` (if asked)
   - Click "Create"

### Step 2: Replace Generated Files

The Xcode template creates some default files. We'll replace them with our custom implementation.

1. **Delete default files** (keep the project structure):
   - Right-click `ContentView.swift` → Delete → "Move to Trash"
   - Right-click `SaxTrackApp.swift` → Delete → "Move to Trash"
   - Keep `Assets.xcassets` folder
   - Keep `Preview Content` folder

2. **Add our source files:**
   - Drag the entire `SaxTrack` folder from Finder into Xcode's Project Navigator
   - Make sure "Copy items if needed" is **checked** ✅
   - Select "Create groups" (not folder references)
   - Add to target: `SaxTrack` ✅
   - Click "Finish"

### Step 3: Configure Project Settings

1. **Select project** in Navigator (top item)

2. **General Tab:**
   - **Minimum Deployments:** iOS 17.0
   - **Supported Destinations:** iPhone, iPad
   - **Status Bar Style:** Default

3. **Signing & Capabilities:**
   - Select your **Team**
   - Xcode will auto-manage signing

4. **Build Settings:**
   - Search for "Swift Language Version"
   - Set to: **Swift 5** (or later)

### Step 4: Verify File Structure

Your Xcode project should now look like this:

```
SaxTrack
├── SaxTrack
│   ├── SaxTrackApp.swift
│   ├── ContentView.swift
│   ├── Models
│   │   ├── InstagramUser.swift
│   │   ├── FollowerSnapshot.swift
│   │   └── FollowerChange.swift
│   ├── ViewModels
│   │   └── FollowerTrackingViewModel.swift
│   ├── Views
│   │   ├── DashboardView.swift
│   │   ├── NonFollowersView.swift
│   │   ├── ChangesView.swift
│   │   ├── ImportDataView.swift
│   │   └── SettingsView.swift
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── Preview Content
└── SaxTrackTests (optional)
```

### Step 5: Build and Run

1. **Select a simulator** or device:
   - iPhone 15 Pro (or any iPhone running iOS 17+)

2. **Build and Run:**
   - Press `⌘R` or click the "Play" button
   - Wait for build to complete
   - App should launch in simulator

3. **Test the app:**
   - Navigate through tabs
   - Try importing sample data
   - Explore the features

---

## Alternative: Use Existing Files

If you prefer to work with the existing structure:

### Option A: Create Project in Different Location

1. Create Xcode project in a temporary location
2. Copy the `.xcodeproj` file to `/Users/saxonbrooker/Documents/SaxWeather/SaxTrack/`
3. Open the project
4. Fix file references if needed

### Option B: Manual File Addition

1. Create project at exact location
2. Manually add each `.swift` file:
   - Right-click project → "Add Files to SaxTrack"
   - Navigate to each file
   - Ensure "Copy items if needed" is **unchecked** (files already in place)
   - Select target: `SaxTrack`

---

## Troubleshooting

### Build Errors

**Error: "No such module 'SwiftData'"**
- Solution: Make sure Minimum Deployment is iOS 17.0+

**Error: "Cannot find 'InstagramUser' in scope"**
- Solution: Verify all files are added to the SaxTrack target
- Check: File Inspector → Target Membership → SaxTrack ✅

**Error: "Missing required module 'SwiftUI'"**
- Solution: Clean build folder (⇧⌘K) and rebuild (⌘B)

### Runtime Errors

**App crashes on launch**
- Check console for SwiftData errors
- Verify modelContainer is properly configured in SaxTrackApp.swift

**Preview not working**
- Common with SwiftData
- Run on simulator instead of using previews

---

## Development Tips

### Using Previews

Some views have `#Preview` macros. To use them:
- Click "Resume" on the preview canvas
- Or press `⌥⌘↩` to show preview
- Note: SwiftData previews may be limited

### Testing Changes

1. **Quick iteration:**
   - Make changes
   - Press `⌘R` to rebuild
   - Test in simulator

2. **Debug issues:**
   - Set breakpoints by clicking line numbers
   - Use `print()` statements
   - Check console for errors

### Code Organization

- **Models**: Data structures (SwiftData @Model)
- **ViewModels**: Business logic (@Observable)
- **Views**: UI components (SwiftUI)

---

## Next Steps

Once the project is set up:

1. ✅ **Build and run** to verify everything works
2. 📱 **Test features** with sample data
3. 🎨 **Customize** colors, icons, or layout
4. 📊 **Add features** from the roadmap
5. 🚀 **Deploy** to your device

---

## Need Help?

- Check the main [README.md](README.md) for features and usage
- Review [.github/copilot-instructions.md](.github/copilot-instructions.md) for code guidelines
- Open an issue if you encounter problems

---

**Ready to track your Instagram followers!** 🎉
