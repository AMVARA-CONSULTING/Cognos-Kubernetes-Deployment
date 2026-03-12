# Cognos on Minikube

Step-by-step guide to run IBM Cognos on a local Minikube cluster: start Minikube with Docker, enable ingress, create the Cognos namespace, run PostgreSQL and SMB via Docker Compose, wire external DBs into the cluster, apply SMB storage, deploy Cognos with the deploy script, then use port-forwarding or SSH tunneling to access Cognos and the Minikube dashboard.

---

### Deploy Minikube
```bash
minikube start --driver=docker --memory=32768 --cpus=16 --cni=cilium
```

### Install ingress controller (routing external traffic)
```bash
minikube addons enable ingress
```

### Enable bash completion for kubectl
```bash
sudo apt install bash-completion -y
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

### Set Docker environment for the Minikube cluster
Use this so containers you build run inside the Minikube cluster:
```bash
eval $(minikube docker-env)
```

### List all containers running in the Minikube cluster
```bash
docker ps
```

### Export the following values
```bash
export CP_REPO_USERNAME=your_user_name
export CP_REPO_PASSWORD=your_key_from_ibm
export CP_REPOSITORY=icr.io
export CLUSTER_NAMESPACE=cognos-ns
export VERSION=1.1.1
docker login -u ${CP_REPO_USERNAME} -p ${CP_REPO_PASSWORD} ${CP_REPOSITORY}
```

### Create namespace for Cognos
```bash
kubectl create ns cognos-ns
```

### Set Cognos namespace as the default
```bash
kubectl config set-context minikube --namespace=cognos-ns
```

### Export CLUSTER_NAMESPACE for Cognos
```bash
export CLUSTER_NAMESPACE="${CLUSTER_NAMESPACE:-cognos-ns}"
```

### Deploy databases for Cognos
```bash
docker compose -f docker-compose-postgres.yml up -d
```

### Create Service and Endpoints for databases
So Kubernetes pods can access the databases running on Docker using the Minikube IP:

- Before applying, check the Minikube IP with `minikube ip`
- Update the IP in `postgres-external-endpoints.yaml` under `Endpoints.addresses.ip`

```bash
kubectl apply -f postgres-external-endpoints.yaml
```

### Deploy SMB server for Cognos
Used to store Cognos data (e.g. drivers, logs, etc.):
```bash
docker compose -f docker-compose-smb.yml up -d
```

### Create storage class for SMB server
- By default Cognos uses the SMB storage class
- This makes the Cognos Helm chart use host storage instead of the default Minikube storage class

- install csi-driver-smb so that kubernetes can handle smb storage
```bash
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

helm install csi-driver-smb csi-driver-smb/csi-driver-smb \
  --namespace kube-system
```

```bash
kubectl apply -f smb-storage.yaml
```

### Pull Helm chart from IBM
Once you have access to the IBM Helm repo, pull the chart and store it in the `./ibm-cacc-prod` directory.

### Run script to deploy Cognos
```bash
./deployecabeta-kubectl.sh
```

### Check PV and PVC in the namespace (status should be Bound)
```bash
kubectl get pv -n cognos-ns
kubectl get pvc -n cognos-ns
```

### Check pods in the namespace (status should be Running)
Wait 2–3 minutes for all pods to reach Running state:
```bash
kubectl get pods -n cognos-ns
```

### Port-forward to access Cognos outside the Minikube cluster
```bash
kubectl port-forward -n cognos-ns svc/ca-ingress-lb 9300:9300
```

### Run Minikube dashboard (note the URL and port)
```bash
minikube dashboard --url
```

### SSH tunneling for port 9300 and the Minikube dashboard port
Replace `<username>` and `<ip>` with your SSH user and host. Use the port from the previous `minikube dashboard --url` output (e.g. 40000, change it with the port that you see):
```bash
ssh -L 9300:localhost:9300 -L 40000:localhost:40000 <username>@<ip>
```

