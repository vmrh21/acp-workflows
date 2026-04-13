# /rhoai-disconnected - Install or Update RHOAI on a Disconnected OpenShift Cluster

Install or update Red Hat OpenShift AI (RHOAI) on a disconnected (air-gapped) OpenShift cluster. This command handles the unique requirements of disconnected environments: verifying images exist on the bastion registry, using digest-pinned FBC catalogs, applying known workarounds for disconnected-specific issues, and validating all pods can pull their images.

## Command Usage

```bash
# Install RHOAI on a fresh disconnected cluster
/rhoai-disconnected install fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:fe1157d5...

# Update existing RHOAI to a new build
/rhoai-disconnected update fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:abc123...

# Auto-detect install vs update
/rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:fe1157d5...

# With explicit bastion and channel
/rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:fe1157d5... bastion=bastion.example.com:8443 channel=stable-3.4
```

## Inputs

| Input | Required | Description | Example |
|-------|----------|-------------|---------|
| `fbc` | **Yes** | FBC (File-Based Catalog) image reference. Must include `@sha256:` digest. This is the **source** reference (IDMS rewrites to bastion). | `quay.io/rhoai/rhoai-fbc-fragment@sha256:fe1157d5...` |
| `bastion` | No (auto-detected) | Bastion registry host:port. Auto-detected from IDMS if not specified. | `bastion.ods-dis-rhoai-test.aws.rh-ods.com:8443` |
| `channel` | No | OLM subscription channel. Default: `stable-3.4` for install, preserved for update. | `stable-3.4`, `beta` |
| `install` / `update` | No | Force install or update mode. Auto-detected if omitted. | |

**Auto-detected:**

| Value | Source |
|-------|--------|
| `BASTION` | Extracted from IDMS entries for `quay.io/rhoai` or `registry.redhat.io/rhoai` |
| `MODE` | `install` if no RHOAI CSV exists, `update` if one does |
| `RHOAI_VERSION` | Extracted from the CSV version after install/update |

## Prerequisites

1. Logged into the **disconnected** OpenShift cluster with cluster-admin privileges (`/oc-login`)
2. `oc` CLI and `jq` available
3. FBC image and ALL component images already mirrored to the bastion (use `/mirror-images` on the connected cluster first)
4. IDMS (ImageDigestMirrorSet) entries configured for all source registries
5. No ODH installation on the cluster (RHOAI and ODH cannot coexist)
6. **Dependent operators installed** — RHOAI DSC requires these operators to fully reconcile:
   - Red Hat OpenShift Service Mesh (provides `DestinationRule` CRD — required for KServe/gateway)
   - Red Hat OpenShift Serverless (provides `KnativeServing` — required for KServe)
   - Red Hat OpenShift Pipelines (provides Tekton — required for DSP)
   - cert-manager for Red Hat OpenShift (provides `Certificate` CRD — required for TLS)

## Process

### Step 1: Parse Input Arguments

```bash
# Defaults
FBC_IMAGE=""
BASTION=""
CHANNEL=""
MODE=""  # install or update, auto-detected if empty

# Parse key=value arguments
for arg in "$@"; do
  case "$arg" in
    fbc=*)       FBC_IMAGE="${arg#*=}" ;;
    bastion=*)   BASTION="${arg#*=}" ;;
    channel=*)   CHANNEL="${arg#*=}" ;;
    install)     MODE="install" ;;
    update)      MODE="update" ;;
  esac
done

# Validate FBC image is provided and uses digest
if [[ -z "$FBC_IMAGE" ]]; then
  die "FBC image is required. Usage: /rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:..."
fi

if [[ "$FBC_IMAGE" != *"@sha256:"* ]]; then
  echo "WARNING: FBC image should use @sha256: digest for reproducibility on disconnected clusters."
  echo "  Provided: $FBC_IMAGE"
  echo "  Floating tags may resolve to different images if the bastion cache is stale."
fi
```

### Step 2: Verify Cluster Access and Detect Mode

```bash
command -v oc &>/dev/null || die "oc command not found"
command -v jq &>/dev/null || die "jq command not found"
oc whoami &>/dev/null || die "Not logged into an OpenShift cluster"

echo "Logged in as: $(oc whoami)"
echo "Cluster: $(oc whoami --show-server)"

# Check ODH conflict
if oc get csv -n openshift-operators 2>/dev/null | grep -q opendatahub-operator; then
  die "ODH is installed. Uninstall ODH first with /odh-uninstall before installing RHOAI."
fi

# Auto-detect install vs update
if [[ -z "$MODE" ]]; then
  if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods-operator; then
    MODE="update"
    echo "Detected existing RHOAI installation -> UPDATE mode"
  else
    MODE="install"
    echo "No existing RHOAI installation -> INSTALL mode"
  fi
fi

# Set default channel
if [[ -z "$CHANNEL" ]]; then
  if [[ "$MODE" == "update" ]]; then
    CHANNEL=$(oc get subscription -n redhat-ods-operator -o jsonpath='{.items[0].spec.channel}' 2>/dev/null || echo "stable-3.4")
    echo "Preserving existing channel: $CHANNEL"
  else
    CHANNEL="stable-3.4"
    echo "Using default channel: $CHANNEL"
  fi
fi
```

### Step 2b: Verify Dependent Operators

RHOAI DSC cannot fully reconcile without dependent operators. Missing operators cause specific component failures (e.g., KServe fails without Service Mesh, DSP fails without Pipelines). Check and warn early.

```bash
echo ""
echo "=== Checking Dependent Operators ==="

MISSING_DEPS=()

# Service Mesh — required for KServe gateway (DestinationRule CRD)
if oc get crd destinationrules.networking.istio.io &>/dev/null; then
  echo "  Service Mesh: OK"
else
  MISSING_DEPS+=("Red Hat OpenShift Service Mesh (DestinationRule CRD missing — KServe gateway will fail)")
fi

# Serverless — required for KServe (KnativeServing)
if oc get crd knativeservings.operator.knative.dev &>/dev/null; then
  echo "  Serverless: OK"
else
  MISSING_DEPS+=("Red Hat OpenShift Serverless (KnativeServing CRD missing — KServe will fail)")
fi

# Pipelines — required for Data Science Pipelines (Tekton)
if oc get crd pipelines.tekton.dev &>/dev/null; then
  echo "  Pipelines: OK"
else
  MISSING_DEPS+=("Red Hat OpenShift Pipelines (Tekton CRD missing — DSP will fail)")
fi

# Cert Manager — required for TLS certificate management
if oc get crd certificates.cert-manager.io &>/dev/null; then
  echo "  Cert Manager: OK"
else
  MISSING_DEPS+=("cert-manager for Red Hat OpenShift (Certificate CRD missing — TLS cert management will fail)")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  echo ""
  echo "WARNING: ${#MISSING_DEPS[@]} dependent operator(s) are missing:"
  for dep in "${MISSING_DEPS[@]}"; do
    echo "  - $dep"
  done
  echo ""
  echo "RHOAI will install but DSC may not fully reconcile."
  echo "Install these operators from the disconnected catalog before proceeding, or continue with partial functionality."
  echo ""
  echo "Continuing in 10 seconds... (Ctrl+C to cancel)"
  sleep 10
fi
```

### Step 3: Auto-Detect Bastion from IDMS

```bash
if [[ -z "$BASTION" ]]; then
  # Extract bastion from IDMS entries for rhoai source
  BASTION=$(oc get imagedigestmirrorset -o jsonpath='{range .items[*]}{range .spec.imageDigestMirrors[*]}{.source}{"|"}{.mirrors[0]}{"\n"}{end}{end}' 2>/dev/null \
    | grep 'registry.redhat.io/rhoai' \
    | head -1 \
    | awk -F'|' '{print $2}' \
    | sed 's|/rhoai$||')

  if [[ -z "$BASTION" ]]; then
    die "Could not auto-detect bastion from IDMS. Provide it explicitly: bastion=host:port"
  fi

  echo "Auto-detected bastion: $BASTION"
fi
```

### Step 4: Pre-Flight Image Verification

This is the critical step that prevents the ImagePullBackOff failures seen on disconnected clusters. Verify that the FBC image and key component images exist on the bastion BEFORE proceeding.

```bash
echo ""
echo "=== Pre-Flight Image Verification ==="
echo "Checking that required images exist on bastion: $BASTION"

PULL_SECRET_JSON=$(oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d)
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
trap 'rm -f "$TMPFILE"' EXIT
echo "$PULL_SECRET_JSON" > "$TMPFILE"

MISSING_IMAGES=()
VERIFIED_COUNT=0

# 4a. Verify FBC image on bastion
# Compute bastion FBC path from the source FBC reference
FBC_REPO=$(echo "$FBC_IMAGE" | sed 's|@sha256:.*||' | awk -F'/' '{print $NF}')
FBC_DIGEST=$(echo "$FBC_IMAGE" | grep -oE 'sha256:[a-f0-9]+')

# The FBC may be mirrored under different paths depending on IDMS config
# Try the IDMS-mapped path first, then common paths
FBC_BASTION_CANDIDATES=(
  "${BASTION}/rhoai/${FBC_REPO}@${FBC_DIGEST}"
  "${BASTION}/catalogs/${FBC_REPO}@${FBC_DIGEST}"
  "${BASTION}/modh/${FBC_REPO}@${FBC_DIGEST}"
)

FBC_FOUND=false
for candidate in "${FBC_BASTION_CANDIDATES[@]}"; do
  if oc image info "$candidate" --insecure=true -a "$TMPFILE" &>/dev/null; then
    echo "FBC image verified: $candidate"
    FBC_FOUND=true
    FBC_BASTION_REF="$candidate"
    break
  fi
done

if [[ "$FBC_FOUND" != "true" ]]; then
  MISSING_IMAGES+=("FBC: $FBC_IMAGE")
  echo "MISSING: FBC image not found on bastion"
fi

# 4b. Extract relatedImages from the FBC catalog and verify key images
# Render the catalog from the FBC image to get the CSV's relatedImages
echo ""
echo "Extracting relatedImages from FBC catalog..."

# Create a temporary pod to read the FBC catalog content
CATALOG_CONTENT=$(oc run fbc-verify --image="$FBC_IMAGE" --restart=Never \
  --command -- cat /configs/rhods-operator/catalog.yaml 2>/dev/null && \
  oc logs fbc-verify 2>/dev/null; oc delete pod fbc-verify --force 2>/dev/null || true)

# If pod-based extraction fails (common on disconnected), use the CatalogSource approach:
# Create a temporary CatalogSource, wait for it, then query via the catalog pod
if [[ -z "$CATALOG_CONTENT" ]]; then
  echo "Direct extraction failed, using CatalogSource approach..."

  # Create temp CatalogSource
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-catalog-verify
  namespace: openshift-marketplace
spec:
  displayName: "RHOAI Verify (temp)"
  image: $FBC_IMAGE
  sourceType: grpc
EOF

  # Wait for catalog pod to be ready
  TIMEOUT=120
  ELAPSED=0
  while [[ $ELAPSED -lt $TIMEOUT ]]; do
    CATALOG_STATE=$(oc get catalogsource rhoai-catalog-verify -n openshift-marketplace \
      -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || echo "")
    if [[ "$CATALOG_STATE" == "READY" ]]; then
      break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
  done

  if [[ "$CATALOG_STATE" == "READY" ]]; then
    CATALOG_POD=$(oc get pod -n openshift-marketplace -l olm.catalogSource=rhoai-catalog-verify -o name 2>/dev/null | head -1)
    if [[ -n "$CATALOG_POD" ]]; then
      CATALOG_CONTENT=$(oc exec -n openshift-marketplace "$CATALOG_POD" -- cat /configs/rhods-operator/catalog.yaml 2>/dev/null || echo "")
    fi
  fi
fi

# 4c. Parse relatedImages and verify each on bastion
# Pre-fetch full IDMS source-to-mirror mappings for path resolution
IDMS_SOURCES_FULL=$(oc get imagedigestmirrorset -o jsonpath='{range .items[*]}{range .spec.imageDigestMirrors[*]}{.source}{"|"}{.mirrors[0]}{"\n"}{end}{end}' 2>/dev/null || echo "")

if [[ -n "$CATALOG_CONTENT" ]]; then
  # Extract all image references from the catalog
  RELATED_IMAGES=$(echo "$CATALOG_CONTENT" | grep -oE 'registry\.[^"]+@sha256:[a-f0-9]+|quay\.io[^"]+@sha256:[a-f0-9]+' | sort -u)

  TOTAL_IMAGES=$(echo "$RELATED_IMAGES" | wc -l | tr -d ' ')
  echo "Found $TOTAL_IMAGES relatedImages in FBC catalog"
  echo "Verifying each image exists on bastion..."

  while IFS= read -r img; do
    [[ -z "$img" ]] && continue

    # Compute bastion path using IDMS entries to find the correct mirror path
    # Extract source prefix from the image (e.g., registry.redhat.io/rhoai from registry.redhat.io/rhoai/odh-dashboard-rhel9@sha256:abc)
    IMG_SOURCE_PREFIX=$(echo "$img" | sed -E 's|/[^/]+@sha256:.*||')
    IMG_NAME_DIGEST=$(echo "$img" | sed -E "s|^${IMG_SOURCE_PREFIX}/||")

    # Look up the mirror path from IDMS for this source prefix
    IDMS_MIRROR=$(echo "$IDMS_SOURCES_FULL" | grep "^${IMG_SOURCE_PREFIX}|" | head -1 | awk -F'|' '{print $2}')

    if [[ -n "$IDMS_MIRROR" ]]; then
      BASTION_IMG="${IDMS_MIRROR}/${IMG_NAME_DIGEST}"
    else
      # Fallback: strip registry hostname, prepend bastion
      IMG_PATH=$(echo "$img" | sed -E 's|^[^/]+/||')
      BASTION_IMG="${BASTION}/${IMG_PATH}"
    fi

    if oc image info "$BASTION_IMG" --insecure=true -a "$TMPFILE" &>/dev/null; then
      VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
    else
      MISSING_IMAGES+=("$img")
    fi
  done <<< "$RELATED_IMAGES"
else
  echo "WARNING: Could not extract relatedImages from FBC. Skipping image verification."
  echo "Proceed with caution - pods may fail with ImagePullBackOff if images are missing."
fi

# Clean up temp CatalogSource
oc delete catalogsource rhoai-catalog-verify -n openshift-marketplace 2>/dev/null || true

# 4d. Report results
echo ""
echo "=== Pre-Flight Results ==="
echo "Verified: $VERIFIED_COUNT images"
echo "Missing:  ${#MISSING_IMAGES[@]} images"

if [[ ${#MISSING_IMAGES[@]} -gt 0 ]]; then
  echo ""
  echo "MISSING IMAGES:"
  for img in "${MISSING_IMAGES[@]}"; do
    echo "  $img"
  done
  echo ""
  echo "ERROR: ${#MISSING_IMAGES[@]} images are missing from the bastion registry."
  echo "Run /mirror-images on the connected cluster to mirror these images first."
  die "Pre-flight image verification failed"
fi

echo "All images verified on bastion"
```

### Step 5: Verify IDMS Entries

```bash
echo ""
echo "=== Verifying IDMS Entries ==="

# Check that IDMS entries exist for all source registries used by RHOAI
REQUIRED_SOURCES=(
  "registry.redhat.io/rhoai"
  "registry.redhat.io/rhel9"
  "registry.redhat.io/ubi9"
  "registry.redhat.io/openshift-service-mesh"
  "registry.redhat.io/rhbk"
  "registry.redhat.io/cert-manager"
  "registry.redhat.io/rhcl-1"
  "registry.redhat.io/rhaii-early-access"
  "quay.io/rhoai"
  "quay.io/minio"
  "quay.io/opendatahub"
  "docker.io/milvusdb"
)

IDMS_SOURCES=$(oc get imagedigestmirrorset -o jsonpath='{range .items[*]}{range .spec.imageDigestMirrors[*]}{.source}{"\n"}{end}{end}' 2>/dev/null | sort -u)

MISSING_IDMS=()
for source in "${REQUIRED_SOURCES[@]}"; do
  if echo "$IDMS_SOURCES" | grep -q "$source"; then
    echo "  IDMS OK: $source"
  else
    MISSING_IDMS+=("$source")
    echo "  IDMS MISSING: $source"
  fi
done

if [[ ${#MISSING_IDMS[@]} -gt 0 ]]; then
  echo ""
  echo "WARNING: ${#MISSING_IDMS[@]} IDMS entries are missing."
  echo "Pods pulling from these registries will fail with ImagePullBackOff."
  echo "The IDMS YAML can be generated by /mirror-images."
  echo ""
  echo "Continuing anyway - but watch for ImagePullBackOff errors."
fi
```

### Step 6: Create or Update CatalogSource

```bash
echo ""
echo "=== Setting Up OLM Catalog ==="

# Use the FBC image reference directly - IDMS handles rewriting to bastion
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhoai-catalog-dev
  namespace: openshift-marketplace
spec:
  displayName: "Red Hat OpenShift AI"
  image: $FBC_IMAGE
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 30m
EOF

echo "CatalogSource created/updated with image: $FBC_IMAGE"

# Force catalog pod refresh to ensure it picks up the new image
CATALOG_POD=$(oc get pod -n openshift-marketplace -l olm.catalogSource=rhoai-catalog-dev -o name 2>/dev/null | head -1)
if [[ -n "$CATALOG_POD" ]]; then
  echo "Deleting old catalog pod to force image refresh..."
  oc delete "$CATALOG_POD" -n openshift-marketplace 2>/dev/null || true
fi

# Wait for catalog to be READY
TIMEOUT=180
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  CATALOG_STATE=$(oc get catalogsource rhoai-catalog-dev -n openshift-marketplace \
    -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || echo "")

  if [[ "$CATALOG_STATE" == "READY" ]]; then
    echo "CatalogSource is READY"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "  CatalogSource state: ${CATALOG_STATE:-Unknown} (${ELAPSED}s/${TIMEOUT}s)"
done

[[ "$CATALOG_STATE" == "READY" ]] || die "CatalogSource not READY after ${TIMEOUT}s. Check that the FBC image is accessible on the bastion."
```

### Step 7: Install - Create Namespace, OperatorGroup, Subscription (Install mode only)

```bash
if [[ "$MODE" == "install" ]]; then
  OPERATOR_NAMESPACE="redhat-ods-operator"

  # Create namespace
  if ! oc get namespace "$OPERATOR_NAMESPACE" &>/dev/null; then
    oc create namespace "$OPERATOR_NAMESPACE"
    echo "Created namespace: $OPERATOR_NAMESPACE"
  fi

  # Create OperatorGroup
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: $OPERATOR_NAMESPACE
spec:
  targetNamespaces:
  - $OPERATOR_NAMESPACE
EOF

  echo "OperatorGroup created"

  # Create Subscription
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhoai-operator-dev
  namespace: $OPERATOR_NAMESPACE
spec:
  channel: $CHANNEL
  installPlanApproval: Automatic
  name: rhods-operator
  source: rhoai-catalog-dev
  sourceNamespace: openshift-marketplace
EOF

  echo "Subscription created (channel: $CHANNEL)"
fi
```

### Step 8: Update - Forced Reinstall to Pick Up New Images (Update mode only)

On disconnected clusters, OLM may not auto-update if only component images changed (CSV version unchanged). Force a reinstall.

```bash
if [[ "$MODE" == "update" ]]; then
  echo ""
  echo "=== Forcing Operator Reinstall ==="

  # Record current state
  OLD_CSV=$(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods-operator | grep -v Replacing | awk '{print $1}')
  SUB_NAME=$(oc get subscription -n redhat-ods-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  echo "Current CSV: $OLD_CSV"
  echo "Current subscription: $SUB_NAME"

  # Delete CSV to force OLM to reinstall from updated catalog
  if [[ -n "$OLD_CSV" ]]; then
    echo "Deleting CSV: $OLD_CSV"
    oc delete csv "$OLD_CSV" -n redhat-ods-operator || true
    sleep 10
  fi

  # Delete and recreate subscription
  if [[ -n "$SUB_NAME" ]]; then
    echo "Deleting subscription: $SUB_NAME"
    oc delete subscription "$SUB_NAME" -n redhat-ods-operator || true
    sleep 5
  fi

  # Recreate subscription pointing to updated catalog
  cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhoai-operator-dev
  namespace: redhat-ods-operator
spec:
  channel: $CHANNEL
  installPlanApproval: Automatic
  name: rhods-operator
  source: rhoai-catalog-dev
  sourceNamespace: openshift-marketplace
EOF

  echo "Subscription recreated (channel: $CHANNEL)"
fi
```

### Step 9: Wait for Operator CSV

```bash
echo ""
echo "=== Waiting for Operator CSV ==="

CSV_PHASE=""
TIMEOUT=600
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  CSV_LINE=$(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods-operator | grep -v Replacing || echo "")

  if [[ -n "$CSV_LINE" ]]; then
    CSV_NAME=$(echo "$CSV_LINE" | awk '{print $1}')
    CSV_PHASE=$(echo "$CSV_LINE" | awk '{print $NF}')
    echo "CSV: $CSV_NAME, Phase: $CSV_PHASE"

    if [[ "$CSV_PHASE" == "Succeeded" ]]; then
      echo "Operator CSV installed successfully"
      break
    fi
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

[[ "$CSV_PHASE" == "Succeeded" ]] || die "Operator did not reach Succeeded phase within ${TIMEOUT}s"

# Extract version
RHOAI_VERSION=$(oc get csv "$CSV_NAME" -n redhat-ods-operator -o jsonpath='{.spec.version}' 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+')
echo "RHOAI Version: $RHOAI_VERSION"
```

### Step 10: Create/Configure DataScienceCluster

```bash
echo ""
echo "=== Configuring DataScienceCluster ==="

# Wait for DSCInitialization
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get dscinitializations default-dsci &>/dev/null; then
    echo "DSCInitialization found"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# For install mode, create DSC from CSV initialization-resource
if [[ "$MODE" == "install" ]]; then
  CSV_NAME=$(oc get csv -n redhat-ods-operator 2>/dev/null | awk '/rhods-operator/{print $1; exit}')
  if [[ -n "$CSV_NAME" ]]; then
    oc get csv "$CSV_NAME" -n redhat-ods-operator \
      -o jsonpath='{.metadata.annotations.operatorframework\.io/initialization-resource}' \
      > /tmp/default-dsc.json
    oc apply -f /tmp/default-dsc.json
    echo "DSC created from CSV initialization-resource"
    rm -f /tmp/default-dsc.json
  fi
fi

# Wait for DSC to exist
TIMEOUT=120
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get datasciencecluster default-dsc &>/dev/null; then
    echo "DataScienceCluster found"
    break
  fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Patch DSC to enable required components with disconnected-specific settings
cat > /tmp/dsc-patch.yaml << 'YAML'
spec:
  components:
    aipipelines:
      managementState: Managed
      argoWorkflowsControllers:
        managementState: Managed
    kserve:
      serving:
        managementState: Managed
      rawDeploymentServiceConfig: Headless
    nim:
      managementState: Managed
      airGapped: true
    llamastackoperator:
      managementState: Managed
    mlflowoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    trainer:
      managementState: Removed
YAML

oc patch datasciencecluster default-dsc --type merge --patch-file /tmp/dsc-patch.yaml || \
  die "Failed to patch DataScienceCluster"

echo "DSC component configuration applied:"
echo "  - aipipelines: Managed (with argoWorkflowsControllers)"
echo "  - kserve: Managed (rawDeploymentServiceConfig: Headless for disconnected)"
echo "  - nim: Managed (airGapped: true for disconnected)"
echo "  - llamastackoperator: Managed"
echo "  - mlflowoperator: Managed"
echo "  - trustyai: Managed"
echo "  - trainer: Removed (requires JobSet operator)"

rm -f /tmp/dsc-patch.yaml
```

### Step 11: Wait for DSC Ready

```bash
echo ""
echo "=== Waiting for DataScienceCluster ==="

TIMEOUT=600
INTERVAL=15
ELAPSED=0
DSC_PHASE=""

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  DSC_PHASE=$(oc get datasciencecluster -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
  echo "DSC phase: $DSC_PHASE"

  if [[ "$DSC_PHASE" == "Ready" ]]; then
    echo "DataScienceCluster is Ready"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ "$DSC_PHASE" != "Ready" ]]; then
  echo "WARNING: DSC is not Ready after ${TIMEOUT}s (current: ${DSC_PHASE:-Unknown})"
  echo "Not-ready components:"
  oc get dsc default-dsc -o json 2>/dev/null | \
    jq -r '.status.conditions[] | select(.status=="False") | select(.message | test("Removed") | not) | "  \(.type): \(.message)"' 2>/dev/null || true
fi
```

### Step 12: Post-Install/Update Health Check - Verify No ImagePullBackOff

This is critical for disconnected clusters. After the operator reconciles, check ALL pods in RHOAI namespaces for ImagePullBackOff or ErrImagePull errors.

```bash
echo ""
echo "=== Post-Install Health Check ==="
echo "Waiting 60 seconds for operator to reconcile pods..."
sleep 60

PROBLEM_PODS=()

# Check pods in all RHOAI-related namespaces
for ns in redhat-ods-operator redhat-ods-applications; do
  PODS=$(oc get pods -n "$ns" --no-headers 2>/dev/null || echo "")

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    POD_NAME=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $3}')

    if [[ "$STATUS" == "ImagePullBackOff" || "$STATUS" == "ErrImagePull" ]]; then
      # Get the failing image
      FAILING_IMAGE=$(oc get pod "$POD_NAME" -n "$ns" -o jsonpath='{range .status.containerStatuses[*]}{.state.waiting.message}{"\n"}{end}' 2>/dev/null | grep -oE 'image "[^"]+"' | head -1)
      PROBLEM_PODS+=("$ns/$POD_NAME: $STATUS ($FAILING_IMAGE)")
    elif [[ "$STATUS" == "CrashLoopBackOff" ]]; then
      PROBLEM_PODS+=("$ns/$POD_NAME: $STATUS")
    fi
  done <<< "$PODS"
done

if [[ ${#PROBLEM_PODS[@]} -gt 0 ]]; then
  echo ""
  echo "WARNING: ${#PROBLEM_PODS[@]} pods have issues:"
  for pod in "${PROBLEM_PODS[@]}"; do
    echo "  $pod"
  done
  echo ""
  echo "For ImagePullBackOff: The image is missing from the bastion. Run /mirror-images to mirror it."
  echo "For CrashLoopBackOff: Check pod logs for root cause (may be the podToPodTLS bug - see Step 13)."
else
  echo "All pods in RHOAI namespaces are running normally"
fi
```

### Step 13: Apply Known Disconnected Workarounds

#### 13a. podToPodTLS Bug Workaround

In some RHOAI nightly builds, the DSP operator sets `--caCertPath` flag in pipeline component deployments, but the binary only supports `--mlPipelineServiceTLSCert`. This causes CrashLoopBackOff for `scheduledworkflow` and other pipeline pods with error: `flag provided but not defined: -caCertPath`.

The workaround is to set `podToPodTLS: false` on all DataSciencePipelinesApplication (DSPA) CRs. This must be applied AFTER the operator creates the DSPA resources.

```bash
echo ""
echo "=== Applying Known Disconnected Workarounds ==="

# 13a. Check for and fix podToPodTLS bug
# Only apply if pipeline components are enabled and DSPAs exist
DSPA_LIST=$(oc get datasciencepipelinesapplication --all-namespaces --no-headers 2>/dev/null || echo "")

if [[ -n "$DSPA_LIST" ]]; then
  echo "Found DataSciencePipelinesApplication resources. Checking for podToPodTLS bug..."

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    DSPA_NS=$(echo "$line" | awk '{print $1}')
    DSPA_NAME=$(echo "$line" | awk '{print $2}')

    # Check if any pipeline pods are in CrashLoopBackOff with caCertPath error
    CRASH_PODS=$(oc get pods -n "$DSPA_NS" --no-headers 2>/dev/null | grep CrashLoopBackOff || echo "")

    if [[ -n "$CRASH_PODS" ]]; then
      # Check logs for the specific caCertPath error
      for crash_pod in $(echo "$CRASH_PODS" | awk '{print $1}'); do
        if oc logs "$crash_pod" -n "$DSPA_NS" --tail=5 2>/dev/null | grep -q "caCertPath"; then
          echo "  Found podToPodTLS bug in $DSPA_NS/$DSPA_NAME"
          echo "  Applying workaround: podToPodTLS=false"
          oc patch datasciencepipelinesapplication "$DSPA_NAME" -n "$DSPA_NS" \
            --type='merge' -p '{"spec":{"podToPodTLS":false}}'
        fi
      done
    fi

    # Also proactively set podToPodTLS=false to prevent the issue
    CURRENT_TLS=$(oc get datasciencepipelinesapplication "$DSPA_NAME" -n "$DSPA_NS" \
      -o jsonpath='{.spec.podToPodTLS}' 2>/dev/null || echo "")
    if [[ "$CURRENT_TLS" != "false" ]]; then
      echo "  Setting podToPodTLS=false on $DSPA_NS/$DSPA_NAME (proactive)"
      oc patch datasciencepipelinesapplication "$DSPA_NAME" -n "$DSPA_NS" \
        --type='merge' -p '{"spec":{"podToPodTLS":false}}'
    fi
  done <<< "$DSPA_LIST"
else
  echo "No DSPAs found (pipelines not yet configured). podToPodTLS workaround will need to be applied after creating DSPAs."
  echo "  Command: oc patch datasciencepipelinesapplication <name> -n <namespace> --type='merge' -p '{\"spec\":{\"podToPodTLS\":false}}'"
fi
```

#### 13b. PersistenceAgent TLS Certificate Fix (Proactive + Reactive)

The pipeline persistenceagent may fail with `x509: certificate signed by unknown authority` when connecting to the pipeline API server. This happens because the trusted CA bundle doesn't include the OpenShift service-ca that signed the pipeline API server cert.

**Proactive fix:** Apply the service-ca to ALL DSPA trusted CA configmaps immediately, before waiting for a crash. This prevents the issue entirely.

```bash
# 13b. Proactively fix persistenceagent TLS for all DSPAs
SERVICE_CA=$(oc get configmap openshift-service-ca.crt -n openshift-config-managed \
  -o jsonpath='{.data.service-ca\.crt}' 2>/dev/null || echo "")

if [[ -n "$SERVICE_CA" && -n "$DSPA_LIST" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    DSPA_NS=$(echo "$line" | awk '{print $1}')
    DSPA_NAME=$(echo "$line" | awk '{print $2}')

    CM_NAME="dsp-trusted-ca-${DSPA_NAME}"

    # Wait for the configmap to be created by the operator (up to 60s)
    TIMEOUT=60
    ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      if oc get configmap "$CM_NAME" -n "$DSPA_NS" &>/dev/null; then
        break
      fi
      sleep 5
      ELAPSED=$((ELAPSED + 5))
    done

    if oc get configmap "$CM_NAME" -n "$DSPA_NS" &>/dev/null; then
      CURRENT_CA=$(oc get configmap "$CM_NAME" -n "$DSPA_NS" -o jsonpath='{.data.dsp-ca\.crt}' 2>/dev/null || echo "")

      if [[ -n "$CURRENT_CA" ]] && ! echo "$CURRENT_CA" | grep -q "openshift-service-serving-signer"; then
        echo "  Proactively appending service-ca to $CM_NAME in $DSPA_NS"
        COMBINED_CA="${CURRENT_CA}
${SERVICE_CA}"
        TMPCA=$(mktemp)
        chmod 600 "$TMPCA"
        echo "$COMBINED_CA" > "$TMPCA"
        oc create configmap "$CM_NAME" -n "$DSPA_NS" \
          --from-file=dsp-ca.crt="$TMPCA" \
          --dry-run=client -o yaml | oc replace -f -
        rm -f "$TMPCA"
        echo "  Service-ca appended to $CM_NAME"

        # Restart persistenceagent if it exists (may or may not be running yet)
        PA_POD=$(oc get pods -n "$DSPA_NS" --no-headers 2>/dev/null | grep persistenceagent | awk '{print $1}')
        if [[ -n "$PA_POD" ]]; then
          oc delete pod "$PA_POD" -n "$DSPA_NS" 2>/dev/null || true
          echo "  Restarted persistenceagent pod"
        fi
      else
        echo "  $CM_NAME in $DSPA_NS already has service-ca (or empty)"
      fi
    else
      echo "  WARNING: $CM_NAME not found in $DSPA_NS after ${TIMEOUT}s. Will need manual fix after DSPA creates it."
    fi
  done <<< "$DSPA_LIST"
elif [[ -z "$SERVICE_CA" ]]; then
  echo "  WARNING: Could not retrieve openshift-service-ca.crt — persistenceagent TLS fix skipped"
fi
```

### Step 14: Configure Dashboard Features

```bash
echo ""
echo "=== Configuring Dashboard ==="

# Wait for dashboard
TIMEOUT=300
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  READY=$(oc get deployment rhods-dashboard -n redhat-ods-applications -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED=$(oc get deployment rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

  if [[ "$READY" -gt 0 && "$READY" -eq "$DESIRED" ]]; then
    echo "Dashboard deployment is ready ($READY/$DESIRED)"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Wait for OdhDashboardConfig
TIMEOUT=120
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
    break
  fi
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

# Enable feature flags
if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
  oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type merge -p '{
    "spec": {
      "dashboardConfig": {
        "automl": true,
        "autorag": true,
        "genAiStudio": true
      }
    }
  }' 2>/dev/null || echo "WARNING: Failed to patch dashboard config"

  echo "Dashboard feature flags configured (automl, autorag, genAiStudio)"

  # Restart dashboard to pick up changes
  oc rollout restart deployment rhods-dashboard -n redhat-ods-applications 2>/dev/null || true
else
  echo "WARNING: OdhDashboardConfig not found. Feature flags will need manual configuration."
fi
```

### Step 15: Final Verification

```bash
echo ""
echo "=========================================="
echo "  RHOAI ${MODE^^} Summary (Disconnected)"
echo "=========================================="

# CSV info
echo ""
echo "Operator CSV:"
oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods-operator || echo "  WARNING: CSV not found"

# Version
echo ""
CSV_NAME=$(oc get csv -n redhat-ods-operator 2>/dev/null | awk '/rhods-operator/{print $1; exit}')
if [[ -n "$CSV_NAME" ]]; then
  VERSION=$(oc get csv "$CSV_NAME" -n redhat-ods-operator -o jsonpath='{.spec.version}' 2>/dev/null)
  echo "RHOAI Version: $VERSION"
fi

# FBC image
echo "FBC Image: $FBC_IMAGE"
echo "Channel: $CHANNEL"
echo "Bastion: $BASTION"

# DSC status
echo ""
echo "DataScienceCluster:"
DSC_PHASE=$(oc get datasciencecluster -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
echo "  Phase: $DSC_PHASE"

# Dashboard URL
echo ""
echo "Dashboard:"
DASHBOARD_ROUTE=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -n "$DASHBOARD_ROUTE" ]]; then
  echo "  https://$DASHBOARD_ROUTE"
else
  echo "  Route not found yet"
fi

# Pod health summary
echo ""
echo "Pod Health (RHOAI namespaces):"
for ns in redhat-ods-operator redhat-ods-applications; do
  TOTAL=$(oc get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  RUNNING=$(oc get pods -n "$ns" --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
  ISSUES=$(oc get pods -n "$ns" --no-headers 2>/dev/null | grep -cE 'ImagePullBackOff|ErrImagePull|CrashLoopBackOff' | tr -d ' ')
  echo "  $ns: $RUNNING/$TOTAL running, $ISSUES with issues"
done

echo ""
if [[ "$DSC_PHASE" == "Ready" ]]; then
  echo "RHOAI ${MODE} on disconnected cluster complete!"
else
  echo "RHOAI ${MODE} completed but DSC is not fully Ready."
  echo "Check pod status and apply workarounds if needed."
fi
```

## Known Issues and Workarounds

### 1. podToPodTLS CrashLoopBackOff (DSP Components)

**Symptom:** Pipeline pods (`scheduledworkflow`, `persistenceagent`) crash with `flag provided but not defined: -caCertPath`

**Cause:** RHOAI nightly build bug -- operator sets `--caCertPath` in deployment spec but the binary only supports `--mlPipelineServiceTLSCert`

**Fix:** Applied automatically in Step 13a. For new DSPAs created after install:
```bash
oc patch datasciencepipelinesapplication <name> -n <namespace> --type='merge' -p '{"spec":{"podToPodTLS":false}}'
```

### 2. PersistenceAgent x509 Certificate Error

**Symptom:** `persistenceagent` crashes with `x509: certificate signed by unknown authority` when connecting to `ds-pipeline-*.svc.cluster.local:8888`

**Cause:** The DSP trusted CA configmap has Mozilla CA bundle but NOT the OpenShift service-ca that signed the pipeline API server cert

**Fix:** Applied automatically in Step 13b. Manual fix:
```bash
# Get the service-ca
SERVICE_CA=$(oc get configmap openshift-service-ca.crt -n openshift-config-managed -o jsonpath='{.data.service-ca\.crt}')
# Append to the existing DSP CA configmap
```

### 3. Missing Images on Bastion

**Symptom:** Multiple pods in `ImagePullBackOff` state after install/update

**Cause:** Not all RHOAI images were mirrored to the bastion before install/update

**Prevention:** Step 4 (pre-flight verification) catches this before proceeding. Always run `/mirror-images` on the connected cluster first.

### 4. EvalHub Cross-Namespace Issues

**Symptom:** EvalHub evaluation jobs fail when running in a different namespace than `evalhub`

**Cause:** EvalHub operator creates K8s Jobs in the target namespace but doesn't create the required ServiceAccount (`evalhub-evalhub-job`) or ConfigMap (`evalhub-service-ca`) there

**Fix:** Manually create the SA and copy the ConfigMap:
```bash
oc create sa evalhub-evalhub-job -n <target-namespace>
oc adm policy add-role-to-user edit system:serviceaccount:<target-namespace>:evalhub-evalhub-job -n <target-namespace>
oc get configmap evalhub-service-ca -n evalhub -o json | \
  jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp,.metadata.managedFields,.metadata.ownerReferences)' | \
  oc create -n <target-namespace> -f -
```

## Output

The command creates a report at `artifacts/rhoai-manager/reports/disconnected-{install|update}-report-[timestamp].md` with:
- FBC image reference and digest
- Pre-flight verification results
- Operator CSV details
- DataScienceCluster status
- Pod health check results
- Workarounds applied
- Dashboard URL
