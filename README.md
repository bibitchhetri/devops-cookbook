# DevOps Application - Complete Infrastructure & Monitoring Stack

## Project Overview

This project implements a complete DevOps pipeline with infrastructure automation, CI/CD, container orchestration, and comprehensive monitoring (metrics + logs).

---

## What Has Been Accomplished

### 1. Infrastructure (Terraform)
- **Multipass VM** - Creates a local VM named `devops-vm` with 1 CPU, 1GB RAM, 5GB disk
- Uses Ubuntu 24.04 LTS

### 2. Application Deployment (Ansible)
- Installs Docker on the VM
- Pulls multi-arch Docker image from Docker Hub
- Deploys container with health checks
- Exposes port 3000

### 3. CI/CD Pipeline (GitHub Actions)
- Multi-platform Docker builds (ARM64 + AMD64)
- Pushes to Docker Hub (`bibitkunwar/devops-app`)
- Also pushes to GitHub Container Registry (GHCR)
- Supports versioned tags + `latest`

### 4. Application Metrics (Prometheus)
- Added `prom-client` to Node.js app
- Exposes `/metrics` endpoint
- Tracks HTTP request duration & total requests
- Collects Node.js default metrics (CPU, memory, etc.)

### 5. Monitoring Stack (Docker Compose)
- **Prometheus** (port 9090) - Metrics collection
- **Loki** (port 3100) - Log aggregation
- **Promtail** - Docker log collection
- **Grafana** (port 3001) - Visualization

---

## Architecture

```
                        GitHub Repository
                    (CI triggers on push to main)
                                │
                                ▼
                    GitHub Actions (CI/CD)
  - Checkout - Test - Build (multi-arch) - Push to Docker Hub
                                │
                                ▼
                      Local Machine
  +------------------+    +----------------------------------+
  |   Multipass VM   |    |   Docker Compose (Monitoring)    |
  |   devops-vm      |    |   +---------+ +-----+ +--------+ |
  |   192.168.2.8    |    |   |Prometheus| |Loki | |Grafana ||
  |                  |    |   +----+----+ +-+---+ +---+----+ |
  |  +------------+  |    |        |         |        |      |
  |  |devops-app  |<-+----+--------+---------+--------+      |
  |  |:3000       |  |    |         |                        |
  |  |/metrics    |  |    |   +-----+---------+              |
  |  |/health     |  |    |   |  Promtail     |              |
  |  |/users      |  |    |   |(log collector)|              |
  |  +------------+  |    |   +---------------+              |
  +------------------+    +----------------------------------+
```

---

## How to Execute (Step by Step)

### Prerequisites

- Node.js 22+
- Docker + Docker Compose
- Multipass (for local VM)
- Terraform
- Ansible
- SSH key at `~/.ssh/multipass_devops`

### Step 1: Create Environment File

Create a `.env` file in the project root with the following variables:

```bash
# VM Configuration
VM_IP=<your-vm-ip># Your Multipass VM IP (update after provisioning)
APP_PORT=3000             # Application port

# Loki Configuration (optional - for log aggregation)
LOKI_IP=172.18.0.6       # Loki container IP (auto-assigned by Docker)
LOKI_PORT=3100           # Loki port
```

You can also use the provided `update_ip.sh` script after getting the VM IP:

```bash
chmod +x update_ip.sh
./update_ip.sh <your-vm-ip>
```

### Step 2: Start/Provision VM

```bash
cd terraform
terraform init
terraform apply
```

### Step 3: Setup SSH Access

```bash
# Get VM IP
multipass list

# SSH key setup (replace with actual IP from multipass list)
 ssh-keygen -R <your-vm-ip> && ssh-keyscan -H <your-vm-ip> >> ~/.ssh/known_hosts 2>/dev/null

# Add your SSH key to VM
multipass exec devops-vm -- sudo bash -c "echo '$(cat ~/.ssh/multipass_devops.pub)' >> /home/ubuntu/.ssh/authorized_keys"

# Update ip on .env
chmod +x update_ip.sh
./update_ip.sh <your-vm-ip>
```

### Step 4: Deploy Application

```bash
cd ansible
ansible-playbook -i inventory.ini -e "ansible_host=<your-vm-ip>" playbook.yml
```

### Step 5: Start Monitoring Stack

```bash
docker-compose -f docker-compose.monitoring.yml up -d

# Add Prometheus to Grafana
curl -s -u admin:admin -X POST -H "Content-Type: application/json" -d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus:9090","access":"proxy"}' "http://localhost:3001/api/datasources"

# Add Loki to Grafana
curl -s -u admin:admin -X POST -H "Content-Type: application/json" -d '{"name":"Loki","type":"loki","url":"http://loki:3100","access":"proxy"}' "http://localhost:3001/api/datasources"
```

### Step 6: Verify Everything

| Service | URL | Expected |
|---------|-----|----------|
| Health | http://<your-vm-ip>:3000/health | `{"status":"UP"}` |
| Metrics | http://<your-vm-ip>:3000/metrics | Prometheus metrics |
| Prometheus | http://localhost:9090 | Target: `up` |
| Grafana | http://localhost:3001 | Login: admin/admin |
| Loki | http://localhost:3100 | Ready status |

### Step 7: CI/CD (Automatic)

Simply push to main branch:

```bash
git add .
git commit -m "Your changes"
git push origin main
```

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /users` | Returns user list |
| `GET /metrics` | Prometheus metrics |

---

## Monitoring Dashboards

### Prometheus Queries

```promql
# Request duration histogram
http_request_duration_seconds_bucket

# Request count
http_request_total

# Node.js metrics
process_resident_memory_bytes
process_cpu_seconds_total
process_open_fds
```

### Loki Log Queries

```
{container="/devops-app"}
{container=~".*"}
```

---

## Files Overview

| File | Purpose |
|------|---------|
| `terraform/main.tf` | VM provisioning |
| `ansible/playbook.yml` | App deployment |
| `ansible/inventory.ini` | VM connection config |
| `.github/workflows/ci.yml` | CI/CD pipeline |
| `app.js` | Express app with metrics |
| `Dockerfile` | Container definition |
| `docker-compose.monitoring.yml` | Monitoring stack |
| `prometheus.yml` | Prometheus config |
| `loki-config.yml` | Loki config |
| `promtail-config.yml` | Log collector config |
| `.env` | Environment variables |
| `update_ip.sh` | Script to update VM_IP in config files |

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VM_IP` | Multipass VM IP address | `your-vm-ip` |
| `APP_PORT` | Application port | `3000` |
| `LOKI_IP` | Loki container IP | `172.18.0.6` |
| `LOKI_PORT` | Loki port | `3100` |

---

## Next Steps (Optional)

- Add alerts with Alertmanager
- Migrate to Kubernetes
- Add distributed tracing (Jaeger)
- Add application logging (winston)
- Setup SSL/TLS with reverse proxy
