#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
NAMESPACE="gitea"
GITEA_HELM_REPO="https://dl.gitea.io/charts/"
GITEA_RELEASE_NAME="gitea"
EXTERNAL_REPO_URL="<replace-with-your-github-repo-url>"  # Replace this
EXTERNAL_REPO_TOKEN="<replace-with-your-github-token>"  # Replace this

# Step 1: Install MicroK8s Addons (if not already enabled)
echo "Enabling MicroK8s addons..."
microk8s enable dns storage helm3

# Step 2: Add Gitea Helm Repository
echo "Adding Gitea Helm repository..."
microk8s helm3 repo add gitea-charts $GITEA_HELM_REPO
microk8s helm3 repo update

# Step 3: Install Gitea with Helm
echo "Installing Gitea with Helm..."
microk8s helm3 install $GITEA_RELEASE_NAME gitea-charts/gitea \
    --namespace $NAMESPACE \
    --create-namespace \
    --set postgresql.enabled=false \
    --set sqlite.enabled=true \
    --set redis.enabled=false \
    --set gitea.admin.username=admin \
    --set gitea.admin.password=admin123 \
    --set gitea.admin.email=admin@example.com

# Step 4: Wait for Gitea to Start
echo "Waiting for Gitea to become ready..."
microk8s kubectl wait --for=condition=available deployment/$GITEA_RELEASE_NAME -n $NAMESPACE --timeout=300s

# Step 5: Expose Gitea Service
echo "Exposing Gitea service via port-forwarding..."
microk8s kubectl port-forward svc/$GITEA_RELEASE_NAME-http 3000:3000 -n $NAMESPACE &
sleep 5  # Allow port-forwarding to start

# Step 6: Add Push Mirror to Gitea
echo "Configuring Gitea repository and push mirror..."
curl -X POST -H "Content-Type: application/json" \
     -d '{"name": "kubernetes-files"}' \
     http://admin:admin123@localhost:3000/api/v1/user/repos

curl -X POST -H "Content-Type: application/json" \
     -d '{
         "remote_address": "'"${EXTERNAL_REPO_URL}"'",
         "remote_password": "'"${EXTERNAL_REPO_TOKEN}"'",
         "remote_username": "'"${EXTERNAL_REPO_URL#https://}"'",
         "sync_on_update": true
     }' \
     http://admin:admin123@localhost:3000/api/v1/repos/admin/kubernetes-files/push_mirrors

echo "Setup complete! Gitea is now mirroring to $EXTERNAL_REPO_URL."
