# 🔗 Shortcuts Integration Guide

## Overview

SaxTrack supports iOS Shortcuts for semi-automated data import. This allows you to create custom workflows that automatically collect and import your Instagram follower data.

---

## 🎯 What Can You Do?

- **Automated Weekly Updates**: Schedule automatic data imports
- **One-Tap Import**: Import data with a single shortcut tap
- **Background Processing**: Run imports without opening the app
- **Custom Workflows**: Combine with other shortcuts and automations

---

## 📱 URL Scheme

SaxTrack uses the custom URL scheme: `saxtrack://`

### Import URL Format

```
saxtrack://import?type=[followers|following]&data=[usernames]
```

**Parameters:**
- `type`: Either `followers` or `following`
- `data`: Comma-separated usernames or base64-encoded list

### Examples

**Import Followers:**
```
saxtrack://import?type=followers&data=user1,user2,user3
```

**Import Following:**
```
saxtrack://import?type=following&data=user1,user2,user3
```

---

## 🛠️ Creating Shortcuts

### Method 1: Simple Import Shortcut

1. Open Shortcuts app
2. Tap "+" to create new shortcut
3. Add action: "Ask for Input"
   - Prompt: "Paste Instagram usernames (one per line)"
   - Input Type: Text
   - Allow Multiple Lines: ON
4. Add action: "Replace Text"
   - Text: [Provided Input]
   - Replace: "\n" (newline)
   - With: ","
5. Add action: "URL"
   - URL: `saxtrack://import?type=followers&data=`[Replaced Text]
6. Add action: "Open URLs"
   - URLs: [URL]
7. Name shortcut: "Import to SaxTrack"

### Method 2: Clipboard Monitor

1. Open Shortcuts app
2. Create new shortcut
3. Add action: "Get Clipboard"
4. Add action: "Replace Text"
   - Text: [Clipboard]
   - Replace: "\n"
   - With: ","
5. Add action: "URL"
   - URL: `saxtrack://import?type=followers&data=`[Replaced Text]
6. Add action: "Open URLs"
7. Name: "Import Clipboard to SaxTrack"

### Method 3: Scheduled Auto-Import

1. Create shortcut as in Method 1
2. Open Shortcuts → Automation
3. Tap "+" → "Create Personal Automation"
4. Choose "Time of Day"
   - Set time (e.g., every Sunday at 10 AM)
   - Frequency: Weekly
5. Add action: "Run Shortcut"
   - Select your import shortcut
6. Disable "Ask Before Running" for true automation

---

## 📋 Instagram Data Export Workflow

### Complete Automation Setup

**Step 1: Request Instagram Data**
1. Instagram → Settings → Privacy & Security → Download Your Information
2. Request data (JSON format)
3. Wait for email (1-48 hours)

**Step 2: Create Import Shortcut**
```
Shortcut Name: "Instagram Follower Tracker"

Actions:
1. Ask for Input
   - "Select Instagram data file"
   - Type: File
   
2. Get File
   - From: [Provided Input]
   
3. Get Text from [File]

4. Match Text
   - Pattern: "\"value\"\\s*:\\s*\"([^\"]+)\""
   - Case Sensitive: OFF
   - Get Group: 1
   
5. Combine Text
   - [Matches]
   - Separator: ","
   
6. URL
   - saxtrack://import?type=followers&data=[Combined Text]
   
7. Open URLs
```

**Step 3: Set Up Automation**
- Run every week
- Or create Home Screen widget for quick access

---

## 🎨 Advanced Shortcuts

### Multi-Account Support

```
Shortcut: "Track Multiple Accounts"

1. Choose from Menu
   - Prompt: "Which account?"
   - Options: ["Main Account", "Business Account", "Secondary"]
   
2. If [Main Account]
   - Run shortcut "Import Main Followers"
   
3. Otherwise If [Business Account]
   - Run shortcut "Import Business Followers"
   
4. Otherwise
   - Run shortcut "Import Secondary Followers"
```

### Instagram Web Scraper (Advanced)

⚠️ **Warning**: Web scraping may violate Instagram's Terms of Service. Use at your own risk.

```
Shortcut: "Scrape Instagram Followers" (Concept Only)

1. Open URL: "https://www.instagram.com/[username]/followers"
2. Wait 2 seconds
3. Get Contents of Web Page
4. Match Text pattern for usernames
5. Pass to SaxTrack via URL scheme
```

### Export & Backup

```
Shortcut: "Export SaxTrack Data"

Actions:
1. Run shortcut "Get SaxTrack Stats"
2. Create text file with date
3. Save to Files (iCloud/Dropbox)
4. Show notification: "Backup complete"
```

---

## 🔔 Notification Triggers

### Set Up Change Alerts

1. Create shortcut that checks for changes
2. Use "If" conditions to detect new unfollowers
3. Send notification with details
4. Run on schedule (daily/weekly)

**Example:**
```
1. Run shortcut "Get SaxTrack Changes"
2. If [Changes > 0]
   - Show notification: "You have [X] new changes"
   - Open SaxTrack app
```

---

## 📊 Widget Integration (Future)

Coming soon:
- Home Screen widgets showing stats
- Lock Screen widgets for quick glance
- Interactive widgets for one-tap import

---

## 🔐 Privacy & Security

### What Gets Shared?
- Only usernames you explicitly import
- No passwords or authentication tokens
- Data never leaves your device

### Best Practices
- Don't share shortcuts that contain personal data
- Review shortcut permissions before running
- Use Face ID/Touch ID locks on sensitive shortcuts

---

## 🐛 Troubleshooting

### "Shortcut didn't work"
- Check URL format is correct
- Ensure usernames are comma-separated
- Verify SaxTrack app is installed

### "Import failed"
- Check for special characters in usernames
- Ensure data parameter isn't too long (URL limit: 2048 chars)
- Try importing in smaller batches

### "Automation not running"
- Check Shortcuts automation settings
- Disable "Ask Before Running"
- Ensure notification permissions enabled

---

## 📚 Resources

### Sample Shortcuts

Download pre-made shortcuts:

1. **Quick Import**: [Download](#)
2. **Scheduled Tracker**: [Download](#)
3. **Clipboard Monitor**: [Download](#)
4. **Change Notifier**: [Download](#)

### Video Tutorials

- Setting up your first shortcut
- Creating automations
- Advanced workflows

### Community Shortcuts

Share your shortcuts on:
- r/shortcuts
- SaxTrack GitHub Discussions
- Twitter #SaxTrack

---

## 💡 Pro Tips

### Tip 1: Batch Processing
Import followers and following separately for better tracking:
```
1. Import followers (type=followers)
2. Wait 1 second
3. Import following (type=following)
```

### Tip 2: Data Validation
Add a "Count Items" action to verify data before importing:
```
1. Split text by ","
2. Count items
3. Show alert: "Found [X] usernames. Continue?"
4. If confirmed → import
```

### Tip 3: Error Handling
Add try/catch logic:
```
1. Try: Run shortcut
2. If failed: Show notification
3. Retry or save data for manual import
```

### Tip 4: Combine with Other Apps
- Save exports to Notion/Airtable
- Create charts in Numbers
- Send reports via email
- Post stats to social media

---

## 🚀 Advanced Use Cases

### Business Analytics
```
Weekly Report Shortcut:
1. Import latest Instagram data
2. Get SaxTrack stats
3. Calculate growth rate
4. Create formatted report
5. Email to team
```

### Influencer Management
```
Client Tracking Shortcut:
1. Menu: Select client
2. Import their follower data
3. Compare to last week
4. Generate insights
5. Save to client folder
```

### Content Strategy
```
Engagement Tracker:
1. Import followers after each post
2. Track follower gain/loss
3. Correlate with post performance
4. Identify best posting times
```

---

## 📖 API Documentation

### URL Scheme Reference

**Scheme**: `saxtrack://`

**Endpoints**:
- `/import` - Import user data

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | `followers` or `following` |
| `data` | string | Yes | Comma-separated usernames or base64 encoded |

**Response**: App opens and processes import

**Error Handling**: Invalid URLs show error alert in app

---

## 🎓 Learning Resources

### Beginner
- [iOS Shortcuts Basics](https://support.apple.com/guide/shortcuts/)
- [Creating Your First Shortcut](#)
- [SaxTrack Quickstart](#)

### Intermediate
- [URL Schemes in Shortcuts](#)
- [Automation Triggers](#)
- [Data Processing](#)

### Advanced
- [Regular Expressions in Shortcuts](#)
- [Web Scraping Techniques](#)
- [Custom Shortcut Actions](#)

---

## 🤝 Contributing

Have a cool shortcut? Share it!

1. Test thoroughly
2. Document clearly
3. Submit via GitHub
4. Help others in discussions

---

**Need Help?** Open an issue on GitHub or join our community discussions!
