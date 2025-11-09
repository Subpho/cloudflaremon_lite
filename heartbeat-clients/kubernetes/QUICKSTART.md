# Kubernetes DaemonSet - Quick Start

Deploy heartbeat monitoring to your Kubernetes cluster in 5 minutes.

## ⚡ Fast Deploy

### 1. Generate Service Configuration

Each node needs a unique service ID. Generate the config:

```bash
# Make script executable
chmod +x generate-services-config.sh

# Generate configuration
./generate-services-config.sh
```

This will output configuration for all your nodes. **Copy and merge it into your `config/services.json`**.

Example output for 3 nodes:
```json
{
  "groups": [
    {
      "id": "kubernetes",
      "name": "Kubernetes Cluster",
      "services": ["k8s-node-1", "k8s-node-2", "k8s-node-3"],
      ...
    }
  ],
  "services": [
    {"id": "k8s-node-1", "name": "K8s Node: node-1", ...},
    {"id": "k8s-node-2", "name": "K8s Node: node-2", ...},
    {"id": "k8s-node-3", "name": "K8s Node: node-3", ...}
  ]
}
```

See `services-example.json` for a complete example.

### 2. Edit DaemonSet Configuration

```bash
# Edit the secret section
nano heartbeat-daemonset.yaml
```

Update these lines:
```yaml
stringData:
  worker-url: "https://mon.pipdor.com/api/heartbeat"  # ✅ Your worker URL
  service-id-prefix: "k8s-"                            # ✅ Prefix (will become k8s-node-1, k8s-node-2, etc.)
  api-key: "your-actual-api-key-here"                  # ✅ Your API key
```

**Important:** The `service-id-prefix` must match what you used in `services.json`!

### 3. Deploy

```bash
kubectl apply -f heartbeat-daemonset.yaml
```

### 4. Verify

```bash
# Check status
kubectl get daemonset -n monitoring

# View logs
kubectl logs -n monitoring -l app=heartbeat-client --tail=20
```

**Expected output:**
```
[Sun Nov  9 10:00:00 UTC 2025] Sending heartbeat for service: k8s-node-1 (node: node-1)
[Sun Nov  9 10:00:00 UTC 2025] ✓ Heartbeat sent successfully
```

**Each node reports as a separate service:** `k8s-node-1`, `k8s-node-2`, etc.

## ✅ Done!

Your Kubernetes cluster is now monitored! 

Check your dashboard: **https://mon.pipdor.com** 🎯

---

## 📋 What Gets Created

| Resource | Name | Namespace | Purpose |
|----------|------|-----------|---------|
| Namespace | `monitoring` | - | Dedicated namespace |
| Secret | `heartbeat-secrets` | `monitoring` | API credentials |
| ConfigMap | `heartbeat-script` | `monitoring` | Heartbeat script |
| DaemonSet | `heartbeat-client` | `monitoring` | Runs on all nodes |
| ServiceAccount | `heartbeat-client` | `monitoring` | RBAC permissions |

---

## 🎛️ Common Customizations

### Change Heartbeat Interval

Default: 2 minutes

```yaml
# In ConfigMap, change sleep duration:
sleep 300  # 5 minutes
```

### Monitor Per-Node

Use node name in service ID:

```yaml
- name: SERVICE_ID
  value: "k8s-$(NODE_NAME)"
```

### Exclude Control Plane

```yaml
# Remove these tolerations:
tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
```

### Run on Specific Nodes

```yaml
nodeSelector:
  node-role.kubernetes.io/worker: "true"
```

---

## 🗑️ Remove

```bash
kubectl delete -f heartbeat-daemonset.yaml
```

---

## 📚 More Info

- **Full Documentation**: [README.md](README.md)
- **Sidecar Pattern**: [heartbeat-sidecar.yaml](heartbeat-sidecar.yaml)
- **Kustomize**: [kustomization.yaml](kustomization.yaml)
- **Helm Values**: [helm-values.yaml](helm-values.yaml)

---

## 💡 Tips

### Development
Test locally first:
```bash
# Port-forward for testing
kubectl port-forward -n monitoring $(kubectl get pod -n monitoring -l app=heartbeat-client -o name | head -1) 8080:8080
```

### Production
- Use **Sealed Secrets** or **External Secrets Operator**
- Set **resource limits** appropriately
- Monitor **DaemonSet health** in your observability stack
- Use **GitOps** (ArgoCD, Flux) for deployment

### Troubleshooting
```bash
# Check pod events
kubectl describe pod -n monitoring <pod-name>

# Check logs for errors
kubectl logs -n monitoring -l app=heartbeat-client | grep "✗"

# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

---

## 🆘 Need Help?

**Common Issues:**

| Problem | Solution |
|---------|----------|
| Pods not starting | Check: `kubectl describe pod -n monitoring <pod>` |
| Heartbeats failing | Verify API key and service ID |
| Missing nodes | Check node taints and tolerations |
| No logs | Ensure pods are in Running state |

**Check Status:**
```bash
# Overall health
kubectl get all -n monitoring

# Detailed events
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

---

## 🎉 Success!

Your cluster health is now monitored from every node! 🚀

**Next steps:**
- ✅ Add service to your dashboard
- ✅ Configure alerting in `config/notifications.json`
- ✅ Set appropriate staleness threshold
- ✅ Monitor DaemonSet health

Happy monitoring! 📊

