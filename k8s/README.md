### 🔐 Step 1: Key Pair aur CSR (Certificate Signing Request) Generate Karna
🧠 Yeh kyu kar rahe hain?
Kubernetes me ek naya user add karne ke liye hume us user ke liye key aur certificate banani padti hai. Ye ek tarike ka ID proof hai jise Kubernetes recognize karta hai.

 ### 1) Command:

```
openssl genrsa -out developer.key 2048

```
#### ➡️ Isse ek private key banegi developer.key.

```
openssl req -new -key developer.key -out developer.csr -subj "/CN=developer"
```
#### ➡️ Ab developer.csr file banegi jo Kubernetes ko request bhejegi certificate dene ke liye.


### 📄 Step 2: CSR ko Kubernetes me Submit Karna

#### 🧠 Yeh kyu kar rahe hain?
Aapne developer.csr banaya hai, ab isko Kubernetes me bhejna hoga taaki wo aapko certificate de sake.


### 🔧 CSR file encode karo aur YAML file banao:

```
CSR_CONTENT=$(cat developer.csr | base64 | tr -d '\n')
```
### ➡️ Ye command .csr file ko Base64 me convert karega (Kubernetes me yeh format chahiye hota hai)

```
cat <<EOF > csr_template.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: developer-csr
spec:
  request: $CSR_CONTENT
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```

#### 🔧 Kubernetes me apply karo:
```
kubectl create -f csr_template.yaml
```
#### 🔧 Approve karo:
```
kubectl certificate approve developer-csr
```

#### 🔧 Certificate file nikalo:

```
kubectl get csr developer-csr -o jsonpath='{.status.certificate}' | base64 --decode > developer.crt
```

#### Ab aapke paas teen files hain:

- developer.key (private key)

- developer.csr (request file)

- developer.crt (approved certificate)

## 🧭 Step 3: kubeconfig File Banana (Developer User ke liye)

### 🧠 Yeh kya hai?

#### kubeconfig ek config file hoti hai jisme bataya jata hai:

- kahan par Kubernetes server hai

- kaunsa certificate use karna hai

- kaunsa user login karega


## 🔧 Cluster details dekho:
```
kubectl config view
ls /etc/kubernetes/pki/
```

## 🔧 Kubeconfig banana:

```
kubectl config set-cluster kubernetes \
  --server=https://104.248.28.87:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=developer.kubeconfig

kubectl config set-credentials developer \
  --client-certificate=developer.crt \
  --client-key=developer.key \
  --embed-certs=true \
  --kubeconfig=developer.kubeconfig

kubectl config set-context developer-context \
  --cluster=kubernetes \
  --namespace=default \
  --user=developer \
  --kubeconfig=developer.kubeconfig

kubectl config use-context developer-context --kubeconfig=developer.kubeconfig
```
## 🔍 Verify karo:
```
kubectl --kubeconfig=developer.kubeconfig get pods
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
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-role
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
```
## 🔧 Apply karo:

```
kubectl apply -f developer-cluster-role.yaml
kubectl apply -f developer-role-binding.yaml
```
## ✅ Step 5: Test karo Developer ka Access

```
kubectl --kubeconfig=developer.kubeconfig get pods
kubectl --kubeconfig=developer.kubeconfig run nginx --image=nginx
kubectl --kubeconfig=developer.kubeconfig get pods
```
➡️ Ye sab commands chal gaye to matlab developer user ke paas sahi permission hai.

```
kubectl --kubeconfig=developer.kubeconfig get pods -A
```
➡️ Ye fail hoga kyunki aapne permission sirf default namespace ke liye di hai, all namespaces ke liye nahi.












