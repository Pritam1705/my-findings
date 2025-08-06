#!/bin/bash

# Check arguments
if [ "$#" -ne 2 ]; then
  echo "❌ Usage: $0 <username> <namespace>"
  exit 1
fi

USERNAME=$1
NAMESPACE=$2

# Check if user directory already exists
if [ -d "$USERNAME" ]; then
  echo "❌ Directory '$USERNAME' already exists. Aborting."
  exit 1
fi

# Check if namespace already exists
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' already exists. Aborting."
  exit 1
fi

# Create directory
mkdir -p "$USERNAME"

echo "✅ Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE"

echo "✅ Creating ServiceAccount: $USERNAME in namespace: $NAMESPACE"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $USERNAME
  namespace: $NAMESPACE
EOF

echo "✅ Creating ClusterRole: ${USERNAME}-admin-role"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${USERNAME}-admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

echo "✅ Creating RoleBinding: ${USERNAME}-admin-binding in namespace: $NAMESPACE"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USERNAME}-admin-binding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $USERNAME
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: ${USERNAME}-admin-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo "✅ Creating Secret: ${USERNAME}-token"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${USERNAME}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: "$USERNAME"
type: kubernetes.io/service-account-token
EOF

echo "⏳ Waiting for token to be created..."
sleep 10

SA_TOKEN=$(kubectl get secret ${USERNAME}-token -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
CA_CERT=$(kubectl get secret ${USERNAME}-token -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')

echo "✅ Creating kubeconfig for user: $USERNAME"
cat <<EOF > "$USERNAME/${USERNAME}.kubeconfig"
apiVersion: v1
kind: Config
clusters:
- name: k8s-cluster
  cluster:
    certificate-authority-data: ${CA_CERT}
    server: https://192.168.10.21:6443
users:
- name: $USERNAME
  user:
    token: ${SA_TOKEN}
contexts:
- name: ${USERNAME}-context
  context:
    cluster: k8s-cluster
    namespace: $NAMESPACE
    user: $USERNAME
current-context: ${USERNAME}-context
EOF

echo "✅ Done! Kubeconfig created at: $USERNAME/${USERNAME}.kubeconfig"
