# /rhoai-verify - Post-Install/Update Verification Tests for RHOAI

Run a comprehensive suite of verification tests after RHOAI install or update to confirm all components are healthy and functional. Works on both connected and disconnected clusters.

## Command Usage

```bash
# Run all tests
/rhoai-verify

# Run specific test categories
/rhoai-verify quick          # Operator + DSC + pod health only
/rhoai-verify full           # All tests including smoke tests
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `quick` / `full` | No | `full` | Test scope |

## Process

### Step 1: Initialize Test Report

```bash
REPORT_FILE="artifacts/rhoai-manager/reports/verify-$(date +%Y%m%d-%H%M%S).md"
mkdir -p artifacts/rhoai-manager/reports

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "  PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "  FAIL: $1"; }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); echo "  WARN: $1"; }

echo "=== RHOAI Post-Install/Update Verification ==="
echo "Cluster: $(oc whoami --show-server 2>/dev/null)"
echo "User: $(oc whoami 2>/dev/null)"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
```

### Step 2: Operator Health

Verify the RHOAI operator CSV is installed and in Succeeded phase.

```bash
echo "=== Test 1: Operator Health ==="

# 2a. Check CSV
CSV_LINE=$(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods-operator | grep -v Replacing || echo "")

if [[ -z "$CSV_LINE" ]]; then
  fail "No RHOAI CSV found in redhat-ods-operator namespace"
else
  CSV_NAME=$(echo "$CSV_LINE" | awk '{print $1}')
  CSV_PHASE=$(echo "$CSV_LINE" | awk '{print $NF}')
  CSV_VERSION=$(oc get csv "$CSV_NAME" -n redhat-ods-operator -o jsonpath='{.spec.version}' 2>/dev/null)

  if [[ "$CSV_PHASE" == "Succeeded" ]]; then
    pass "CSV $CSV_NAME is Succeeded (version: $CSV_VERSION)"
  else
    fail "CSV $CSV_NAME phase is $CSV_PHASE (expected: Succeeded)"
  fi
fi

# 2b. Check Subscription
SUB=$(oc get subscription -n redhat-ods-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$SUB" ]]; then
  SUB_STATE=$(oc get subscription "$SUB" -n redhat-ods-operator -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
  SUB_CHANNEL=$(oc get subscription "$SUB" -n redhat-ods-operator -o jsonpath='{.spec.channel}' 2>/dev/null || echo "Unknown")
  SUB_SOURCE=$(oc get subscription "$SUB" -n redhat-ods-operator -o jsonpath='{.spec.source}' 2>/dev/null || echo "Unknown")

  if [[ "$SUB_STATE" == "AtLatestKnown" ]]; then
    pass "Subscription $SUB state: $SUB_STATE (channel: $SUB_CHANNEL, source: $SUB_SOURCE)"
  else
    warn "Subscription $SUB state: $SUB_STATE (expected: AtLatestKnown)"
  fi
else
  fail "No RHOAI subscription found"
fi

# 2c. Check CatalogSource
CATALOG=$(oc get subscription "$SUB" -n redhat-ods-operator -o jsonpath='{.spec.source}' 2>/dev/null || echo "")
if [[ -n "$CATALOG" ]]; then
  CATALOG_STATE=$(oc get catalogsource "$CATALOG" -n openshift-marketplace \
    -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || echo "Unknown")

  if [[ "$CATALOG_STATE" == "READY" ]]; then
    pass "CatalogSource $CATALOG is READY"
  else
    fail "CatalogSource $CATALOG state: $CATALOG_STATE (expected: READY)"
  fi
fi

echo ""
```

### Step 3: DataScienceCluster Health

Verify DSC exists and is in Ready phase with all managed components healthy.

```bash
echo "=== Test 2: DataScienceCluster Health ==="

# 3a. Check DSCInitialization
DSCI_PHASE=$(oc get dscinitializations default-dsci -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$DSCI_PHASE" == "Ready" ]]; then
  pass "DSCInitialization phase: Ready"
else
  fail "DSCInitialization phase: $DSCI_PHASE (expected: Ready)"
fi

# 3b. Check DSC phase
DSC_PHASE=$(oc get datasciencecluster -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$DSC_PHASE" == "Ready" ]]; then
  pass "DataScienceCluster phase: Ready"
else
  fail "DataScienceCluster phase: $DSC_PHASE (expected: Ready)"
fi

# 3c. Check individual component conditions
DSC_CONDITIONS=$(oc get datasciencecluster -o json 2>/dev/null | \
  jq -r '.items[0].status.conditions[] | "\(.type)|\(.status)|\(.message // "")"' 2>/dev/null || echo "")

if [[ -n "$DSC_CONDITIONS" ]]; then
  while IFS='|' read -r ctype cstatus cmsg; do
    [[ -z "$ctype" ]] && continue
    # Skip conditions that are about Removed components
    if echo "$cmsg" | grep -qi "removed"; then
      continue
    fi
    if [[ "$cstatus" == "True" ]]; then
      pass "Component $ctype: Ready"
    else
      fail "Component $ctype: Not Ready ($cmsg)"
    fi
  done <<< "$DSC_CONDITIONS"
fi

echo ""
```

### Step 4: Pod Health Across RHOAI Namespaces

Check all pods in RHOAI-related namespaces for failures.

```bash
echo "=== Test 3: Pod Health ==="

RHOAI_NAMESPACES="redhat-ods-operator redhat-ods-applications redhat-ods-monitoring"

for ns in $RHOAI_NAMESPACES; do
  # Skip if namespace doesn't exist
  if ! oc get namespace "$ns" &>/dev/null; then
    continue
  fi

  PODS=$(oc get pods -n "$ns" --no-headers 2>/dev/null || echo "")
  if [[ -z "$PODS" ]]; then
    warn "No pods found in $ns"
    continue
  fi

  TOTAL=0
  RUNNING=0
  COMPLETED=0
  ISSUES=0
  ISSUE_DETAILS=""

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    TOTAL=$((TOTAL + 1))
    POD_NAME=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $3}')
    READY=$(echo "$line" | awk '{print $2}')

    case "$STATUS" in
      Running)
        # Check if all containers are ready
        READY_NUM=$(echo "$READY" | cut -d/ -f1)
        TOTAL_NUM=$(echo "$READY" | cut -d/ -f2)
        if [[ "$READY_NUM" == "$TOTAL_NUM" ]]; then
          RUNNING=$((RUNNING + 1))
        else
          ISSUES=$((ISSUES + 1))
          ISSUE_DETAILS="${ISSUE_DETAILS}\n    $POD_NAME: Running but not ready ($READY)"
        fi
        ;;
      Completed|Succeeded)
        COMPLETED=$((COMPLETED + 1))
        ;;
      ImagePullBackOff|ErrImagePull)
        ISSUES=$((ISSUES + 1))
        ISSUE_DETAILS="${ISSUE_DETAILS}\n    $POD_NAME: $STATUS (missing image on registry)"
        ;;
      CrashLoopBackOff)
        ISSUES=$((ISSUES + 1))
        ISSUE_DETAILS="${ISSUE_DETAILS}\n    $POD_NAME: $STATUS (check logs: oc logs $POD_NAME -n $ns)"
        ;;
      *)
        ISSUES=$((ISSUES + 1))
        ISSUE_DETAILS="${ISSUE_DETAILS}\n    $POD_NAME: $STATUS"
        ;;
    esac
  done <<< "$PODS"

  if [[ $ISSUES -eq 0 ]]; then
    pass "$ns: $RUNNING running, $COMPLETED completed, $TOTAL total"
  else
    fail "$ns: $ISSUES pods with issues out of $TOTAL total"
    echo -e "$ISSUE_DETAILS"
  fi
done

echo ""
```

### Step 5: Dashboard Accessibility

Verify the RHOAI dashboard is reachable and responding.

```bash
echo "=== Test 4: Dashboard Accessibility ==="

# 5a. Check deployment
DASH_READY=$(oc get deployment rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DASH_DESIRED=$(oc get deployment rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [[ "$DASH_READY" -gt 0 && "$DASH_READY" -eq "$DASH_DESIRED" ]]; then
  pass "Dashboard deployment ready ($DASH_READY/$DASH_DESIRED replicas)"
else
  fail "Dashboard deployment not ready ($DASH_READY/$DASH_DESIRED replicas)"
fi

# 5b. Check route exists
DASH_ROUTE=$(oc get route rhods-dashboard -n redhat-ods-applications \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [[ -n "$DASH_ROUTE" ]]; then
  pass "Dashboard route exists: https://$DASH_ROUTE"
else
  fail "Dashboard route not found"
fi

# 5c. HTTP health check (expect 403 or 200 — both mean dashboard is responding)
if [[ -n "$DASH_ROUTE" ]]; then
  HTTP_CODE=$(/usr/bin/curl -sk -o /dev/null -w '%{http_code}' "https://$DASH_ROUTE" 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "403" || "$HTTP_CODE" == "302" ]]; then
    pass "Dashboard HTTP response: $HTTP_CODE (responding)"
  else
    fail "Dashboard HTTP response: $HTTP_CODE (expected 200, 302, or 403)"
  fi
fi

# 5d. Check dashboard feature flags
if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
  AUTOML=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    -o jsonpath='{.spec.dashboardConfig.automl}' 2>/dev/null || echo "unset")
  AUTORAG=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    -o jsonpath='{.spec.dashboardConfig.autorag}' 2>/dev/null || echo "unset")
  GENAISTUDIO=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    -o jsonpath='{.spec.dashboardConfig.genAiStudio}' 2>/dev/null || echo "unset")

  echo "  Dashboard features: automl=$AUTOML, autorag=$AUTORAG, genAiStudio=$GENAISTUDIO"
fi

echo ""
```

### Step 6: Pipeline (Data Science Pipelines) Readiness

Verify the DSP operator and controllers are running. If DSPAs exist, verify their health.

```bash
echo "=== Test 5: Data Science Pipelines ==="

# 6a. Check DSP operator deployment
DSP_OPERATOR=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "data-science-pipelines-operator" || echo "")

if [[ -n "$DSP_OPERATOR" ]]; then
  DSP_NAME=$(echo "$DSP_OPERATOR" | awk '{print $1}')
  DSP_READY=$(echo "$DSP_OPERATOR" | awk '{print $2}')
  READY_NUM=$(echo "$DSP_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$DSP_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "DSP operator deployment ready ($DSP_READY)"
  else
    fail "DSP operator deployment not ready ($DSP_READY)"
  fi
else
  warn "DSP operator deployment not found (pipelines may be set to Removed)"
fi

# 6b. Check existing DSPAs
DSPA_LIST=$(oc get datasciencepipelinesapplication --all-namespaces --no-headers 2>/dev/null || echo "")

if [[ -n "$DSPA_LIST" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    DSPA_NS=$(echo "$line" | awk '{print $1}')
    DSPA_NAME=$(echo "$line" | awk '{print $2}')
    DSPA_READY=$(echo "$line" | awk '{print $NF}')

    # Check DSPA status
    DSPA_PHASE=$(oc get datasciencepipelinesapplication "$DSPA_NAME" -n "$DSPA_NS" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [[ "$DSPA_PHASE" == "True" ]]; then
      pass "DSPA $DSPA_NS/$DSPA_NAME: Ready"
    else
      fail "DSPA $DSPA_NS/$DSPA_NAME: Not Ready"
    fi

    # Check podToPodTLS (known issue)
    POD_TLS=$(oc get datasciencepipelinesapplication "$DSPA_NAME" -n "$DSPA_NS" \
      -o jsonpath='{.spec.podToPodTLS}' 2>/dev/null || echo "unset")
    if [[ "$POD_TLS" != "false" ]]; then
      warn "DSPA $DSPA_NS/$DSPA_NAME: podToPodTLS=$POD_TLS (set to false if pipeline pods crash with caCertPath error)"
    fi

    # Check pipeline pods in that namespace
    CRASH_PODS=$(oc get pods -n "$DSPA_NS" --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|ImagePullBackOff" || echo "")
    if [[ -n "$CRASH_PODS" ]]; then
      fail "DSPA $DSPA_NS has crashing/failing pods:"
      echo "$CRASH_PODS" | while read -r pline; do
        echo "    $(echo "$pline" | awk '{print $1, $3}')"
      done
    fi
  done <<< "$DSPA_LIST"
else
  echo "  No DSPAs configured yet (create one to test pipelines)"
fi

echo ""
```

### Step 7: Workbench / Notebook Controller Readiness

```bash
echo "=== Test 6: Workbench / Notebook Controller ==="

# 7a. Check notebook controller
NB_CONTROLLER=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "notebook-controller" | head -1 || echo "")

if [[ -n "$NB_CONTROLLER" ]]; then
  NB_NAME=$(echo "$NB_CONTROLLER" | awk '{print $1}')
  NB_READY=$(echo "$NB_CONTROLLER" | awk '{print $2}')
  READY_NUM=$(echo "$NB_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$NB_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "Notebook controller ready ($NB_READY)"
  else
    fail "Notebook controller not ready ($NB_READY)"
  fi
else
  warn "Notebook controller deployment not found"
fi

# 7b. Check ODH notebook controller
ODH_NB=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "odh-notebook-controller" | head -1 || echo "")

if [[ -n "$ODH_NB" ]]; then
  ODH_NB_NAME=$(echo "$ODH_NB" | awk '{print $1}')
  ODH_NB_READY=$(echo "$ODH_NB" | awk '{print $2}')
  READY_NUM=$(echo "$ODH_NB_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$ODH_NB_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "ODH notebook controller ready ($ODH_NB_READY)"
  else
    fail "ODH notebook controller not ready ($ODH_NB_READY)"
  fi
fi

# 7c. Check workbench namespace
WB_NS=$(oc get datasciencecluster -o jsonpath='{.items[0].spec.components.workbenches.workbenchNamespace}' 2>/dev/null || echo "rhods-notebooks")
if oc get namespace "$WB_NS" &>/dev/null; then
  pass "Workbench namespace $WB_NS exists"
else
  warn "Workbench namespace $WB_NS not found"
fi

echo ""
```

### Step 8: Model Serving Readiness (KServe / ModelMesh)

```bash
echo "=== Test 7: Model Serving ==="

# 8a. Check KServe controller
KSERVE=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "kserve-controller" | head -1 || echo "")

if [[ -n "$KSERVE" ]]; then
  KS_READY=$(echo "$KSERVE" | awk '{print $2}')
  READY_NUM=$(echo "$KS_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$KS_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "KServe controller ready ($KS_READY)"
  else
    fail "KServe controller not ready ($KS_READY)"
  fi
else
  warn "KServe controller not found (kserve may be Removed)"
fi

# 8b. Check ModelMesh controller
MODELMESH=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "modelmesh-controller" | head -1 || echo "")

if [[ -n "$MODELMESH" ]]; then
  MM_READY=$(echo "$MODELMESH" | awk '{print $2}')
  READY_NUM=$(echo "$MM_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$MM_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "ModelMesh controller ready ($MM_READY)"
  else
    fail "ModelMesh controller not ready ($MM_READY)"
  fi
else
  echo "  ModelMesh controller not found (may not be deployed)"
fi

# 8c. Check ServingRuntimes exist
SR_COUNT=$(oc get servingruntimes -n redhat-ods-applications --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SR_COUNT" -gt 0 ]]; then
  pass "Found $SR_COUNT ServingRuntime(s) in redhat-ods-applications"
else
  warn "No ServingRuntimes found in redhat-ods-applications"
fi

# 8d. Check InferenceServices across cluster
IS_COUNT=$(oc get inferenceservice --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$IS_COUNT" -gt 0 ]]; then
  echo "  Found $IS_COUNT InferenceService(s) across cluster"
  # Check each for readiness
  oc get inferenceservice --all-namespaces --no-headers 2>/dev/null | while read -r line; do
    IS_NS=$(echo "$line" | awk '{print $1}')
    IS_NAME=$(echo "$line" | awk '{print $2}')
    IS_READY=$(echo "$line" | awk '{print $NF}')
    echo "    $IS_NS/$IS_NAME: $IS_READY"
  done
else
  echo "  No InferenceServices deployed"
fi

echo ""
```

### Step 9: Model Registry Readiness

```bash
echo "=== Test 8: Model Registry ==="

MR_OPERATOR=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "model-registry-operator" | head -1 || echo "")

if [[ -n "$MR_OPERATOR" ]]; then
  MR_READY=$(echo "$MR_OPERATOR" | awk '{print $2}')
  READY_NUM=$(echo "$MR_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$MR_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "Model Registry operator ready ($MR_READY)"
  else
    fail "Model Registry operator not ready ($MR_READY)"
  fi
else
  warn "Model Registry operator not found (may be set to Removed)"
fi

# Check registry namespace
MR_NS=$(oc get datasciencecluster -o jsonpath='{.items[0].spec.components.modelregistry.registriesNamespace}' 2>/dev/null || echo "")
if [[ -n "$MR_NS" ]]; then
  if oc get namespace "$MR_NS" &>/dev/null; then
    pass "Model Registry namespace $MR_NS exists"
  else
    warn "Model Registry namespace $MR_NS not found"
  fi
fi

echo ""
```

### Step 10: TrustyAI / EvalHub Readiness

```bash
echo "=== Test 9: TrustyAI / EvalHub ==="

# 10a. TrustyAI operator
TRUSTYAI=$(oc get deployment -n redhat-ods-applications --no-headers 2>/dev/null | grep "trustyai" | head -1 || echo "")

if [[ -n "$TRUSTYAI" ]]; then
  TA_READY=$(echo "$TRUSTYAI" | awk '{print $2}')
  READY_NUM=$(echo "$TA_READY" | cut -d/ -f1)
  TOTAL_NUM=$(echo "$TA_READY" | cut -d/ -f2)

  if [[ "$READY_NUM" == "$TOTAL_NUM" && "$READY_NUM" -gt 0 ]]; then
    pass "TrustyAI operator ready ($TA_READY)"
  else
    fail "TrustyAI operator not ready ($TA_READY)"
  fi
else
  warn "TrustyAI operator not found (may be set to Removed)"
fi

# 10b. Check EvalHub namespace and resources
if oc get namespace evalhub &>/dev/null; then
  EVALHUB_PODS=$(oc get pods -n evalhub --no-headers 2>/dev/null || echo "")
  EH_TOTAL=$(echo "$EVALHUB_PODS" | grep -c '.' || echo "0")
  EH_RUNNING=$(echo "$EVALHUB_PODS" | grep -c "Running" || echo "0")
  EH_ISSUES=$(echo "$EVALHUB_PODS" | grep -cE "CrashLoopBackOff|ImagePullBackOff|Error" || echo "0")

  if [[ "$EH_ISSUES" -eq 0 && "$EH_RUNNING" -gt 0 ]]; then
    pass "EvalHub namespace: $EH_RUNNING/$EH_TOTAL pods running"
  elif [[ "$EH_ISSUES" -gt 0 ]]; then
    fail "EvalHub namespace: $EH_ISSUES pods with issues"
  else
    warn "EvalHub namespace exists but no running pods"
  fi

  # Check EvalHub route
  EH_ROUTE=$(oc get route -n evalhub --no-headers 2>/dev/null | head -1 | awk '{print $2}' || echo "")
  if [[ -n "$EH_ROUTE" ]]; then
    pass "EvalHub route: https://$EH_ROUTE"
  fi
else
  echo "  EvalHub namespace not found (not configured)"
fi

echo ""
```

### Step 11: Dependent Operator Health

Check that key dependent operators (service mesh, serverless, pipelines, cert-manager) are installed and healthy.

```bash
echo "=== Test 10: Dependent Operators ==="

DEPENDENT_OPERATORS=(
  "servicemeshoperator"
  "openshift-pipelines-operator-rh"
  "serverless-operator"
  "openshift-cert-manager-operator"
)

for op in "${DEPENDENT_OPERATORS[@]}"; do
  OP_CSV=$(oc get csv --all-namespaces 2>/dev/null | grep "$op" | grep -v Replacing | head -1 || echo "")

  if [[ -n "$OP_CSV" ]]; then
    OP_PHASE=$(echo "$OP_CSV" | awk '{print $NF}')
    OP_NAME=$(echo "$OP_CSV" | awk '{print $2}')
    if [[ "$OP_PHASE" == "Succeeded" ]]; then
      pass "$op ($OP_NAME): Succeeded"
    else
      warn "$op ($OP_NAME): $OP_PHASE"
    fi
  else
    warn "$op: not installed"
  fi
done

echo ""
```

### Step 12: Disconnected-Specific Checks (auto-detected)

If running on a disconnected cluster (detected by IDMS presence), run additional checks.

```bash
echo "=== Test 11: Disconnected Cluster Checks ==="

IDMS_COUNT=$(oc get imagedigestmirrorset --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "$IDMS_COUNT" -gt 0 ]]; then
  echo "  Detected disconnected cluster ($IDMS_COUNT IDMS entries)"

  # Check IDMS entries for key RHOAI sources
  REQUIRED_SOURCES=("registry.redhat.io/rhoai" "registry.redhat.io/rhel9" "registry.redhat.io/ubi9")
  IDMS_SOURCES=$(oc get imagedigestmirrorset -o jsonpath='{range .items[*]}{range .spec.imageDigestMirrors[*]}{.source}{"\n"}{end}{end}' 2>/dev/null | sort -u)

  for source in "${REQUIRED_SOURCES[@]}"; do
    if echo "$IDMS_SOURCES" | grep -q "$source"; then
      pass "IDMS entry exists for $source"
    else
      fail "IDMS entry missing for $source"
    fi
  done

  # Check for any ImagePullBackOff across ALL namespaces (not just RHOAI)
  IPB_PODS=$(oc get pods --all-namespaces --no-headers 2>/dev/null | grep -E "ImagePullBackOff|ErrImagePull" | head -10 || echo "")
  if [[ -n "$IPB_PODS" ]]; then
    IPB_COUNT=$(echo "$IPB_PODS" | wc -l | tr -d ' ')
    warn "$IPB_COUNT pods with ImagePullBackOff across cluster (may indicate missing mirrored images)"
    echo "$IPB_PODS" | while read -r line; do
      echo "    $(echo "$line" | awk '{print $1"/"$2": "$4}')"
    done
  else
    pass "No ImagePullBackOff pods across cluster"
  fi
else
  echo "  Connected cluster detected (no IDMS entries) — skipping disconnected checks"
fi

echo ""
```

### Step 13: Test Summary

```bash
echo "=========================================="
echo "  RHOAI Verification Summary"
echo "=========================================="
echo ""
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  WARN: $WARN_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "  Result: ALL TESTS PASSED"
else
  echo "  Result: $FAIL_COUNT FAILURE(S) DETECTED"
  echo ""
  echo "  Troubleshooting:"
  echo "  - ImagePullBackOff: Run /mirror-images to mirror missing images"
  echo "  - CrashLoopBackOff: Check pod logs (may need podToPodTLS workaround)"
  echo "  - DSC not Ready: Check component conditions with: oc get dsc -o yaml"
  echo "  - CSV not Succeeded: Check InstallPlan and operator logs"
fi

echo ""
echo "Cluster: $(oc whoami --show-server 2>/dev/null)"
echo "RHOAI Version: ${CSV_VERSION:-Unknown}"
```

Write the test results to the report file in markdown format for archival.

## Output

Report saved to `artifacts/rhoai-manager/reports/verify-[timestamp].md` with:
- Cluster info and RHOAI version
- Per-test PASS/FAIL/WARN results
- Summary counts
- Troubleshooting guidance for failures
