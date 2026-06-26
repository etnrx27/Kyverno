#!/bin/bash

echo "Copying latest certs from Windows..."
cp /mnt/c/Users/edwar/.minikube/ca.crt /root/.minikube/
cp /mnt/c/Users/edwar/.minikube/profiles/minikube/client.crt /root/.minikube/profiles/minikube/
cp /mnt/c/Users/edwar/.minikube/profiles/minikube/client.key /root/.minikube/profiles/minikube/
chmod 600 /root/.minikube/profiles/minikube/client.key

#echo "Getting current Minikube IP..."
#MINIKUBE_IP=$(grep -A5 '"Nodes"' /mnt/c/Users/edwar/.minikube/profiles/minikube/config.json | grep '"IP"' | cut -d'"' -f4)
#echo "Minikube IP: $MINIKUBE_IP"

#echo "Updating kubeconfig..."
#kubectl config set-cluster minikube \
  #--certificate-authority=/root/.minikube/ca.crt \
  #--server=https://$MINIKUBE_IP:8443

echo "Getting Minikube mapped port..."
MINIKUBE_PORT=$(docker inspect minikube --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "8443/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}')
echo "Minikube Port: $MINIKUBE_PORT"

# Update kubeconfig to use localhost and mapped port
# This is necessary because the Minikube VM is not directly accessible from WSL, but the port is forwarded to localhost.
# Mapped port changes on each start, so we need to extract dynamically and update kubeconfig accordingly.

echo "Updating kubeconfig..."
kubectl config set-cluster minikube \
  --certificate-authority=/root/.minikube/ca.crt \
  --server=https://127.0.0.1:$MINIKUBE_PORT

echo "Testing connection..."
kubectl get nodes