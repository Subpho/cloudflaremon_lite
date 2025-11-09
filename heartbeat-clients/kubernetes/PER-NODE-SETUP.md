# Per-Node Service ID Setup

## 🎯 Problem

In Kubernetes DaemonSet deployments, each node needs a **unique service ID** in `config/services.json`. 

- ❌ **Wrong:** All nodes report as the same service ID (e.g., `k8s-cluster`)
- ✅ **Correct:** Each node reports as a unique service (e.g., `k8s-node-1`, `k8s-node-2`)

---

## 📝 Solution

The DaemonSet now uses a **service ID prefix** that combines with the node name to create unique IDs.

### How It Works

```
Service ID Prefix: "k8s-"
Node Name: "node-1"
Result: "k8s-node-1" ✅
```

```
Service ID Prefix: "prod-k8s-"
Node Name: "worker-3"
Result: "prod-k8s-worker-3" ✅
```

---

## 🚀 Setup Steps

### Step 1: Generate Service Configuration

Use the helper script to generate `services.json` entries for all your nodes:

```bash
cd heartbeat-clients/kubernetes

# Make script executable
chmod +x generate-services-config.sh

# Generate configuration
./generate-services-config.sh
```

**Output Example (3 nodes):**
```json
{
  "groups": [
    {
      "id": "kubernetes",
      "name": "Kubernetes Cluster",
      "services": [
        "k8s-node-1",
        "k8s-node-2",
        "k8s-node-3"
      ],
      "stalenessThreshold": 300,
      "auth": {"required": false}
    }
  ],
  "services": [
    {
      "id": "k8s-node-1",
      "name": "K8s Node: node-1",
      "description": "Kubernetes control-plane node (10.0.1.10)",
      "enabled": true
    },
    {
      "id": "k8s-node-2",
      "name": "K8s Node: node-2",
      "description": "Kubernetes worker node (10.0.1.11)",
      "enabled": true
    },
    {
      "id": "k8s-node-3",
      "name": "K8s Node: node-3",
      "description": "Kubernetes worker node (10.0.1.12)",
      "enabled": true
    }
  ]
}
```

### Step 2: Merge into services.json

Add the generated configuration to your `config/services.json`:

**Before:**
```json
{
  "groups": [
    {"id": "core-services", "services": ["service-1"], ...}
  ],
  "services": [
    {"id": "service-1", "name": "Internal API", ...}
  ]
}
```

**After (merged):**
```json
{
  "groups": [
    {"id": "core-services", "services": ["service-1"], ...},
    {"id": "kubernetes", "services": ["k8s-node-1", "k8s-node-2", "k8s-node-3"], ...}
  ],
  "services": [
    {"id": "service-1", "name": "Internal API", ...},
    {"id": "k8s-node-1", "name": "K8s Node: node-1", ...},
    {"id": "k8s-node-2", "name": "K8s Node: node-2", ...},
    {"id": "k8s-node-3", "name": "K8s Node: node-3", ...}
  ]
}
```

### Step 3: Configure DaemonSet

Edit `heartbeat-daemonset.yaml`:

```yaml
stringData:
  worker-url: "https://mon.pipdor.com/api/heartbeat"
  service-id-prefix: "k8s-"  # ✅ Must match your services.json!
  api-key: "your-secret-key-here"
```

**Important:** The prefix `k8s-` will be combined with node names to create `k8s-node-1`, `k8s-node-2`, etc.

### Step 4: Deploy

```bash
kubectl apply -f heartbeat-daemonset.yaml
```

### Step 5: Verify

```bash
# Check logs to see unique service IDs
kubectl logs -n monitoring -l app=heartbeat-client --tail=5 -f
```

**Expected output:**
```
# From pod on node-1:
[Sun Nov  9 10:00:00 UTC 2025] Sending heartbeat for service: k8s-node-1 (node: node-1)
[Sun Nov  9 10:00:00 UTC 2025] ✓ Heartbeat sent successfully

# From pod on node-2:
[Sun Nov  9 10:00:00 UTC 2025] Sending heartbeat for service: k8s-node-2 (node: node-2)
[Sun Nov  9 10:00:00 UTC 2025] ✓ Heartbeat sent successfully
```

---

## 🎨 Customization

### Different Prefix

```bash
# Generate with custom prefix
SERVICE_ID_PREFIX='prod-k8s-' ./generate-services-config.sh
```

Then update the DaemonSet:
```yaml
stringData:
  service-id-prefix: "prod-k8s-"
```

Result: `prod-k8s-node-1`, `prod-k8s-node-2`, etc.

### Multiple Clusters

**Cluster 1 (Production):**
```yaml
service-id-prefix: "prod-k8s-"
```
Services: `prod-k8s-node-1`, `prod-k8s-node-2`

**Cluster 2 (Staging):**
```yaml
service-id-prefix: "staging-k8s-"
```
Services: `staging-k8s-node-1`, `staging-k8s-node-2`

---

## 🔍 Verification

### Check Dashboard

Visit your dashboard: `https://mon.pipdor.com`

You should see separate entries for each node:
- ✅ K8s Node: node-1 (Status: Up)
- ✅ K8s Node: node-2 (Status: Up)
- ✅ K8s Node: node-3 (Status: Up)

### Check API

```bash
curl https://mon.pipdor.com/api/status | jq '.services[] | select(.id | startswith("k8s-"))'
```

**Expected:**
```json
{
  "id": "k8s-node-1",
  "name": "K8s Node: node-1",
  "status": "up",
  "lastHeartbeat": "2025-11-09T10:00:00.000Z"
}
{
  "id": "k8s-node-2",
  "name": "K8s Node: node-2",
  "status": "up",
  "lastHeartbeat": "2025-11-09T10:00:05.000Z"
}
```

---

## 🔄 Adding/Removing Nodes

### When Adding New Nodes

1. Node joins cluster
2. DaemonSet automatically creates pod on new node
3. **Add the new service to `config/services.json`:**

```json
{
  "groups": [
    {
      "id": "kubernetes",
      "services": [
        "k8s-node-1",
        "k8s-node-2",
        "k8s-node-3",
        "k8s-node-4"  // ← Add new node
      ]
    }
  ],
  "services": [
    // ... existing services ...
    {
      "id": "k8s-node-4",  // ← Add new service
      "name": "K8s Node: node-4",
      "enabled": true
    }
  ]
}
```

4. Deploy updated config:
```bash
npx wrangler deploy
```

### When Removing Nodes

1. Drain and remove node from cluster
2. DaemonSet pod automatically deleted
3. **Optionally disable** the service in `services.json`:

```json
{
  "id": "k8s-node-4",
  "name": "K8s Node: node-4",
  "enabled": false  // ← Disable instead of deleting
}
```

---

## 🆘 Troubleshooting

### Issue: "Invalid service ID" error

**Cause:** Service ID not found in `services.json`

**Fix:**
1. Check the logs to see what service ID is being sent:
   ```bash
   kubectl logs -n monitoring <pod-name> | grep "Sending heartbeat"
   ```
2. Ensure that service ID exists in `config/services.json`
3. Re-run the generator script if needed

### Issue: All nodes show as same service

**Cause:** Not using the new per-node configuration

**Fix:**
1. Update `heartbeat-daemonset.yaml` to use `service-id-prefix` (see Step 3)
2. Redeploy: `kubectl apply -f heartbeat-daemonset.yaml`
3. Restart pods: `kubectl rollout restart daemonset/heartbeat-client -n monitoring`

### Issue: Service shows "Unknown" status

**Cause:** Service exists in `services.json` but no heartbeats received yet

**Fix:**
1. Wait 2-3 minutes for first heartbeat
2. Check pod logs for errors
3. Verify API key is correct

---

## 📚 Related Files

- **`generate-services-config.sh`** - Helper script to generate config
- **`services-example.json`** - Complete example with K8s nodes
- **`heartbeat-daemonset.yaml`** - Main DaemonSet configuration
- **`QUICKSTART.md`** - Step-by-step deployment guide

---

## 🎉 Summary

✅ **Each node = Unique service ID**  
✅ **Automatic service ID generation**  
✅ **Easy to add/remove nodes**  
✅ **Flexible naming with prefixes**  
✅ **Production-ready setup**

**The DaemonSet now properly handles unique service IDs for each node!** 🚀

