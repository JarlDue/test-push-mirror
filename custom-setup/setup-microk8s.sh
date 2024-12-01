
#!/bin/bash

# Exit on any error
set -e

# Variables
DASHBOARD_PORT=10443
HELM_VERSION="v3.14.0"

echo "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "Installing MicroK8s..."
sudo snap install microk8s --classic

echo "Adding current user to the microk8s group..."
sudo usermod -aG microk8s $USER

echo "Waiting for MicroK8s to start..."
sudo microk8s status --wait-ready

echo "Enabling essential MicroK8s addons..."
sudo microk8s enable dns storage helm3 dashboard

echo "Verifying enabled addons..."
sudo microk8s status

echo "Installing Helm (if not already installed)..."
if ! command -v helm &> /dev/null; then
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x get_helm.sh
    ./get_helm.sh
    rm -f get_helm.sh
else
    echo "Helm is already installed."
fi

echo "Setting up Kubernetes dashboard port-forwarding..."
# Kill any existing port-forwarding for the dashboard
sudo pkill -f "kubectl port-forward svc/kubernetes-dashboard" || true
# Start port-forwarding in the background
sudo microk8s kubectl port-forward -n kube-system svc/kubernetes-dashboard $DASHBOARD_PORT:443 &
sleep 5

echo "Access the Kubernetes dashboard at: https://localhost:$DASHBOARD_PORT"

echo "Fetching Kubernetes dashboard token..."
sudo microk8s kubectl -n kube-system describe secret $(sudo microk8s kubectl -n kube-system get secret | grep default | awk '{print $1}')

echo "MicroK8s setup is complete! Please log out and log back in to apply group changes."
