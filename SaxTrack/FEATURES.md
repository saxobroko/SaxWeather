# 📱 SaxTrack Feature Guide

## Core Features

### 📊 Dashboard
The main hub showing your Instagram statistics at a glance.

**Stats Cards:**
- **Followers**: Total people following you
- **Following**: Total people you follow
- **Don't Follow Back**: People you follow who don't follow you
- **Mutual**: People who follow you back

**Quick Actions:**
- Import new data
- View non-followers
- Check recent activity

**Recent Activity Preview:**
- Last 5 follower changes
- Quick overview of what's happening

---

### 👥 Non-Followers View
See exactly who doesn't follow you back.

**Features:**
- **Search Bar**: Filter by username or display name
- **Summary Card**: Total count and description
- **User Cards**: Tap to open Instagram profile
- **Visual Indicators**:
  - ❌ Orange badge = Doesn't follow back
  - ✅ Green badge = Mutual follower

**Actions:**
- Tap any user card to open their Instagram profile
- Use this to decide who to unfollow

---

### 📅 Activity/Changes View
Complete timeline of all follower changes.

**Filter Options:**
- **All**: Every change
- **Unfollows**: Only people who unfollowed you
- **Follows**: Only new followers

**Change Types:**
- 🟢 **Followed**: Someone new followed you
- 🔴 **Unfollowed**: Someone stopped following you
- 🔵 **You Followed**: You followed someone new
- ⚫ **You Unfollowed**: You stopped following someone

**Features:**
- Grouped by date
- Unread indicators (blue dot)
- "Mark All Read" button
- Tap to mark individual changes as read

---

### ⚙️ Settings
App configuration and information.

**Statistics Section:**
- Total users tracked
- Follower/Following counts
- Total changes recorded

**Data Management:**
- **Clear All Data**: Reset app completely
- Confirmation dialog for safety

**Privacy Information:**
- Learn about local-only storage
- No cloud sync details
- Privacy-first approach

**Usage Tips:**
- How to export Instagram data
- Best practices for tracking
- Feature recommendations

---

## Data Import

### Methods

#### 1️⃣ Instagram Export File (Recommended)
**Best for:** Complete and accurate data

**Steps:**
1. Dashboard → Import Data
2. Choose "Instagram Export File"
3. Select your JSON file from Instagram's data export
4. Automatic detection of followers/following
5. Instant import with change tracking

**Supported Formats:**
- Instagram's official JSON export (2024+ format)
- Legacy JSON formats (2023 and earlier)
- Auto-detection of file type

**Get Your Instagram Data:**
1. Instagram → Settings → Privacy & Security
2. Download Your Information → Request Download
3. Format: JSON, Date Range: All time
4. Wait 1-48 hours for email
5. Download and extract ZIP file
6. Import `followers_1.json` and `following.json`

#### 2️⃣ Clipboard Import
**Best for:** Quick imports from any source

**How it works:**
- Copy Instagram usernames anywhere (Instagram app, web, notes)
- Open SaxTrack
- App automatically detects data in clipboard
- One-tap import with format detection

**Supported formats:**
- Line-separated usernames
- Comma-separated usernames
- JSON data from Instagram
- Mixed formats (auto-detected)

#### 3️⃣ Manual Entry
**Best for:** Quick testing or small lists

**Steps:**
1. Dashboard → Import Data
2. Choose "Manual Entry"
3. Select "Followers" or "Following"
4. Paste usernames (one per line)
5. Tap "Import X Users"

**Format:**
```
username1
username2
username3
```

#### 4️⃣ iOS Shortcuts (Semi-Automated)
**Best for:** Scheduled updates and automation

**Features:**
- One-tap import from shortcuts
- Scheduled weekly/monthly updates
- Background processing
- Custom workflows

**Quick Setup:**
1. Create shortcut with URL: `saxtrack://import?type=followers&data=user1,user2`
2. Add to Home Screen or automation
3. Run anytime for instant import

**See [SHORTCUTS.md](SHORTCUTS.md) for detailed guide**

#### 5️⃣ Sample Data
**Best for:** Testing the app

**Steps:**
1. Dashboard → Import Data
2. Choose import type
3. Tap "Import Sample Data"
4. Instant demo data loaded

**Includes:**
- 10 sample followers
- 10 sample following
- Automatic non-follower detection

---

## Understanding Your Data

### Follower Metrics

**Followers Count**
- People who follow you
- May or may not follow them back

**Following Count**
- People you follow
- May or may not follow you back

**Don't Follow Back**
- Following count - Mutual count
- People you follow who don't follow you

**Mutual Followers**
- Both following each other
- Your true community

### Ideal Ratios

**Balanced Account:**
- Followers ≈ Following
- High mutual percentage
- Low non-followers count

**Growing Account:**
- Followers > Following
- Shows strong content/engagement

**Follow-for-Follow:**
- Following > Followers
- Consider unfollowing non-followers

---

## Privacy & Security

### What We Track
✅ Usernames (from your import)
✅ Follow/unfollow events
✅ Historical snapshots
✅ Change timestamps

### What We DON'T Track
❌ Passwords or credentials
❌ Private messages
❌ Post content
❌ Your location
❌ Device information
❌ Usage analytics

### Data Storage
- 📱 **Local Only**: All data on your device
- 🔒 **SwiftData**: Apple's encrypted storage
- 🚫 **No Cloud**: Data never leaves your phone
- 🗑️ **Full Control**: Delete anytime in Settings

### Instagram Access
- ⚠️ **No API Connection**: We never connect to Instagram
- 📥 **Manual Import**: You provide the data
- 🔐 **No Login**: We never ask for your password
- 🛡️ **Safe**: Can't be banned or flagged

---

## Tips & Best Practices

### 📈 Tracking Tips

**Regular Updates**
- Import data weekly for accuracy
- Changes detected automatically
- Build comprehensive history

**Compare Snapshots**
- View trends over time
- Identify patterns
- Make informed decisions

**Act on Insights**
- Review non-followers regularly
- Consider unfollowing inactive accounts
- Focus on genuine engagement

### 🎯 Growth Strategies

**Clean Your Following**
- Unfollow non-followers
- Keep mutual followers
- Maintain healthy ratio

**Monitor Activity**
- Check who unfollowed
- Don't take it personally
- Focus on quality over quantity

**Engage Authentically**
- Real interactions matter
- Build genuine community
- Quality > Quantity

### ⚠️ Important Notes

**Instagram Export Timing**
- Exports can take 1-48 hours
- Request during low-activity periods
- Check spam folder for email

**Data Accuracy**
- Only as current as your import
- Instagram API not used
- Manual import required

**App Limitations**
- Can't auto-sync with Instagram
- Requires manual data export
- No real-time updates

---

## Keyboard Shortcuts (iPad)

When using SaxTrack on iPad with keyboard:

- `⌘1` - Dashboard tab
- `⌘2` - Non-Followers tab  
- `⌘3` - Activity tab
- `⌘4` - Settings tab
- `⌘F` - Search (on relevant screens)
- `⌘R` - Refresh data
- `⌘,` - Settings (future)

---

## Accessibility

SaxTrack is built with accessibility in mind:

**VoiceOver Support**
- All buttons labeled
- Descriptive hints
- Navigable hierarchy

**Dynamic Type**
- Supports all text sizes
- Scales appropriately
- Maintains readability

**High Contrast**
- Clear visual hierarchy
- Sufficient color contrast
- Works in both light/dark modes

**Reduced Motion**
- Respects system settings
- Minimal animations when enabled
- Smooth transitions

---

## Troubleshooting

### Common Issues

**"No Data Yet" showing**
- Solution: Import followers/following data first

**Changes not appearing**
- Solution: Import data at least twice to detect changes

**Search not working**
- Solution: Type full or partial username

**Can't open Instagram profile**
- Solution: Make sure Instagram app is installed

### Getting Help

1. Check this guide
2. Review SETUP.md
3. Read README.md
4. Open GitHub issue

---

## Future Features

Vote for features you want:

- [ ] JSON file import
- [ ] Export to CSV/PDF
- [ ] Charts and graphs
- [ ] Push notifications
- [ ] Home screen widgets
- [ ] Multiple accounts
- [ ] Cloud sync (optional)
- [ ] AI insights

---

**Happy tracking! 📊✨**
