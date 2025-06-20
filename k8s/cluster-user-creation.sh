#!/bin/bash

# Simple script to create Kubernetes user (Key, CSR, kubeconfig, RBAC) in a user directory

# Ask for inputs
read -p "Enter username: " USERNAME
read -p "Enter namespace: " NAMESPACE

# Create user directory
USER_DIR="./$USERNAME"
mkdir -p $USER_DIR
cd $USER_DIR

echo "Working inside directory: $(pwd)"

# Step 1: Generate Private Key and CSR
echo "Generating key and CSR for user: $USERNAME ..."
openssl genrsa -out ${USERNAME}.key 2048
openssl req -new -key ${USERNAME}.key -out ${USERNAME}.csr -subj "/CN=${USERNAME}"

# Step 2: Submit CSR to Kubernetes
CSR_CONTENT=$(cat ${USERNAME}.csr | base64 | tr -d '\n')

cat <<EOF > ${USERNAME}_csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}-csr
spec:
  request: ${CSR_CONTENT}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

echo "Submitting CSR to Kubernetes ..."
kubectl apply -f ${USERNAME}_csr.yaml
kubectl certificate approve ${USERNAME}-csr

# Extract certificate
kubectl get csr ${USERNAME}-csr -o jsonpath='{.status.certificate}' | base64 --decode > ${USERNAME}.crt

# Step 3: Generate kubeconfig
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_CERT_PATH="/etc/kubernetes/pki/ca.crt"

echo "Creating kubeconfig for user: $USERNAME ..."
kubectl config set-cluster kubernetes \
  --server=https://192.168.10.21:6443 \
  --certificate-authority=${CA_CERT_PATH} \
  --embed-certs=true --kubeconfig=${USERNAME}.kubeconfig

kubectl config set-credentials ${USERNAME} \
  --client-certificate=${USERNAME}.crt \
  --client-key=${USERNAME}.key \
  --embed-certs=true --kubeconfig=${USERNAME}.kubeconfig

kubectl config set-context ${USERNAME}-context \
  --cluster=kubernetes \
  --namespace=${NAMESPACE} \
  --user=${USERNAME} --kubeconfig=${USERNAME}.kubeconfig

kubectl config use-context ${USERNAME}-context --kubeconfig=${USERNAME}.kubeconfig

# Step 4: Create Namespace (if not exists)
echo "Creating namespace: $NAMESPACE ..."
kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create namespace $NAMESPACE

# Step 5: Create Role
cat <<EOF > ${USERNAME}-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: ${USERNAME}-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

# Step 6: Create RoleBinding
cat <<EOF > ${USERNAME}-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${USERNAME}-role-binding
  namespace: ${NAMESPACE}
subjects:
- kind: User
  name: ${USERNAME}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ${USERNAME}-role
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Applying Role and RoleBinding ..."
kubectl apply -f ${USERNAME}-role.yaml
kubectl apply -f ${USERNAME}-role-binding.yaml

echo " User $USERNAME setup completed!"
echo " All files are in: $USER_DIR"
echo " Kubeconfig file: ${USERNAME}.kubeconfig"
