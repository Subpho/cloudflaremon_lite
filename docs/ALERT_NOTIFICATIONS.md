# Alert Notifications Feature

Real-time notification system that shows toast notifications in the dashboard when external alerts are received via `/api/alert`.

## 🎉 Features

- **📱 Toast Notifications** - In-page notifications with title, message, and severity
- **🔔 Browser Notifications** - System notifications (optional, requires permission)
- **🎨 Severity Colors** - Critical (red), Warning (yellow), Info (blue)
- **⏰ Auto-dismiss** - Toast notifications auto-close after 10 seconds
- **🔄 Real-time Polling** - Checks for new alerts every 10 seconds
- **💾 Persistent State** - Remembers last seen alert (no duplicates)

---

## 📊 How It Works

### 1. **Alert Received**
When someone calls `/api/alert`:
```bash
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "High CPU Usage",
    "message": "Server CPU usage at 95%",
    "severity": "warning"
  }'
```

### 2. **Alert Stored**
- Alert is stored in KV (`recent:alerts`)
- Kept for up to 50 most recent alerts
- Includes timestamp, title, message, severity

### 3. **Dashboard Polls**
- Dashboard checks `/api/alerts/recent` every 10 seconds
- Only fetches alerts since last seen timestamp
- Prevents showing duplicates

### 4. **Notification Shown**
- **Toast notification** slides in from right
- **Browser notification** shown (if permitted)
- Auto-dismisses after 10 seconds
- User can manually close anytime

---

## 🎨 Notification Appearance

### Toast Notification (In-Page)

```
┌─────────────────────────────────────┐
│ 🚨 High CPU Usage            ×    │
│                                     │
│ Server CPU usage at 95%             │
│ 11/8/2025, 2:30:45 PM              │
└─────────────────────────────────────┘
```

- **Critical**: 🚨 Red border
- **Warning**: ⚠️  Yellow border
- **Info**: ℹ️  Blue border

### Browser Notification (System)

Shows as a system notification (Windows/Mac/Linux):
```
─────────────────────────────
⚠️ High CPU Usage

Server CPU usage at 95%
─────────────────────────────
```

---

## 🔧 Usage Examples

### Example 1: Send a Critical Alert

```bash
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Service Down",
    "message": "Production API is not responding",
    "severity": "critical",
    "source": "monitoring-system"
  }'
```

**Result:** 🚨 Red toast notification appears on dashboard

### Example 2: Send a Warning Alert

```bash
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Disk Space Low",
    "message": "Only 10% disk space remaining",
    "severity": "warning"
  }'
```

**Result:** ⚠️ Yellow toast notification appears

### Example 3: Send from Grafana

```bash
# Grafana webhook format
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "CPU Alert",
    "state": "alerting",
    "message": "CPU usage above threshold",
    "ruleName": "High CPU Alert"
  }'
```

### Example 4: Send from Alertmanager

```bash
# Prometheus Alertmanager format
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "HighMemoryUsage",
        "severity": "warning"
      },
      "annotations": {
        "summary": "Memory usage is high",
        "description": "Memory usage at 85%"
      }
    }]
  }'
```

---

## 🔔 Browser Notifications

### Enabling Browser Notifications

1. **Dashboard will auto-request permission** on first alert
2. **Or manually enable:**
   - Chrome: Click 🔔 icon in address bar
   - Firefox: Click ⓘ icon → Permissions
   - Safari: Safari → Preferences → Websites → Notifications

### Permission States

- **Granted** ✅ - Notifications shown
- **Denied** ❌ - Only toast notifications shown
- **Default** ⚠️ - Will ask for permission on first alert

### Example: Request Permission Manually

```javascript
// In browser console
Notification.requestPermission().then(permission => {
  console.log('Permission:', permission);
});
```

---

## ⚙️ API Endpoints

### POST `/api/alert`

Send an alert (triggers notification)

**Request:**
```json
{
  "title": "Alert Title",
  "message": "Alert message details",
  "severity": "warning"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Alert processed and notifications sent",
  "alertTitle": "Alert Title"
}
```

### GET `/api/alerts/recent`

Fetch recent alerts

**Parameters:**
- `since` (optional) - ISO timestamp, only return alerts after this time
- `limit` (optional) - Max number of alerts (default: 20)

**Request:**
```bash
GET /api/alerts/recent?since=2025-11-08T10:00:00Z&limit=10
```

**Response:**
```json
{
  "success": true,
  "count": 3,
  "alerts": [
    {
      "id": "alert:1730000000000:abc123",
      "title": "High CPU Usage",
      "message": "Server CPU usage at 95%",
      "severity": "warning",
      "source": "external",
      "timestamp": "2025-11-08T14:30:00Z",
      "read": false
    }
  ]
}
```

---

## 🎯 Configuration

### Check Interval

Default: Every 10 seconds

**To change:**
Edit line 2547 in `src/index.js`:
```javascript
const ALERT_CHECK_INTERVAL = 10000; // milliseconds
```

### Auto-dismiss Timeout

Default: 10 seconds

**To change:**
Edit line 2589 in `src/index.js`:
```javascript
setTimeout(() => {
    closeToast(toast);
}, 10000); // milliseconds
```

### Maximum Stored Alerts

Default: 50 alerts

**To change:**
Edit line 635 in `src/index.js`:
```javascript
const maxAlerts = 50;
```

---

## 🔍 How It Works Internally

### Flow Diagram

```
┌──────────────┐
│ External     │
│ System       │
└──────┬───────┘
       │
       │ POST /api/alert
       ▼
┌──────────────────────┐
│ Cloudflare Worker    │
│ - Parse alert        │
│ - Send notifications │
│ - Store in KV        │
└──────┬───────────────┘
       │
       │ Stored in KV
       ▼
┌──────────────────────┐
│ recent:alerts        │
│ [list of 50 alerts]  │
└──────┬───────────────┘
       │
       │ Polled every 10s
       ▼
┌──────────────────────┐
│ Dashboard            │
│ GET /api/alerts/     │
│     recent?since=    │
└──────┬───────────────┘
       │
       │ New alerts?
       ▼
┌──────────────────────┐
│ Show Notifications   │
│ - Toast (in-page)    │
│ - Browser (system)   │
└──────────────────────┘
```

### Data Storage

**KV Key:** `recent:alerts`

**Format:**
```json
[
  {
    "id": "alert:timestamp:random",
    "title": "string",
    "message": "string",
    "severity": "critical|warning|info",
    "source": "string",
    "timestamp": "ISO-8601",
    "read": false
  }
]
```

---

## 🐛 Troubleshooting

### Issue: No notifications appearing

**Check:**
1. Dashboard is open and running
2. Browser console for errors
3. Alerts are being stored: `GET /api/alerts/recent`
4. No JavaScript errors in console

**Debug:**
```javascript
// In browser console
localStorage.getItem('last-alert-timestamp'); // Check last seen
```

### Issue: Duplicate notifications

**Cause:** Multiple dashboard tabs open

**Solution:** Close extra tabs or clear:
```javascript
localStorage.removeItem('last-alert-timestamp');
```

### Issue: Browser notifications not showing

**Check:**
1. Permission granted: `Notification.permission`
2. Browser supports: `'Notification' in window`
3. Not in incognito/private mode
4. System "Do Not Disturb" mode off

**Debug:**
```javascript
// Check permission
console.log(Notification.permission);

// Request permission
Notification.requestPermission();
```

### Issue: Toast appearing off-screen

**Mobile devices:** Toasts automatically adjust to screen width

**Fix manually:**
```css
@media (max-width: 768px) {
    .alert-toast-container {
        left: 20px;
        right: 20px;
    }
}
```

---

## 📱 Mobile Compatibility

- ✅ **Toast notifications** work on all devices
- ⚠️ **Browser notifications** vary by mobile browser:
  - **iOS Safari:** Not supported
  - **Android Chrome:** Supported
  - **Android Firefox:** Supported

---

## 🔒 Security

### Authentication

**Optional:** Set `ALERT_API_KEY` environment variable to require authentication:

```bash
# In Cloudflare dashboard or wrangler
ALERT_API_KEY=your-secret-alert-key
```

**Usage:**
```bash
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Authorization: Bearer your-secret-alert-key" \
  -d '{"title":"Alert","message":"Test"}'
```

### Rate Limiting

**Dashboard polling:** Every 10 seconds (6 requests/minute)

**Recommendation:** Add Cloudflare rate limiting if needed:
- Dashboard: 6 req/min per IP
- Alert submission: 60 req/min per IP

---

## 🚀 Quick Start

### 1. Deploy the Updated Worker

```bash
npx wrangler deploy
```

### 2. Open Dashboard

```
https://mon.pipdor.com
```

### 3. Send a Test Alert

```bash
curl -X POST https://mon.pipdor.com/api/alert \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Alert",
    "message": "This is a test notification",
    "severity": "info"
  }'
```

### 4. See Notification

- Toast notification slides in from right ✅
- Browser notification (if permitted) 🔔
- Auto-dismisses after 10 seconds ⏰

---

## 📊 Examples with Different Tools

### Prometheus Alertmanager

```yaml
# alertmanager.yml
receivers:
  - name: 'cloudflare-monitor'
    webhook_configs:
      - url: 'https://mon.pipdor.com/api/alert'
        send_resolved: true
```

### Grafana

```json
{
  "url": "https://mon.pipdor.com/api/alert",
  "httpMethod": "POST"
}
```

### Custom Script

```python
import requests

def send_alert(title, message, severity='warning'):
    requests.post('https://mon.pipdor.com/api/alert', json={
        'title': title,
        'message': message,
        'severity': severity
    })

send_alert('Backup Failed', 'Daily backup did not complete', 'critical')
```

---

## ✨ Summary

- ✅ **Real-time notifications** for external alerts
- ✅ **Toast + Browser notifications** with auto-dismiss
- ✅ **Severity-based styling** (critical, warning, info)
- ✅ **10-second polling** for new alerts
- ✅ **No duplicates** via timestamp tracking
- ✅ **Works with Grafana, Alertmanager, custom integrations**
- ✅ **Mobile-responsive** design
- ✅ **Optional authentication** via ALERT_API_KEY

Your dashboard now shows real-time alerts as they arrive! 🎉

