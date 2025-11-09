# Unified Alert Notifications - Summary

## 🎯 What Changed

The alert notification system now includes **BOTH** external alerts and service status changes in a **unified dashboard notification feed**.

---

## ✨ New Features

### 1. **Unified Alert Feed**
Dashboard notifications now show:
- ✅ **External alerts** from `/api/alert` (Grafana, Alertmanager, custom)
- ✅ **Service status changes** from heartbeat monitoring (down/up/degraded)
- ✅ All in one real-time notification feed

### 2. **Automatic Service Status Alerts**
When services change status:

| Event | Severity | Example |
|-------|----------|---------|
| Service goes down | 🚨 Critical | "Service Down: Internal API" |
| Service recovers | ℹ️ Info | "Service Recovered: Internal API" |
| Service degraded | ⚠️ Warning | "Service Degraded: Internal API" |

### 3. **Respects Notification Settings**
- Uses cooldown period from `notifications.json`
- Honors per-service notification preferences
- Same alert visible in external channels (Discord, Slack) AND dashboard

---

## 📝 Files Modified

### 1. `/src/notifications.js`
**Added:**
- `storeServiceAlert()` function to save service status changes to KV
- Integrated with existing `checkAndSendNotifications()` function
- Stores alerts in same format as external alerts

**Changes:**
```javascript
// Before: Only sent to external channels
await sendNotifications(env, eventType, result, serviceConfig);

// After: Sends to external channels AND stores for dashboard
await sendNotifications(env, eventType, result, serviceConfig);
await storeServiceAlert(env, eventType, result);  // NEW
```

### 2. `/docs/ALERT_NOTIFICATIONS.md`
**Updated:**
- Added "Alert Sources" section explaining both types
- Added service status change examples
- Updated flow diagram to show both sources
- Added local testing instructions for service status changes
- Updated data storage format with examples

### 3. `/test-all-notifications.sh`
**Created:**
- Comprehensive test script for both alert types
- Tests external alerts (critical, warning, info)
- Tests Grafana and Alertmanager formats
- Establishes service heartbeat for status change testing
- Verifies alert storage

---

## 🔄 How It Works

```
┌─────────────────────┐           ┌─────────────────────┐
│  External System    │           │ Heartbeat Monitor   │
│  (Grafana, etc.)    │           │  (Cron Checks)      │
└──────────┬──────────┘           └──────────┬──────────┘
           │                                  │
           │ POST /api/alert                  │ Status change
           │                                  │ detected
           ▼                                  ▼
┌──────────────────────────────────────────────────────┐
│              Cloudflare Worker                        │
│  ┌────────────────────┐   ┌─────────────────────┐   │
│  │ handleCustomAlert  │   │ storeServiceAlert   │   │
│  │ (external)         │   │ (status change)     │   │
│  └──────────┬─────────┘   └──────────┬──────────┘   │
│             │                        │               │
│             └────────────┬───────────┘               │
│                          │                           │
│                  ┌───────▼────────┐                  │
│                  │ recent:alerts  │                  │
│                  │ [Unified feed] │                  │
│                  └───────┬────────┘                  │
└──────────────────────────┼───────────────────────────┘
                           │
                           │ Polled every 10s
                           ▼
                  ┌────────────────┐
                  │   Dashboard    │
                  │  Notifications │
                  └────────────────┘
```

---

## 📊 Alert Format

### External Alert
```json
{
  "id": "alert:1731085512000:abc123",
  "title": "High CPU Usage",
  "message": "Server CPU usage at 95%",
  "severity": "warning",
  "source": "grafana",
  "timestamp": "2025-11-08T15:45:12.000Z",
  "read": false
}
```

### Service Status Change
```json
{
  "id": "alert:1731085512000:def456",
  "title": "Service Down: Internal API",
  "message": "Internal API is not responding. Last seen: 11/8/2025, 3:45:12 PM",
  "severity": "critical",
  "source": "heartbeat-monitor",
  "timestamp": "2025-11-08T15:45:12.000Z",
  "read": false,
  "serviceId": "service-1",
  "status": "down"
}
```

**Key differences:**
- `source`: "heartbeat-monitor" for service status changes
- `serviceId`: Identifies which service changed
- `status`: "down", "up", or "degraded"

---

## 🧪 Testing

### Local Testing - Quick Start

```bash
# 1. Start local dev server
npx wrangler dev --local

# 2. Run comprehensive test
./test-all-notifications.sh

# 3. Open dashboard
open http://localhost:8787
```

### Test External Alert
```bash
curl -X POST http://localhost:8787/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Alert",
    "message": "Testing external alerts",
    "severity": "warning"
  }'
```

### Trigger Service Status Change

**Step 1: Establish service as "up"**
```bash
curl -X POST http://localhost:8787/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "service-1"}'
```

**Step 2: Wait for cron check (or stop sending heartbeats)**

**Step 3: Service goes "down" → Alert shown**
```
🚨 Service Down: [Service Name]
[Service Name] is not responding. Last seen: [timestamp]
```

**Step 4: Resume heartbeats**
```bash
curl -X POST http://localhost:8787/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "service-1"}'
```

**Step 5: Service goes "up" → Alert shown**
```
ℹ️ Service Recovered: [Service Name]
[Service Name] has recovered and is now operational.
```

---

## 🎨 Dashboard Appearance

### External Alert Toast
```
┌─────────────────────────────────────┐
│ ⚠️ High CPU Usage            ×    │
│                                     │
│ Server CPU usage at 95%             │
│ 11/8/2025, 3:45:12 PM              │
│ Source: grafana                     │
└─────────────────────────────────────┘
```

### Service Status Change Toast
```
┌─────────────────────────────────────┐
│ 🚨 Service Down: Internal API  ×  │
│                                     │
│ Internal API is not responding.     │
│ Last seen: 11/8/2025, 3:45:12 PM   │
│ Source: heartbeat-monitor           │
└─────────────────────────────────────┘
```

---

## 🔧 Configuration

### Service Status Alerts

Controlled by `notifications.json`:

```json
{
  "enabled": true,
  "settings": {
    "cooldownMinutes": 5  // Wait 5 min between status change alerts
  },
  "channels": [
    {
      "type": "discord",
      "enabled": true,
      "events": ["down", "up", "degraded"]  // Which status changes to send
    }
  ]
}
```

### Per-Service Notification Control

In `services.json`:

```json
{
  "id": "service-1",
  "name": "Internal API",
  "notifications": {
    "enabled": true,     // Enable/disable for this service
    "channels": ["discord"]  // Optional: limit to specific channels
  }
}
```

---

## 📈 Benefits

### 1. **Unified View**
- All alerts in one place
- No need to check multiple systems
- Real-time updates every 10 seconds

### 2. **Complete Coverage**
- External monitoring tools (Grafana, Prometheus)
- Internal heartbeat monitoring
- No alerts missed

### 3. **Consistent Experience**
- Same toast notification style
- Same severity colors (red, yellow, blue)
- Same auto-dismiss behavior

### 4. **Flexible Configuration**
- Control which services send alerts
- Set cooldown periods
- Choose notification channels
- Per-service preferences

---

## 🚀 Deployment

### No Changes Required!

The feature works automatically once deployed:

```bash
npx wrangler deploy
```

**What happens:**
1. Worker deployed with updated code
2. Cron jobs continue running on schedule
3. Next service status change → Alert stored
4. Dashboard polls → Alert shown
5. No configuration changes needed

### Verify It's Working

**Check recent alerts:**
```bash
curl https://mon.pipdor.com/api/alerts/recent | jq
```

**Expected response:**
```json
{
  "success": true,
  "count": 5,
  "alerts": [
    {
      "title": "Service Recovered: Internal API",
      "source": "heartbeat-monitor",
      "severity": "info",
      ...
    },
    {
      "title": "High CPU Usage",
      "source": "grafana",
      "severity": "warning",
      ...
    }
  ]
}
```

---

## 📚 Documentation

Updated documentation:
- ✅ `/docs/ALERT_NOTIFICATIONS.md` - Complete guide
- ✅ Alert sources explained
- ✅ Service status change examples
- ✅ Local testing instructions
- ✅ Flow diagrams updated
- ✅ Data format examples

Test scripts:
- ✅ `/test-all-notifications.sh` - Comprehensive test
- ✅ Tests both external alerts and service status changes

---

## 💡 Use Cases

### Use Case 1: External Monitoring
**Scenario:** Grafana detects high CPU usage

**Flow:**
1. Grafana sends webhook to `/api/alert`
2. Alert stored in KV
3. Dashboard polls and shows toast notification
4. User sees: "⚠️ High CPU Usage"

### Use Case 2: Service Goes Down
**Scenario:** Database stops sending heartbeats

**Flow:**
1. Cron job runs, checks heartbeat staleness
2. Detects service is down
3. Sends Discord notification
4. Stores alert for dashboard
5. Dashboard polls and shows toast notification
6. User sees: "🚨 Service Down: Database"

### Use Case 3: Service Recovers
**Scenario:** Database resumes sending heartbeats

**Flow:**
1. Cron job runs, checks heartbeat
2. Detects service is back up
3. Sends Discord notification
4. Stores alert for dashboard
5. Dashboard polls and shows toast notification
6. User sees: "ℹ️ Service Recovered: Database"

---

## ✅ Summary

✨ **One unified alert feed** for all notifications
📱 **Real-time dashboard updates** every 10 seconds
🔔 **No missed alerts** from any source
⚙️ **Fully configurable** per service and channel
🚀 **Zero configuration** required - works automatically

**Both external alerts AND service status changes are now visible on your dashboard!** 🎉

