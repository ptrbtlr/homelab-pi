#!/bin/bash
# ======================================================
# K3s Homelab Setup Script (Actual Steps Followed)
# Author: Cian Butler
# ======================================================

set -e  # Stop if any command fails

# --- Helper function for clean output ---
log() {
  echo -e "\n\033[1;32m[INFO]\033[0m $1\n"
}

# --- Update the system and install essentials ---
log "Updating packages and installing basic tools..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl vim git net-tools htop

# --- Install K3s ---
log "Installing K3s (lightweight Kubernetes)..."
curl -sfL https://get.k3s.io | sh -

# --- Wait a bit for K3s to initialize ---
log "Waiting for K3s to start..."
sleep 30

# --- Check cluster status ---
log "Checking K3s service and node status..."
sudo systemctl status k3s --no-pager || true
sudo kubectl get nodes -o wide

# --- Set static IP using Netplan (modern syntax) ---
log "Configuring static IP using Netplan..."
cat <<EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.114/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

sudo netplan apply
log "Static IP set to 192.168.1.114"

# --- Create directory for manifests ---
log "Creating NGINX project directory..."
mkdir -p ~/k3s-projects/nginx
cd ~/k3s-projects/nginx

# --- NGINX Deployment manifest ---
log "Creating nginx-deployment.yaml..."
cat <<EOF > nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# --- NGINX Service manifest ---
log "Creating nginx-service.yaml..."
cat <<EOF > nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# --- Deploy the app ---
log "Deploying NGINX to K3s..."
sudo kubectl apply -f nginx-deployment.yaml
sudo kubectl apply -f nginx-service.yaml

# --- Check results ---
log "Checking running pods and services..."
sudo kubectl get pods -o wide
sudo kubectl get svc

NODE_PORT=$(sudo kubectl get svc nginx-service -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(hostname -I | awk '{print $1}')

log "✅ Deployment successful!"
echo "------------------------------------------------------"
echo "Access NGINX in your browser:"
echo "  👉 http://$NODE_IP:$NODE_PORT"
echo "------------------------------------------------------"

log "Cluster node summary:"
sudo kubectl get nodes
