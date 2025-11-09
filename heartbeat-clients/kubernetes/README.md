# Kubernetes DaemonSet Deployment

Deploy the heartbeat client as a Kubernetes DaemonSet to monitor cluster health from every node.

## 📋 Overview

The DaemonSet ensures a heartbeat client pod runs on **every node** in your Kubernetes cluster, sending periodic heartbeats to your monitoring worker.

### What's Included

- **DaemonSet**: Runs heartbeat client on all nodes
- **ConfigMap**: Contains the heartbeat script
- **Secret**: Stores API credentials securely
- **ServiceAccount**: (Optional) For RBAC
- **Namespace**: Dedicated monitoring namespace

---

## 🚀 Quick Start

### 1. Update Configuration

Edit `heartbeat-daemonset.yaml` and update the Secret:

```yaml
stringData:
  worker-url: "https://mon.pipdor.com/api/heartbeat"  # Your worker URL
  service-id: "k8s-cluster"                            # Your service ID
  api-key: "your-actual-api-key-here"                  # Your API key
```

### 2. Deploy

```bash
kubectl apply -f heartbeat-daemonset.yaml
```

### 3. Verify

```bash
# Check DaemonSet status
kubectl get daemonset -n monitoring

# Check pods (should see one per node)
kubectl get pods -n monitoring -o wide

# Check logs
kubectl logs -n monitoring -l app=heartbeat-client --tail=20
```

---

## 📊 Expected Output

### DaemonSet Status
```bash
$ kubectl get daemonset -n monitoring
NAME               DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
heartbeat-client   3         3         3       3            3
```

### Pods (One Per Node)
```bash
$ kubectl get pods -n monitoring -o wide
NAME                     READY   STATUS    NODE
heartbeat-client-abc12   1/1     Running   node-1
heartbeat-client-def34   1/1     Running   node-2
heartbeat-client-ghi56   1/1     Running   node-3
```

### Logs
```bash
$ kubectl logs -n monitoring heartbeat-client-abc12
[Sun Nov  9 10:00:00 UTC 2025] Sending heartbeat for node: node-1
[Sun Nov  9 10:00:00 UTC 2025] ✓ Heartbeat sent successfully
Sleeping for 2 minutes...
```

---

## ⚙️ Configuration

### Heartbeat Interval

Default: **2 minutes**

To change, edit the sleep duration in the ConfigMap:

```yaml
data:
  heartbeat.sh: |
    ...
    sleep 300  # 5 minutes
```

### Service ID

Each node reports as the same service. To monitor nodes individually:

**Option 1: Use node name in service ID**
```yaml
- name: SERVICE_ID
  value: "k8s-$(NODE_NAME)"
```

**Option 2: Create separate service IDs in services.json**
```json
{
  "services": [
    {"id": "k8s-node-1", "name": "K8s Node 1"},
    {"id": "k8s-node-2", "name": "K8s Node 2"},
    {"id": "k8s-node-3", "name": "K8s Node 3"}
  ]
}
```

### Node Selector

Run only on specific nodes:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: "true"
```

### Tolerations

Already configured to run on control-plane nodes. To exclude them:

```yaml
# Remove these tolerations
tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
```

---

## 🔒 Security

### Using Kubernetes Secrets

Credentials are stored in Kubernetes Secrets (base64 encoded):

```bash
# Create secret manually
kubectl create secret generic heartbeat-secrets \
  --from-literal=worker-url="https://mon.pipdor.com/api/heartbeat" \
  --from-literal=service-id="k8s-cluster" \
  --from-literal=api-key="your-secret-key" \
  -n monitoring
```

### Using Sealed Secrets (Recommended for GitOps)

If using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets):

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubectl create secret generic heartbeat-secrets \
  --from-literal=worker-url="https://mon.pipdor.com/api/heartbeat" \
  --from-literal=service-id="k8s-cluster" \
  --from-literal=api-key="your-secret-key" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > heartbeat-sealed-secret.yaml

# Apply sealed secret
kubectl apply -f heartbeat-sealed-secret.yaml
```

### Using External Secrets Operator

For AWS Secrets Manager, Vault, etc., use [External Secrets Operator](https://external-secrets.io/).

---

## 📈 Resource Usage

### Per Pod
- **CPU Request**: 10m (0.01 cores)
- **CPU Limit**: 50m (0.05 cores)
- **Memory Request**: 32Mi
- **Memory Limit**: 64Mi

### Total Cluster
For a 10-node cluster:
- **CPU**: ~100-500m total
- **Memory**: ~320-640Mi total

Very lightweight! 🎯

---

## 🔍 Monitoring & Troubleshooting

### Check DaemonSet Health

```bash
# Overall status
kubectl get daemonset -n monitoring heartbeat-client

# Detailed events
kubectl describe daemonset -n monitoring heartbeat-client

# Pod status on all nodes
kubectl get pods -n monitoring -o wide -l app=heartbeat-client
```

### View Logs

```bash
# All pods
kubectl logs -n monitoring -l app=heartbeat-client --tail=50

# Specific pod
kubectl logs -n monitoring heartbeat-client-abc12 -f

# Previous logs (if crashed)
kubectl logs -n monitoring heartbeat-client-abc12 --previous
```

### Common Issues

#### Pods Not Starting

**Check events:**
```bash
kubectl describe pod -n monitoring heartbeat-client-abc12
```

**Common causes:**
- Secret not found
- Insufficient resources
- Image pull errors

#### Heartbeats Failing

**Check logs for HTTP errors:**
```bash
kubectl logs -n monitoring heartbeat-client-abc12 | grep "✗"
```

**Common causes:**
- Wrong API key
- Wrong service ID
- Network connectivity issues
- Worker URL incorrect

#### Node Not Running Pod

**Check node conditions:**
```bash
kubectl describe node node-name
```

**Check taints:**
```bash
kubectl get nodes -o json | jq '.items[].spec.taints'
```

---

## 🎯 Advanced Configurations

### Batch Mode (Multiple Services)

Monitor multiple services from each node:

```yaml
data:
  heartbeat.sh: |
    #!/bin/bash
    # Batch heartbeat for multiple services
    
    JSON_PAYLOAD=$(cat <<EOF
    {
      "services": [
        {
          "serviceId": "k8s-node-$NODE_NAME",
          "metadata": {"type": "node"}
        },
        {
          "serviceId": "k8s-cluster",
          "metadata": {"node": "$NODE_NAME"}
        }
      ]
    }
    EOF
    )
    
    # Send batch heartbeat
    curl -X POST "$WORKER_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "$JSON_PAYLOAD"
```

### Custom Metadata

Add more node information:

```yaml
env:
- name: CLUSTER_NAME
  value: "production"
- name: REGION
  value: "us-east-1"

# In script:
"metadata": {
  "node": "$NODE_NAME",
  "cluster": "$CLUSTER_NAME",
  "region": "$REGION",
  "pod": "$POD_NAME"
}
```

### Sidecar Pattern

Run heartbeat as a sidecar in your application pods instead of DaemonSet.

See: `heartbeat-sidecar.yaml`

---

## 🗑️ Cleanup

Remove all resources:

```bash
kubectl delete -f heartbeat-daemonset.yaml
```

Or by namespace:

```bash
kubectl delete namespace monitoring
```

---

## 📚 Related Documentation

- [Kubernetes DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Main Documentation](../README.md)
- [Docker Compose Setup](../docker-compose.yml)
- [Systemd Setup](../systemd/)

---

## 💡 Tips

### Development/Testing

Test on a single node first:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: "specific-node-name"
```

### Production Best Practices

1. **Use Sealed Secrets** or External Secrets Operator
2. **Set Resource Limits** to prevent resource exhaustion
3. **Monitor DaemonSet Status** with your monitoring stack
4. **Use Labels** for better organization:
   ```yaml
   metadata:
     labels:
       app: heartbeat-client
       component: monitoring
       team: platform
   ```

5. **Version Your Configs** - Use Git tags/branches for different environments

---

## 🎉 Success!

Once deployed, your Kubernetes cluster will:
- ✅ Send heartbeats from every node
- ✅ Include node metadata in heartbeats
- ✅ Automatically adapt to cluster scaling
- ✅ Recover automatically if pods crash

Check your dashboard at: **https://mon.pipdor.com** 🎯

