#!/bin/bash
# setup-monitoring.sh
# Install Prometheus + Grafana on a Raspberry Pi running K3s
# **** NOTE: This script assumes you have already downloaded the kube-prometheus-stack-79.0.1.tgz Helm chart file on your local machine (e.g., Mac) ****
# Using the manual Helm chart method so you need to have that downloaded to your local machine first for it to be SCP'd over

set -e

echo "🚀 Starting KubeCraft Homelab - Monitoring Setup"

# 1. Update system
echo "🔄 Updating packages..."
sudo apt update && sudo apt upgrade -y

# 2. Verify K3s is running
echo "🔍 Checking Kubernetes node status..."
sudo kubectl get nodes

# 3. Install Helm (if not already installed)
if ! command -v helm &> /dev/null; then
  echo "📦 Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm already installed"
fi

# 4. Add Prometheus Community repo
echo "📚 Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 5. Create monitoring namespace
echo "📂 Creating 'monitoring' namespace..."
kubectl create namespace monitoring || echo "Namespace already exists."

# 6. (Manual step) The chart was downloaded on your Mac & transferred via SCP
# So we assume the .tgz is already in /home/cian or current directory
CHART_TGZ="kube-prometheus-stack-79.0.1.tgz"
if [ ! -f "$CHART_TGZ" ]; then
  echo "⚠️ $CHART_TGZ not found!"
  echo "Please download it on your Mac and SCP it to this directory:"
  echo "scp kube-prometheus-stack-79.0.1.tgz cian@<pi-ip>:/home/cian/"
  exit 1
fi

# 7. Install the chart locally
echo "📈 Installing kube-prometheus-stack from local file..."
helm install kube-prom "./$CHART_TGZ" -n monitoring

# 8. Wait for pods to come online
echo "⏳ Waiting for monitoring pods..."
kubectl wait --for=condition=ready pod -l release=kube-prom -n monitoring --timeout=180s || true
kubectl get pods -n monitoring

# 9. Expose Grafana via NodePort
echo "🌐 Changing Grafana service to NodePort..."
kubectl patch svc kube-prom-grafana -n monitoring -p '{"spec": {"type": "NodePort"}}'

# 10. Show Grafana access details
echo "🔑 Grafana admin password:"
kubectl get secret -n monitoring kube-prom-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

echo "🌍 Grafana service:"
kubectl get svc -n monitoring | grep grafana

echo "✅ Done! Grafana should now be accessible via:"
echo "👉 http://<your-pi-ip>:<NodePort>"

