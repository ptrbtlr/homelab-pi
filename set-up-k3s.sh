#!/bin/bash
# ======================================================
# K3s Single-Node Kubernetes Setup Script for Ubuntu
# Author: Cian Butler
# ======================================================

set -e  # Exit immediately if a command exits with a non-zero status.

# --- Helper function for styled output ---
function log() {
  echo -e "\n\033[1;32m[INFO]\033[0m $1\n"
}

# --- Update system ---
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# --- Install essentials ---
log "Installing required tools (curl, vim, git, net-tools, htop)..."
sudo apt install -y curl vim git net-tools htop

# --- Install K3s ---
log "Installing K3s (lightweight Kubernetes)..."
curl -sfL https://get.k3s.io | sh -

# --- Wait for services to start ---
log "Waiting for K3s to initialize..."
sleep 30

# --- Verify K3s status ---
log "Checking K3s service status..."
sudo systemctl status k3s --no-pager

# --- Check node readiness ---
log "Verifying Kubernetes node..."
sudo kubectl get nodes -o wide

# --- Deploy a test NGINX app ---
log "Deploying test NGINX application..."
sudo kubectl create deployment nginx --image=nginx

# --- Expose NGINX via NodePort ---
log "Exposing NGINX on port 80 via NodePort..."
sudo kubectl expose deployment nginx --type=NodePort --port=80

# --- Wait for deployment to stabilize ---
sleep 10
sudo kubectl get pods -o wide

# --- Display service info ---
log "Fetching NGINX service info..."
sudo kubectl get svc nginx

# --- Extract NodePort automatically ---
NODE_PORT=$(sudo kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(hostname -I | awk '{print $1}')

log "✅ K3s cluster setup complete!"
echo "------------------------------------------------------"
echo "Kubernetes Node:    $NODE_IP"
echo "NGINX Access URL:   http://$NODE_IP:$NODE_PORT"
echo "------------------------------------------------------"

# --- Optional: show quick cluster summary ---
log "Cluster Summary:"
sudo kubectl get nodes
sudo kubectl get pods -A

log "Done! Your single-node K3s cluster is live. ☸️"

