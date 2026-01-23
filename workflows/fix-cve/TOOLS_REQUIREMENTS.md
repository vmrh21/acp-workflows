# CVE Fix Workflow - Tools Requirements

This document lists all tools needed to run the CVE Fix Workflow effectively.

## 🔴 Required Tools (Core Functionality)

These tools are **essential** for basic workflow operation:

### 1. Git
**Purpose:** Version control and repository access

**Installation:**
```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get install git

# Windows
# Download from https://git-scm.com/
```

**Verify:**
```bash
git --version
# Expected: git version 2.x.x
```

### 2. GitHub CLI (gh)
**Purpose:** Required for automatic PR creation with `--create-pr` flag

**Installation:**
```bash
# macOS
brew install gh

# Ubuntu/Debian
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Windows
winget install --id GitHub.cli
```

**Setup:**
```bash
gh auth login
# Follow prompts to authenticate
```

**Verify:**
```bash
gh --version
# Expected: gh version 2.x.x
```

### 3. Security Scanner (Choose One or More)

#### Trivy (Recommended - Multi-purpose)
**Purpose:** Scan dependencies, containers, and filesystems for CVEs

**Installation:**
```bash
# macOS
brew install aquasecurity/trivy/trivy

# Ubuntu/Debian
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Windows
# Download from https://github.com/aquasecurity/trivy/releases
```

**Verify:**
```bash
trivy --version
# Expected: Version: 0.x.x
```

**Basic Usage:**
```bash
# Scan filesystem
trivy fs .

# Scan container image
trivy image nginx:latest

# Scan with severity filter
trivy fs . --severity HIGH,CRITICAL
```

## 🟡 Language-Specific Tools

Install based on your project's technology stack:

### Node.js/JavaScript Projects

#### npm
**Purpose:** Dependency management and security auditing

**Installation:**
```bash
# Included with Node.js
# Download from https://nodejs.org/

# Or use nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts
```

**Verify:**
```bash
npm --version
node --version
```

**Security Commands:**
```bash
npm audit                    # Audit dependencies
npm audit --audit-level=high # Only high/critical
npm audit fix                # Auto-fix vulnerabilities
```

### Python Projects

#### pip-audit
**Purpose:** Audit Python dependencies for CVEs

**Installation:**
```bash
pip install pip-audit
```

**Verify:**
```bash
pip-audit --version
```

**Security Commands:**
```bash
pip-audit                    # Audit dependencies
pip-audit --desc             # With descriptions
pip-audit --fix              # Auto-fix vulnerabilities
```

#### safety (Alternative)
```bash
pip install safety
safety check
```

### Java/Maven Projects

#### OWASP Dependency-Check Maven Plugin
**Purpose:** Scan Java dependencies for CVEs

**Setup:** Add to `pom.xml`:
```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>8.4.0</version>
</plugin>
```

**Usage:**
```bash
mvn dependency-check:check
```

### Go Projects

#### govulncheck
**Purpose:** Go vulnerability scanner

**Installation:**
```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
```

**Verify:**
```bash
govulncheck --version
```

**Usage:**
```bash
govulncheck ./...
```

### Ruby Projects

#### bundler-audit
**Purpose:** Audit Ruby gems for CVEs

**Installation:**
```bash
gem install bundler-audit
```

**Usage:**
```bash
bundler-audit check --update
```

### Rust Projects

#### cargo-audit
**Purpose:** Audit Rust crates for CVEs

**Installation:**
```bash
cargo install cargo-audit
```

**Usage:**
```bash
cargo audit
```

## 🟢 Optional Tools (Enhanced Functionality)

These tools provide additional capabilities:

### 1. Grype (Alternative Scanner)
**Purpose:** Advanced vulnerability scanner

**Installation:**
```bash
# macOS
brew tap anchore/grype
brew install grype

# Ubuntu/Debian
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
```

**Usage:**
```bash
grype .
grype nginx:latest
```

### 2. Snyk CLI
**Purpose:** Commercial vulnerability scanner (free tier available)

**Installation:**
```bash
# macOS
brew install snyk/tap/snyk

# npm (all platforms)
npm install -g snyk
```

**Setup:**
```bash
snyk auth
```

**Usage:**
```bash
snyk test                    # Test dependencies
snyk test --docker nginx     # Test container
snyk monitor                 # Continuous monitoring
```

### 3. Docker (for Container Scanning)
**Purpose:** Build and scan container images

**Installation:**
```bash
# macOS
brew install --cask docker

# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Windows
# Download from https://www.docker.com/products/docker-desktop
```

**Verify:**
```bash
docker --version
docker ps
```

### 4. jq (JSON Processor)
**Purpose:** Parse JSON output from scanners

**Installation:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows
# Download from https://stedolan.github.io/jq/
```

**Usage:**
```bash
trivy fs . --format json | jq '.Results'
```

### 5. Testing Frameworks

Install based on your project:

```bash
# Node.js
npm install -g jest
npm install -g mocha

# Python
pip install pytest

# Java
# Maven/Gradle handle this

# Go
# Built into Go toolchain (go test)
```

## 📋 Tool Installation Checklist

Use this checklist to verify your setup:

### Core Tools
- [ ] Git installed and configured
- [ ] GitHub CLI (gh) installed and authenticated
- [ ] At least one security scanner (Trivy recommended)

### Language-Specific (check what applies)
- [ ] **Node.js:** npm/yarn with audit capability
- [ ] **Python:** pip-audit or safety
- [ ] **Java:** Maven/Gradle with dependency-check
- [ ] **Go:** govulncheck
- [ ] **Ruby:** bundler-audit
- [ ] **Rust:** cargo-audit

### Container Tools (if using Docker)
- [ ] Docker installed and running
- [ ] Trivy or Grype for image scanning

### Testing Tools
- [ ] Test framework for your language
- [ ] Linter for your language
- [ ] Build tools (npm, maven, go, etc.)

## 🚀 Quick Setup Scripts

### All-in-One Setup (macOS)
```bash
#!/bin/bash
# install-cve-tools-macos.sh

echo "Installing CVE Fix Workflow tools..."

# Core tools
brew install git gh

# Security scanners
brew install aquasecurity/trivy/trivy
brew tap anchore/grype
brew install grype

# Optional tools
brew install jq
brew install --cask docker

# Language-specific (install as needed)
# Node.js
# brew install node

# Python
# brew install python
# pip3 install pip-audit safety

echo "✅ Core tools installed!"
echo "Authenticate with GitHub:"
echo "  gh auth login"
```

### All-in-One Setup (Ubuntu/Debian)
```bash
#!/bin/bash
# install-cve-tools-ubuntu.sh

echo "Installing CVE Fix Workflow tools..."

# Update package list
sudo apt-get update

# Core tools
sudo apt-get install -y git curl wget

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# jq for JSON processing
sudo apt-get install -y jq

# Docker (optional)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "✅ Core tools installed!"
echo "Authenticate with GitHub:"
echo "  gh auth login"
```

## 🔧 Tool Configuration

### Trivy Configuration
Create `.trivy.yaml` in your project root:

```yaml
# .trivy.yaml
severity: HIGH,CRITICAL
exit-code: 1
format: json
```

### GitHub CLI Configuration
```bash
# Set default editor
gh config set editor vim

# Set default protocol
gh config set git_protocol ssh
```

## 🧪 Verify Installation

Run this script to verify all tools are installed:

```bash
#!/bin/bash
# verify-tools.sh

echo "🔍 Verifying CVE Fix Workflow Tools Installation"
echo "================================================"

# Core tools
echo ""
echo "Core Tools:"
command -v git >/dev/null 2>&1 && echo "✅ Git: $(git --version)" || echo "❌ Git: NOT INSTALLED"
command -v gh >/dev/null 2>&1 && echo "✅ GitHub CLI: $(gh --version | head -n1)" || echo "❌ GitHub CLI: NOT INSTALLED"

# Security scanners
echo ""
echo "Security Scanners:"
command -v trivy >/dev/null 2>&1 && echo "✅ Trivy: $(trivy --version | head -n1)" || echo "⚠️  Trivy: NOT INSTALLED (recommended)"
command -v grype >/dev/null 2>&1 && echo "✅ Grype: $(grype version | head -n1)" || echo "⚠️  Grype: NOT INSTALLED (optional)"
command -v snyk >/dev/null 2>&1 && echo "✅ Snyk: $(snyk --version)" || echo "⚠️  Snyk: NOT INSTALLED (optional)"

# Language-specific
echo ""
echo "Language-Specific Tools:"
command -v npm >/dev/null 2>&1 && echo "✅ npm: $(npm --version)" || echo "⚠️  npm: NOT INSTALLED"
command -v pip >/dev/null 2>&1 && pip show pip-audit >/dev/null 2>&1 && echo "✅ pip-audit: INSTALLED" || echo "⚠️  pip-audit: NOT INSTALLED"
command -v mvn >/dev/null 2>&1 && echo "✅ Maven: $(mvn --version | head -n1)" || echo "⚠️  Maven: NOT INSTALLED"
command -v go >/dev/null 2>&1 && echo "✅ Go: $(go version)" || echo "⚠️  Go: NOT INSTALLED"

# Container tools
echo ""
echo "Container Tools:"
command -v docker >/dev/null 2>&1 && echo "✅ Docker: $(docker --version)" || echo "⚠️  Docker: NOT INSTALLED (for container scanning)"

# Utilities
echo ""
echo "Utilities:"
command -v jq >/dev/null 2>&1 && echo "✅ jq: $(jq --version)" || echo "⚠️  jq: NOT INSTALLED (recommended)"

echo ""
echo "================================================"
echo "Installation verification complete!"
```

## 📊 Tool Comparison

| Tool | Scope | Best For | Cost |
|------|-------|----------|------|
| **Trivy** | Dependencies, containers, filesystems | All-in-one scanning | Free |
| **Grype** | Dependencies, containers | Container-focused | Free |
| **Snyk** | Dependencies, containers, code | CI/CD integration | Free tier + paid |
| **npm audit** | npm packages | Node.js projects | Free |
| **pip-audit** | Python packages | Python projects | Free |
| **OWASP Dependency-Check** | Java dependencies | Java/Maven projects | Free |
| **govulncheck** | Go modules | Go projects | Free |

## 🎯 Minimum Required Setup

For basic workflow functionality:

```bash
# 1. Install Git
brew install git  # or apt-get install git

# 2. Install GitHub CLI (for --create-pr flag)
brew install gh  # or use apt-get
gh auth login

# 3. Install Trivy (recommended scanner)
brew install aquasecurity/trivy/trivy  # or use apt-get

# 4. Install language-specific tools
npm install -g npm  # for Node.js projects
pip install pip-audit  # for Python projects
# etc.
```

**That's it!** You're ready to run the workflow.

## 🆘 Troubleshooting

### "command not found" errors
- Ensure tools are in your PATH
- Restart terminal after installation
- Verify installation with `which <tool-name>`

### Permission denied errors
- Use `sudo` for system-wide installations
- Or use language-specific package managers (npm -g, pip --user)

### GitHub CLI authentication fails
```bash
# Clear existing auth
gh auth logout

# Re-authenticate
gh auth login

# Verify
gh auth status
```

### Trivy database update issues
```bash
# Clear cache and re-download
trivy image --clear-cache
trivy image --download-db-only
```

## 📚 Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [npm audit Documentation](https://docs.npmjs.com/cli/v8/commands/npm-audit)
- [Grype GitHub](https://github.com/anchore/grype)
