# /odh-uninstall - Uninstall Open Data Hub from Cluster

Completely uninstall Open Data Hub (ODH) from an OpenShift cluster, removing all related resources.

## Command Usage

```bash
/odh-uninstall              # Standard uninstall (removes everything)
/odh-uninstall keep-crds    # Uninstall but keep CRDs
/odh-uninstall keep-all     # Keep CRDs and user resources (projects, models, etc.)
```

## Uninstall Options

| Option | Removes Operator | Removes CRDs | Removes User Resources |
|--------|-----------------|--------------|----------------------|
| (default) | Yes | Yes | Yes |
| `keep-crds` | Yes | No | Yes |
| `keep-all` | Yes | No | No |

## Prerequisites

1. **Cluster access**: Logged into OpenShift cluster with cluster-admin privileges (use `/oc-login`)
2. **ODH installed**: ODH must be installed on the cluster

## Process

### Step 1: Parse Arguments and Verify

```bash
KEEP_CRDS=false
KEEP_ALL=false

for arg in "$@"; do
  case "$arg" in
    keep-crds) KEEP_CRDS=true ;;
    keep-all)  KEEP_CRDS=true; KEEP_ALL=true ;;
    *) echo "Unknown option: $arg (valid: keep-crds, keep-all)" ;;
  esac
done

oc whoami &>/dev/null || { echo "ERROR: Not logged into OpenShift cluster"; exit 1; }
echo "Logged in as: $(oc whoami)"
echo "Cluster: $(oc whoami --show-server)"
echo ""
echo "Uninstall options: keep-crds=$KEEP_CRDS keep-all=$KEEP_ALL"

# Verify ODH is installed
if ! oc get csv -n openshift-operators 2>/dev/null | grep -q opendatahub-operator; then
  echo "ODH does not appear to be installed on this cluster"
  exit 0
fi

ODH_CSV=$(oc get csv -n openshift-operators --no-headers 2>/dev/null | grep opendatahub-operator | awk '{print $1}')
echo "Found ODH: $ODH_CSV"
```

### Step 2: Delete DataScienceCluster and DSCInitialization

```bash
echo ""
echo "=== Step 2: Removing DataScienceCluster and DSCInitialization ==="

oc delete datasciencecluster --all --timeout=60s 2>/dev/null || true
oc delete dscinitializations.dscinitialization.opendatahub.io --all --timeout=60s 2>/dev/null || true
sleep 10
```

### Step 3: Delete CSV and Subscription

```bash
echo ""
echo "=== Step 3: Removing ODH operator subscription and CSV ==="

oc delete subscription opendatahub-operator -n openshift-operators 2>/dev/null || true
oc delete csv "$ODH_CSV" -n openshift-operators 2>/dev/null || true

# Remove catalog source
oc delete catalogsource odh-catalog -n openshift-marketplace 2>/dev/null || true
sleep 10
```

### Step 4: Remove User Resources (unless keep-all)

```bash
if [[ "$KEEP_ALL" != "true" ]]; then
  echo ""
  echo "=== Step 4: Removing user resources ==="

  # Delete data science projects
  for ns in $(oc get namespace -l opendatahub.io/dashboard=true -o name 2>/dev/null); do
    echo "Deleting namespace: $ns"
    oc delete $ns --timeout=60s 2>/dev/null || true
  done

  # Remove finalizers from any stuck resources
  for crd in notebooks.kubeflow.org inferenceservices.serving.kserve.io \
              datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io; do
    oc get $crd -A -o name 2>/dev/null | while read res; do
      oc patch $res --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
    done
  done
else
  echo "=== Step 4: Skipping user resources (keep-all) ==="
fi
```

### Step 5: Remove ODH Namespace

```bash
echo ""
echo "=== Step 5: Removing ODH application namespace ==="

if [[ "$KEEP_ALL" != "true" ]]; then
  oc delete namespace opendatahub --timeout=120s 2>/dev/null || {
    echo "Namespace stuck — removing finalizers..."
    oc get namespace opendatahub -o json 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" | \
      oc replace --raw /api/v1/namespaces/opendatahub/finalize -f - 2>/dev/null || true
  }
fi
```

### Step 6: Remove CRDs (unless keep-crds)

```bash
if [[ "$KEEP_CRDS" != "true" ]]; then
  echo ""
  echo "=== Step 6: Removing ODH CRDs ==="

  # Get all CRDs owned by ODH
  ODH_CRDS=$(oc get crd -o name 2>/dev/null | grep -E \
    "opendatahub|datasciencecluster|dscinitialization|featuretracker|datasciencepipeline" || true)

  for crd in $ODH_CRDS; do
    echo "Deleting CRD: $crd"
    oc delete $crd --timeout=30s 2>/dev/null || true
  done
else
  echo "=== Step 6: Skipping CRD removal (keep-crds) ==="
fi
```

### Step 7: Verify Cleanup

```bash
echo ""
echo "=== Uninstall Complete ==="
echo ""

# Check for remaining resources
REMAINING_CSV=$(oc get csv -n openshift-operators 2>/dev/null | grep opendatahub || echo "")
REMAINING_NS=$(oc get namespace opendatahub 2>/dev/null || echo "")

if [[ -z "$REMAINING_CSV" && -z "$REMAINING_NS" ]]; then
  echo "ODH successfully removed"
else
  [[ -n "$REMAINING_CSV" ]] && echo "WARNING: CSV still present: $REMAINING_CSV"
  [[ -n "$REMAINING_NS" ]] && echo "WARNING: Namespace 'opendatahub' still present"
fi

echo ""
echo "To install ODH again: /odh-install"
echo "To install RHOAI:     /rhoai-install"
```

## Switching from ODH to RHOAI

If you want to install RHOAI after ODH, use the **default** uninstall (no flags):

```bash
/odh-uninstall
/rhoai-install
```

Do **not** use `keep-crds` or `keep-all` when switching to RHOAI — RHOAI installs its own versions of the shared CRDs (`DataScienceCluster`, etc.) and leftover ODH CRDs will conflict.

## Notes

- ODH and RHOAI share cluster-scoped CRDs (`DataScienceCluster`, `DSCInitialization`) — they cannot coexist
- If the `opendatahub` namespace gets stuck on termination, the command attempts to remove its finalizers automatically
- User data (notebooks, pipelines, models) in data science project namespaces is deleted by default — use `keep-all` to preserve it (note: ODH user data is not compatible with RHOAI namespaces)
