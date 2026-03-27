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
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Step 1: Create Environment File
log_info "Step 1: Creating Environment File..."

if [ -f .env ]; then
	log_warn ".env already exists, using existing values"
	source .env
else
	cat >.env <<'EOF'
VM_IP=192.168.2.12
APP_PORT=3000
LOKI_IP=172.18.0.6
LOKI_PORT=3100
EOF
	log_info "Created .env file"
fi

# Step 2: Provision VM with Terraform
log_info "Step 2: Provisioning VM with Terraform..."

cd terraform

if [ ! -d ".terraform" ]; then
	log_info "Initializing Terraform..."
	terraform init
fi

log_info "Applying Terraform configuration..."
terraform apply -auto-approve

cd ..

# Wait for VM to be ready
log_info "Waiting for VM to be ready..."
sleep 10

# Get VM IP
VM_IP=$(multipass list | grep devops-vm | awk '{print $3}' | head -1)
log_info "VM IP: $VM_IP"

# Step 3: Setup SSH Access
log_info "Step 3: Setting up SSH Access..."

# Update known hosts
if [ -n "$VM_IP" ]; then
	ssh-keygen -R "$VM_IP" 2>/dev/null || true
	ssh-keyscan -H "$VM_IP" >>~/.ssh/known_hosts 2>/dev/null || true

	# Add SSH key to VM
	if [ -f ~/.ssh/multipass_devops.pub ]; then
		multipass exec devops-vm -- sudo bash -c "echo '$(cat ~/.ssh/multipass_devops.pub)' >> /home/ubuntu/.ssh/authorized_keys" 2>/dev/null || true
		log_info "SSH key added to VM"
	else
		log_warn "SSH public key not found at ~/.ssh/multipass_devops.pub"
	fi
fi

# Update inventory.ini with VM IP
log_info "Updating inventory.ini with VM IP..."
cat >ansible/inventory.ini <<EOF
[servers]
devops-vm ansible_host=$VM_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/multipass_devops

[servers:vars]
deploy_version=latest-arm64
EOF

# Update .env file with new VM IP
log_info "Updating .env file..."
sed -i.bak "s/^VM_IP=.*/VM_IP=$VM_IP/" .env 2>/dev/null || true
rm -f .env.bak

# Step 4: Deploy Application with Ansible
log_info "Step 4: Deploying Application with Ansible..."

cd ansible
ansible-playbook -i inventory.ini playbook.yml
cd ..

# Step 5: Start Monitoring Stack
log_info "Step 5: Starting Monitoring Stack..."

# Get local IP for Prometheus
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

# Update prometheus.yml with correct target IP
log_info "Updating Prometheus configuration..."
sed -i "s/192.168.2.12:3000/$VM_IP:3000/" prometheus.yml

# Start monitoring stack
log_info "Starting Docker Compose monitoring stack..."
docker-compose -f docker-compose.monitoring.yml up -d

# Wait for services to start
log_info "Waiting for services to start..."
sleep 15

# Configure Grafana datasources
log_info "Configuring Grafana datasources..."

# Add Prometheus datasource
curl -s -u admin:admin -X POST \
	-H "Content-Type: application/json" \
	-d '{"name":"Prometheus","type":"prometheus","url":"http://prometheus:9090","access":"proxy"}' \
	"http://localhost:3001/api/datasources" || log_warn "Failed to add Prometheus datasource"

# Add Loki datasource
curl -s -u admin:admin -X POST \
	-H "Content-Type: application/json" \
	-d '{"name":"Loki","type":"loki","url":"http://loki:3100","access":"proxy"}' \
	"http://localhost:3001/api/datasources" || log_warn "Failed to add Loki datasource"

# Open Prometheus and Grafana in default browser
log_info "Opening Prometheus and Grafana in browser..."

if [[ "$OSTYPE" == "darwin"* ]]; then
	open http://localhost:9090
	open http://localhost:3001
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
	xdg-open http://localhost:9090 &
	xdg-open http://localhost:3001 &
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
	start http://localhost:9090
	start http://localhost:3001
fi

# Final verification
echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Services:"
echo "  - App:         http://$VM_IP:3000"
echo "  - App Health:  http://$VM_IP:3000/health"
echo "  - App Metrics: http://$VM_IP:3000/metrics"
echo "  - Prometheus:  http://localhost:9090"
echo "  - Grafana:     http://localhost:3001 (admin/admin)"
echo "  - Loki:        http://localhost:3100"
echo ""
echo "========================================="
