# /use-odh-main - Override Component Images to ODH Main Branch

Patch the RHOAI operator CSV to use ODH main branch images (`quay.io/opendatahub/<component>:main`) for specified components, then verify pods pull the correct images.

## Command Usage

- `/use-odh-main odh-mod-arch-automl odh-mod-arch-autorag` - Override automl and autorag to main branch
- `/use-odh-main odh-dashboard-rhel9` - Override just the dashboard image
- `/use-odh-main odh-mod-arch-automl odh-mod-arch-autorag odh-model-registry-rhel9` - Override multiple components
- `/use-odh-main --list` - List all component images in the current CSV (no changes)
- `/use-odh-main --registry quay.io/myorg odh-mod-arch-automl` - Use a custom registry instead of quay.io/opendatahub
- `/use-odh-main --tag my-branch odh-mod-arch-automl` - Use a custom tag instead of `main`

## What This Does

RHOAI operator CSV contains `relatedImages` and deployment env vars that pin every component to a specific `sha256` digest. This command overrides selected components to use floating tags from the ODH main branch (`quay.io/opendatahub/<component>:main`), which is useful for:

- Testing unreleased ODH main branch changes inside an RHOAI deployment
- Validating component builds before they land in a nightly catalog
- Debugging component-level issues with the latest source

## Prerequisites

1. **Existing RHOAI or ODH**: Operator must already be installed
2. **Cluster access**: Logged in with cluster-admin privileges (use `/oc-login`)
3. **Tools installed**: `oc` CLI and `jq` must be available

## Process

### Step 1: Parse Input Arguments

```bash
COMPONENTS=()
REGISTRY="quay.io/opendatahub"
TAG="main"
LIST_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --list)
      LIST_ONLY=true
      ;;
    --registry)
      shift
      REGISTRY="$1"
      ;;
    --tag)
      shift
      TAG="$1"
      ;;
    *)
      COMPONENTS+=("$arg")
      ;;
  esac
done

if [[ "$LIST_ONLY" == "false" && ${#COMPONENTS[@]} -eq 0 ]]; then
  echo "ERROR: No components specified."
  echo "Usage: /use-odh-main <component1> [component2] ..."
  echo "Example: /use-odh-main odh-mod-arch-automl odh-mod-arch-autorag"
  echo "Use --list to see available component images in the current CSV."
  exit 1
fi
```

### Step 2: Verify Cluster Access and Detect Operator

```bash
command -v oc &>/dev/null || { echo "ERROR: oc command not found"; exit 1; }
command -v jq &>/dev/null || { echo "ERROR: jq command not found"; exit 1; }
oc whoami &>/dev/null || { echo "ERROR: Not logged into an OpenShift cluster"; exit 1; }

echo "Logged in as: $(oc whoami)"
echo "Cluster: $(oc whoami --show-server)"

# Detect RHOAI or ODH
OPERATOR_NS=""
CSV_NAME=""
OPERATOR_DEPLOY=""

if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods-operator; then
  OPERATOR_NS="redhat-ods-operator"
  CSV_NAME=$(oc get csv -n "$OPERATOR_NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep rhods-operator)
  OPERATOR_DEPLOY="rhods-operator"
  APPS_NS="redhat-ods-applications"
  echo "Detected RHOAI operator: $CSV_NAME in $OPERATOR_NS"
elif oc get csv -n openshift-operators 2>/dev/null | grep -q opendatahub-operator; then
  OPERATOR_NS="openshift-operators"
  CSV_NAME=$(oc get csv -n "$OPERATOR_NS" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep opendatahub-operator)
  OPERATOR_DEPLOY="opendatahub-operator-controller-manager"
  APPS_NS="opendatahub"
  echo "Detected ODH operator: $CSV_NAME in $OPERATOR_NS"
else
  echo "ERROR: Neither RHOAI nor ODH operator found. Install one first."
  exit 1
fi
```

### Step 3: List Current CSV relatedImages

Always list current images so the user can see what's available.

```bash
echo ""
echo "=== Current relatedImages in CSV: $CSV_NAME ==="
echo ""

oc get csv "$CSV_NAME" -n "$OPERATOR_NS" -o json | \
  jq -r '.spec.relatedImages[] | "\(.name)  \(.image)"' | \
  sort

echo ""
```

If `--list` was specified, stop here:

```bash
if [[ "$LIST_ONLY" == "true" ]]; then
  echo "Use /use-odh-main <component-image-name> to override specific images."
  echo "The component-image-name is the image portion (e.g., odh-mod-arch-automl)."
  exit 0
fi
```

### Step 4: Match Components to CSV relatedImages and Env Vars

For each requested component, find the matching `relatedImages` entry and the corresponding env var in the operator deployment spec within the CSV.

```bash
CSV_JSON=$(oc get csv "$CSV_NAME" -n "$OPERATOR_NS" -o json)

MATCHED=()
UNMATCHED=()

for COMPONENT in "${COMPONENTS[@]}"; do
  # Find matching relatedImages entry (match on image name containing the component)
  RELATED_NAME=$(echo "$CSV_JSON" | jq -r --arg comp "$COMPONENT" \
    '.spec.relatedImages[] | select(.image | contains($comp)) | .name' 2>/dev/null | head -1)

  if [[ -z "$RELATED_NAME" ]]; then
    # Try matching on the relatedImages name field itself
    RELATED_NAME=$(echo "$CSV_JSON" | jq -r --arg comp "$COMPONENT" \
      '.spec.relatedImages[] | select(.name | gsub("-"; "_") | contains($comp | gsub("-"; "_"))) | .name' 2>/dev/null | head -1)
  fi

  if [[ -n "$RELATED_NAME" ]]; then
    MATCHED+=("$COMPONENT|$RELATED_NAME")
    echo "Matched: $COMPONENT -> relatedImage name: $RELATED_NAME"
  else
    UNMATCHED+=("$COMPONENT")
    echo "WARNING: No relatedImage found matching: $COMPONENT"
  fi
done

if [[ ${#MATCHED[@]} -eq 0 ]]; then
  echo ""
  echo "ERROR: No components matched any relatedImages in the CSV."
  echo "Use --list to see available component image names."
  exit 1
fi

if [[ ${#UNMATCHED[@]} -gt 0 ]]; then
  echo ""
  echo "WARNING: The following components were not found and will be skipped:"
  for u in "${UNMATCHED[@]}"; do
    echo "  - $u"
  done
fi
```

### Step 5: Build the New Image References

```bash
echo ""
echo "=== Preparing Image Overrides ==="
echo ""

PATCHES=()

for entry in "${MATCHED[@]}"; do
  COMPONENT="${entry%%|*}"
  RELATED_NAME="${entry##*|}"

  NEW_IMAGE="${REGISTRY}/${COMPONENT}:${TAG}"

  CURRENT_IMAGE=$(echo "$CSV_JSON" | jq -r --arg name "$RELATED_NAME" \
    '.spec.relatedImages[] | select(.name == $name) | .image' 2>/dev/null)

  echo "Component:     $COMPONENT"
  echo "  relatedImage: $RELATED_NAME"
  echo "  Current:      $CURRENT_IMAGE"
  echo "  New:          $NEW_IMAGE"
  echo ""

  PATCHES+=("$RELATED_NAME|$NEW_IMAGE|$CURRENT_IMAGE")
done

echo "Target registry: $REGISTRY"
echo "Target tag:      $TAG"
echo ""
```

### Step 6: Patch CSV relatedImages

Patch the CSV `spec.relatedImages` array to replace the digest-pinned image with the tag-based image for each matched component.

```bash
echo "=== Patching CSV relatedImages ==="

for patch_entry in "${PATCHES[@]}"; do
  IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"

  # Build a JSON patch to update the specific relatedImage entry
  # First find the index of this relatedImage
  INDEX=$(echo "$CSV_JSON" | jq -r --arg name "$REL_NAME" \
    '[.spec.relatedImages[] | .name] | to_entries[] | select(.value == $name) | .key')

  if [[ -n "$INDEX" ]]; then
    oc patch csv "$CSV_NAME" -n "$OPERATOR_NS" --type=json \
      -p "[{\"op\": \"replace\", \"path\": \"/spec/relatedImages/$INDEX/image\", \"value\": \"$NEW_IMG\"}]"
    echo "Patched relatedImage[$INDEX] ($REL_NAME) -> $NEW_IMG"
  else
    echo "WARNING: Could not find index for $REL_NAME, skipping relatedImage patch"
  fi
done

echo ""
```

### Step 7: Patch Operator Deployment Env Vars in CSV

The operator reads component images from env vars in its deployment spec inside the CSV. These env var names follow the pattern `RELATED_IMAGE_<UPPER_SNAKE_NAME>`.

```bash
echo "=== Patching Operator Deployment Env Vars in CSV ==="

# Get the deployments spec from the CSV
DEPLOY_JSON=$(echo "$CSV_JSON" | jq '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env')

for patch_entry in "${PATCHES[@]}"; do
  IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"

  # Convert relatedImage name to env var name:
  # e.g., "odh_mod_arch_automl_image" -> "RELATED_IMAGE_ODH_MOD_ARCH_AUTOML"
  # The pattern varies; search for env vars whose value matches the old image
  ENV_INDEX=$(echo "$CSV_JSON" | jq -r --arg old "$OLD_IMG" \
    '[.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[] | .value] | to_entries[] | select(.value == $old) | .key' 2>/dev/null | head -1)

  if [[ -n "$ENV_INDEX" ]]; then
    ENV_NAME=$(echo "$CSV_JSON" | jq -r \
      ".spec.install.spec.deployments[0].spec.template.spec.containers[0].env[$ENV_INDEX].name")

    oc patch csv "$CSV_NAME" -n "$OPERATOR_NS" --type=json \
      -p "[{\"op\": \"replace\", \"path\": \"/spec/install/spec/deployments/0/spec/template/spec/containers/0/env/$ENV_INDEX/value\", \"value\": \"$NEW_IMG\"}]"
    echo "Patched env var $ENV_NAME -> $NEW_IMG"
  else
    # Try matching by env var name derived from the relatedImage name
    DERIVED_ENV="RELATED_IMAGE_$(echo "$REL_NAME" | tr '[:lower:]-' '[:upper:]_' | sed 's/_IMAGE$//')"
    ENV_INDEX=$(echo "$CSV_JSON" | jq -r --arg env "$DERIVED_ENV" \
      '[.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[] | .name] | to_entries[] | select(.value == $env) | .key' 2>/dev/null | head -1)

    if [[ -n "$ENV_INDEX" ]]; then
      oc patch csv "$CSV_NAME" -n "$OPERATOR_NS" --type=json \
        -p "[{\"op\": \"replace\", \"path\": \"/spec/install/spec/deployments/0/spec/template/spec/containers/0/env/$ENV_INDEX/value\", \"value\": \"$NEW_IMG\"}]"
      echo "Patched env var $DERIVED_ENV -> $NEW_IMG"
    else
      echo "WARNING: Could not find env var for $REL_NAME — operator may not pick up the override automatically"
      echo "  You may need to patch the component deployment directly (see Step 9 fallback)"
    fi
  fi
done

echo ""
```

### Step 8: Restart Operator to Pick Up New Env Vars

After patching the CSV, OLM will update the operator deployment. If it doesn't restart automatically, force a rollout.

```bash
echo "=== Restarting Operator to Apply New Images ==="

# Wait briefly for OLM to detect CSV changes
sleep 10

# Check if operator pod restarted on its own
OPERATOR_POD_AGE=$(oc get pod -n "$OPERATOR_NS" -l name="$OPERATOR_DEPLOY" -o jsonpath='{.items[0].metadata.creationTimestamp}' 2>/dev/null || echo "")

# Force rollout restart if OLM hasn't restarted it
oc rollout restart deployment "$OPERATOR_DEPLOY" -n "$OPERATOR_NS" 2>/dev/null || {
  echo "Could not restart operator deployment directly, trying alternative names..."
  oc rollout restart deployment -n "$OPERATOR_NS" -l olm.owner="$CSV_NAME" 2>/dev/null || true
}

echo "Waiting for operator rollout to complete..."

TIMEOUT=180
INTERVAL=10
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  READY=$(oc get deployment "$OPERATOR_DEPLOY" -n "$OPERATOR_NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED=$(oc get deployment "$OPERATOR_DEPLOY" -n "$OPERATOR_NS" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

  if [[ "$READY" -ge "$DESIRED" && "$READY" -gt 0 ]]; then
    echo "Operator deployment ready ($READY/$DESIRED)"
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for operator... ($READY/$DESIRED ready, ${ELAPSED}s/${TIMEOUT}s)"
done

if [[ "$READY" -lt "$DESIRED" ]]; then
  echo "WARNING: Operator not fully ready after ${TIMEOUT}s"
fi
```

### Step 9: Wait for Component Pods to Reconcile

The operator should detect the changed env vars and reconcile the affected component deployments. Components may be standalone deployments OR sidecar containers inside a parent deployment (e.g., `odh-mod-arch-automl` runs as the `automl-ui` sidecar in `rhods-dashboard`).

```bash
echo ""
echo "=== Waiting for Component Reconciliation ==="
echo ""

# Give operator time to reconcile
sleep 30

# Fetch all deployments once
ALL_DEPLOYS_JSON=$(oc get deployments -n "$APPS_NS" -o json 2>/dev/null)

TIMEOUT=300
INTERVAL=15
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
  ALL_DONE=true
  ALL_DEPLOYS_JSON=$(oc get deployments -n "$APPS_NS" -o json 2>/dev/null)

  for patch_entry in "${PATCHES[@]}"; do
    IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"

    # Search ALL containers (primary + sidecars) and initContainers across all deployments
    DEPLOY_USING=$(echo "$ALL_DEPLOYS_JSON" | jq -r --arg img "$NEW_IMG" \
      '.items[] | select(
        (.spec.template.spec.containers[]?.image == $img) or
        (.spec.template.spec.initContainers[]?.image == $img)
      ) | .metadata.name' 2>/dev/null | head -1)

    if [[ -z "$DEPLOY_USING" ]]; then
      ALL_DONE=false
    fi
  done

  if [[ "$ALL_DONE" == "true" ]]; then
    echo "All overridden components reconciled."
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Waiting for component deployments to update... (${ELAPSED}s/${TIMEOUT}s)"
done
```

### Step 10: Verify Pod Images

Confirm that the running pods are using the expected main branch images. Components may live as standalone deployments or as sidecar containers (e.g., dashboard modules like `automl-ui`, `autorag-ui`).

```bash
echo ""
echo "=== Verification: Pod Image Check ==="
echo ""

PASS=0
FAIL=0

ALL_DEPLOYS_JSON=$(oc get deployments -n "$APPS_NS" -o json 2>/dev/null)

for patch_entry in "${PATCHES[@]}"; do
  IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"
  COMPONENT_SHORT=$(echo "$NEW_IMG" | sed 's|.*/||' | sed 's|:.*||')

  echo "--- $COMPONENT_SHORT ---"

  # Search ALL containers (primary + sidecars) and initContainers for the new image
  MATCH=$(echo "$ALL_DEPLOYS_JSON" | jq -r --arg img "$NEW_IMG" '
    .items[] |
    . as $deploy |
    (
      (.spec.template.spec.containers[] | select(.image == $img) | {deploy: $deploy.metadata.name, container: .name, image: .image}),
      (.spec.template.spec.initContainers[]? | select(.image == $img) | {deploy: $deploy.metadata.name, container: .name, image: .image})
    ) | "\(.deploy)|\(.container)|\(.image)"
  ' 2>/dev/null | head -1)

  if [[ -z "$MATCH" ]]; then
    # Fallback: search by component name in container images
    MATCH=$(echo "$ALL_DEPLOYS_JSON" | jq -r --arg comp "$COMPONENT_SHORT" '
      .items[] |
      . as $deploy |
      .spec.template.spec.containers[] |
      select(.image | contains($comp)) |
      "\($deploy.metadata.name)|\(.name)|\(.image)"
    ' 2>/dev/null | head -1)
  fi

  if [[ -z "$MATCH" ]]; then
    echo "  WARNING: No container found using $COMPONENT_SHORT"
    echo "  The operator may not have reconciled yet."
    FAIL=$((FAIL + 1))
    continue
  fi

  IFS='|' read -r DEPLOY_NAME CONTAINER_NAME ACTUAL_IMAGE <<< "$MATCH"

  # Get pod status for this deployment
  POD_NAME=$(oc get pods -n "$APPS_NS" -l app="$DEPLOY_NAME" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  POD_STATUS=""
  CONTAINER_READY=""

  if [[ -n "$POD_NAME" ]]; then
    POD_STATUS=$(oc get pod "$POD_NAME" -n "$APPS_NS" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    CONTAINER_READY=$(oc get pod "$POD_NAME" -n "$APPS_NS" \
      -o jsonpath="{.status.containerStatuses[?(@.name==\"$CONTAINER_NAME\")].ready}" 2>/dev/null || echo "unknown")
  fi

  if [[ "$ACTUAL_IMAGE" == "$NEW_IMG" ]]; then
    echo "  PASS: Deployment $DEPLOY_NAME, container $CONTAINER_NAME"
    echo "    Image: $ACTUAL_IMAGE"
    echo "    Pod: ${POD_STATUS:-Unknown}, container ready: ${CONTAINER_READY:-unknown}"
    PASS=$((PASS + 1))
  else
    echo "  PENDING: Deployment $DEPLOY_NAME, container $CONTAINER_NAME"
    echo "    Expected: $NEW_IMG"
    echo "    Actual:   $ACTUAL_IMAGE"
    echo "    Pod: ${POD_STATUS:-Unknown}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Verification Summary ==="
echo "  PASS: $PASS"
echo "  PENDING/FAIL: $FAIL"
```

### Step 11: Check for ImagePullBackOff

Verify no pods are stuck in ImagePullBackOff due to the new image references.

```bash
echo ""
echo "=== Checking for Image Pull Errors ==="

PULL_ERRORS=$(oc get pods -n "$APPS_NS" -o json 2>/dev/null | \
  jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "ImagePullBackOff" or .status.containerStatuses[]?.state.waiting.reason == "ErrImagePull") | .metadata.name' 2>/dev/null)

if [[ -n "$PULL_ERRORS" ]]; then
  echo "WARNING: Pods with image pull errors detected:"
  for pod in $PULL_ERRORS; do
    IMAGE=$(oc get pod "$pod" -n "$APPS_NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
    echo "  $pod -> $IMAGE"
  done
  echo ""
  echo "This may indicate the image tag does not exist on the registry."
  echo "Verify the images exist:"
  for patch_entry in "${PATCHES[@]}"; do
    IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"
    echo "  skopeo inspect docker://$NEW_IMG"
  done
else
  echo "No image pull errors detected."
fi
```

### Step 12: Print Summary

```bash
echo ""
echo "=========================================="
echo "  Image Override Summary"
echo "=========================================="
echo ""
echo "Operator:  $CSV_NAME"
echo "Namespace: $OPERATOR_NS"
echo "Registry:  $REGISTRY"
echo "Tag:       $TAG"
echo ""
echo "Overridden Components:"

for patch_entry in "${PATCHES[@]}"; do
  IFS='|' read -r REL_NAME NEW_IMG OLD_IMG <<< "$patch_entry"
  echo "  $REL_NAME"
  echo "    Was: $OLD_IMG"
  echo "    Now: $NEW_IMG"
done

echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "All components verified — pods are pulling the correct main branch images."
else
  echo "$FAIL component(s) not yet verified."
  echo "The operator may still be reconciling. Re-run /rhoai-verify to check status."
fi

echo ""
echo "NOTE: These overrides persist until the next operator upgrade."
echo "Running /rhoai-update or /odh-update replaces the CSV and resets all images."
```

## Output

The command prints a summary showing:
- Which components were overridden
- Old (digest-pinned) vs new (tag-based) image references
- Pod image verification results (PASS/PENDING)
- Any image pull errors

## Usage Examples

```bash
# Override automl and autorag to ODH main branch
/use-odh-main odh-mod-arch-automl odh-mod-arch-autorag

# List all component images in the CSV without making changes
/use-odh-main --list

# Override a single component with a custom tag
/use-odh-main --tag feature-branch odh-mod-arch-automl

# Override using a custom registry
/use-odh-main --registry quay.io/myorg odh-mod-arch-automl
```

Or simply ask:
- "Override automl and autorag to use ODH main branch"
- "Patch RHOAI to use main branch images for automl"
- "Switch odh-mod-arch-automl to quay.io/opendatahub/odh-mod-arch-automl:main"

## Important Notes

- **CSV CR patching**: This command patches the CSV CR directly (relatedImages + operator deployment env vars). OLM propagates env var changes to the operator deployment, and the operator reconciles component deployments with the new images. The patch persists — OLM does not revert CSV CR changes during normal operation.
- **Resets on operator upgrade**: Running `/rhoai-update` or `/odh-update` replaces the CSV with a new one from the catalog, which resets all image overrides. Re-run `/use-odh-main` after any operator update.
- **Image must exist**: The `quay.io/opendatahub/<component>:main` image must exist and be pullable from the cluster. If the cluster uses a private registry, use `--registry` to specify it.
- **Operator reconciliation**: After patching, the operator must reconcile to update component deployments. This can take 1-5 minutes depending on the number of components.
- **Works with both RHOAI and ODH**: The command auto-detects which operator is installed and patches accordingly.

## Troubleshooting

**Problem:** Pod stuck in ImagePullBackOff after override
**Solution:** Verify the image exists: `skopeo inspect docker://quay.io/opendatahub/<component>:main`. The `main` tag may not exist for all components.

**Problem:** Component deployment not updating after CSV patch
**Solution:** The operator watches env vars to decide which image to deploy. If the env var wasn't patched (warning in Step 7), patch the component deployment directly:
```bash
oc set image deployment/<component-deploy> <container-name>=quay.io/opendatahub/<component>:main -n <apps-ns>
```

**Problem:** DSC shows component as degraded after override
**Solution:** The operator may report degraded status if it detects image mismatch. Check pod logs: `oc logs -n <apps-ns> deployment/<component> --tail=50`
