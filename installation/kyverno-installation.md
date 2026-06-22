# Kyverno Installation 
This is a document that governs how to install and set up Kyverno on WSL.

# Prerequisites
## 1. WSL Installed  
👉 https://learn.microsoft.com/en-us/windows/wsl/install
## 2. Helm Installed
👉 https://helm.sh/docs/intro/install/
## 3. Kubectl Installed
👉 https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
## 4. MinKube Cluster
👉 [minikube-installation.md](miniKube-installation.md)
> ⚙️ **Version of MiniKube used in this doc**:  
> minikube: v1.38.1

# Install Kyverno using helm
```
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno -n kyverno --create-namespace -f values.yaml

kubectl get pods -n kyverno -w
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-66756fbfdf-pcg5b    1/1     Running   0          60s
kyverno-background-controller-57f7cb7c48-dzrbd   1/1     Running   0          60s
kyverno-cleanup-controller-75c566db9c-zrk97      1/1     Running   0          60s
kyverno-reports-controller-dfdd969cd-bddkt       1/1     Running   0          60s
```
> ⚙️ **Version of Kyverno installed in this doc**:  
> kyverno-3.8.1   v1.18.1
#
#
 🗓️ *Last Updated: 22/06/2026*