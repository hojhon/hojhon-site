# Hojhon Portfolio Site

A secure, containerized portfolio website with automated CI/CD pipeline featuring security scanning and vulnerability management.

## 🚀 CI/CD Pipeline

This repository uses GitHub Actions for automated build, security scanning, and deployment:

### Workflow: Build, Scan & Push
**Trigger:** Manual dispatch (`workflow_dispatch`)  
**File:** `.github/workflows/build-scan-push.yml`

#### Pipeline Stages:
1. **Build** - Creates Docker image with embedded Formspree configuration
2. **Code Scan** - Semgrep static analysis for code vulnerabilities  
3. **Container Scan** - Trivy security scan for container vulnerabilities
4. **Security Evaluation** - Fails pipeline on critical/high vulnerabilities
5. **Push** - Pushes secure images to Docker registry (only if scans pass)

### CI/CD Pipeline

```mermaid
graph LR
    A[Trigger] --> B[Checkout] --> C[Build]
    C --> D[Semgrep Scan]
    C --> E[Trivy Scan]
    D --> F{Security Gate}
    E --> F
    F -->|Pass| G[Push Image]
    F -->|Fail| H[Fail]
    
    style F fill:#ff6b6b,stroke:#ffffff,stroke-width:2px,color:#ffffff
    style G fill:#96ceb4,stroke:#ffffff,stroke-width:2px,color:#ffffff
    style H fill:#ff6b6b,stroke:#ffffff,stroke-width:2px,color:#ffffff
```

### Deployment Architecture

```mermaid
graph LR
    subgraph "GitHub"
        A[Developer] --> B[Push Code] --> C[GitHub Actions] --> D[Docker Registry]
    end
    
    subgraph "Proxmox Infrastructure"
        E[ArgoCD] --> F[K8s Services] --> G[Portfolio Pod]
    end
    
    subgraph "Cloudflare"
        H[Zero Trust Tunnel] --> I[Public Access]
    end
    
    D --> E
    G --> H
    
    style C fill:#45b7d1,stroke:#ffffff,stroke-width:2px,color:#ffffff
    style E fill:#ff9800,stroke:#ffffff,stroke-width:2px,color:#ffffff
    style G fill:#4caf50,stroke:#ffffff,stroke-width:2px,color:#ffffff
    style H fill:#ff6b35,stroke:#ffffff,stroke-width:2px,color:#ffffff
```

#### Security Gate Details:
- **Pass Criteria:** 0 Critical + 0 High vulnerabilities
- **Fail Criteria:** Any Critical or High vulnerabilities detected  
- **Reporting:** Detailed scan results in GitHub Actions summary

#### Security Thresholds:
- **Critical vulnerabilities:** `0` (fails pipeline)
- **High vulnerabilities:** `0` (fails pipeline)  
- **Medium/Low:** Allowed (with warnings)

### Required GitHub Secrets
Configure these in your repository settings under **Settings > Secrets > Actions**:

| Secret | Description | Example |
|--------|-------------|---------|
| `DOCKER_REGISTRY` | Docker registry URL | `docker.io` |
| `DOCKER_REPOSITORY` | Full repository path | `pxpucho/hojhon-site` |
| `DOCKER_USERNAME` | Registry username | `pxpucho` |
| `DOCKER_PASSWORD` | Registry access token | `dckr_pat_xxx...` |
| `FORMSPREE_FORM_ID` | Contact form endpoint ID | `xanpozrj` |

### Environment Configuration
The pipeline uses the **`hojhon-site`** GitHub Environment for secure secret management.

## 🏗️ Architecture

### Infrastructure Stack
- **Hypervisor**: Proxmox VE for virtualization
- **Container Platform**: Kubernetes cluster on Proxmox VMs
- **GitOps**: ArgoCD for automated deployments
- **Security**: Cloudflare Zero Trust tunnels for secure access
- **CI/CD**: GitHub Actions with security scanning

### Deployment Flow
1. **Code Push** → GitHub Actions triggers build and security scans
2. **Image Registry** → Secure images pushed to Docker registry
3. **ArgoCD Sync** → Monitors registry and deploys to Kubernetes
4. **Cloudflare Tunnel** → Exposes application securely without port forwarding
5. **Zero Trust Access** → Users access via secure Cloudflare tunnel

### Multi-Stage Docker Build
- **Stage 1:** Build preparation with Formspree URL injection
- **Stage 2:** Production nginx:alpine3.20 with security hardening
- **Security Features:**
  - Non-root user execution (nginx-app:1001)
  - Non-privileged port (8080)
  - Updated packages with vulnerability patches
  - Custom nginx configuration for security headers

### Runtime Configuration
The contact form is configured at **build time** using the `FORMSPREE_FORM_ID` secret, eliminating the need for runtime environment variables and keeping sensitive data out of source control.

## 🔧 Local Development

### Pull and Run
```bash
# Pull the latest secure image
docker pull docker.io/pxpucho/hojhon-site:latest

# Run locally
docker run --rm -p 8080:8080 docker.io/pxpucho/hojhon-site:latest

# Access the site
open http://localhost:8080
```

### Build Locally
```bash
# Build with Formspree configuration
docker build --build-arg FORMSPREE_FORM_ID=your_form_id -t hojhon-site:local .

# Run local build
docker run --rm -p 8080:8080 hojhon-site:local
```

## 🛡️ Security Features

- **Vulnerability Scanning:** Trivy container security scanning
- **Code Analysis:** Semgrep static code analysis  
- **Base Image:** Regularly updated Alpine Linux with security patches
- **Container Hardening:** Non-root execution, minimal attack surface
- **Secret Management:** Build-time injection prevents runtime secret exposure

## 📈 Monitoring

The pipeline generates detailed security reports and fails fast on security violations:
- **Build Summary:** Security scan results in GitHub Actions summary
- **Vulnerability Reports:** Detailed findings for any detected issues
- **Deployment Gates:** Automatic blocking of vulnerable images

## 🚀 Production Features

### Current Implementation
- **GitOps Deployment**: ArgoCD manages Kubernetes deployments
- **Self-Hosted Infrastructure**: Running on Proxmox home lab
- **Zero Trust Security**: Cloudflare tunnels eliminate need for port forwarding
- **Automated CI/CD**: Security-first pipeline with vulnerability gates
- **Container Security**: Multi-stage builds with non-root execution

### Infrastructure Benefits
- **No Public IPs**: Cloudflare tunnels provide secure external access
- **Automated Deployments**: ArgoCD watches for image updates
- **High Availability**: Kubernetes provides container orchestration
- **Security First**: Multiple scanning layers before deployment
- **Cost Effective**: Self-hosted on Proxmox infrastructure
