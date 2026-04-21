# /rhoai-install-rosa - Install RHOAI on ROSA (HCP) Cluster

Install Red Hat OpenShift AI (RHOAI) pre-release builds on ROSA (Red Hat OpenShift Service on AWS) clusters, including Hosted Control Plane (HCP) variants.

ROSA HCP clusters have a managed pull secret that gets reconciled by the platform, so standard pull secret injection doesn't work. This command uses Kyverno to distribute brew registry credentials to all namespaces, enabling OLM to pull pre-release images from brew.registry.redhat.io.

## Command Usage

```bash
/rhoai-install-rosa                                       # Install RHOAI 3.4 (default)
/rhoai-install-rosa version=3.4                            # Explicit version
/rhoai-install-rosa version=3.4-ea.2                       # Specific EA build
/rhoai-install-rosa channel=beta                           # Explicit channel
/rhoai-install-rosa image=quay.io/rhoai/rhoai-fbc-fragment:rhoai-3.4  # Custom image
```

## Prerequisites

Before running this command:
1. **Cluster access**: Logged into a ROSA cluster with cluster-admin privileges (use `/oc-login`)
2. **Tools installed**: `oc` CLI and `jq` must be available
3. **Brew registry credentials**: Obtain from [employee-token-manager](https://employee-token-manager.registry.redhat.com) — you will be prompted
4. **No existing RHOAI**: This command is for fresh installations only (use `/rhoai-update` for updates)

## Process

### Step 1: Parse Input Arguments

```bash
# Default values
VERSION="3.4"
CHANNEL="beta"
IMAGE=""
BREW_SECRET_NAME="pull-secret-brew"

# Parse key=value arguments
for arg in "$@"; do
  case "$arg" in
    version=*)
      VERSION="${arg#*=}"
      ;;
    channel=*)
      CHANNEL="${arg#*=}"
      ;;
    image=*)
      IMAGE="${arg#*=}"
      ;;
    *)
      echo "⚠️  Unknown parameter: $arg (expected: version=, channel=, or image=)"
      ;;
  esac
done

# Build FBC fragment image URL if not explicitly provided
if [[ -z "$IMAGE" ]]; then
  if [[ "$VERSION" == rhoai-* ]]; then
    IMAGE="quay.io/rhoai/rhoai-fbc-fragment:${VERSION}"
  else
    IMAGE="quay.io/rhoai/rhoai-fbc-fragment:rhoai-${VERSION}"
  fi
fi

echo "📦 RHOAI ROSA Installation"
echo "   Image: $IMAGE"
echo "   Channel: $CHANNEL"
```

### Step 2: Verify Cluster Access and Detect ROSA Type

```bash
# Check prerequisites
command -v oc &>/dev/null || die "oc command not found"
command -v jq &>/dev/null || die "jq command not found"
oc whoami &>/dev/null || die "Not logged into an OpenShift cluster"

echo "Logged in as: $(oc whoami)"
echo "Cluster: $(oc whoami --show-server)"

# Detect ROSA cluster
INFRA_PLATFORM=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}' 2>/dev/null || echo "")
if [[ "$INFRA_PLATFORM" != "AWS" ]]; then
  echo "⚠️  WARNING: This cluster does not appear to be AWS-based (platform: $INFRA_PLATFORM)"
  echo "   This command is designed for ROSA clusters. Consider using /rhoai-install instead."
fi

# Detect ROSA HCP vs Classic
IS_HCP=false
if oc get nodes -o jsonpath='{.items[0].metadata.labels}' 2>/dev/null | grep -q "hypershift.openshift.io"; then
  IS_HCP=true
  echo "✅ Detected ROSA HCP (Hosted Control Plane) cluster"
  echo "   ⚠️  Global pull-secret is managed — will use Kyverno for credential injection"
elif oc get infrastructure cluster -o jsonpath='{.status.controlPlaneTopology}' 2>/dev/null | grep -q "External"; then
  IS_HCP=true
  echo "✅ Detected ROSA HCP cluster (External control plane)"
  echo "   ⚠️  Global pull-secret is managed — will use Kyverno for credential injection"
else
  echo "✅ Detected ROSA Classic cluster"
  echo "   Global pull-secret can be modified directly"
fi

# Check if ODH is installed — RHOAI and ODH cannot coexist
if oc get csv -n openshift-operators 2>/dev/null | grep -q opendatahub-operator; then
  die "ODH is installed on this cluster. Uninstall ODH first with /odh-uninstall"
fi

# Verify RHOAI is not already installed
if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods-operator; then
  die "RHOAI is already installed. Use /rhoai-update to update existing installation."
fi

echo "✅ No existing RHOAI or ODH installation detected"
```

### Step 3: Configure Brew Registry Credentials

Pre-release RHOAI builds require access to `brew.registry.redhat.io`. On ROSA HCP, the global pull-secret is managed and cannot be permanently modified. Instead, we create a separate pull secret and use Kyverno to distribute it.

```bash
echo ""
echo "=== Brew Registry Credentials ==="

# Check if brew pull secret already exists in openshift-config
BREW_CREDS_EXIST=false
if oc get secret "$BREW_SECRET_NAME" -n openshift-config &>/dev/null 2>&1; then
  echo "✅ Brew pull secret '$BREW_SECRET_NAME' already exists in openshift-config"
  BREW_CREDS_EXIST=true
fi

if [[ "$BREW_CREDS_EXIST" == "false" ]]; then
  echo ""
  echo "Pre-release RHOAI requires brew.registry.redhat.io credentials."
  echo "Obtain credentials from: https://employee-token-manager.registry.redhat.com"
  echo ""
  echo "You need to provide brew registry credentials."
  echo "The credentials will be stored in a Kubernetes secret (not in shell history)."

  # IMPORTANT: Credentials should be provided via environment variables or
  # interactive prompt — never as command-line arguments (visible in ps aux).
  #
  # Option 1: Environment variables (set before running)
  #   export BREW_USERNAME="..."
  #   export BREW_TOKEN="..."
  #
  # Option 2: Interactive prompt (the command will ask)

  if [[ -z "${BREW_USERNAME:-}" || -z "${BREW_TOKEN:-}" ]]; then
    echo ""
    echo "Provide brew credentials (from employee-token-manager):"
    echo "  BREW_USERNAME and BREW_TOKEN environment variables are not set."
    echo ""
    echo "Set them and re-run, or provide them now:"
    echo "  export BREW_USERNAME='your-username|your-token-name'"
    echo "  export BREW_TOKEN='your-token-value'"
    die "Brew credentials not provided. Set BREW_USERNAME and BREW_TOKEN env vars."
  fi

  # Validate credentials are not empty
  [[ -n "$BREW_USERNAME" ]] || die "BREW_USERNAME is empty"
  [[ -n "$BREW_TOKEN" ]] || die "BREW_TOKEN is empty"

  # Create dockerconfigjson for brew registry
  BREW_AUTH=$(echo -n "${BREW_USERNAME}:${BREW_TOKEN}" | base64)
  TMPFILE=$(mktemp)
  chmod 600 "$TMPFILE"
  trap 'rm -f "$TMPFILE"' EXIT

  cat > "$TMPFILE" << AUTHEOF
{
  "auths": {
    "brew.registry.redhat.io": {
      "auth": "${BREW_AUTH}"
    }
  }
}
AUTHEOF

  # Create the secret
  oc create secret generic "$BREW_SECRET_NAME" \
    --from-file=.dockerconfigjson="$TMPFILE" \
    --type=kubernetes.io/dockerconfigjson \
    -n openshift-config 2>/dev/null || \
  oc create secret docker-registry "$BREW_SECRET_NAME" \
    --docker-server=brew.registry.redhat.io \
    --docker-username="$BREW_USERNAME" \
    --docker-password="$BREW_TOKEN" \
    -n openshift-config

  rm -f "$TMPFILE"
  unset BREW_AUTH

  echo "✅ Brew pull secret created: $BREW_SECRET_NAME in openshift-config"
fi
```

**Why a separate secret?**
On ROSA HCP, the global `pull-secret` in `openshift-config` is managed by the platform and gets reconciled (reverted). Creating a separate secret avoids this issue. Kyverno (Step 4) syncs this secret to all namespaces where OLM and operators need it.

### Step 4: Install Kyverno and Create Policies

Kyverno is used to:
1. **Sync the brew pull secret** to all namespaces (so OLM unpack jobs and operator pods can pull images)
2. **Add imagePullSecrets** to service accounts (so pods automatically use the brew credentials)

```bash
echo ""
echo "=== Kyverno Setup ==="

# Check if Kyverno is already installed
if oc get deployment kyverno -n kyverno &>/dev/null 2>&1; then
  echo "✅ Kyverno is already installed"
else
  echo "Installing Kyverno..."

  # Install Kyverno via Helm or manifests
  if command -v helm &>/dev/null; then
    helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
    helm repo update kyverno 2>/dev/null || true
    helm install kyverno kyverno/kyverno \
      --namespace kyverno --create-namespace \
      --set admissionController.replicas=1 \
      --set backgroundController.replicas=1 \
      --set cleanupController.replicas=1 \
      --set reportsController.replicas=1 \
      --wait --timeout 300s
  else
    # Fallback: install from release manifest
    oc create namespace kyverno 2>/dev/null || true
    oc apply -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml
    echo "Waiting for Kyverno to be ready..."
    oc wait deployment kyverno-admission-controller -n kyverno --for=condition=available --timeout=300s 2>/dev/null || \
    oc wait deployment kyverno -n kyverno --for=condition=available --timeout=300s 2>/dev/null || true
  fi

  echo "✅ Kyverno installed"
fi

# Wait for Kyverno webhook to be ready
echo "Waiting for Kyverno webhooks to be ready..."
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get clusterpolicy &>/dev/null 2>&1; then
    echo "✅ Kyverno CRDs are available"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "   Waiting for Kyverno CRDs... (${ELAPSED}s/${TIMEOUT}s)"
done
```

### Step 5: Create Kyverno ClusterPolicies

```bash
echo ""
echo "=== Kyverno Policies ==="

# Policy 1: Sync brew pull secret to all namespaces
cat <<'POLICYEOF' | sed "s/BREW_SECRET_PLACEHOLDER/$BREW_SECRET_NAME/g" | oc apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-brew-pull-secret
spec:
  generateExisting: true
  rules:
  - name: sync-secret
    match:
      any:
      - resources:
          kinds:
          - Namespace
    exclude:
      any:
      - resources:
          namespaces:
          - kube-system
          - kube-public
          - kube-node-lease
    generate:
      synchronize: true
      apiVersion: v1
      kind: Secret
      name: BREW_SECRET_PLACEHOLDER
      namespace: "{{request.object.metadata.name}}"
      clone:
        namespace: openshift-config
        name: BREW_SECRET_PLACEHOLDER
POLICYEOF

echo "✅ Policy created: sync-brew-pull-secret"

# Policy 2: Add imagePullSecrets to default service account in all namespaces
cat <<'POLICYEOF' | sed "s/BREW_SECRET_PLACEHOLDER/$BREW_SECRET_NAME/g" | oc apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-brew-imagepullsecret
spec:
  rules:
  - name: add-imagepullsecret
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          imagePullSecrets:
          - name: BREW_SECRET_PLACEHOLDER
POLICYEOF

echo "✅ Policy created: add-brew-imagepullsecret"

# Wait for policies to be ready
sleep 10
echo "Waiting for policies to be applied..."

TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  READY=$(oc get clusterpolicy sync-brew-pull-secret -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  if [[ "$READY" == "True" ]]; then
    echo "✅ Kyverno policies are ready"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "   Waiting for policies... (${ELAPSED}s/${TIMEOUT}s)"
done
```

**What these policies do:**
- `sync-brew-pull-secret`: Automatically copies the brew pull secret from `openshift-config` to every namespace (including new ones created later by OLM)
- `add-brew-imagepullsecret`: Mutates every Pod to include the brew pull secret in `imagePullSecrets`, so containers can pull from `brew.registry.redhat.io`

### Step 6: Create Operator Namespace and CatalogSource

```bash
echo ""
echo "=== Operator Installation ==="

OPERATOR_NAMESPACE="redhat-ods-operator"
CATALOG_SOURCE="rhoai-catalog-dev"
CATALOG_NAMESPACE="openshift-marketplace"

# Create namespace
if ! oc get namespace "$OPERATOR_NAMESPACE" &>/dev/null; then
  oc create namespace "$OPERATOR_NAMESPACE"
  echo "✅ Created namespace: $OPERATOR_NAMESPACE"
else
  echo "✅ Namespace already exists: $OPERATOR_NAMESPACE"
fi

# Wait for Kyverno to sync the brew secret to marketplace namespace
echo "Waiting for brew secret to sync to $CATALOG_NAMESPACE..."
TIMEOUT=60
INTERVAL=5
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get secret "$BREW_SECRET_NAME" -n "$CATALOG_NAMESPACE" &>/dev/null 2>&1; then
    echo "✅ Brew secret synced to $CATALOG_NAMESPACE"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "   Waiting for secret sync... (${ELAPSED}s/${TIMEOUT}s)"
done

if ! oc get secret "$BREW_SECRET_NAME" -n "$CATALOG_NAMESPACE" &>/dev/null 2>&1; then
  echo "⚠️  Secret not yet synced — manually copying..."
  oc get secret "$BREW_SECRET_NAME" -n openshift-config -o json | \
    jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp)' | \
    oc apply -n "$CATALOG_NAMESPACE" -f -
fi

# Create CatalogSource using FBC fragment image
echo "Creating CatalogSource: $CATALOG_SOURCE"

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $CATALOG_SOURCE
  namespace: $CATALOG_NAMESPACE
spec:
  displayName: "Red Hat OpenShift AI Dev Catalog"
  image: $IMAGE
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m
  secrets:
  - $BREW_SECRET_NAME
EOF

echo "✅ CatalogSource created: $CATALOG_SOURCE"
echo "   Image: $IMAGE"

# Wait for CatalogSource to be ready
echo "Waiting for CatalogSource to be ready..."
TIMEOUT=300
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  CATALOG_STATE=$(oc get catalogsource "$CATALOG_SOURCE" -n "$CATALOG_NAMESPACE" \
    -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || echo "")

  if [[ "$CATALOG_STATE" == "READY" ]]; then
    echo "✅ CatalogSource is READY"
    break
  fi

  # Check for image pull issues
  CATALOG_POD=$(oc get pod -n "$CATALOG_NAMESPACE" -l olm.catalogSource="$CATALOG_SOURCE" -o name 2>/dev/null | head -1)
  if [[ -n "$CATALOG_POD" ]]; then
    POD_STATUS=$(oc get "$CATALOG_POD" -n "$CATALOG_NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
    if [[ "$POD_STATUS" == "ImagePullBackOff" || "$POD_STATUS" == "ErrImagePull" ]]; then
      echo "   ❌ Catalog pod has $POD_STATUS — check brew credentials and image URL"
      echo "   Pod: $CATALOG_POD"
      oc get events -n "$CATALOG_NAMESPACE" --field-selector "involvedObject.name=${CATALOG_POD#pod/}" --sort-by='.lastTimestamp' 2>/dev/null | tail -3
    fi
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "   CatalogSource state: ${CATALOG_STATE:-Unknown} (${ELAPSED}s/${TIMEOUT}s)"
done

[[ "$CATALOG_STATE" == "READY" ]] || die "CatalogSource not READY after ${TIMEOUT}s. Check brew credentials and image: $IMAGE"
```

### Step 7: Create OperatorGroup and Subscription

```bash
# Create OperatorGroup
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: $OPERATOR_NAMESPACE
spec: {}
EOF

echo "✅ OperatorGroup created (AllNamespaces mode)"

# Create Subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: $OPERATOR_NAMESPACE
spec:
  channel: $CHANNEL
  installPlanApproval: Automatic
  name: rhods-operator
  source: $CATALOG_SOURCE
  sourceNamespace: $CATALOG_NAMESPACE
EOF

echo "✅ Subscription created"
echo "   Channel: $CHANNEL"
echo "   Source: $CATALOG_SOURCE"

sleep 5
```

### Step 8: Wait for Operator CSV

```bash
echo ""
echo "=== Wait for Operator CSV ==="

CSV_PHASE=""
TIMEOUT=600
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  CSV_LINE=$(oc get csv -n "$OPERATOR_NAMESPACE" 2>/dev/null | grep rhods-operator | grep -v Replacing || echo "")

  if [[ -n "$CSV_LINE" ]]; then
    CSV_NAME=$(echo "$CSV_LINE" | awk "{print \$1}")
    CSV_PHASE=$(echo "$CSV_LINE" | awk "{print \$NF}")
    echo "CSV: $CSV_NAME, Phase: $CSV_PHASE"

    if [[ "$CSV_PHASE" == "Succeeded" ]]; then
      echo "✅ Operator installed successfully"
      break
    fi

    # Check for bundle unpack issues (common on ROSA with brew images)
    if [[ "$CSV_PHASE" == "Pending" || "$CSV_PHASE" == "Installing" ]]; then
      UNPACK_JOBS=$(oc get jobs -n "$CATALOG_NAMESPACE" --no-headers 2>/dev/null | grep -c "bundle-unpack" || echo "0")
      FAILED_JOBS=$(oc get jobs -n "$CATALOG_NAMESPACE" --no-headers 2>/dev/null | grep "bundle-unpack" | grep -c "0/1" || echo "0")
      if [[ "$FAILED_JOBS" -gt 0 ]]; then
        echo "   ⚠️  $FAILED_JOBS bundle unpack job(s) failing — may need brew credentials in $CATALOG_NAMESPACE"
      fi
    fi
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for rhods-operator CSV... (${ELAPSED}s/${TIMEOUT}s)"
done

if [[ "$CSV_PHASE" != "Succeeded" ]]; then
  echo ""
  echo "=== DIAGNOSTICS ==="
  echo "--- CatalogSource ---"
  oc get catalogsource "$CATALOG_SOURCE" -n "$CATALOG_NAMESPACE" -o yaml 2>/dev/null | grep -A5 "status:" || true
  echo "--- Subscription ---"
  oc get subscription -n "$OPERATOR_NAMESPACE" -o yaml 2>/dev/null | grep -A10 "status:" || true
  echo "--- InstallPlan ---"
  oc get installplan -n "$OPERATOR_NAMESPACE" 2>/dev/null || true
  echo "--- Failed pods ---"
  oc get pods -n "$OPERATOR_NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || echo "  none"
  echo "==================="
  die "Operator did not reach Succeeded phase within ${TIMEOUT}s"
fi
```

### Step 9: Create DataScienceCluster

```bash
echo ""
echo "=== Create DataScienceCluster ==="

# Wait for DSCInitialization
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get dscinitializations default-dsci &>/dev/null; then
    echo "✅ DSCInitialization found"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for DSCInitialization... (${ELAPSED}s/${TIMEOUT}s)"
done

oc get dscinitializations default-dsci &>/dev/null || die "DSCInitialization not found within ${TIMEOUT}s"

# Create DSC from CSV initialization-resource annotation
CSV_NAME=$(oc get csv -n "$OPERATOR_NAMESPACE" 2>/dev/null | awk '/rhods-operator/{print $1; exit}')
if [[ -n "$CSV_NAME" ]]; then
  oc get csv "$CSV_NAME" -n "$OPERATOR_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.operatorframework\.io/initialization-resource}' \
    > /tmp/default-dsc.json

  oc apply -f /tmp/default-dsc.json
  rm -f /tmp/default-dsc.json
  echo "✅ DSC created from CSV initialization-resource"
else
  die "Cannot find rhods-operator CSV"
fi
```

### Step 10: Configure DSC Components

```bash
echo ""
echo "=== Configure DSC Components ==="

# Wait for DSC to exist
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get datasciencecluster default-dsc &>/dev/null; then
    echo "✅ DataScienceCluster found"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for DataScienceCluster... (${ELAPSED}s/${TIMEOUT}s)"
done

# Patch DSC to enable required components
cat > /tmp/dsc-components-patch.yaml << 'YAML'
spec:
  components:
    aipipelines:
      managementState: Managed
      argoWorkflowsControllers:
        managementState: Managed
    llamastackoperator:
      managementState: Managed
    mlflowoperator:
      managementState: Managed
    trainer:
      managementState: Removed
YAML

oc patch datasciencecluster default-dsc --type merge --patch-file /tmp/dsc-components-patch.yaml || \
  die "Failed to patch DataScienceCluster"
rm -f /tmp/dsc-components-patch.yaml

echo "✅ DSC component configuration applied:"
echo "   - aipipelines: Managed (with argoWorkflowsControllers)"
echo "   - llamastackoperator: Managed"
echo "   - mlflowoperator: Managed"
echo "   - trainer: Removed (requires JobSet operator)"

sleep 5
```

### Step 11: Wait for DSC Ready

```bash
echo ""
echo "=== Wait for DSC Ready ==="

TIMEOUT=600
INTERVAL=15
ELAPSED=0
DSC_PHASE=""

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  DSC_PHASE=$(oc get datasciencecluster -o jsonpath="{.items[0].status.phase}" 2>/dev/null || echo "Unknown")
  echo "DSC phase: $DSC_PHASE"

  if [[ "$DSC_PHASE" == "Ready" ]]; then
    echo "✅ DataScienceCluster is Ready"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for DataScienceCluster... (${ELAPSED}s/${TIMEOUT}s)"
done

if [[ "$DSC_PHASE" != "Ready" ]]; then
  echo "⚠️  WARNING: DSC is not Ready after ${TIMEOUT}s (current: ${DSC_PHASE:-Unknown})"
  echo "Not-ready components:"
  oc get dsc default-dsc -o json 2>/dev/null | \
    jq -r '.status.conditions[] | select(.status=="False") | select(.message | test("Removed") | not) | "  \(.type): \(.message)"' 2>/dev/null || true

  # Check for image pull issues (common on ROSA with brew images)
  echo ""
  echo "Checking for image pull issues..."
  for ns in redhat-ods-operator redhat-ods-applications; do
    PULL_PODS=$(oc get pods -n "$ns" --no-headers 2>/dev/null | grep -E "ImagePullBackOff|ErrImagePull" || echo "")
    if [[ -n "$PULL_PODS" ]]; then
      echo "  ⚠️  Image pull issues in $ns:"
      echo "$PULL_PODS" | while read -r line; do echo "    $line"; done
    fi
  done
fi
```

### Step 12: Wait for Dashboard

```bash
echo ""
echo "=== Wait for Dashboard ==="

TIMEOUT=300
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  READY=$(oc get deployment rhods-dashboard -n redhat-ods-applications -o jsonpath="{.status.readyReplicas}" 2>/dev/null || echo "0")
  DESIRED=$(oc get deployment rhods-dashboard -n redhat-ods-applications -o jsonpath="{.spec.replicas}" 2>/dev/null || echo "0")

  if [[ "$READY" -gt 0 && "$READY" -eq "$DESIRED" ]]; then
    echo "✅ Dashboard deployment is ready"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for dashboard deployment... (${ELAPSED}s/${TIMEOUT}s)"
done

echo "Dashboard containers:"
oc get deployment rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null || \
  echo "  Dashboard deployment not found"
```

### Step 13: Configure Dashboard Features

```bash
echo ""
echo "=== Configure Dashboard Features ==="

# Wait for OdhDashboardConfig to exist
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
    echo "✅ OdhDashboardConfig found"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for OdhDashboardConfig... (${ELAPSED}s/${TIMEOUT}s)"
done

if ! oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
  echo "⚠️  WARNING: OdhDashboardConfig not found yet, feature flags will be configured when available"
else
  oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type merge -p '{
    "spec": {
      "dashboardConfig": {
        "automl": true,
        "autorag": true,
        "genAiStudio": true
      }
    }
  }' || {
    echo "⚠️  WARNING: Failed to patch dashboard config"
  }

  echo "✅ Dashboard feature flags configured:"
  echo "   - automl: enabled"
  echo "   - autorag: enabled"
  echo "   - genAiStudio: enabled"

  # Restart dashboard to pick up changes
  echo "Restarting dashboard to apply feature flag changes..."
  oc rollout restart deployment rhods-dashboard -n redhat-ods-applications 2>/dev/null || true
  sleep 3
fi
```

### Step 14: Verify Installation

```bash
echo ""
echo "=== Installation Summary ==="

# Cluster info
echo ""
echo "Cluster:"
echo "  Type: ROSA $(if [[ "$IS_HCP" == "true" ]]; then echo "HCP"; else echo "Classic"; fi)"
echo "  Server: $(oc whoami --show-server)"

# Show CSV
echo ""
echo "CSV:"
oc get csv -n "$OPERATOR_NAMESPACE" 2>/dev/null | grep rhods-operator || echo "  WARNING: CSV not found"

# Show DSC
echo ""
echo "DSC:"
DSC_PHASE=$(oc get datasciencecluster -o jsonpath="{.items[0].status.phase}" 2>/dev/null || echo "Unknown")
echo "  Phase: $DSC_PHASE"

# Show Dashboard URL
echo ""
echo "Dashboard:"
DASHBOARD_ROUTE=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -n "$DASHBOARD_ROUTE" ]]; then
  echo "  https://$DASHBOARD_ROUTE"
else
  echo "  WARNING: Dashboard route not found yet"
fi

# Kyverno status
echo ""
echo "Kyverno:"
echo "  Policies: $(oc get clusterpolicy --no-headers 2>/dev/null | wc -l | tr -d ' ') active"
echo "  Brew secret: $BREW_SECRET_NAME (synced to all namespaces)"

echo ""
echo "✅ RHOAI installation on ROSA complete!"
```

## Output

The command creates a report at `artifacts/rhoai-manager/reports/install-rosa-report-[timestamp].md` with:
- Installation parameters (version, channel, image)
- ROSA cluster type (HCP vs Classic)
- Kyverno policies created
- Operator CSV details
- DataScienceCluster status
- Dashboard URL
- Feature flags enabled

## ROSA-Specific Details

### Why Kyverno?

ROSA HCP clusters have a **managed pull secret** (OCPBUGS-23901). The platform periodically reconciles the global `pull-secret` in `openshift-config`, reverting any manual additions. This means:
- You cannot permanently add brew.registry.redhat.io credentials to the global pull secret
- OLM unpack jobs and operator pods need brew credentials to pull pre-release images
- Kyverno solves this by syncing a separate pull secret to all namespaces and injecting it into pods

### FBC Fragment Catalog

ROSA installs use the **FBC (File-Based Catalog) fragment** image from `quay.io/rhoai/rhoai-fbc-fragment` instead of the standard `quay.io/modh/rhoai-catalog`. This is the recommended approach for pre-release builds on managed clusters.

## Usage Examples

```bash
# Install latest RHOAI 3.4 on ROSA
/rhoai-install-rosa

# Install specific EA build
/rhoai-install-rosa version=3.4-ea.2

# Install with custom FBC image
/rhoai-install-rosa image=quay.io/rhoai/rhoai-fbc-fragment:rhoai-3.4
```

Or simply ask:
- "Install RHOAI on this ROSA cluster"
- "Set up RHOAI pre-release on ROSA HCP"
- "Install RHOAI nightly on ROSA"

## Common Issues

**Problem:** CatalogSource stuck — catalog pod in ImagePullBackOff
**Solution:** Brew credentials are incorrect or expired. Refresh from employee-token-manager and recreate the secret.

**Problem:** OLM bundle unpack fails
**Solution:** Kyverno policy hasn't synced the brew secret to `openshift-marketplace`. Check `oc get secret pull-secret-brew -n openshift-marketplace`.

**Problem:** Global pull-secret changes get reverted on ROSA HCP
**Solution:** This is expected (OCPBUGS-23901). The Kyverno approach in this command avoids this by using a separate secret.

**Problem:** Operator pods in ImagePullBackOff after CSV Succeeded
**Solution:** Some component images may be on brew.registry.redhat.io. Verify Kyverno `add-brew-imagepullsecret` policy is active.

**Problem:** Dashboard not showing automl/autorag tabs
**Solution:** Feature flags may need a dashboard restart: `oc rollout restart deployment rhods-dashboard -n redhat-ods-applications`

## Next Steps

After installation:
1. Access the dashboard at the URL shown in the output
2. Deploy models using KServe RawDeployment mode (ROSA clusters typically don't have Knative/Serverless)
3. Set up AI pipelines, Llama Stack, and other components
4. To update RHOAI, use `/rhoai-update`
5. To update AutoML/AutoRAG UI to ODH main, patch the CSV env vars (see `/rhoai-update` Step 8)
