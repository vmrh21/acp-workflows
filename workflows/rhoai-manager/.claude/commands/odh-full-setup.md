# /odh-full-setup - Deploy ODH with Full Supporting Stack

Deploy Open Data Hub (ODH) with all supporting services (EvalHub, LlamaStack, Keycloak, Milvus, MinIO) on an OpenShift cluster. Idempotent: checks existing deployments, verifies health, and only deploys what's missing.

## Command Usage

```bash
/odh-full-setup                                          # Deploy everything with defaults
/odh-full-setup llm-url=https://my-vllm.example.com/v1  # Custom LLM endpoint for LlamaStack
/odh-full-setup emb-url=https://my-emb.example.com/v1   # Custom embedding endpoint
/odh-full-setup skip=milvus,minio                        # Skip specific components
/odh-full-setup components=odh,evalhub                   # Deploy only specific components
```

## Components

| # | Component | Namespace(s) | Description |
|---|-----------|-------------|-------------|
| 1 | ODH Operator | `openshift-operators`, `opendatahub` | Operator, DSCI, DSC with all components managed |
| 2 | MinIO | `minio` | Object storage for Milvus |
| 3 | Milvus | `milvus` | Vector database for RAG/vector_io |
| 4 | Keycloak | `keycloak`, `postgresql` | RHBK operator + PostgreSQL for OAuth2 auth |
| 5 | EvalHub | `evalhub`, `tenant` | Evaluation hub with PostgreSQL and multi-tenancy |
| 6 | LlamaStack | `llama-stack` | LLM gateway with remote vLLM provider |

## Prerequisites

1. **Cluster access**: Logged into OpenShift cluster with cluster-admin privileges (use `/oc-login`)
2. **Tools installed**: `oc` CLI must be available
3. **No existing RHOAI**: ODH and RHOAI cannot coexist (use `/rhoai-uninstall` first)
4. **LLM endpoint** (for LlamaStack): Either provide `llm-url=` / `emb-url=` arguments or have models served on a reachable vLLM endpoint

## Process

### Step 1: Parse Input Arguments

```bash
CATALOG_IMAGE="quay.io/opendatahub/opendatahub-operator-catalog:latest"
CHANNEL="fast"
LLM_URL=""
EMB_URL=""
LLM_MODEL_ID="meta-llama/Llama-3.3-70B-Instruct"
EMB_MODEL_ID="ibm-granite/granite-embedding-english-r2"
EMB_DIMENSION="768"
SKIP_LIST=""
COMPONENT_LIST=""

for arg in "$@"; do
  case "$arg" in
    channel=*)    CHANNEL="${arg#*=}" ;;
    image=*)      CATALOG_IMAGE="${arg#*=}" ;;
    llm-url=*)    LLM_URL="${arg#*=}" ;;
    emb-url=*)    EMB_URL="${arg#*=}" ;;
    llm-model=*)  LLM_MODEL_ID="${arg#*=}" ;;
    emb-model=*)  EMB_MODEL_ID="${arg#*=}" ;;
    skip=*)       SKIP_LIST="${arg#*=}" ;;
    components=*) COMPONENT_LIST="${arg#*=}" ;;
    *) echo "Unknown parameter: $arg" ;;
  esac
done

should_deploy() {
  local name="$1"
  if [[ -n "$COMPONENT_LIST" ]]; then
    echo "$COMPONENT_LIST" | tr ',' '\n' | grep -qw "$name" && return 0 || return 1
  fi
  if [[ -n "$SKIP_LIST" ]]; then
    echo "$SKIP_LIST" | tr ',' '\n' | grep -qw "$name" && return 1 || return 0
  fi
  return 0
}
```

### Step 2: Verify Cluster Access

```bash
oc whoami &>/dev/null || { echo "ERROR: Not logged into OpenShift cluster. Use /oc-login first."; exit 1; }
echo "Logged in as: $(oc whoami)"
echo "Cluster: $(oc whoami --show-server)"

# RHOAI and ODH cannot coexist
if oc get csv -A 2>/dev/null | grep -q rhods-operator; then
  echo "ERROR: RHOAI is installed. Use /rhoai-uninstall first, then re-run /odh-full-setup."
  exit 1
fi
```

### Step 3: ODH Operator (check/install)

Skip if `should_deploy odh` returns false.

```bash
if should_deploy odh; then
  echo ""
  echo "=========================================="
  echo "  Component 1/6: ODH Operator"
  echo "=========================================="

  # Check if already installed
  CSV_LINE=$(oc get csv -A 2>/dev/null | grep opendatahub-operator || echo "")
  if [[ -n "$CSV_LINE" ]]; then
    CSV_PHASE=$(echo "$CSV_LINE" | awk '{print $NF}')
    CSV_NAME=$(echo "$CSV_LINE" | awk '{print $2}')
    echo "ODH operator already installed: $CSV_NAME (Phase: $CSV_PHASE)"

    if [[ "$CSV_PHASE" != "Succeeded" ]]; then
      echo "WARNING: CSV is not in Succeeded state"
    fi
  else
    echo "Installing ODH operator..."

    # CatalogSource
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: odh-catalog-main
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${CATALOG_IMAGE}
  displayName: ODH Catalog (main)
  publisher: opendatahub.io
  updateStrategy:
    registryPoll:
      interval: 15m
  grpcPodConfig:
    securityContextConfig: restricted
EOF

    # Wait for catalog pod
    TIMEOUT=120; ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      PHASE=$(oc get pod -n openshift-marketplace -l olm.catalogSource=odh-catalog-main \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
      [[ "$PHASE" == "Running" ]] && echo "CatalogSource ready" && break
      sleep 5; ELAPSED=$((ELAPSED + 5))
    done

    # Subscription — ODH goes into openshift-operators (already has global OperatorGroup)
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: opendatahub-operator
  namespace: openshift-operators
spec:
  channel: ${CHANNEL}
  name: opendatahub-operator
  source: odh-catalog-main
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

    # Wait for CSV
    TIMEOUT=600; ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      CSV_LINE=$(oc get csv -n openshift-operators 2>/dev/null | grep opendatahub-operator || echo "")
      if [[ -n "$CSV_LINE" ]]; then
        CSV_PHASE=$(echo "$CSV_LINE" | awk '{print $NF}')
        [[ "$CSV_PHASE" == "Succeeded" ]] && echo "ODH operator CSV: Succeeded" && break
      fi
      sleep 10; ELAPSED=$((ELAPSED + 10))
      echo "Waiting for CSV... (${ELAPSED}s/${TIMEOUT}s)"
    done
    [[ "$CSV_PHASE" != "Succeeded" ]] && echo "ERROR: CSV did not reach Succeeded" && exit 1
  fi
fi
```

### Step 4: DSCI and DSC (check/create, wait for Ready)

```bash
if should_deploy odh; then
  # DSCInitialization
  if oc get dsci default-dsci &>/dev/null 2>&1; then
    echo "DSCI already exists"
  else
    echo "Creating DSCInitialization..."
    cat << EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: opendatahub
  monitoring:
    managementState: Managed
    namespace: opendatahub
  trustedCABundle:
    managementState: Managed
  devFlags:
    logMode: production
EOF
    sleep 10
  fi

  # DataScienceCluster
  if oc get dsc default-dsc &>/dev/null 2>&1; then
    echo "DSC already exists"
  else
    echo "Creating DataScienceCluster with all components managed..."
    cat << EOF | oc apply -f -
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    dashboard:
      managementState: Managed
    workbenches:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    kserve:
      managementState: Managed
      serving:
        managementState: Removed
    modelmeshserving:
      managementState: Managed
    ray:
      managementState: Managed
    kueue:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    modelregistry:
      managementState: Managed
    feastoperator:
      managementState: Managed
EOF
  fi

  # Wait for DSC Ready
  TIMEOUT=600; ELAPSED=0
  while [[ $ELAPSED -lt $TIMEOUT ]]; do
    READY=$(oc get dsc default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    [[ "$READY" == "True" ]] && echo "DSC is Ready" && break
    sleep 15; ELAPSED=$((ELAPSED + 15))
    echo "Waiting for DSC... (${ELAPSED}s/${TIMEOUT}s)"
  done
fi
```

### Step 5: MinIO (check/deploy)

```bash
if should_deploy minio; then
  echo ""
  echo "=========================================="
  echo "  Component 2/6: MinIO"
  echo "=========================================="

  if oc get deployment minio -n minio &>/dev/null 2>&1; then
    MINIO_READY=$(oc get deployment minio -n minio -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$MINIO_READY" -ge 1 ]]; then
      echo "MinIO already running ($MINIO_READY replicas)"
    else
      echo "WARNING: MinIO deployment exists but no ready replicas"
    fi
  else
    echo "Deploying MinIO..."
    oc create namespace minio 2>/dev/null || true

    MINIO_ACCESS_KEY=$(openssl rand -hex 12)
    MINIO_SECRET_KEY=$(openssl rand -hex 24)

    cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: minio
type: Opaque
stringData:
  accesskey: "${MINIO_ACCESS_KEY}"
  secretkey: "${MINIO_SECRET_KEY}"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: minio
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
  labels:
    app: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args: ["server", "/data", "--console-address", ":9001"]
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: accesskey
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-secret
              key: secretkey
        ports:
        - {containerPort: 9000, name: api}
        - {containerPort: 9001, name: console}
        volumeMounts:
        - {name: data, mountPath: /data}
        livenessProbe:
          httpGet: {path: /minio/health/live, port: 9000}
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet: {path: /minio/health/ready, port: 9000}
          initialDelaySeconds: 15
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  ports:
  - {port: 9000, targetPort: 9000, name: api}
  selector:
    app: minio
---
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: minio
spec:
  ports:
  - {port: 9001, targetPort: 9001, name: console}
  selector:
    app: minio
EOF

    oc rollout status deployment/minio -n minio --timeout=180s
    echo "MinIO deployed"
  fi
fi
```

### Step 6: Milvus (check/deploy)

```bash
if should_deploy milvus; then
  echo ""
  echo "=========================================="
  echo "  Component 3/6: Milvus"
  echo "=========================================="

  if oc get statefulset milvus -n milvus &>/dev/null 2>&1; then
    MILVUS_READY=$(oc get statefulset milvus -n milvus -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$MILVUS_READY" -ge 1 ]]; then
      echo "Milvus already running ($MILVUS_READY replicas)"
    else
      echo "WARNING: Milvus statefulset exists but no ready replicas"
    fi
  else
    echo "Deploying Milvus (standalone with embedded etcd)..."
    oc create namespace milvus 2>/dev/null || true

    cat << 'EOF' | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: milvus-data
  namespace: milvus
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: milvus-config
  namespace: milvus
data:
  embedEtcd.yaml: |
    listen-client-urls: http://0.0.0.0:2379
    advertise-client-urls: http://0.0.0.0:2379
    quota-backend-bytes: 4294967296
    auto-compaction-mode: revision
    auto-compaction-retention: "1000"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: milvus
  namespace: milvus
  labels:
    app: milvus
spec:
  serviceName: milvus
  replicas: 1
  selector:
    matchLabels:
      app: milvus
  template:
    metadata:
      labels:
        app: milvus
    spec:
      containers:
      - name: milvus
        image: milvusdb/milvus:v2.5.4
        command: ["milvus", "run", "standalone"]
        env:
        - {name: ETCD_USE_EMBED, value: "true"}
        - {name: ETCD_DATA_DIR, value: /var/lib/milvus/etcd}
        - {name: ETCD_CONFIG_PATH, value: /milvus/configs/embedEtcd.yaml}
        - {name: COMMON_STORAGETYPE, value: local}
        ports:
        - {containerPort: 19530, name: grpc}
        - {containerPort: 9091, name: metrics}
        volumeMounts:
        - {name: milvus-data, mountPath: /var/lib/milvus}
        - {name: config, mountPath: /milvus/configs/embedEtcd.yaml, subPath: embedEtcd.yaml}
        resources:
          requests: {cpu: "500m", memory: "1Gi"}
          limits: {cpu: "2", memory: "4Gi"}
        livenessProbe:
          httpGet: {path: /healthz, port: 9091}
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet: {path: /healthz, port: 9091}
          initialDelaySeconds: 30
          periodSeconds: 15
      volumes:
      - name: milvus-data
        persistentVolumeClaim:
          claimName: milvus-data
      - name: config
        configMap:
          name: milvus-config
---
apiVersion: v1
kind: Service
metadata:
  name: milvus
  namespace: milvus
spec:
  ports:
  - {port: 19530, targetPort: 19530, name: grpc}
  - {port: 9091, targetPort: 9091, name: metrics}
  selector:
    app: milvus
EOF

    echo "Waiting for Milvus to be ready..."
    TIMEOUT=180; ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      READY=$(oc get statefulset milvus -n milvus -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      [[ "$READY" -ge 1 ]] && echo "Milvus is ready" && break
      sleep 10; ELAPSED=$((ELAPSED + 10))
    done
  fi
fi
```

### Step 7: Keycloak PostgreSQL (check/deploy)

```bash
if should_deploy keycloak; then
  echo ""
  echo "=========================================="
  echo "  Component 4/6: Keycloak"
  echo "=========================================="

  # PostgreSQL for Keycloak
  if oc get deployment psql-keycloak -n postgresql &>/dev/null 2>&1; then
    PG_READY=$(oc get deployment psql-keycloak -n postgresql -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "Keycloak PostgreSQL already running ($PG_READY replicas)"
  else
    echo "Deploying Keycloak PostgreSQL..."
    oc create namespace postgresql 2>/dev/null || true

    KC_DB_USER="pguser-$(openssl rand -hex 4)"
    KC_DB_PASS=$(openssl rand -base64 16)

    cat << EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: psql-keycloak-pvc
  namespace: postgresql
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: psql-keycloak
  namespace: postgresql
  labels:
    app: psql-keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: psql-keycloak
  template:
    metadata:
      labels:
        app: psql-keycloak
    spec:
      containers:
      - name: postgresql
        image: registry.redhat.io/rhel9/postgresql-15:latest
        env:
        - {name: POSTGRESQL_USER, value: "${KC_DB_USER}"}
        - {name: POSTGRESQL_PASSWORD, value: "${KC_DB_PASS}"}
        - {name: POSTGRESQL_DATABASE, value: keycloak}
        ports:
        - {containerPort: 5432}
        volumeMounts:
        - {name: postgresql-data, mountPath: /var/lib/pgsql/data}
        livenessProbe:
          exec:
            command: ["/bin/sh", "-i", "-c", "pg_isready -h 127.0.0.1 -p 5432"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["/bin/sh", "-i", "-c", "psql -h 127.0.0.1 -U \$POSTGRESQL_USER -q -d \$POSTGRESQL_DATABASE -c 'SELECT 1'"]
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests: {cpu: "100m", memory: "256Mi"}
          limits: {cpu: "500m", memory: "512Mi"}
      volumes:
      - name: postgresql-data
        persistentVolumeClaim:
          claimName: psql-keycloak-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: psql-keycloak
  namespace: postgresql
spec:
  ports:
  - {port: 5432, targetPort: 5432}
  selector:
    app: psql-keycloak
EOF

    oc rollout status deployment/psql-keycloak -n postgresql --timeout=180s
    echo "Keycloak PostgreSQL deployed"
  fi
fi
```

### Step 8: Keycloak Operator + CR (check/deploy)

```bash
if should_deploy keycloak; then
  oc create namespace keycloak 2>/dev/null || true

  # Create DB secret (idempotent — read existing creds if PostgreSQL already deployed)
  if ! oc get secret keycloak-db-secret -n keycloak &>/dev/null; then
    # Read creds from running PostgreSQL deployment
    KC_DB_USER=$(oc get deployment psql-keycloak -n postgresql \
      -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="POSTGRESQL_USER")].value}' 2>/dev/null)
    KC_DB_PASS=$(oc get deployment psql-keycloak -n postgresql \
      -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="POSTGRESQL_PASSWORD")].value}' 2>/dev/null)

    cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-db-secret
  namespace: keycloak
type: Opaque
stringData:
  username: "${KC_DB_USER}"
  password: "${KC_DB_PASS}"
EOF
  fi

  # RHBK Operator
  if oc get csv -n keycloak 2>/dev/null | grep -q rhbk-operator; then
    RHBK_PHASE=$(oc get csv -n keycloak 2>/dev/null | grep rhbk-operator | awk '{print $NF}')
    echo "RHBK operator: $RHBK_PHASE"
  else
    echo "Installing RHBK operator..."
    cat << 'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: keycloak-og
  namespace: keycloak
spec:
  targetNamespaces:
    - keycloak
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhbk-operator
  namespace: keycloak
spec:
  channel: stable-v26.4
  installPlanApproval: Automatic
  name: rhbk-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    # Wait for CSV
    TIMEOUT=300; ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      STATUS=$(oc get csv -n keycloak 2>/dev/null | grep rhbk | awk '{print $NF}')
      [[ "$STATUS" == "Succeeded" ]] && echo "RHBK operator installed" && break
      sleep 10; ELAPSED=$((ELAPSED + 10))
    done
  fi

  # Keycloak CR
  if oc get keycloak keycloak -n keycloak &>/dev/null 2>&1; then
    KC_READY=$(oc get keycloak keycloak -n keycloak \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    echo "Keycloak CR exists (Ready: $KC_READY)"
  else
    echo "Creating Keycloak CR..."
    cat << 'EOF' | oc apply -f -
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak
spec:
  instances: 1
  db:
    vendor: postgres
    host: psql-keycloak.postgresql.svc.cluster.local
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
  additionalOptions:
    - name: http-enabled
      value: "true"
  proxy:
    headers: xforwarded
  ingress:
    className: openshift-default
EOF

    TIMEOUT=300; ELAPSED=0
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      KC_READY=$(oc get keycloak keycloak -n keycloak \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
      [[ "$KC_READY" == "True" ]] && echo "Keycloak is Ready" && break
      sleep 10; ELAPSED=$((ELAPSED + 10))
    done
  fi
fi
```

### Step 9: Configure Keycloak Realm + Client

```bash
if should_deploy keycloak; then
  KC_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null)

  if [[ -z "$KC_ROUTE" ]]; then
    echo "WARNING: Keycloak route not found, skipping realm setup"
  else
    ADMIN_USER=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d)
    ADMIN_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)

    ADMIN_TOKEN=$(curl -sk -X POST "https://${KC_ROUTE}/realms/master/protocol/openid-connect/token" \
      -d "grant_type=password" -d "client_id=admin-cli" \
      -d "username=${ADMIN_USER}" -d "password=${ADMIN_PASS}" | \
      python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

    if [[ -z "$ADMIN_TOKEN" ]]; then
      echo "WARNING: Could not obtain Keycloak admin token"
    else
      # Create realm (409 = already exists = fine)
      HTTP=$(curl -sk -o /dev/null -w "%{http_code}" -X POST "https://${KC_ROUTE}/admin/realms" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"realm":"llamastack","enabled":true,"accessTokenLifespan":86400}')
      [[ "$HTTP" == "201" ]] && echo "Created realm: llamastack"
      [[ "$HTTP" == "409" ]] && echo "Realm llamastack already exists"

      # Create client (409 = already exists = fine)
      HTTP=$(curl -sk -o /dev/null -w "%{http_code}" -X POST "https://${KC_ROUTE}/admin/realms/llamastack/clients" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"clientId":"llama-stack-client","enabled":true,"protocol":"openid-connect","publicClient":false,"serviceAccountsEnabled":true,"directAccessGrantsEnabled":true,"standardFlowEnabled":false}')
      [[ "$HTTP" == "201" ]] && echo "Created client: llama-stack-client"
      [[ "$HTTP" == "409" ]] && echo "Client llama-stack-client already exists"

      # Get client secret and store in K8s
      if ! oc get secret llama-stack-client-secret -n keycloak &>/dev/null; then
        CLIENT_UUID=$(curl -sk -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          "https://${KC_ROUTE}/admin/realms/llamastack/clients?clientId=llama-stack-client" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
        CLIENT_SECRET=$(curl -sk -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          "https://${KC_ROUTE}/admin/realms/llamastack/clients/${CLIENT_UUID}/client-secret" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['value'])")

        cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: llama-stack-client-secret
  namespace: keycloak
type: Opaque
stringData:
  client-id: llama-stack-client
  client-secret: "${CLIENT_SECRET}"
EOF
        echo "Client secret stored in keycloak namespace"
      else
        echo "Client secret already exists"
      fi
    fi
  fi
fi
```

### Step 10: EvalHub PostgreSQL (check/deploy)

```bash
if should_deploy evalhub; then
  echo ""
  echo "=========================================="
  echo "  Component 5/6: EvalHub"
  echo "=========================================="

  oc create namespace evalhub 2>/dev/null || true

  # Check if EvalHub CRD exists (requires TrustyAI operator)
  if ! oc get crd evalhubs.trustyai.opendatahub.io &>/dev/null; then
    echo "ERROR: EvalHub CRD not found. Ensure TrustyAI is enabled in DSC (trustyai.managementState: Managed)"
    echo "Skipping EvalHub deployment"
  else
    # PostgreSQL for EvalHub
    if oc get deployment postgresql -n evalhub &>/dev/null 2>&1; then
      PG_READY=$(oc get deployment postgresql -n evalhub -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      echo "EvalHub PostgreSQL already running ($PG_READY replicas)"
    else
      echo "Deploying EvalHub PostgreSQL..."
      EVALHUB_DB_PASS=$(openssl rand -hex 16)

      cat << EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: evalhub
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: evalhub
  labels:
    app: postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: registry.redhat.io/rhel9/postgresql-15:latest
        ports:
        - {containerPort: 5432}
        env:
        - {name: POSTGRESQL_USER, value: evalhub_user}
        - {name: POSTGRESQL_PASSWORD, value: "${EVALHUB_DB_PASS}"}
        - {name: POSTGRESQL_DATABASE, value: eval_hub}
        volumeMounts:
        - {name: postgresql-data, mountPath: /var/lib/pgsql/data}
        livenessProbe:
          exec:
            command: ["/bin/sh", "-i", "-c", "pg_isready -h 127.0.0.1 -p 5432"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["/bin/sh", "-i", "-c", "psql -h 127.0.0.1 -U \$POSTGRESQL_USER -q -d \$POSTGRESQL_DATABASE -c 'SELECT 1'"]
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests: {cpu: "100m", memory: "256Mi"}
          limits: {cpu: "500m", memory: "512Mi"}
      volumes:
      - name: postgresql-data
        persistentVolumeClaim:
          claimName: postgresql-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: evalhub
spec:
  ports:
  - {port: 5432, targetPort: 5432}
  selector:
    app: postgresql
EOF

      oc rollout status deployment/postgresql -n evalhub --timeout=300s

      # Create DB secret
      DB_URL="postgres://evalhub_user:${EVALHUB_DB_PASS}@postgresql.evalhub.svc:5432/eval_hub"
      cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: evalhub-db-credentials
  namespace: evalhub
type: Opaque
stringData:
  db-url: "${DB_URL}"
EOF
      echo "EvalHub PostgreSQL deployed"
    fi
  fi
fi
```

### Step 11: EvalHub CR + Tenant (check/deploy)

```bash
if should_deploy evalhub; then
  if oc get crd evalhubs.trustyai.opendatahub.io &>/dev/null; then
    if oc get evalhub evalhub -n evalhub &>/dev/null 2>&1; then
      PHASE=$(oc get evalhub evalhub -n evalhub -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
      echo "EvalHub CR exists (Phase: $PHASE)"
    else
      echo "Creating EvalHub CR..."
      # Only use collections that are available in current ODH build
      COLLECTIONS_YAML="    - leaderboard-v2"
      for col in safety-and-fairness-v1 toxicity-and-ethical-principles; do
        if oc get configmap -n opendatahub -l "trustyai.opendatahub.io/evalhub-collection-name=$col" 2>/dev/null | grep -q "$col"; then
          COLLECTIONS_YAML="${COLLECTIONS_YAML}\n    - $col"
        fi
      done

      cat << EOF | oc apply -f -
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: EvalHub
metadata:
  name: evalhub
  namespace: evalhub
spec:
  replicas: 1
  database:
    type: postgresql
    secret: evalhub-db-credentials
    maxIdleConns: 5
    maxOpenConns: 25
  providers:
    - garak
    - guidellm
    - lighteval
    - lm-evaluation-harness
    - garak-kfp
    - ibm-clear
  collections:
$(echo -e "$COLLECTIONS_YAML")
EOF

      TIMEOUT=300; ELAPSED=0
      while [[ $ELAPSED -lt $TIMEOUT ]]; do
        PHASE=$(oc get evalhub evalhub -n evalhub -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        [[ "$PHASE" == "Ready" ]] && echo "EvalHub is Ready" && break
        sleep 10; ELAPSED=$((ELAPSED + 10))
        echo "Waiting for EvalHub... Phase=${PHASE} (${ELAPSED}s/${TIMEOUT}s)"
      done
    fi

    # Tenant namespace
    oc create namespace tenant 2>/dev/null || true
    oc label namespace tenant evalhub.trustyai.opendatahub.io/tenant= --overwrite 2>/dev/null

    # Tenant RBAC
    cat << 'EOF' | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-user
  namespace: tenant
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-evaluator
  namespace: tenant
rules:
  - apiGroups: [trustyai.opendatahub.io]
    resources: [evaluations, collections, providers]
    verbs: [get, list, create, update, patch, delete]
  - apiGroups: [trustyai.opendatahub.io]
    resources: [status-events]
    verbs: [create]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: evalhub-evaluator-binding
  namespace: tenant
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: evalhub-evaluator
subjects:
  - kind: ServiceAccount
    name: tenant-user
    namespace: tenant
EOF
    echo "Tenant namespace and RBAC configured"
  fi
fi
```

### Step 12: LlamaStack (check/deploy)

Requires `llm-url` and `emb-url` arguments for the remote model endpoints. If not provided, LlamaStack deployment is skipped with a message.

**IMPORTANT: The service MUST be named `llama-stack-svc` (not `llama-stack`) to avoid Kubernetes injecting a `LLAMA_STACK_PORT` env var that collides with LlamaStack's port parsing.**

**IMPORTANT: The config MUST be mounted at `/opt/app-root/config.yaml` via subPath to override the baked-in default config. The `LLAMA_STACK_CONFIG` env var alone is not sufficient.**

```bash
if should_deploy llamastack; then
  echo ""
  echo "=========================================="
  echo "  Component 6/6: LlamaStack"
  echo "=========================================="

  if [[ -z "$LLM_URL" || -z "$EMB_URL" ]]; then
    echo "WARNING: llm-url and emb-url not provided"
    echo "LlamaStack requires remote model endpoints."
    echo "Usage: /odh-full-setup llm-url=https://my-vllm/v1 emb-url=https://my-emb/v1"
    echo "Skipping LlamaStack deployment"
  elif oc get deployment llama-stack -n llama-stack &>/dev/null 2>&1; then
    LS_READY=$(oc get deployment llama-stack -n llama-stack -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "LlamaStack already running ($LS_READY replicas)"
  else
    echo "Deploying LlamaStack..."
    oc create namespace llama-stack 2>/dev/null || true

    KC_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")

    # Build auth section if Keycloak is deployed
    AUTH_SECTION=""
    if [[ -n "$KC_ROUTE" ]]; then
      AUTH_SECTION="
    server:
      port: 8321
      auth:
        provider_config:
          type: oauth2_token
          jwks:
            uri: http://keycloak-service.keycloak.svc.cluster.local:8080/realms/llamastack/protocol/openid-connect/certs
            key_recheck_period: 3600
          issuer: https://${KC_ROUTE}/realms/llamastack
          audience: account
          verify_tls: false"

      # Store client secret in llama-stack namespace
      if oc get secret llama-stack-client-secret -n keycloak &>/dev/null; then
        CLIENT_ID=$(oc get secret llama-stack-client-secret -n keycloak -o jsonpath='{.data.client-id}' | base64 -d)
        CLIENT_SECRET_VAL=$(oc get secret llama-stack-client-secret -n keycloak -o jsonpath='{.data.client-secret}' | base64 -d)
        cat << EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: llama-stack-api-token
  namespace: llama-stack
type: Opaque
stringData:
  client-id: "${CLIENT_ID}"
  client-secret: "${CLIENT_SECRET_VAL}"
EOF
      fi
    else
      AUTH_SECTION="
    server:
      port: 8321"
    fi

    # Build vector_io section if Milvus is deployed
    VECTOR_IO_SECTION=""
    if oc get statefulset milvus -n milvus &>/dev/null 2>&1; then
      VECTOR_IO_SECTION="
      vector_io:
        - provider_id: milvus
          provider_type: remote::milvus
          config:
            uri: http://milvus.milvus.svc.cluster.local:19530
            token: \"\"
            persistence:
              namespace: vector_io::milvus
              backend: kv_default"
    fi

    cat << EOF | oc apply -n llama-stack -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: llama-stack-config
  namespace: llama-stack
data:
  config.yaml: |
    version: 2
    image_name: rh
    apis:
      - inference
      - vector_io
      - files
    storage:
      backends:
        kv_default:
          type: kv_sqlite
          db_path: /opt/app-root/src/.llama/distributions/rh/db
        sql_default:
          type: sql_sqlite
          db_path: /opt/app-root/src/.llama/distributions/rh/db
      stores:
        metadata:
          namespace: registry
          backend: kv_default
        inference:
          table_name: inference_store
          backend: sql_default
          max_write_queue_size: 10000
          num_writers: 4
        conversations:
          table_name: openai_conversations
          backend: sql_default
        prompts:
          namespace: prompts
          backend: kv_default
    providers:
      inference:
        - model_id: ${LLM_MODEL_ID}
          provider_id: vllm-llm
          provider_type: remote::vllm
          provider_model_id: ${LLM_MODEL_ID}
          model_type: llm
          metadata: {}
          config:
            base_url: ${LLM_URL}
            max_tokens: 4096
            api_token: "no-auth"
            tls_verify: false
        - model_id: ${EMB_MODEL_ID}
          provider_id: vllm-embedding
          provider_model_id: ${EMB_MODEL_ID}
          provider_type: remote::vllm
          model_type: embedding
          config:
            base_url: ${EMB_URL}
            max_tokens: 512
            api_token: "no-auth"
            tls_verify: false
${VECTOR_IO_SECTION}
      files:
        - provider_id: meta-reference-files
          provider_type: inline::localfs
          config:
            storage_dir: /opt/app-root/src/.llama/distributions/rh/files
            metadata_store:
              backend: sql_default
              table_name: files_metadata
    registered_resources:
      models:
        - model_id: ${LLM_MODEL_ID}
          provider_id: vllm-llm
          provider_model_id: ${LLM_MODEL_ID}
          model_type: llm
          metadata: {}
        - metadata:
            embedding_dimension: ${EMB_DIMENSION}
          model_id: ${EMB_MODEL_ID}
          provider_id: vllm-embedding
          provider_model_id: ${EMB_MODEL_ID}
          model_type: embedding
${AUTH_SECTION}
EOF

    cat << 'EOF' | oc apply -n llama-stack -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: llama-stack-pvc
  namespace: llama-stack
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-stack
  namespace: llama-stack
  labels:
    app: llama-stack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-stack
  template:
    metadata:
      labels:
        app: llama-stack
    spec:
      containers:
      - name: llama-stack
        image: quay.io/opendatahub/llama-stack:latest
        ports:
        - {containerPort: 8321}
        env:
        - {name: HF_HOME, value: /opt/app-root/src/.llama/distributions/rh/}
        - {name: LLS_WORKERS, value: "1"}
        - {name: LLS_PORT, value: "8321"}
        - {name: LLAMA_STACK_CONFIG, value: /etc/llama-stack/config.yaml}
        volumeMounts:
        - {name: lls-storage, mountPath: /opt/app-root/src/.llama/distributions/rh/}
        - {name: user-config, mountPath: /etc/llama-stack/, readOnly: true}
        - {name: config-override, mountPath: /opt/app-root/config.yaml, subPath: config.yaml, readOnly: true}
        resources:
          requests: {cpu: "250m", memory: "512Mi"}
          limits: {cpu: "1", memory: "1Gi"}
      volumes:
      - name: lls-storage
        persistentVolumeClaim:
          claimName: llama-stack-pvc
      - name: user-config
        configMap:
          name: llama-stack-config
      - name: config-override
        configMap:
          name: llama-stack-config
EOF

    # Service — named llama-stack-svc to avoid LLAMA_STACK_PORT env var collision
    cat << 'EOF' | oc apply -n llama-stack -f -
apiVersion: v1
kind: Service
metadata:
  name: llama-stack-svc
  namespace: llama-stack
spec:
  ports:
  - {port: 8321, targetPort: 8321}
  selector:
    app: llama-stack
EOF

    oc create route edge llama-stack --service=llama-stack-svc --port=8321 -n llama-stack 2>/dev/null || true

    oc rollout status deployment/llama-stack -n llama-stack --timeout=120s
    echo "LlamaStack deployed"
  fi
fi
```

### Step 13: Verification

Test all endpoints to confirm everything is working.

```bash
echo ""
echo "=========================================="
echo "  Verification"
echo "=========================================="
echo ""

RESULTS=()

# ODH
if should_deploy odh; then
  CSV_PHASE=$(oc get csv -A 2>/dev/null | grep opendatahub-operator | awk '{print $NF}')
  DSC_READY=$(oc get dsc default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  DASHBOARD=$(oc get route odh-dashboard -n opendatahub -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  if [[ "$CSV_PHASE" == "Succeeded" && "$DSC_READY" == "True" ]]; then
    RESULTS+=("ODH|PASS|CSV: $CSV_PHASE, DSC: Ready, Dashboard: https://$DASHBOARD")
  else
    RESULTS+=("ODH|FAIL|CSV: $CSV_PHASE, DSC Ready: $DSC_READY")
  fi
fi

# MinIO
if should_deploy minio; then
  MINIO_READY=$(oc get deployment minio -n minio -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "$MINIO_READY" -ge 1 ]]; then
    RESULTS+=("MinIO|PASS|Running ($MINIO_READY replicas)")
  else
    RESULTS+=("MinIO|FAIL|Ready replicas: $MINIO_READY")
  fi
fi

# Milvus
if should_deploy milvus; then
  MILVUS_READY=$(oc get statefulset milvus -n milvus -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "$MILVUS_READY" -ge 1 ]]; then
    RESULTS+=("Milvus|PASS|Running ($MILVUS_READY replicas)")
  else
    RESULTS+=("Milvus|FAIL|Ready replicas: $MILVUS_READY")
  fi
fi

# Keycloak
if should_deploy keycloak; then
  KC_READY=$(oc get keycloak keycloak -n keycloak \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
  KC_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
  if [[ "$KC_READY" == "True" ]]; then
    RESULTS+=("Keycloak|PASS|Ready, Route: https://$KC_ROUTE")
  else
    RESULTS+=("Keycloak|FAIL|Ready: $KC_READY")
  fi
fi

# EvalHub
if should_deploy evalhub; then
  EH_PHASE=$(oc get evalhub evalhub -n evalhub -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  EH_ROUTE=$(oc get route -n evalhub -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
  if [[ "$EH_PHASE" == "Ready" ]]; then
    RESULTS+=("EvalHub|PASS|Phase: Ready, Route: https://$EH_ROUTE")
  else
    RESULTS+=("EvalHub|FAIL|Phase: $EH_PHASE")
  fi
fi

# LlamaStack
if should_deploy llamastack; then
  LS_READY=$(oc get deployment llama-stack -n llama-stack -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  LS_ROUTE=$(oc get route llama-stack -n llama-stack -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
  if [[ "$LS_READY" -ge 1 ]]; then
    RESULTS+=("LlamaStack|PASS|Running, Route: https://$LS_ROUTE")
  else
    RESULTS+=("LlamaStack|FAIL|Ready replicas: $LS_READY")
  fi
fi

# Print results
printf "%-12s %-6s %s\n" "Component" "Status" "Details"
printf "%-12s %-6s %s\n" "---------" "------" "-------"
for r in "${RESULTS[@]}"; do
  IFS='|' read -r COMP STATUS DETAIL <<< "$r"
  printf "%-12s %-6s %s\n" "$COMP" "$STATUS" "$DETAIL"
done
```

### Step 14: Summary

```bash
echo ""
echo "=========================================="
echo "  ODH Full Setup Complete"
echo "=========================================="
echo ""

DASHBOARD=$(oc get route odh-dashboard -n opendatahub -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
echo "Dashboard:    https://$DASHBOARD"

EH_ROUTE=$(oc get route -n evalhub -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
[[ -n "$EH_ROUTE" ]] && echo "EvalHub:      https://$EH_ROUTE"

LS_ROUTE=$(oc get route llama-stack -n llama-stack -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
[[ -n "$LS_ROUTE" ]] && echo "LlamaStack:   https://$LS_ROUTE"

KC_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
[[ -n "$KC_ROUTE" ]] && echo "Keycloak:     https://$KC_ROUTE"

echo ""
echo "Quick test (EvalHub):"
echo "  TOKEN=\$(oc create token tenant-user -n tenant --duration=4h)"
[[ -n "$EH_ROUTE" ]] && echo "  curl -sk -H \"Authorization: Bearer \$TOKEN\" -H \"X-Tenant: tenant\" \"https://${EH_ROUTE}/api/v1/evaluations/providers\""

echo ""
echo "Quick test (LlamaStack with Keycloak):"
[[ -n "$KC_ROUTE" ]] && echo "  CLIENT_ID=\$(oc get secret llama-stack-client-secret -n keycloak -o jsonpath='{.data.client-id}' | base64 -d)"
[[ -n "$KC_ROUTE" ]] && echo "  CLIENT_SECRET=\$(oc get secret llama-stack-client-secret -n keycloak -o jsonpath='{.data.client-secret}' | base64 -d)"
[[ -n "$KC_ROUTE" ]] && echo "  TOKEN=\$(curl -sk -X POST \"https://${KC_ROUTE}/realms/llamastack/protocol/openid-connect/token\" -d \"grant_type=client_credentials\" -d \"client_id=\$CLIENT_ID\" -d \"client_secret=\$CLIENT_SECRET\" | jq -r .access_token)"
[[ -n "$LS_ROUTE" ]] && echo "  curl -sk -H \"Authorization: Bearer \$TOKEN\" \"https://${LS_ROUTE}/v1/models\""
```

## Common Issues

| Problem | Solution |
|---------|----------|
| EvalHub stuck in Pending with collection error | Some collections may not be bundled in current ODH build. The command auto-detects available collections. |
| LlamaStack pod CrashLoopBackOff with `ValueError: invalid literal for int()` | Service named `llama-stack` causes K8s to inject `LLAMA_STACK_PORT` env var. Service must be named `llama-stack-svc`. |
| LlamaStack reads wrong config (`/opt/app-root/config.yaml`) | Config must be mounted at `/opt/app-root/config.yaml` via subPath, not just in `/etc/llama-stack/`. |
| RHBK operator CSV fails with `UnsupportedOperatorGroup` | OperatorGroup must have `targetNamespaces: [keycloak]`, not AllNamespaces. |
| Keycloak PostgreSQL CrashLoopBackOff after redeployment | PVC may have stale data from previous credentials. Delete PVC and let it recreate. |
| ODH CSV stuck in Installing | Check catalog pod: `oc get pods -n openshift-marketplace -l olm.catalogSource=odh-catalog-main` |
| DSC not Ready | Check component status: `oc get dsc default-dsc -o yaml \| grep -A5 conditions` |

## Notes

- **Idempotent**: Safe to run multiple times. Existing healthy components are verified, not re-created.
- **LlamaStack requires model endpoints**: Pass `llm-url=` and `emb-url=` to configure remote vLLM inference.
- **EvalHub auto-detects collections**: Only creates EvalHub CR with collections that have ConfigMaps available in the `opendatahub` namespace.
- **Keycloak realm**: Creates `llamastack` realm with `llama-stack-client` confidential client for OAuth2 authentication.
- **ODH catalog polls every 15 minutes**: When new commits merge to `opendatahub-operator` main, OLM picks up the updated catalog automatically. Dashboard module images (automl-ui, autorag-ui, etc.) use `:main` floating tags — restart `odh-dashboard` deployment to pull latest.
