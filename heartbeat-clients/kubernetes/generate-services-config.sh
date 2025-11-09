#!/bin/bash

# Generate services.json configuration for Kubernetes nodes
# This script helps you create service entries for each node in your cluster

set -e

# Configuration
SERVICE_ID_PREFIX="${SERVICE_ID_PREFIX:-k8s-}"
GROUP_ID="${GROUP_ID:-kubernetes}"
GROUP_NAME="${GROUP_NAME:-Kubernetes Cluster}"
STALENESS_THRESHOLD="${STALENESS_THRESHOLD:-300}"
UPTIME_THRESHOLD_SET="${UPTIME_THRESHOLD_SET:-default}"
AUTH_REQUIRED="${AUTH_REQUIRED:-false}"

echo "Kubernetes Services Generator for services.json"
echo "================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to use this script."
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq"
    exit 1
fi

# Get all node names
echo "Fetching nodes from cluster..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

if [ -z "$NODES" ]; then
    echo "Error: No nodes found in cluster"
    exit 1
fi

NODE_COUNT=$(echo "$NODES" | wc -w | tr -d ' ')
echo "Found $NODE_COUNT nodes"
echo ""

# Generate group configuration
echo "Generating configuration..."
echo ""
echo "# Add this to your config/services.json"
echo ""
echo "{"
echo "  \"groups\": ["

# Generate group
cat <<EOF
    {
      "id": "$GROUP_ID",
      "name": "$GROUP_NAME",
      "services": [
EOF

# Add service IDs to group
FIRST=true
for node in $NODES; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ","
    fi
    echo -n "        \"${SERVICE_ID_PREFIX}${node}\""
done

cat <<EOF

      ],
      "uptimeThresholdSet": "$UPTIME_THRESHOLD_SET",
      "stalenessThreshold": $STALENESS_THRESHOLD,
      "auth": {
        "required": $AUTH_REQUIRED
      },
      "notifications": {
        "enabled": true,
        "channels": ["telegram"],
        "events": ["down", "up", "degraded"]
      }
    }
  ],
  "services": [
EOF

# Generate service entries
FIRST=true
for node in $NODES; do
    # Get node info
    NODE_IP=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    NODE_ROLE=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/[^{}]*}' | head -1)
    
    if [ -z "$NODE_ROLE" ]; then
        NODE_ROLE="worker"
    fi
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ","
    fi
    
    cat <<EOF
    {
      "id": "${SERVICE_ID_PREFIX}${node}",
      "name": "K8s Node: ${node}",
      "description": "Kubernetes ${NODE_ROLE} node (${NODE_IP})",
      "enabled": true
    }
EOF
done

echo "  ]"
echo "}"
echo ""
echo "================================================"
echo ""
echo "📋 Configuration generated for $NODE_COUNT nodes"
echo ""
echo "📝 Next steps:"
echo "  1. Copy the configuration above"
echo "  2. Merge it with your existing config/services.json"
echo "  3. Or save to a new file and merge manually"
echo ""
echo "💡 Tip: To save directly to a file:"
echo "  $0 > k8s-nodes.json"
echo ""
echo "⚙️ Customize settings:"
echo "  SERVICE_ID_PREFIX='prod-k8s-' $0"
echo "  GROUP_NAME='Production Cluster' $0"
echo "  STALENESS_THRESHOLD=600 $0"
echo "  AUTH_REQUIRED=true $0"
echo ""

