# Kyverno101 - The Setup
This is a document that governs how to install Minikube and Kyverno on Windows and WSL

Kyverno is a policy Engine designed for Kubernetes that allows for one to define, enforce, and audit policies using YAML

# Prerequisites
1. Windows  
    1.1 Docker Desktop Installed with WSL Integration Enabled  
    [Docker Desktop → Settings → Resources → WSL Integration → Enable integration with your WSL distro → Apply & Restart]  
    👉 https://docs.docker.com/desktop/setup/install/windows-install/
2. WSL  
    2.1 kubectl  
    2.2 Helm 

# Installation
## Minikube
### 1. Install the application:  
https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download  
> 👉 Installed to C:\Program Files\Kubernetes\Minikube
### 2. Add to PATH Environment
### 3. Start the minikube cluster on Windows
```
minikube start --driver=docker
#--driver=docker is used because default is hyper-v which creates a seperate VM with its own isolated network, making it hard to communicate
# docker desktop needs to be opened first before running this command
```
>⚠️*Warning:*  
>
> Please make sure "Enable integration with your WSL distro" is enabled.    
If not Minikube will not be reachable.
### 4. Copy kube config file from Windows to WSL so that WSL can access it 
```
cp /mnt/c/Users/<YourWindowsUsername>/.kube/config ~/.kube/config
```
### 5. Verify minikube is being used 
```
[root@DESKTOP-1JL50UD .kube]# kubectl config get-contexts
CURRENT   NAME                               CLUSTER                AUTHINFO                         NAMESPACE
          crc-admin                          api-crc-testing:6443   kubeadmin/api-crc-testing:6443   default
          crc-developer                      api-crc-testing:6443   developer/api-crc-testing:6443
          default/localhost:6443/kubeadmin   localhost:6443         kubeadmin/localhost:6443         default
*         minikube                           minikube               minikube                         default
```
>⚠️*Warning:*  
>
> If minikube is not a * use <span style="color: yellow;"><i>kubectl config use-context minikube</i></span>
### 6. Verify if WSL can reach the Minikube cluster
```
[root@DESKTOP-1JL50UD .minikube]# kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   32m   v1.35.1
```
>❌ **When Things Go Wrong**:
>
>🛑 **Error Encountered:** kubeconfig referencing windows path 
> 
>unable to read client-cert /root/.kube/C:\Users\edwar\.minikube\profiles\minikube\client.crt for minikube due to open /root/.kube/C:\Users\edwar\.minikube\profiles\minikube\client.crt: no such file or directory  
>
>unable to read client-key /root/.kube/C:\Users\edwar\.minikube\profiles\minikube\client.key for minikube due to open /root/.kube/C:\Users\edwar\.minikube\profiles\minikube\client.key: no such file or directory  
>
>unable to read certificate-authority /root/.kube/C:\Users\edwar\.minikube\ca.crt for minikube due to open /root/.kube/C:\Users\edwar\.minikube\ca.crt: no such file or directory  
>  
>
>🛑 **Error Encountered:** Connection timeout 
>
>E0615 14:01:06.750707     365 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://192.168.49.2:8443/api?timeout=32s\": dial tcp 192.168.49.2:8443: i/o timeout"

>✅**Fix:**
>
>Copy fix-minikube.sh into notepad on Windows  
>Copy fix-minikube.sh file from Windows to WSL
```
cp /mnt/c/Users/<YourWindowsUsername>/Documents/kyverno/fix-minikube.sh /root/.minikube/
```
>Remove Window line endings 
```
sed -i 's/\r//' /root/.minikube/fix-minikube.sh
```
>Run /root/.minikube/fix-minikube.sh

### fix-minikube.sh: 
```
#!/bin/bash

echo "Copying latest certs from Windows..."
cp /mnt/c/Users/<YourWindowsUsername>/.minikube/ca.crt /root/.minikube/
cp /mnt/c/Users/<YourWindowsUsername>/.minikube/profiles/minikube/client.crt /root/.minikube/profiles/minikube/
cp /mnt/c/Users/<YourWindowsUsername>/.minikube/profiles/minikube/client.key /root/.minikube/profiles/minikube/
chmod 600 /root/.minikube/profiles/minikube/client.key

echo "Getting Minikube mapped port..."
MINIKUBE_PORT=$(docker inspect minikube --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "8443/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}')
echo "Minikube Port: $MINIKUBE_PORT"

# The Docker driver binds Minikube's API server (port 8443) to a random
# localhost port on Windows (e.g. 46497). This port changes every time
# Minikube starts. We extract the current mapped port from Docker and
# update kubeconfig to use 127.0.0.1:<port> instead of Minikube's
# internal IP, which is not directly reachable from WSL.

echo "Updating kubeconfig..."
kubectl config set-cluster minikube \
  --certificate-authority=/root/.minikube/ca.crt \
  --server=https://127.0.0.1:$MINIKUBE_PORT

echo "Testing connection..."
kubectl get nodes
```

## Kyverno
Install Kyverno using helm
```
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno -n kyverno --create-namespace --set replicaCount=1

kubectl get pods -n kyverno -w
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-66756fbfdf-pcg5b    1/1     Running   0          60s
kyverno-background-controller-57f7cb7c48-dzrbd   1/1     Running   0          60s
kyverno-cleanup-controller-75c566db9c-zrk97      1/1     Running   0          60s
kyverno-reports-controller-dfdd969cd-bddkt       1/1     Running   0          60s
```
