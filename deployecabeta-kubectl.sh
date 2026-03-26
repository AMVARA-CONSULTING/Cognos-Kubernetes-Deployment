#!/bin/bash
# Deploy IBM Cognos Analytics to Minikube
#
# Prerequisites:
#   - Minikube running (minikube status)
#   - Helm installed
#   - IBM API key for icr.io (Tech Preview account 321468)
#
# Usage:
#   export CP_REPO_PASSWORD="your-ibm-api-key"
#   ./deployecabeta-kubectl.sh
#
# If the OCI chart (icr.io/ecabeta/ecachart) is not found, use the local chart:
#   export HELM_CHART_PATH="/root/oc_cognos/ibm-cacc-prod"
#   export CP_REPO_PASSWORD="your-ibm-api-key"
#   ./deployecabeta-kubectl.sh

run() {
  local desc="$1"
  shift
  echo "$desc" >&2
  if "$@"; then
    return 0
  else
    local r=$?
    echo "ERROR: Command failed with exit code $r: $*" >&2
    exit $r
  fi
}

export CP_REPO_USERNAME="${CP_REPO_USERNAME:-iam-user}"
export CP_REPO_PASSWORD="${CP_REPO_PASSWORD:?Set CP_REPO_PASSWORD to your IBM Cloud API key (needed for image pulls). For chart only: set HELM_CHART_PATH to use a local chart and avoid OCI fetch.}"
export CP_REPOSITORY="${CP_REPOSITORY:-icr.io/ecabeta}"
export CLUSTER_NAMESPACE="${CLUSTER_NAMESPACE:-cognos-ns}"
export HELM_CHART_VERSION="${HELM_CHART_VERSION:-2.0.3}"
# Use local chart when set (e.g. PROJECT_ROOT/ibm-cacc-prod) to avoid OCI "not found"
export HELM_CHART_PATH="${HELM_CHART_PATH:-}"
export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Deploying IBM Cognos Analytics to Minikube"
if [ -d "./ibm-cacc-prod" ]; then
  echo "IBM Cognos Analytics chart found in the current directory"
else
  echo "IBM Cognos Analytics chart not found in the current directory"
  echo "Please download the chart from the IBM Cloud Object Storage and place it in the current directory"
  echo "https://cloud.ibm.com/objectstorage/object/ibm-cacc-prod.tgz"
  exit 1
fi

run "Creating namespace ${CLUSTER_NAMESPACE}..." \
  kubectl --kubeconfig="${KUBECONFIG}" create namespace "${CLUSTER_NAMESPACE}" --dry-run=client -o yaml \
  | kubectl --kubeconfig="${KUBECONFIG}" apply -f -

run "Deleting old regcred secret (if exists)..." \
  kubectl --kubeconfig="${KUBECONFIG}" delete secret regcred -n "${CLUSTER_NAMESPACE}" --ignore-not-found

run "Creating registry pull secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret docker-registry regcred \
  --docker-server="icr.io" \
  --docker-username="${CP_REPO_USERNAME}" --docker-password="${CP_REPO_PASSWORD}" \
  -n "${CLUSTER_NAMESPACE}"

run "Deleting existing CA secrets (if any)..." \
  kubectl --kubeconfig="${KUBECONFIG}" delete secret \
  ca-cs-credentials-secret ca-audit-credentials-secret ca-nc-credentials-secret \
  ca-mailserver-credentials-secret ca-ldapbind-credentials-secret \
  -n "${CLUSTER_NAMESPACE}" --ignore-not-found

run "Creating ca-cs-credentials-secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret generic ca-cs-credentials-secret \
  --from-literal=username="postgres" --from-literal=password="postgres123" \
  --type=kubernetes.io/basic-auth -n "${CLUSTER_NAMESPACE}"

run "Creating ca-audit-credentials-secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret generic ca-audit-credentials-secret \
  --from-literal=username="postgres" --from-literal=password="postgres123" \
  --type=kubernetes.io/basic-auth -n "${CLUSTER_NAMESPACE}"

run "Creating ca-nc-credentials-secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret generic ca-nc-credentials-secret \
  --from-literal=username="postgres" --from-literal=password="postgres123" \
  --type=kubernetes.io/basic-auth -n "${CLUSTER_NAMESPACE}"

run "Creating ca-mailserver-credentials-secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret generic ca-mailserver-credentials-secret \
  --from-literal=username="greg.mcdonald@ca.ibm.com" --from-literal=password="A" \
  --type=kubernetes.io/basic-auth -n "${CLUSTER_NAMESPACE}"

run "Creating ca-ldapbind-credentials-secret..." \
  kubectl --kubeconfig="${KUBECONFIG}" create secret generic ca-ldapbind-credentials-secret \
  --from-literal=username="" --from-literal=password="" \
  --type=kubernetes.io/basic-auth -n "${CLUSTER_NAMESPACE}"

OVERRIDE_FILE="/root/oc_cognos/cognos_poc/override-minikube.yaml"

helm upgrade --install ca-instance "./ibm-cacc-prod" --namespace "${CLUSTER_NAMESPACE}" -f "override-minikube.yaml" 


echo ""
echo "Deployment complete. Check pods with:"
echo "  kubectl --kubeconfig=${KUBECONFIG} get pods -n ${CLUSTER_NAMESPACE}"
echo ""
echo "For LoadBalancer access, run 'minikube tunnel' in another terminal, then:"
echo "  kubectl --kubeconfig=${KUBECONFIG} get svc -n ${CLUSTER_NAMESPACE}"
echo ""
echo "Access Cognos at: http://<EXTERNAL-IP>/bi/"
