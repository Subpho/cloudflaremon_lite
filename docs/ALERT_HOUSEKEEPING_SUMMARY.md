# Alert History Housekeeping - Quick Summary

## 🎯 What Changed

Alert history cleanup is now **configurable** via `notifications.json` instead of being hardcoded.

---

## ⚙️ Configuration (notifications.json)

```json
{
  "settings": {
    "cooldownMinutes": 5,
    "repeatAlertMinutes": 60,
    "includeMetadata": true,
    "timezone": "UTC",
    "alertHistory": {
      "maxAlerts": 100,
      "maxAgeDays": 7,
      "cleanupOnAdd": true
    }
  }
}
```

---

## 📊 Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `maxAlerts` | 100 | Maximum number of alerts to keep |
| `maxAgeDays` | 7 | Maximum age of alerts in days |
| `cleanupOnAdd` | true | Cleanup when adding new alerts |

---

## 🧹 How It Works

### When Cleanup Runs
- **Automatically** - Every time a new alert is added (if `cleanupOnAdd: true`)
- **Process** - Removes old alerts and trims to max count

### Cleanup Logic

**Step 1: Remove by age**
```javascript
// Remove alerts older than maxAgeDays
const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
alerts = alerts.filter(alert => {
  const age = Date.now() - new Date(alert.timestamp).getTime();
  return age < maxAgeMs;
});
```

**Step 2: Trim by count**
```javascript
// Keep only last maxAlerts
if (alerts.length > maxAlerts) {
  alerts = alerts.slice(0, maxAlerts);
}
```

**Both conditions apply:**
- Alerts must be newer than `maxAgeDays` ✅
- Total count must not exceed `maxAlerts` ✅

---

## 📝 Examples

### Example 1: Default Settings
```json
{
  "maxAlerts": 100,
  "maxAgeDays": 7,
  "cleanupOnAdd": true
}
```
✅ Keeps up to 100 alerts
✅ Removes alerts older than 7 days
✅ Good for most users

### Example 2: High-Traffic System
```json
{
  "maxAlerts": 200,
  "maxAgeDays": 3,
  "cleanupOnAdd": true
}
```
✅ More alerts kept
✅ Shorter retention
✅ Prevents storage bloat

### Example 3: Long-Term History
```json
{
  "maxAlerts": 500,
  "maxAgeDays": 30,
  "cleanupOnAdd": true
}
```
✅ Extended retention
✅ Useful for trends
⚠️ Uses more storage

### Example 4: Manual Cleanup Only
```json
{
  "maxAlerts": 200,
  "maxAgeDays": 14,
  "cleanupOnAdd": false
}
```
❌ No automatic cleanup
⚠️ Alerts accumulate
⚠️ Requires manual intervention

---

## 📁 Files Modified

### 1. `notifications.json`
Added `alertHistory` settings to `settings` section.

### 2. `src/index.js`
- Added `cleanupAlerts()` function
- Updated `storeRecentAlert()` to use config
- Logs total alert count after cleanup

### 3. `src/notifications.js`
- Added `cleanupAlerts()` function (duplicate for module)
- Updated `storeServiceAlert()` to use config
- Logs total alert count after cleanup

### 4. `docs/ALERT_HISTORY_HOUSEKEEPING.md`
Complete documentation with:
- Configuration options
- Examples
- Troubleshooting
- Performance tips

### 5. `docs/ALERT_NOTIFICATIONS.md`
Updated "Configuration" section to reference housekeeping.

---

## 🔍 Monitoring

### Check Alert Count
```bash
curl https://mon.pipdor.com/api/alerts/recent | jq '.count'
```

### Check Worker Logs
Look for cleanup messages:
```
Stored alert for dashboard: Service Down: API (total: 87)
```

The `(total: N)` shows count after cleanup.

---

## 💾 Storage Impact

| Max Alerts | Approx Storage |
|-----------|----------------|
| 50 | ~15 KB |
| 100 | ~30 KB (default) |
| 200 | ~60 KB |
| 500 | ~150 KB |
| 1000 | ~300 KB |

Even at 1000 alerts, storage is minimal.

---

## 🚀 Deployment

### No Migration Required

```bash
# Just deploy
npx wrangler deploy
```

**What happens:**
1. Worker deployed with new code
2. Next alert triggers cleanup with new settings
3. Old alerts cleaned up automatically
4. No data loss (unless over limits)

### Update Configuration

**Before deployment (optional):**
```bash
# Edit notifications.json
nano notifications.json

# Deploy
npx wrangler deploy
```

**After deployment (if needed):**
```bash
# Edit notifications.json
# Trigger new alert to force cleanup
curl -X POST https://mon.pipdor.com/api/alert \
  -d '{"title":"Config Test","message":"Testing new settings"}'
```

---

## 🎨 Before vs After

### Before (Hardcoded)
```javascript
// Hardcoded 50 alerts max
const maxAlerts = 50;
if (alerts.length > maxAlerts) {
  alerts.splice(maxAlerts);
}
```
❌ Not configurable
❌ No age-based cleanup
❌ Fixed at 50

### After (Configurable)
```json
{
  "alertHistory": {
    "maxAlerts": 100,
    "maxAgeDays": 7,
    "cleanupOnAdd": true
  }
}
```
✅ Configurable via JSON
✅ Age-based cleanup
✅ Count-based cleanup
✅ Can disable if needed

---

## 🧪 Testing

### Test Locally

```bash
# 1. Set low limits for testing
# Edit notifications.json:
{
  "alertHistory": {
    "maxAlerts": 5,
    "maxAgeDays": 1,
    "cleanupOnAdd": true
  }
}

# 2. Start dev server
npx wrangler dev --local

# 3. Send 10 alerts
for i in {1..10}; do
  curl -X POST http://localhost:8787/api/alert \
    -d "{\"title\":\"Test $i\",\"message\":\"Testing\"}"
done

# 4. Check count (should be 5)
curl http://localhost:8787/api/alerts/recent | jq '.count'
```

**Expected:** Only 5 alerts stored ✅

---

## ⚠️ Important Notes

### What Gets Cleaned Up
- ✅ External alerts (from `/api/alert`)
- ✅ Service status change alerts (down/up/degraded)
- ✅ All alert types in unified feed

### What Doesn't Get Cleaned Up
- ❌ Notification history in external channels (Discord, Slack)
- ❌ Worker logs
- ❌ Other KV data (monitor data, heartbeats)

### Cleanup Timing
- **Immediate:** Next alert triggers cleanup
- **Not retroactive:** Old alerts remain until next cleanup
- **No scheduled job:** Only happens on new alerts

---

## 📚 Related Documentation

- **[Alert History Housekeeping](./docs/ALERT_HISTORY_HOUSEKEEPING.md)** - Complete guide
- **[Alert Notifications](./docs/ALERT_NOTIFICATIONS.md)** - Main notification docs
- **[Unified Alerts Summary](./UNIFIED_ALERTS_SUMMARY.md)** - System overview

---

## ✅ Summary

🎯 **Configurable via `notifications.json`**
- `maxAlerts`: 100 (default)
- `maxAgeDays`: 7 days (default)
- `cleanupOnAdd`: true (default)

🧹 **Automatic cleanup**
- Runs on every new alert
- Removes old alerts by age
- Trims to max count

💾 **Storage efficient**
- Default: ~30 KB for 100 alerts
- Keeps KV storage small

🚀 **Zero downtime**
- Deploy and forget
- Works immediately
- No migration needed

**The default settings (100 alerts, 7 days) work great for most users!** 🎉

