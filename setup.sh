#!/bin/bash

set -e

echo "========================================="
echo "  DevOps Automation Script"
echo "  Complete Infrastructure Setup"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# ============================================
# PREREQUISITES CHECK
# ============================================
log_step "Checking prerequisites..."

# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
	log_warn "Running as root is not recommended. Consider running as a regular user."
fi

# Check Terraform
if ! command -v terraform &>/dev/null; then
	log_error "Terraform is not installed. Please install Terraform first."
	exit 1
fi
log_info "Terraform found: $(terraform version | head -1)"

# Check Ansible
if ! command -v ansible-playbook &>/dev/null; then
	log_error "Ansible is not installed. Please install Ansible first."
	exit 1
fi
log_info "Ansible found: $(ansible-playbook --version | head -1)"

# Check Multipass
if ! command -v multipass &>/dev/null; then
	log_error "Multipass is not installed. Please install Multipass first."
	exit 1
fi
log_info "Multipass found: $(multipass version | head -1)"

# Check Docker
if ! command -v docker &>/dev/null; then
	log_error "Docker is not installed. Please install Docker first."
	exit 1
fi
log_info "Docker found: $(docker --version)"

# Check Docker Compose
if ! command -v docker-compose &>/dev/null; then
	log_error "Docker Compose is not installed. Please install Docker Compose first."
	exit 1
fi
log_info "Docker Compose found: $(docker-compose --version)"

# Check SSH key
if [ ! -f ~/.ssh/multipass_devops ]; then
	log_error "SSH key not found at ~/.ssh/multipass_devops"
	log_info "Please create an SSH key with: ssh-keygen -t ed25519 -f ~/.ssh/multipass_devops"
	exit 1
fi
log_info "SSH key found at ~/.ssh/multipass_devops"

log_success "All prerequisites satisfied!"

# ============================================
# STEP 1: Create Environment File
# ============================================
log_step "========================================="
log_step "Step 1: Setting up Environment Variables"
log_step "========================================="

if [ -f .env ]; then
	log_warn ".env file already exists, using existing values"
	source .env
	log_info "Loaded existing environment:"
	log_info "  - VM_IP: $VM_IP"
	log_info "  - APP_PORT: $APP_PORT"
	log_info "  - LOKI_IP: $LOKI_IP"
	log_info "  - LOKI_PORT: $LOKI_PORT"
else
	log_info "Creating .env file with default values..."
	cat >.env <<'EOF'
VM_IP=192.168.2.12
APP_PORT=3000
LOKI_IP=172.18.0.6
LOKI_PORT=3100
EOF
	log_success "Created .env file with default values"
fi

# ============================================
# STEP 2: Provision VM with Terraform
# ============================================
log_step "========================================="
log_step "Step 2: Provisioning VM with Terraform"
log_step "========================================="

log_info "Changing to terraform directory..."
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
	log_info "Initializing Terraform..."
	terraform init
	log_success "Terraform initialized successfully"
else
	log_info "Terraform already initialized"
fi

log_info "Applying Terraform configuration to create VM..."
log_info "This may take a few minutes..."

# Run Terraform apply
terraform apply -auto-approve

log_success "VM provisioned successfully!"

cd ..

# Wait for VM to be fully ready
log_info "Waiting for VM to be ready..."
sleep 15

# Get VM IP
VM_IP=$(multipass list | grep devops-vm | awk '{print $3}' | head -1)

if [ -z "$VM_IP" ]; then
	log_error "Failed to get VM IP address"
	exit 1
fi

log_success "VM is running at IP: $VM_IP"

# ============================================
# STEP 3: Setup SSH Access
# ============================================
log_step "========================================="
log_step "Step 3: Setting up SSH Access"
log_step "========================================="

log_info "Updating known_hosts for VM..."
ssh-keygen -R "$VM_IP" 2>/dev/null || true
ssh-keyscan -H "$VM_IP" >>~/.ssh/known_hosts 2>/dev/null || true
log_success "Known hosts updated"

# Add SSH key to VM
if [ -f ~/.ssh/multipass_devops.pub ]; then
	log_info "Adding SSH public key to VM..."
	multipass exec devops-vm -- sudo bash -c "echo '$(cat ~/.ssh/multipass_devops.pub)' >> /home/ubuntu/.ssh/authorized_keys" 2>/dev/null || true
	log_success "SSH key added to VM"
else
	log_warn "SSH public key not found at ~/.ssh/multipass_devops.pub"
fi

# Test SSH connection
log_info "Testing SSH connection to VM..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$VM_IP "echo 'SSH connection successful'" &>/dev/null; then
	log_success "SSH connection verified"
else
	log_warn "SSH connection test failed - continuing anyway"
fi

# Update inventory.ini with VM IP
log_info "Updating Ansible inventory with VM IP: $VM_IP..."
cat >ansible/inventory.ini <<EOF
[servers]
devops-vm ansible_host=$VM_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/multipass_devops

[servers:vars]
deploy_version=latest-arm64
EOF
log_success "Ansible inventory updated"

# Update .env file with new VM IP
log_info "Updating .env file with new VM IP..."
sed -i.bak "s/^VM_IP=.*/VM_IP=$VM_IP/" .env 2>/dev/null || true
rm -f .env.bak
log_success "Environment file updated"

# Update prometheus.yml with new VM IP
log_info "Updating Prometheus configuration..."
sed -i "s/192.168.2.12:3000/$VM_IP:3000/" prometheus.yml 2>/dev/null || true
log_success "Prometheus configuration updated"

# ============================================
# STEP 4: Deploy Application with Ansible
# ============================================
log_step "========================================="
log_step "Step 4: Deploying Application with Ansible"
log_step "========================================="

log_info "Changing to ansible directory..."
cd ansible

log_info "Running Ansible playbook to deploy application..."
log_info "This may take several minutes..."

# Run Ansible playbook
ansible-playbook -i inventory.ini playbook.yml

cd ..

log_success "Application deployed successfully!"

# Verify application is running
log_info "Verifying application is running..."
sleep 5
if curl -sf "http://$VM_IP:3000/health" >/dev/null 2>&1; then
	log_success "Application is running and healthy at http://$VM_IP:3000"
else
	log_warn "Application health check failed - please verify manually"
fi

# ============================================
# STEP 5: Start Monitoring Stack
# ============================================
log_step "========================================="
log_step "Step 5: Starting Monitoring Stack"
log_step "========================================="

log_info "Starting Docker Compose monitoring stack (Prometheus, Loki, Grafana)..."
docker-compose -f docker-compose.monitoring.yml up -d

log_info "Waiting for services to start..."
sleep 20

# Check if services are running
log_info "Verifying monitoring services..."

if docker ps | grep -q prometheus; then
	log_success "Prometheus is running"
else
	log_warn "Prometheus container not found"
fi

if docker ps | grep -q loki; then
	log_success "Loki is running"
else
	log_warn "Loki container not found"
fi

if docker ps | grep -q grafana; then
	log_success "Grafana is running"
else
	log_warn "Grafana container not found"
fi

# Configure Grafana datasources
log_info "Configuring Grafana datasources..."

# Add Prometheus datasource
log_info "Adding Prometheus datasource to Grafana..."
curl -s -u admin:admin -X POST \
	-H "Content-Type: application/json" \
	-d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus:9090","access":"proxy"}' \
	"http://localhost:3001/api/datasources" >/dev/null 2>&1 || log_warn "Failed to add Prometheus datasource (may already exist)"

# Add Loki datasource
log_info "Adding Loki datasource to Grafana..."
curl -s -u admin:admin -X POST \
	-H "Content-Type: application/json" \
	-d '{"name":"Loki","type":"loki","url":"http://loki:3100","access":"proxy"}' \
	"http://localhost:3001/api/datasources" >/dev/null 2>&1 || log_warn "Failed to add Loki datasource (may already exist)"

log_success "Grafana datasources configured"

# ============================================
# OPEN BROWSERS
# ============================================
log_step "========================================="
log_step "Opening Prometheus and Grafana in browser"
log_step "========================================="

if [[ "$OSTYPE" == "darwin"* ]]; then
	log_info "Opening Prometheus at http://localhost:9090"
	open http://localhost:9090
	log_info "Opening Grafana at http://localhost:3001"
	open http://localhost:3001
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	log_info "Opening Prometheus at http://localhost:9090"
	xdg-open http://localhost:9090 &
	log_info "Opening Grafana at http://localhost:3001"
	xdg-open http://localhost:3001 &
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
	log_info "Opening Prometheus at http://localhost:9090"
	start http://localhost:9090
	log_info "Opening Grafana at http://localhost:3001"
	start http://localhost:3001
fi

# ============================================
# FINAL SUMMARY
# ============================================
echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}All services are now running:${NC}"
echo ""
echo "  Application:"
echo "    - App URL:        http://$VM_IP:3000"
echo "    - Health Check:  http://$VM_IP:3000/health"
echo "    - Metrics:        http://$VM_IP:3000/metrics"
echo ""
echo "  Monitoring:"
echo "    - Prometheus:     http://localhost:9090"
echo "    - Grafana:        http://localhost:3001 (admin/admin)"
echo "    - Loki:           http://localhost:3100"
echo ""
echo -e "${GREEN}Happy monitoring!${NC}"
echo "========================================="
