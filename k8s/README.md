### 🔐 Step 1: Key Pair aur CSR (Certificate Signing Request) Generate Karna
🧠 Yeh kyu kar rahe hain?
Kubernetes me ek naya user add karne ke liye hume us user ke liye key aur certificate banani padti hai. Ye ek tarike ka ID proof hai jise Kubernetes recognize karta hai.

 ### 1) Command:

```
openssl genrsa -out aditya.key 2048
```
#### ➡️ Isse ek private key banegi developer.key.

```
openssl req -new -key aditya.key -out aditya.csr -subj "/CN=aditya"
```
#### ➡️ Ab developer.csr file banegi jo Kubernetes ko request bhejegi certificate dene ke liye.


### 📄 Step 2: CSR ko Kubernetes me Submit Karna

#### 🧠 Yeh kyu kar rahe hain?
Aapne developer.csr banaya hai, ab isko Kubernetes me bhejna hoga taaki wo aapko certificate de sake.


### 🔧 CSR file encode karo aur YAML file banao:

```
CSR_CONTENT=$(cat aditya.csr | base64 | tr -d '\n')

```
### ➡️ Phir aditya_csr.yaml file banao:

```
cat <<EOF > aditya_csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: aditya-csr
spec:
  request: $CSR_CONTENT
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

```

#### 🔧 Kubernetes me apply karo:
```
kubectl apply -f aditya_csr.yaml
```
#### 🔧 Approve karo:
```
kubectl certificate approve aditya-csr
```

#### 🔧 Certificate file nikalo:

```
kubectl get csr aditya-csr -o jsonpath='{.status.certificate}' | base64 --decode > aditya.crt
```

#### Ab aapke paas teen files hain:

- developer.key (private key)

- developer.csr (request file)

- developer.crt (approved certificate)

## 🧭 Step 3: kubeconfig File Banana (Developer User ke liye)

### 🧠 Yeh kya hai?

Step 4: aditya ke liye kubeconfig file banao
Ab cluster info ke hisaab se apna kubeconfig banao.

Cluster server ka URL aur CA certificate pata karo:


## 🔧 Cluster details dekho:
```
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
ls /etc/kubernetes/pki/ca.crt

```

## 🔧 Kubeconfig banana:

```
kubectl config set-cluster kubernetes \
  --server=https://<KUBERNETES_API_SERVER>:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true --kubeconfig=aditya.kubeconfig

kubectl config set-credentials aditya \
  --client-certificate=aditya.crt \
  --client-key=aditya.key \
  --embed-certs=true --kubeconfig=aditya.kubeconfig

kubectl config set-context aditya-context \
  --cluster=kubernetes \
  --namespace=adi-testing \
  --user=aditya --kubeconfig=aditya.kubeconfig

kubectl config use-context aditya-context --kubeconfig=aditya.kubeconfig
kubectl create namespace adi-testing

```
## 🔍 Verify karo:
```
kubectl --kubeconfig=aditya.kubeconfig get pods
```
➡️ Agar access deny hua to iska matlab abhi permission nahi di gayi hai.


## 🔑 Step 4: Permissions Dena (RBAC - Role Based Access Control)

### 🧠 Yeh kyu kar rahe hain?

#### Kubernetes me har user ko batana padta hai ki wo kya kya kar sakta hai. Jaise:

- pods dekh sakta hai ya nahi

- create kar sakta hai ya nahi

### 🔧 Role aur Binding banaye
#### developer-cluster-role.yaml

```
cat <<EOF > admin-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: adi-testing
  name: admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

```

```
cat <<EOF > admin-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-role-binding
  namespace: adi-testing
subjects:
- kind: User
  name: aditya
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: admin-role
  apiGroup: rbac.authorization.k8s.io
EOF
```
## 🔧 Apply karo:

```
kubectl apply -f admin-role.yaml
kubectl apply -f admin-role-binding.yaml

```
## ✅ Step 5: Test karo Developer ka Access

```
kubectl --kubeconfig=aditya.kubeconfig get pods -n adi-testing
kubectl --kubeconfig=aditya.kubeconfig run test-nginx --image=nginx -n adi-testing
kubectl --kubeconfig=aditya.kubeconfig get pods -n adi-testing

```
➡️ Ye sab commands chal gaye to matlab developer user ke paas sahi permission hai.

```
kubectl --kubeconfig=developer.kubeconfig get pods -A
```
➡️ Ye fail hoga kyunki aapne permission sirf default namespace ke liye di hai, all namespaces ke liye nahi.

```
kubectl auth can-i get pods --namespace=adi-testing --kubeconfig=aditya.kubeconfig
kubectl auth can-i delete pods --namespace=adi-testing --kubeconfig=aditya.kubeconfig
```










