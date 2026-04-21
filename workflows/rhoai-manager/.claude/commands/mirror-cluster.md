# /mirror-cluster - Mirror Images from Connected Cluster to Disconnected Bastion

## Purpose

Mirror all container images required for a disconnected OpenShift cluster running RHOAI. Supports two modes:

- **`setup`** (default) — Full mirror for a fresh disconnected cluster: RHOAI operator + all CSV components + infrastructure services (minio, milvus, keycloak, cert-manager, postgresql, modelcar models, etc.)
- **`update`** — Incremental mirror for RHOAI version updates: new FBC fragment + operator bundle + changed CSV component images only

Runs the mirror job from a pod on the connected cluster for fast AWS-internal transfers. Uses `skopeo copy --all --remove-signatures` to preserve original manifest digests (unlike `oc image mirror` which rewrites them).

## Command Usage

- `/mirror-cluster bastion=bastion.example.com:8443` — Full setup mirror (default mode)
- `/mirror-cluster mode=setup bastion=bastion.example.com:8443` — Explicit setup mode
- `/mirror-cluster mode=update bastion=bastion.example.com:8443` — Update mode (RHOAI CSV images only)
- `/mirror-cluster bastion=bastion.example.com:8443 extras=registry.redhat.io/rhoai/odh-autorag-rhel9@sha256:abc123` — Include additional images
- `/mirror-cluster bastion=bastion.example.com:8443 exclude=spark,habana` — Exclude image name patterns

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `bastion` | Yes | — | Bastion registry `host:port` (comma-separated for multiple) |
| `mode` | No | `setup` | `setup` = full fresh cluster, `update` = RHOAI delta only |
| `extras` | No | — | Comma-separated extra image refs to mirror |
| `exclude` | No | — | Comma-separated image name patterns to skip |

The command will prompt for bastion credentials (`BASTION_USER`, `BASTION_PASSWORD`) if not already known.

**Auto-detected (no user input needed):**

| Value | Source |
|-------|--------|
| `RHOAI_VERSION` | From CSV version on connected cluster |
| `FBC_IMAGE` | From CatalogSource on connected cluster |
| `ICSP/IDMS mappings` | From connected cluster's ImageContentSourcePolicy / ImageDigestMirrorSet |

## Prerequisites

- `oc` CLI authenticated to the **connected** OpenShift cluster
- Connected cluster has RHOAI installed and running
- For `setup` mode: infrastructure services (minio, keycloak, milvus, postgres, etc.) should be running so their images can be captured
- Network access from connected cluster pods to the bastion registry

## Process

### Step 1: Detect Mode and Validate

Determine mode from user input (default: `setup`). Verify cluster connectivity and RHOAI installation:

```bash
oc whoami
CSV_NAME=$(oc get csv -n redhat-ods-operator -o name 2>/dev/null | grep rhods-operator)
RHOAI_VERSION=$(oc get "$CSV_NAME" -n redhat-ods-operator -o jsonpath='{.spec.version}' | grep -oE '^[0-9]+\.[0-9]+')
echo "RHOAI version: $RHOAI_VERSION"
```

### Step 2: Extract Image List

#### 2a. RHOAI CSV relatedImages (both modes)

Extract ALL images from the operator CSV. These are the core RHOAI images (~124 images).

```bash
oc get "$CSV_NAME" -n redhat-ods-operator -o json | jq -r '.spec.relatedImages[].image' | sort -u > /tmp/mirror-csv-images.txt
wc -l /tmp/mirror-csv-images.txt
```

#### 2b. FBC / CatalogSource images (both modes)

```bash
oc get catalogsource --all-namespaces -o jsonpath='{range .items[*]}{.spec.image}{"\n"}{end}' | sort -u > /tmp/mirror-fbc-images.txt
```

#### 2c. Infrastructure images from running pods (setup mode only)

Scan all non-platform namespaces for running pod images. This captures minio, keycloak, milvus, postgresql, mariadb, argoexec, curl, vllm, llama-stack, cert-manager, service mesh, etc.

```bash
oc get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' \
  | grep -vE '^(openshift-|kube-|nvidia-)' \
  | awk '{print $NF}' \
  | sort -u > /tmp/mirror-pod-images.txt
```

#### 2d. ModelCar images (setup mode only)

These are the LLM and embedding model images for InferenceService deployments. Extract from any running InferenceService or known model configs:

```bash
# Get modelcar images from InferenceService specs
oc get inferenceservice --all-namespaces -o json 2>/dev/null \
  | jq -r '.items[].spec.predictor.model.storageUri // empty' \
  | grep -oE '[a-z0-9.]+/[a-zA-Z0-9_./-]+@sha256:[a-f0-9]+' \
  | sort -u > /tmp/mirror-modelcar-images.txt

# Also check for modelcar images in pod specs (initContainers with model volumes)
oc get pods --all-namespaces -o json 2>/dev/null \
  | jq -r '.items[].spec.initContainers[]? | select(.name == "storage-initializer" or .name == "model-initializer") | .image // empty' \
  | sort -u >> /tmp/mirror-modelcar-images.txt
```

#### 2e. Extra images (if provided)

If the user specified `extras=`, add those to the list:

```bash
# Parse comma-separated extras into the image list
for img in ${EXTRAS//,/ }; do
  echo "$img" >> /tmp/mirror-extras.txt
done
```

#### 2f. Merge, deduplicate, and filter

Combine all lists, deduplicate, and apply exclusion filters:

```bash
cat /tmp/mirror-csv-images.txt \
    /tmp/mirror-fbc-images.txt \
    /tmp/mirror-pod-images.txt \
    /tmp/mirror-modelcar-images.txt \
    /tmp/mirror-extras.txt 2>/dev/null \
  | sort -u \
  | grep -v '^$' > /tmp/mirror-all-images-raw.txt

# Filter out platform images and apply exclude patterns
grep -vE '(^bastion\.|nvcr\.io/nvidia|openshift-release-dev)' /tmp/mirror-all-images-raw.txt \
  > /tmp/mirror-all-images.txt

# Apply user exclusions
if [ -n "${EXCLUDE_PATTERNS:-}" ]; then
  for pattern in ${EXCLUDE_PATTERNS//,/ }; do
    grep -vi "$pattern" /tmp/mirror-all-images.txt > /tmp/mirror-filtered.txt
    mv /tmp/mirror-filtered.txt /tmp/mirror-all-images.txt
  done
fi

TOTAL=$(wc -l < /tmp/mirror-all-images.txt)
echo "Total images to mirror: $TOTAL"
```

For **update mode**, only use the CSV + FBC images (skip 2c, 2d):

```bash
cat /tmp/mirror-csv-images.txt /tmp/mirror-fbc-images.txt /tmp/mirror-extras.txt 2>/dev/null \
  | sort -u | grep -v '^$' > /tmp/mirror-all-images.txt
```

### Step 3: Detect ICSP/IDMS Mappings on Connected Cluster

The connected cluster may have ICSP/IDMS entries that remap image sources (e.g., `registry.redhat.io/rhoai` -> `quay.io/rhoai`). Detect these and rewrite source URLs accordingly, but keep the original references for IDMS generation on the disconnected cluster.

```bash
# Save original image list for IDMS generation later
cp /tmp/mirror-all-images.txt /tmp/mirror-original-images.txt

# Detect ICSP mappings
ICSP_MAPPINGS=$(oc get imagecontentsourcepolicy -o json 2>/dev/null \
  | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    for item in data.get('items',[]):
        for m in item.get('spec',{}).get('repositoryDigestMirrors',[]):
            src=m.get('source','')
            for mirror in m.get('mirrors',[]):
                print(f'{src}={mirror}')
except: pass
" 2>/dev/null || echo "")

# Detect IDMS mappings
IDMS_MAPPINGS=$(oc get imagedigestmirrorset -o json 2>/dev/null \
  | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    for item in data.get('items',[]):
        for m in item.get('spec',{}).get('imageDigestMirrors',[]):
            src=m.get('source','')
            for mirror in m.get('mirrors',[]):
                print(f'{src}={mirror}')
except: pass
" 2>/dev/null || echo "")

ALL_MAPPINGS="${ICSP_MAPPINGS}${IDMS_MAPPINGS}"

# Rewrite source URLs in the image list
if [ -n "$ALL_MAPPINGS" ]; then
  echo "Detected ICSP/IDMS mappings — rewriting source URLs..."
  while IFS='=' read -r map_src map_mirror; do
    [ -z "$map_src" ] && continue
    sed -i.bak "s|^${map_src}/|${map_mirror}/|g" /tmp/mirror-all-images.txt
  done <<< "$ALL_MAPPINGS"
  rm -f /tmp/mirror-all-images.txt.bak
fi
```

### Step 4: Build Combined Pull Secret

```bash
# Get connected cluster's pull secret
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/cluster-pull-secret.json

# Add bastion registry credentials
BASTION_AUTH=$(printf '%s:%s' "$BASTION_USER" "$BASTION_PASSWORD" | base64 | tr -d '\n')
JQ_EXPR='.'
for BASTION in ${BASTION_REGISTRIES//,/ }; do
  JQ_EXPR="$JQ_EXPR | .auths[\"$BASTION\"] = {\"auth\": \"$BASTION_AUTH\"}"
done
jq "$JQ_EXPR" /tmp/cluster-pull-secret.json > /tmp/combined-pull-secret.json

# Create secret in mirror namespace
oc new-project image-mirror 2>/dev/null || true
oc delete secret mirror-pull-secret -n image-mirror 2>/dev/null || true
oc create secret generic mirror-pull-secret \
  --from-file=auth.json=/tmp/combined-pull-secret.json \
  -n image-mirror

# Clean up local temp files
rm -f /tmp/cluster-pull-secret.json /tmp/combined-pull-secret.json
```

### Step 5: Generate Mirror Script

Generate a bash script that the mirror pod will run. **Critical: use `skopeo copy --all --remove-signatures` instead of `oc image mirror`** to preserve original manifest digests.

The generated script must:

1. Install skopeo if not present in the pod
2. For each image:
   - Compute destination path (strip source registry hostname)
   - Check if already on bastion (skip if present)
   - Copy with `skopeo copy --all --remove-signatures --dest-tls-verify=false`
   - Retry up to 3 times with registry fallback (`registry.redhat.io/rhoai` -> `quay.io/rhoai`)
3. Track success/failure/skip counts
4. Print summary

**Key mirror logic in the generated script:**

```bash
#!/bin/bash
set -euo pipefail

PULL_SECRET="/auth/auth.json"
MAX_RETRIES=3
MIRRORED=0; FAILED=0; SKIPPED=0; TOTAL=0
FAILED_IMAGES=""

# Install skopeo
if ! command -v skopeo &>/dev/null; then
  echo "Installing skopeo..."
  dnf install -y --setopt=install_weak_deps=False skopeo 2>&1 | tail -1
fi

compute_dest_repo() {
  local src="$1"
  # Strip registry hostname: registry.redhat.io/rhoai/foo -> rhoai/foo
  # Handle docker.io special case: milvusdb/milvus -> milvusdb/milvus
  if [[ "$src" == *"/"*"/"* ]]; then
    echo "$src" | sed -E 's|^[^/]+/||; s|[@:].*||'
  else
    echo "$src" | sed -E 's|[@:].*||'
  fi
}

mirror_image() {
  local src="$1"
  local bastion="$2"
  TOTAL=$((TOTAL + 1))

  local dest_repo
  dest_repo=$(compute_dest_repo "$src")

  local dest_tag="latest"
  local digest_ref=""
  if [[ "$src" == *"@sha256:"* ]]; then
    digest_ref="${bastion}/${dest_repo}@${src#*@}"
  else
    dest_tag="${src##*:}"
    digest_ref="${bastion}/${dest_repo}:${dest_tag}"
  fi

  # Skip check (unless CLEAN_MODE is set)
  if [[ "${CLEAN_MODE:-}" != "true" ]]; then
    if skopeo inspect --tls-verify=false --authfile "$PULL_SECRET" \
        "docker://${digest_ref}" &>/dev/null; then
      echo "SKIP (already on bastion): ${dest_repo}"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
  fi

  # Mirror with retries
  local attempt=1 mirror_ok=false actual_src="$src"
  while [[ $attempt -le $MAX_RETRIES ]]; do
    if skopeo copy --all --remove-signatures \
        --authfile "$PULL_SECRET" \
        --dest-tls-verify=false \
        "docker://${actual_src}" \
        "docker://${bastion}/${dest_repo}:${dest_tag}" 2>&1; then
      mirror_ok=true
      break
    fi

    # Registry fallback: registry.redhat.io/rhoai -> quay.io/rhoai
    if [[ $attempt -eq 1 && "$actual_src" == registry.redhat.io/rhoai/* ]]; then
      actual_src="${actual_src/registry.redhat.io\/rhoai/quay.io\/rhoai}"
      echo "RETRY with quay.io fallback: $actual_src"
    fi
    attempt=$((attempt + 1))
    sleep 5
  done

  if [[ "$mirror_ok" == "true" ]]; then
    echo "OK: ${dest_repo}"
    MIRRORED=$((MIRRORED + 1))
  else
    echo "FAILED: ${src} -> ${bastion}/${dest_repo}"
    FAILED=$((FAILED + 1))
    FAILED_IMAGES="${FAILED_IMAGES}\n  ${src}"
  fi
}

# Mirror each image to each bastion
while IFS= read -r image; do
  [[ -z "$image" || "$image" == \#* ]] && continue
  for bastion in BASTION_LIST; do
    mirror_image "$image" "$bastion"
  done
done < /images/images.txt

echo ""
echo "===== MIRROR SUMMARY ====="
echo "Total:   $TOTAL"
echo "Mirrored: $MIRRORED"
echo "Skipped:  $SKIPPED"
echo "Failed:   $FAILED"
if [[ -n "$FAILED_IMAGES" ]]; then
  echo -e "Failed images:$FAILED_IMAGES"
fi
```

Replace `BASTION_LIST` with the actual bastion registries from user input.

### Step 6: Deploy Mirror Pod

Create the image list as a ConfigMap, the mirror script as another ConfigMap, and deploy the pod:

```bash
# Create ConfigMap with image list
oc delete configmap mirror-images -n image-mirror 2>/dev/null || true
oc create configmap mirror-images \
  --from-file=images.txt=/tmp/mirror-all-images.txt \
  -n image-mirror

# Create ConfigMap with mirror script
oc delete configmap mirror-script -n image-mirror 2>/dev/null || true
oc create configmap mirror-script \
  --from-file=mirror.sh=/tmp/mirror-script.sh \
  -n image-mirror

# Delete any previous mirror pod
oc delete pod image-mirror -n image-mirror 2>/dev/null || true
```

Pod manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-mirror
  namespace: image-mirror
spec:
  restartPolicy: Never
  activeDeadlineSeconds: 14400
  containers:
  - name: mirror
    image: registry.redhat.io/openshift4/ose-cli-rhel9:latest
    command: ["/bin/bash", "/scripts/mirror.sh"]
    volumeMounts:
    - name: auth
      mountPath: /auth
      readOnly: true
    - name: script
      mountPath: /scripts
      readOnly: true
    - name: images
      mountPath: /images
      readOnly: true
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "2"
  volumes:
  - name: auth
    secret:
      secretName: mirror-pull-secret
  - name: script
    configMap:
      name: mirror-script
      defaultMode: 0755
  - name: images
    configMap:
      name: mirror-images
```

Apply and wait:

```bash
oc apply -f /tmp/mirror-pod.yaml
oc wait --for=condition=Ready pod/image-mirror -n image-mirror --timeout=120s
```

### Step 7: Monitor Progress

Stream logs periodically and wait for completion:

```bash
# Check progress
oc logs image-mirror -n image-mirror --tail=50

# Check pod phase
oc get pod image-mirror -n image-mirror -o jsonpath='{.status.phase}'
```

Check every 10-15 minutes. When pod reaches `Succeeded`, retrieve the full log:

```bash
oc logs image-mirror -n image-mirror > artifacts/rhoai-manager/mirror-log-${RHOAI_VERSION}.txt
```

If any images failed, offer to create a retry pod with only the failed images.

### Step 8: Generate IDMS YAML

After mirroring completes, generate ImageDigestMirrorSet YAML using the **original** (pre-ICSP-rewrite) image list. This ensures the IDMS on the disconnected cluster maps from the canonical `registry.redhat.io` paths, not from `quay.io` paths.

```bash
# Extract unique source registry prefixes from ORIGINAL image list
SOURCE_PREFIXES=$(grep -v '^#' /tmp/mirror-original-images.txt | grep -v '^$' \
  | sed -E 's|^([^/]+/[^/@:]+).*|\1|' | sort -u)

# Generate IDMS YAML
cat > artifacts/rhoai-manager/mirror-idms-${RHOAI_VERSION}.yaml << 'HEADER'
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: rhoai-mirror
spec:
  imageDigestMirrors:
HEADER

for prefix in $SOURCE_PREFIXES; do
  # Compute bastion mirror path (strip registry hostname)
  MIRROR_PATH=$(echo "$prefix" | sed -E 's|^[^/]+/||')
  # Handle Docker Hub images (no registry prefix)
  if [[ "$prefix" != *"."* ]]; then
    # Docker Hub: milvusdb -> docker.io/milvusdb
    SOURCE="docker.io/$prefix"
    MIRROR_PATH="$prefix"
  else
    SOURCE="$prefix"
  fi
  cat >> artifacts/rhoai-manager/mirror-idms-${RHOAI_VERSION}.yaml << EOF
  - source: $SOURCE
    mirrors:
    - ${BASTION}/${MIRROR_PATH}
    mirrorSourcePolicy: NeverContactSource
EOF
done
```

### Step 9: Save Artifacts and Cleanup

```bash
# Save image list
cp /tmp/mirror-all-images.txt artifacts/rhoai-manager/mirror-images-${RHOAI_VERSION}.txt

# Cleanup mirror pod and resources
oc delete pod image-mirror -n image-mirror
oc delete configmap mirror-script mirror-images -n image-mirror
oc delete secret mirror-pull-secret -n image-mirror
```

## Mode-Specific Behavior

### Setup Mode (`mode=setup`)

Mirrors everything needed for a brand-new disconnected cluster:

| Category | Source | How Captured |
|----------|--------|-------------|
| RHOAI Operator + Components (~124) | `registry.redhat.io/rhoai/*` | CSV relatedImages |
| FBC Fragment | `quay.io/rhoai/rhoai-fbc-fragment` | CatalogSource |
| vLLM Serving Runtimes | `registry.redhat.io/rhaiis/*` | CSV relatedImages |
| MinIO | `quay.io/minio/minio` | Running pods |
| Milvus | `docker.io/milvusdb/milvus` | Running pods |
| PostgreSQL | `registry.redhat.io/rhel9/postgresql-*` | Running pods |
| MariaDB | `registry.redhat.io/rhel9/mariadb-105` | Running pods |
| Keycloak | `registry.redhat.io/rhbk/*` | Running pods |
| cert-manager | `registry.redhat.io/cert-manager/*` | Running pods |
| Service Mesh / Istio | `registry.redhat.io/openshift-service-mesh/*` | Running pods |
| Argo Exec | `quay.io/modh/argoexec` | Running pods |
| Curl (init containers) | `docker.io/curlimages/curl` | Running pods |
| ModelCar (LLM + Embedding) | `quay.io/redhat-ai-services/modelcar-catalog` | InferenceService specs |
| LlamaStack | `quay.io/opendatahub/llama-stack` | Running pods |
| Base images (UBI, nginx) | `registry.redhat.io/ubi9/*` | Running pods |
| NFD Operator | `registry.redhat.io/openshift4/ose-cluster-nfd-*` | Running pods |
| OpenShift Platform | `registry.redhat.io/openshift4/ose-oauth-proxy-*` | Running pods |
| Extra images | User-provided `extras=` parameter | User input |

### Update Mode (`mode=update`)

Mirrors only what changes between RHOAI versions:

| Category | Source | How Captured |
|----------|--------|-------------|
| RHOAI Operator + Components | `registry.redhat.io/rhoai/*` | CSV relatedImages (new digests) |
| FBC Fragment | `quay.io/rhoai/rhoai-fbc-fragment` | CatalogSource (new digest) |
| Operator Bundle | `registry.redhat.io/rhoai/odh-operator-bundle` | CSV relatedImages |
| Extra images | User-provided `extras=` parameter | User input |

Infrastructure images (minio, keycloak, milvus, etc.) are NOT re-mirrored in update mode since they rarely change. The skip-check in the mirror script ensures already-present images are not re-copied even in setup mode.

## IDMS Requirements

Key IDMS entries needed on the disconnected cluster (generated automatically in Step 8):

| Source Prefix | Bastion Path |
|---------------|-------------|
| `registry.redhat.io/rhoai` | `bastion/rhoai` |
| `registry.redhat.io/rhaiis` | `bastion/rhaiis` |
| `registry.redhat.io/rhaii-early-access` | `bastion/rhaii-early-access` |
| `registry.redhat.io/rhbk` | `bastion/rhbk` |
| `registry.redhat.io/rhel9` | `bastion/rhel9` |
| `registry.redhat.io/ubi9` | `bastion/ubi9` |
| `registry.redhat.io/cert-manager` | `bastion/cert-manager` |
| `registry.redhat.io/openshift-service-mesh` | `bastion/openshift-service-mesh` |
| `registry.redhat.io/openshift4` | `bastion/openshift4` |
| `registry.redhat.io/rhelai1` | `bastion/rhelai1` |
| `quay.io/rhoai` | `bastion/rhoai` |
| `quay.io/modh` | `bastion/modh` |
| `quay.io/minio` | `bastion/minio` |
| `quay.io/redhat-ai-services` | `bastion/redhat-ai-services` |
| `quay.io/opendatahub` | `bastion/opendatahub` |
| `docker.io/milvusdb` | `bastion/milvusdb` |
| `docker.io/curlimages` | `bastion/curlimages` |

**cert-manager gotcha:** The IDMS for `registry.redhat.io/cert-manager` must cover both `cert-manager-operator-rhel9` AND `jetstack-cert-manager-rhel9`. These are different image names under the same registry prefix — a single IDMS entry for `registry.redhat.io/cert-manager` covers both.

## Important Notes

- **Why skopeo, not oc image mirror**: `oc image mirror --keep-manifest-list=true` rewrites manifest contents, producing new per-arch digests. Pods referencing the original manifest-list digest get `manifest unknown` errors. `skopeo copy --all` does a byte-for-byte copy preserving every digest.
- **Why `--remove-signatures`**: Required when copying between registries with different signing configs.
- **Why `--dest-tls-verify=false`**: Bastion registries use self-signed certs.
- **ICSP/IDMS on connected cluster**: If the connected cluster has ICSP mapping `registry.redhat.io/rhoai` -> `quay.io/rhoai`, the script detects this and rewrites source URLs automatically. The generated IDMS YAML uses the original `registry.redhat.io` paths so the disconnected cluster resolves correctly.
- **Large images**: Some images are 5-8 GB (automl, autorag, vllm-cuda, ta-lmes-job). The 4-hour pod deadline accommodates this.
- **Storage**: Plan for ~150-200GB on the bastion registry for a full setup mirror.
- **Docker Hub images**: `milvusdb/milvus` and `curlimages/curl` may require Docker Hub credentials in the pull secret. The script warns if these fail.

## Output

- `artifacts/rhoai-manager/mirror-images-{version}.txt` — image list that was mirrored
- `artifacts/rhoai-manager/mirror-log-{version}.txt` — full mirror pod log
- `artifacts/rhoai-manager/mirror-idms-{version}.yaml` — IDMS YAML for the disconnected cluster

## Summary Display

After mirroring completes, display:

```
RHOAI v{version} Image Mirror — Complete ({mode} mode)

| Metric | Value |
|--------|-------|
| Mode | {setup/update} |
| Total images | {total} |
| Mirrored | {mirrored} |
| Skipped (already on bastion) | {skipped} |
| Failed | {failed} |
| Duration | {duration} |
| Target | {bastion_registry} |

Artifacts saved:
- artifacts/rhoai-manager/mirror-images-{version}.txt
- artifacts/rhoai-manager/mirror-log-{version}.txt
- artifacts/rhoai-manager/mirror-idms-{version}.yaml

Next step: Apply IDMS on disconnected cluster:
  oc apply -f artifacts/rhoai-manager/mirror-idms-{version}.yaml
```

If any images failed, append a **Failed Images** section listing them with full image references.
