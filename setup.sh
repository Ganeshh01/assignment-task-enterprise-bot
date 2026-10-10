#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE_NAME="demo"
IMAGE_NAME="demo-service"
IMAGE_TAG="v1.0.0"

echo "==> [1/4] Checking/Creating kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster '${CLUSTER_NAME}' already exists."
else
  cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    apiVersion: kubeadm.k8s.io/v1beta3
    kind: ClusterConfiguration
    metadata:
      name: config
    apiServer:
      extraArgs:
        enable-admission-plugins: NodeRestriction
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
fi

echo "==> [2/4] Installing ingress-nginx controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml 2>/dev/null || true

echo "==> [3/4] Building Docker image and loading into kind cluster..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" ./service
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "${CLUSTER_NAME}"

echo "==> [4/4] Installing/upgrading Helm release '${RELEASE_NAME}' into namespace '${NAMESPACE}'..."
helm upgrade --install "${RELEASE_NAME}" ./chart \
  --namespace "${NAMESPACE}" \
  --create-namespace

echo "==> Setup completed successfully!"
