# API Keys Configuration Guide

## 🎯 Overview

The authentication system now supports **three levels** of API key configuration:

1. **Service-level**: Specific key for each service
2. **Group-level**: Shared key for all services in a group ⭐ **NEW!**
3. **Wildcard**: Single key for all services ⭐ **NEW!**

**Problem Solved:** No more repeating the same key 50 times for 50 Kubernetes nodes! 🎉

---

## 🔑 Key Lookup Priority

When a heartbeat arrives, the system checks keys in this order:

```
1. Exact service ID    →  apiKeys["service-1"]
2. Group ID (if exists) →  apiKeys["core-services"]
3. Wildcard             →  apiKeys["*"]

✅ First match wins!
```

---

## 📋 Configuration Options

### Option 1: Service-Level Keys (Most Secure)

**Best for:** High-security environments, few services

**API_KEYS:**
```json
{
  "payment-api": "secret-key-1",
  "admin-panel": "secret-key-2",
  "user-api": "secret-key-3"
}
```

**Pros:**
- ✅ Maximum security (different key per service)
- ✅ Can revoke individual service access

**Cons:**
- ❌ Tedious with many services
- ❌ Hard to manage 50+ keys

---

### Option 2: Group-Level Keys ⭐ (Recommended)

**Best for:** Multiple related services, Kubernetes clusters

**services.json:**
```json
{
  "groups": [
    {
      "id": "kubernetes",
      "name": "Kubernetes Cluster",
      "services": ["node-1", "node-2", "node-3", ..., "node-50"]
    }
  ],
  "services": [
    {"id": "node-1", "name": "K8s Node 1"},
    {"id": "node-2", "name": "K8s Node 2"},
    ...
  ]
}
```

**API_KEYS:**
```json
{
  "kubernetes": "shared-k8s-key"
}
```

**Result:** ALL 50 nodes use the same key! ✅

**Pros:**
- ✅ Simple configuration (one key for many services)
- ✅ Perfect for clusters/groups
- ✅ Easy to rotate keys per group

**Cons:**
- ⚠️ All services in group share access

---

### Option 3: Wildcard Key (Simplest)

**Best for:** Development, small setups, internal networks

**API_KEYS:**
```json
{
  "*": "one-key-for-everything"
}
```

**Result:** ALL services use this key!

**Pros:**
- ✅ Simplest possible setup
- ✅ One key to remember

**Cons:**
- ⚠️ Least secure (all services share)
- ⚠️ Can't revoke per-service

---

### Option 4: Hybrid (Most Flexible)

**Best for:** Production with mixed security requirements

**API_KEYS:**
```json
{
  "payment-api": "critical-secret-key",    // Service-level (highest priority)
  "admin-api": "admin-secret-key",          // Service-level
  "core-services": "shared-core-key",       // Group-level
  "kubernetes": "k8s-cluster-key",          // Group-level
  "*": "default-key"                        // Wildcard (lowest priority)
}
```

**Logic:**
- `payment-api` uses its specific key (most secure)
- Services in `core-services` group share one key
- Services in `kubernetes` group share one key
- Everything else uses the wildcard key

**Pros:**
- ✅ Maximum flexibility
- ✅ Security where needed
- ✅ Convenience where acceptable

---

## 🎯 Real-World Examples

### Example 1: Kubernetes Cluster (50 nodes)

**Before (Tedious):**
```json
{
  "node-1": "shared-key",
  "node-2": "shared-key",
  "node-3": "shared-key",
  ...
  "node-50": "shared-key"
}
```
❌ Repeat key 50 times!

**After (Simple):**
```json
{
  "kubernetes": "shared-key"
}
```
✅ One entry for all nodes!

---

### Example 2: Multi-Tenant Platform

**Setup:**
- Tenant A: 20 services
- Tenant B: 15 services  
- Tenant C: 10 services

**services.json:**
```json
{
  "groups": [
    {"id": "tenant-a", "services": ["tenant-a-app1", "tenant-a-app2", ...]},
    {"id": "tenant-b", "services": ["tenant-b-app1", "tenant-b-app2", ...]},
    {"id": "tenant-c", "services": ["tenant-c-app1", "tenant-c-app2", ...]}
  ]
}
```

**API_KEYS:**
```json
{
  "tenant-a": "tenant-a-secret",
  "tenant-b": "tenant-b-secret",
  "tenant-c": "tenant-c-secret"
}
```

**Result:** Each tenant has their own key, easy to manage!

---

### Example 3: Production with Critical Services

**API_KEYS:**
```json
{
  "payment-gateway": "ultra-secure-payment-key",
  "billing-api": "secure-billing-key",
  "monitoring-group": "monitoring-key",
  "*": "general-access-key"
}
```

**Result:**
- Critical services (`payment-gateway`, `billing-api`) have unique keys
- Monitoring services share a key
- Everything else uses the default key

---

## 🔧 How to Set API Keys

### Method 1: Wrangler CLI (Local/Production)

```bash
# Generate a strong key
openssl rand -base64 32

# Set the API_KEYS secret
npx wrangler secret put API_KEYS
# Paste: {"kubernetes":"your-generated-key"}
```

### Method 2: GitHub Secrets (CI/CD)

1. Go to: Repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `API_KEYS`
4. Value: `{"kubernetes":"your-generated-key"}`
5. Click "Add secret"

### Method 3: Cloudflare Dashboard

1. Go to: Workers & Pages → Your Worker → Settings → Variables
2. Under "Environment Variables", add:
   - Variable name: `API_KEYS`
   - Type: Secret
   - Value: `{"kubernetes":"your-generated-key"}`
3. Click "Save"

---

## ✅ Verification

### Test Your Configuration

```bash
# Test with correct key
curl -X POST https://your-worker.workers.dev/api/heartbeat \
  -H "Authorization: Bearer your-key-here" \
  -H "Content-Type: application/json" \
  -d '{"serviceId": "node-1"}'

# Should return: {"success": true, ...}
```

### Check Worker Logs

```bash
npx wrangler tail
```

Look for authentication messages:
```
Service node-1 authenticated using group key ✅
Service payment-api authenticated using service key ✅
Service random-service authenticated using wildcard key ✅
```

---

## 🎨 Migration Guide

### From Per-Service to Group-Level

**Before:**
```json
{
  "node-1": "shared-key",
  "node-2": "shared-key",
  "node-3": "shared-key",
  "node-4": "shared-key",
  "node-5": "shared-key"
}
```

**After:**
```json
{
  "kubernetes": "shared-key"
}
```

**Steps:**
1. Ensure all nodes are in the "kubernetes" group in `services.json`
2. Update `API_KEYS` to use group key
3. Deploy: `npx wrangler deploy`
4. Test with a heartbeat
5. ✅ Done!

---

## 🔒 Security Best Practices

### 1. Use Strong Keys

```bash
# Generate cryptographically secure keys
openssl rand -base64 32
```

### 2. Layer Your Security

```json
{
  "critical-service": "unique-ultra-secure-key",  // Most critical
  "production-group": "shared-prod-key",          // Shared but still secure
  "*": "dev-default-key"                          // Fallback
}
```

### 3. Rotate Keys Regularly

```bash
# Generate new key
NEW_KEY=$(openssl rand -base64 32)

# Update secret
echo "{\"kubernetes\":\"$NEW_KEY\"}" | npx wrangler secret put API_KEYS

# Update clients with new key
```

### 4. Don't Commit Secrets

```bash
# Add to .gitignore
echo "secrets.txt" >> .gitignore
echo "*.key" >> .gitignore
```

---

## 🆘 Troubleshooting

### Issue: "Invalid API key" error

**Check:**
1. Key matches between client and `API_KEYS`
2. Group ID in `services.json` matches key in `API_KEYS`
3. Authorization header format: `Bearer your-key`

**Debug:**
```bash
# Check worker logs
npx wrangler tail

# Look for:
# "Service xxx requires auth but has no API key configured"
```

### Issue: Services not using group key

**Verify group configuration:**

```json
// services.json
{
  "groups": [
    {
      "id": "kubernetes",  // ← This must match API_KEYS key!
      "services": ["node-1", "node-2"]
    }
  ]
}
```

```json
// API_KEYS
{
  "kubernetes": "your-key"  // ← Must match group.id!
}
```

### Issue: Wildcard not working

**Ensure:**
- Key is exactly `"*"` (with quotes)
- No typos or extra spaces
- JSON is valid

```json
// Correct
{"*": "key"}

// Wrong
{"wildcard": "key"}
{"default": "key"}
```

---

## 📊 Comparison

| Method | Security | Ease of Use | Best For |
|--------|----------|-------------|----------|
| Service-level | ⭐⭐⭐⭐⭐ | ⭐ | High-security, few services |
| Group-level | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Kubernetes, multi-tenant |
| Wildcard | ⭐⭐ | ⭐⭐⭐⭐⭐ | Development, internal |
| Hybrid | ⭐⭐⭐⭐ | ⭐⭐⭐ | Production mixed environments |

---

## 🎉 Summary

✅ **Three levels of keys:** service → group → wildcard  
✅ **Priority-based lookup:** Most specific wins  
✅ **Simple for clusters:** One key for 50+ nodes  
✅ **Flexible:** Mix approaches as needed  
✅ **Backward compatible:** Existing configs still work  

**For Kubernetes:** Use group-level keys! 🚀

---

## 📚 Related Documentation

- [secrets.example.txt](secrets.example.txt) - Configuration examples
- [SECURITY.md](SECURITY.md) - Security best practices  
- [AUTHENTICATION.md](AUTHENTICATION.md) - Full auth guide
- [AUTH_CONFIGURATION.md](AUTH_CONFIGURATION.md) - Per-service auth control

---

**Questions?** Check the examples in `docs/secrets.example.txt`!

