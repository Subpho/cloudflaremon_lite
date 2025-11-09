# Alert History Housekeeping

Configuration for automatic cleanup of old dashboard alerts.

---

## 📋 Overview

Alert history housekeeping automatically cleans up old alerts to:
- **Limit storage** - Keep KV storage under control
- **Improve performance** - Faster dashboard loading
- **Remove stale data** - Keep only relevant recent alerts

**When cleanup happens:**
- Every time a new alert is added (if `cleanupOnAdd: true`)
- Can be manually triggered via API (optional)

---

## ⚙️ Configuration

Edit `notifications.json`:

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

### Configuration Options

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `maxAlerts` | number | 100 | Maximum number of alerts to keep |
| `maxAgeDays` | number | 7 | Maximum age of alerts in days |
| `cleanupOnAdd` | boolean | true | Clean up when adding new alerts |

---

## 🧹 How Cleanup Works

### Process

1. **New alert arrives** (external or service status change)
2. **Alert stored** in KV (`recent:alerts`)
3. **Cleanup triggered** (if `cleanupOnAdd: true`)
4. **Age check** - Remove alerts older than `maxAgeDays`
5. **Count check** - Keep only last `maxAlerts` entries
6. **Updated list** saved to KV

### Cleanup Logic

```javascript
// 1. Remove old alerts (by age)
const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
const now = Date.now();

alerts = alerts.filter(alert => {
  const alertTime = new Date(alert.timestamp).getTime();
  const age = now - alertTime;
  return age < maxAgeMs;
});

// 2. Trim to max count
if (alerts.length > maxAlerts) {
  alerts = alerts.slice(0, maxAlerts);
}
```

**Both conditions are applied:**
- Alerts must be newer than `maxAgeDays`
- Total count must not exceed `maxAlerts`

---

## 📊 Examples

### Example 1: Keep Last 100 Alerts (Default)

```json
{
  "alertHistory": {
    "maxAlerts": 100,
    "maxAgeDays": 7,
    "cleanupOnAdd": true
  }
}
```

**Behavior:**
- ✅ Keeps up to 100 most recent alerts
- ✅ Removes alerts older than 7 days
- ✅ Cleans up on every new alert

### Example 2: Keep More History

```json
{
  "alertHistory": {
    "maxAlerts": 500,
    "maxAgeDays": 30,
    "cleanupOnAdd": true
  }
}
```

**Behavior:**
- ✅ Keeps up to 500 alerts
- ✅ Keeps alerts for 30 days
- ⚠️ Uses more KV storage

### Example 3: Minimal Storage

```json
{
  "alertHistory": {
    "maxAlerts": 50,
    "maxAgeDays": 3,
    "cleanupOnAdd": true
  }
}
```

**Behavior:**
- ✅ Keeps only 50 alerts
- ✅ Only last 3 days
- ✅ Minimal KV storage usage

### Example 4: Manual Cleanup Only

```json
{
  "alertHistory": {
    "maxAlerts": 200,
    "maxAgeDays": 14,
    "cleanupOnAdd": false
  }
}
```

**Behavior:**
- ❌ No automatic cleanup
- ✅ Alerts accumulate indefinitely
- ⚠️ Requires manual cleanup
- ⚠️ KV storage may grow large

---

## 🔍 Monitoring

### Check Alert Count

**Via API:**
```bash
curl https://mon.pipdor.com/api/alerts/recent | jq '.count'
```

**Expected output:**
```json
{
  "success": true,
  "count": 87,
  "alerts": [...]
}
```

### Check Oldest Alert

```bash
curl https://mon.pipdor.com/api/alerts/recent?limit=1000 | \
  jq '.alerts[-1].timestamp'
```

**Example output:**
```
"2025-11-08T10:30:45.000Z"
```

### Worker Logs

Look for cleanup messages:
```
Stored alert for dashboard: Service Down: Internal API (total: 87)
```

The `(total: N)` shows the count after cleanup.

---

## 💾 Storage Impact

### KV Storage Calculation

**Average alert size:** ~300 bytes

| Max Alerts | Approx Storage |
|-----------|----------------|
| 50 | ~15 KB |
| 100 | ~30 KB |
| 200 | ~60 KB |
| 500 | ~150 KB |
| 1000 | ~300 KB |

**Cloudflare KV limits:**
- Value size: 25 MB (max)
- Storage: 1 GB (free plan)

Even at 1000 alerts, you'll use < 1 MB.

---

## 🎯 Best Practices

### Recommended Settings by Use Case

#### High-Traffic System (lots of alerts)
```json
{
  "maxAlerts": 200,
  "maxAgeDays": 3,
  "cleanupOnAdd": true
}
```
- Keeps recent alerts
- Prevents storage bloat
- Fast cleanup

#### Low-Traffic System (few alerts)
```json
{
  "maxAlerts": 500,
  "maxAgeDays": 30,
  "cleanupOnAdd": true
}
```
- Long history retention
- Useful for trends
- Minimal storage impact

#### Compliance/Audit Requirements
```json
{
  "maxAlerts": 1000,
  "maxAgeDays": 90,
  "cleanupOnAdd": true
}
```
- Extended retention
- Meets audit requirements
- Archive before cleanup (optional)

### Tips

1. **Start conservative** - Use default `100/7 days`
2. **Monitor storage** - Check KV usage in Cloudflare dashboard
3. **Adjust as needed** - Increase if alerts disappear too fast
4. **Consider external logging** - For long-term retention, send to external system

---

## 🚨 Troubleshooting

### Issue: Alerts disappearing too quickly

**Cause:** `maxAgeDays` too low or `maxAlerts` too small

**Solution:**
```json
{
  "maxAlerts": 200,    // Increase
  "maxAgeDays": 14     // Increase
}
```

### Issue: Old alerts not being removed

**Cause:** `cleanupOnAdd: false` or alerts not being added

**Check:**
1. Verify `cleanupOnAdd: true` in config
2. Check worker logs for cleanup messages
3. Verify new alerts are being added

**Manual cleanup:**
```bash
# Get current alerts
curl https://mon.pipdor.com/api/alerts/recent?limit=1000 > alerts.json

# Count them
cat alerts.json | jq '.count'

# If too many, adjust config and trigger new alert to force cleanup
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{"title":"Cleanup Trigger","message":"Force cleanup","severity":"info"}'
```

### Issue: Storage growing despite cleanup

**Check:**
1. Verify cleanup is running (check logs)
2. Check for other KV keys: `npx wrangler kv:key list`
3. Confirm `maxAlerts` setting is reasonable
4. Check if multiple workers are writing alerts

**Debug:**
```javascript
// In worker logs, add before cleanup:
console.log(`Before cleanup: ${alerts.length} alerts`);
alerts = cleanupAlerts(alerts, historyConfig);
console.log(`After cleanup: ${alerts.length} alerts`);
```

---

## 📈 Performance

### Cleanup Performance

| Alert Count | Cleanup Time |
|------------|--------------|
| 100 | < 1 ms |
| 500 | < 5 ms |
| 1000 | < 10 ms |

Cleanup is fast and doesn't impact alert storage performance.

### Dashboard Load Performance

| Alert Count | Load Time |
|------------|-----------|
| 50 | Fast |
| 100 | Fast |
| 500 | Moderate |
| 1000+ | Slower |

**Recommendation:** Keep `maxAlerts` ≤ 200 for optimal dashboard performance.

---

## 🔄 Migration from Old System

### Before (Hardcoded)

```javascript
// Old code (hardcoded 50)
const maxAlerts = 50;
if (alerts.length > maxAlerts) {
  alerts.splice(maxAlerts);
}
```

### After (Configurable)

```javascript
// New code (configurable)
const historyConfig = notificationsConfig?.settings?.alertHistory || {};
if (historyConfig.cleanupOnAdd !== false) {
  alerts = cleanupAlerts(alerts, historyConfig);
}
```

**No migration needed!** Just deploy and adjust `notifications.json`.

**Default behavior:**
- Old: 50 alerts, no age limit
- New: 100 alerts, 7 days max age
- Both: Cleanup on add

---

## 🧪 Testing

### Test Cleanup Locally

```bash
# 1. Set aggressive cleanup
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

# 3. Send 10 test alerts
for i in {1..10}; do
  curl -X POST http://localhost:8787/api/alert \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Test $i\",\"message\":\"Testing cleanup\",\"severity\":\"info\"}"
  sleep 1
done

# 4. Check count (should be 5)
curl http://localhost:8787/api/alerts/recent | jq '.count'
```

**Expected:** Only 5 most recent alerts stored.

### Test Age-Based Cleanup

```bash
# 1. Create old alert manually (requires KV access)
# Use Wrangler to add old alert with past timestamp

# 2. Trigger new alert (forces cleanup)
curl -X POST http://localhost:8787/api/alert \
  -d '{"title":"New","message":"Trigger cleanup"}'

# 3. Check that old alert is gone
curl http://localhost:8787/api/alerts/recent?limit=100
```

---

## 📚 Related Documentation

- [Alert Notifications](./ALERT_NOTIFICATIONS.md) - Main notification docs
- [Unified Alerts Summary](/UNIFIED_ALERTS_SUMMARY.md) - System overview
- [Notifications Configuration](../notifications.json) - Config file

---

## ✅ Summary

✨ **Configurable cleanup** via `notifications.json`
🧹 **Automatic housekeeping** on every alert
⚙️ **Two limits** - count and age
💾 **Storage efficient** - keeps KV small
🚀 **Zero downtime** - works immediately after deploy

**Default settings (100 alerts, 7 days) work well for most users!** 🎉

