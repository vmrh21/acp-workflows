# RHOAI Manager

Comprehensive workflow for managing the complete lifecycle of Red Hat OpenShift AI (RHOAI) and Open Data Hub (ODH): installation, updates, version detection, and uninstallation.

## Overview

This workflow provides an AI-powered pipeline for:
- Installing RHOAI or ODH from scratch on OpenShift clusters
- Updating RHOAI or ODH to latest nightly builds
- Detecting RHOAI version and build information
- Completely uninstalling RHOAI or ODH when needed
- Managing cluster connections and authentication
- Safely switching between RHOAI and ODH
- Overriding specific component images to use ODH main branch builds for testing

## Important: RHOAI and ODH Cannot Coexist

RHOAI and ODH share cluster-scoped CRDs (`DataScienceCluster`, `DSCInitialization`) and overlapping operators. They **cannot** be installed on the same cluster simultaneously. Both `/rhoai-install` and `/odh-install` detect the other and block with a clear error.

## Structure

```
workflows/rhoai-manager/
├── .ambient/
│   └── ambient.json              # Workflow configuration
├── .claude/
│   └── commands/
│       ├── oc-login.md           # OpenShift cluster login
│       ├── rhoai-install.md      # RHOAI installation
│       ├── rhoai-version.md      # RHOAI version detection
│       ├── rhoai-update.md       # RHOAI update to latest nightly
│       ├── rhoai-uninstall.md    # RHOAI uninstall
│       ├── odh-install.md        # ODH installation
│       ├── odh-update.md         # ODH update to latest nightly
│       ├── odh-uninstall.md      # ODH uninstall
│       ├── odh-pr-tracker.md     # Track ODH PRs in RHOAI builds
│       ├── mirror-images.md     # Mirror images to disconnected bastions
│       ├── rhoai-disconnected.md # Install/update RHOAI on disconnected clusters
│       ├── rhoai-verify.md      # Post-install/update verification tests
│       └── use-odh-main.md      # Override component images to ODH main branch
└── README.md                     # This file
```

## Commands

### /oc-login

Login to OpenShift cluster using credentials from Ambient session.

**Usage:** `/oc-login`

**Required env vars:** `OCP_SERVER`, `OCP_USERNAME`, `OCP_PASSWORD`

---

### /rhoai-install

Install RHOAI from scratch on an OpenShift cluster.

**Usage:**
```bash
/rhoai-install                                    # Latest dev nightly (default)
/rhoai-install channel=stable-3.4                 # GA stable-3.4 channel
/rhoai-install catalog=redhat-operators           # GA production catalog
```

**Prerequisite:** No existing RHOAI **or ODH** installation (detected automatically).

**What gets deployed:**
- Operator namespace: `redhat-ods-operator`
- Application namespace: `redhat-ods-applications`
- DataScienceCluster with all components

---

### /rhoai-update

Update RHOAI to the latest nightly or GA build.

**Usage:**
```bash
/rhoai-update                    # Pull latest (preserves current channel)
/rhoai-update 3.4 -c stable-3.4  # Update with explicit channel
```

**Features:** Preserves channel, auto-detects newer component images, forces reinstall if needed.

---

### /rhoai-version

Check installed RHOAI version, CSV, catalog digest, and all component image SHAs.

**Usage:** `/rhoai-version`

---

### /rhoai-uninstall

Completely uninstall RHOAI from an OpenShift cluster.

**Usage:**
```bash
/rhoai-uninstall              # Remove everything (use this before installing ODH)
/rhoai-uninstall graceful     # Graceful then forceful cleanup
/rhoai-uninstall keep-crds    # Keep CRDs
/rhoai-uninstall keep-all     # Keep CRDs and user resources
```

---

### /odh-install

Install Open Data Hub (ODH) nightly on an OpenShift cluster.

**Usage:**
```bash
/odh-install                  # odh-stable-nightly catalog, fast channel (default)
/odh-install channel=fast image=quay.io/opendatahub/opendatahub-operator-catalog:latest
```

**Prerequisite:** No existing ODH **or RHOAI** installation (detected automatically).

**Key differences from RHOAI:**

| | RHOAI | ODH |
|-|-------|-----|
| Package | `rhods-operator` | `opendatahub-operator` |
| Operator namespace | `redhat-ods-operator` | `openshift-operators` |
| App namespace | `redhat-ods-applications` | `opendatahub` |
| Default channel | `stable-3.4` / `beta` | `fast` |
| Nightly tag | `rhoai-3.4` (floating) | `odh-stable-nightly` (floating) |

---

### /odh-update

Update ODH to the latest nightly build.

**Usage:**
```bash
/odh-update                   # Pull latest odh-stable-nightly
/odh-update image=quay.io/opendatahub/opendatahub-operator-catalog:latest
```

**Note:** ODH nightlies typically bump the CSV version daily, so OLM auto-upgrades without a forced reinstall in most cases.

---

### /odh-uninstall

Completely uninstall ODH from an OpenShift cluster.

**Usage:**
```bash
/odh-uninstall              # Remove everything (use this before installing RHOAI)
/odh-uninstall keep-crds    # Keep CRDs
/odh-uninstall keep-all     # Keep CRDs and user resources
```

**Note:** Use the default (no flags) when switching to RHOAI — `keep-crds` or `keep-all` would leave conflicting CRDs.

---

### /odh-pr-tracker

Track whether an ODH pull request has been included in the latest RHOAI build.

**Usage:** `/odh-pr-tracker <pr-number>`

---

### /mirror-images

Mirror all images needed for a complete disconnected RHOAI deployment from a connected cluster to one or more bastion registries. Includes RHOAI operator, all components, and infrastructure services.

**Usage:** `/mirror-images`

**What it does:**

1. Extracts images from connected cluster's CSV relatedImages (all of them, no exclusions by default)
2. Scans all relevant namespaces for running pod images (minio, keycloak, postgres, milvus, vLLM, service mesh, etc.)
3. Captures catalog source images and module architecture images
4. Builds a combined pull secret with source registry and bastion credentials
5. Deploys a mirror pod on the connected cluster (fast AWS-internal transfers)
6. Mirrors all images to each bastion with `--keep-manifest-list=true --filter-by-os=".*"`
7. Tags destinations with `:latest` to prevent Quay tagless manifest GC
8. Verifies every image on each bastion, reports failures by category
9. Generates IDMS (ImageDigestMirrorSet) YAML for the disconnected cluster

**Required inputs:** Bastion registry address(es), bastion credentials. RHOAI version is auto-detected. Optional exclude patterns (empty by default).

---

### /rhoai-disconnected

Install or update RHOAI on a disconnected (air-gapped) OpenShift cluster using a digest-pinned FBC catalog image.

**Usage:**
```bash
/rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:fe1157d5...
/rhoai-disconnected install fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:...
/rhoai-disconnected update fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:...
/rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:... bastion=host:8443 channel=stable-3.4
```

**Required input:** `fbc=<image@sha256:digest>` — the FBC catalog image (must be already mirrored to bastion via `/mirror-images`).

**Optional inputs:** `bastion=<host:port>` (auto-detected from IDMS), `channel=<channel>` (default: `stable-3.4`), `install`/`update` (auto-detected).

**What it does:**

1. Auto-detects install vs update mode and bastion registry from IDMS
2. **Pre-flight verification**: checks that the FBC image and ALL relatedImages exist on the bastion before proceeding
3. Verifies IDMS entries cover all required source registries
4. Creates/updates OLM CatalogSource, namespace, OperatorGroup, and Subscription
5. For updates: forces CSV reinstall to pick up new component images
6. Waits for operator CSV and DataScienceCluster to reach Ready state
7. Post-install health check: detects ImagePullBackOff and CrashLoopBackOff pods
8. Applies known workarounds (podToPodTLS bug, persistenceagent TLS cert)
9. Configures dashboard feature flags (automl, autorag, genAiStudio)

**Prerequisite:** All images mirrored to bastion (use `/mirror-images` on connected cluster first). IDMS configured on disconnected cluster.

---

### /rhoai-verify

Run post-install/update verification tests to confirm all RHOAI components are healthy and functional.

**Usage:**
```bash
/rhoai-verify              # Run all tests (default: full)
/rhoai-verify quick        # Operator + DSC + pod health only
/rhoai-verify full         # All tests including smoke tests
```

**What it checks:**

1. Operator health — CSV phase, subscription state, CatalogSource readiness
2. DataScienceCluster — phase, component conditions
3. Pod health — scans all RHOAI namespaces for ImagePullBackOff, CrashLoopBackOff, not-ready containers
4. Dashboard — deployment readiness, route existence, HTTP response
5. Data Science Pipelines — DSP operator, DSPA health, podToPodTLS status
6. Workbenches — notebook controller, ODH notebook controller, workbench namespace
7. Model Serving — KServe controller, ModelMesh controller, ServingRuntimes, InferenceServices
8. Model Registry — operator readiness, registry namespace
9. TrustyAI / EvalHub — TrustyAI operator, EvalHub namespace/pods/route
10. Dependent operators — service mesh, serverless, pipelines, cert-manager
11. Disconnected checks (auto-detected) — IDMS entries, cluster-wide ImagePullBackOff scan

**Output:** Report at `artifacts/rhoai-manager/reports/verify-[timestamp].md` with PASS/FAIL/WARN summary and troubleshooting guidance.

---

### /use-odh-main

Override specific component images in the RHOAI/ODH operator CSV to use ODH main branch builds for testing.

**Usage:**
```bash
/use-odh-main odh-mod-arch-automl odh-mod-arch-autorag   # Override to main branch
/use-odh-main --list                                      # List all component images
/use-odh-main --tag feature-branch odh-mod-arch-automl    # Use custom tag
/use-odh-main --registry quay.io/myorg odh-mod-arch-automl # Use custom registry
```

**What it does:**

1. Finds the matching `relatedImages` entries and env vars in the operator CSV
2. Patches them to use `quay.io/opendatahub/<component>:main` (or custom registry/tag)
3. Restarts the operator to pick up new env vars
4. Waits for component deployments to reconcile with new images
5. Verifies running pods are pulling the correct images
6. Checks for ImagePullBackOff errors

**Important:** Overrides are **not persistent** — running `/rhoai-update` or `/odh-update` resets all images to catalog versions.

---

## Typical Workflows

### Fresh RHOAI Installation
```
1. /oc-login
2. /rhoai-install
3. /rhoai-verify
```

### Fresh ODH Installation
```
1. /oc-login
2. /odh-install
3. /rhoai-version   # (check via version command — ODH has no dedicated version command yet)
```

### Pull Latest Nightly (RHOAI)
```
1. /oc-login
2. /rhoai-update
3. /rhoai-verify
```

### Pull Latest Nightly (ODH)
```
1. /oc-login
2. /odh-update
```

### Switch from RHOAI to ODH
```
1. /oc-login
2. /rhoai-uninstall          # Standard uninstall (removes CRDs)
3. /odh-install
```

### Switch from ODH to RHOAI
```
1. /oc-login
2. /odh-uninstall            # Standard uninstall (removes CRDs)
3. /rhoai-install
```

### Mirror Images to Disconnected Clusters
```
1. /oc-login           # Connect to the connected cluster
2. /mirror-images      # Mirror all RHOAI + infrastructure images to bastion(s)
```

### Install/Update RHOAI on Disconnected Cluster
```
1. /oc-login                     # Connect to the disconnected cluster
2. /rhoai-disconnected fbc=quay.io/rhoai/rhoai-fbc-fragment@sha256:...
3. /rhoai-verify                 # Verify everything is healthy
```

### Test ODH Main Branch Components on RHOAI
```
1. /oc-login
2. /use-odh-main odh-mod-arch-automl odh-mod-arch-autorag
3. /rhoai-verify         # Verify everything is healthy with new images
```

### Decommission
```
1. /oc-login
2. /rhoai-uninstall   # or /odh-uninstall
```

## Prerequisites

- OpenShift cluster (version 4.12+)
- `oc` CLI installed (auto-installed if missing)
- Cluster credentials configured in Ambient session:
  - `OCP_SERVER` - OpenShift cluster API URL
  - `OCP_USERNAME` - Your OpenShift username
  - `OCP_PASSWORD` - Your OpenShift password
- Cluster admin permissions

## Output Artifacts

All artifacts are stored in `artifacts/rhoai-manager/`:

- `reports/*.md` - Installation and update reports
- `version/*.md` - Version detection summaries
- `logs/*.log` - Detailed execution logs
