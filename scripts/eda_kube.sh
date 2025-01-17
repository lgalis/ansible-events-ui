#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

SCRIPTS_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR="${SCRIPTS_DIR}/.."

CMD=${1:-help}
IMAGE=${2:-'eda:latest'}
UI_LOCAL_PORT=${2:-8080}

export DEBUG=${DEBUG:-false}

# import common & logging
source "${SCRIPTS_DIR}"/common/logging.sh
source "${SCRIPTS_DIR}"/common/utils.sh

trap handle_errors ERR

handle_errors() {
  log-err "An error occurred on or around line ${BASH_LINENO[0]}. Unable to continue."
  exit 1
}

# deployment dir
DEPLOY_DIR="${PROJECT_DIR}"/tools/deploy

# minikube namespace
NAMESPACE=${NAMESPACE:-eda-project}

usage() {
    log-info "Usage: $(basename "$0") <command> [command_arg]"
    log-info ""
    log-info "commands:"
    log-info "\t build <image>                 build and push image to minikube"
    log-info "\t deploy <image>                build deployment and deploy to minikube"
    log-info "\t clean                         remove deployment directory and all EDA resource from minikube"
    log-info "\t port-forward-ui <port>        forward local port to Events UI (default: 8080)"
    log-info "\t help                          show usage"
}

help() {
    usage
}

build-deployment() {
  local _image="${1}"

  log-info "Deployment Directory: ${DEPLOY_DIR}/temp"
  log-info "\tIMAGE: ${_image}"

  [ -d "${DEPLOY_DIR}"/temp ] || mkdir "${DEPLOY_DIR}"/temp

  log-debug "kustomize edit set image ansible-events-ui=${_image}"
  cd "${DEPLOY_DIR}"/events-ui
  kustomize edit set image "ansible-events-ui=${_image}"
  cd "${PROJECT_DIR}"
  log-debug "kustomize build ${DEPLOY_DIR} -o ${DEPLOY_DIR}/temp"
  kustomize build "${DEPLOY_DIR}" -o "${DEPLOY_DIR}/temp"
}

build() {
  local _image="${1}"

  log-info "minikube image build . -t ${_image} -f tools/docker/Dockerfile"
  minikube image build . -t "${_image}" -f tools/docker/Dockerfile
}

deploy() {
  local _image="${1}"

  if ! kubectl get ns -o jsonpath='{..name}'| grep "${NAMESPACE}" &> /dev/null; then
    log-debug "kubectl create namespace ${NAMESPACE}"
    kubectl create namespace "${NAMESPACE}"
  fi

  kubectl config set-context --current --namespace="${NAMESPACE}"

  build-deployment "${_image}"

  log-info "deploying eda to ${NAMESPACE}"
  log-debug "kubectl apply -f ${DEPLOY_DIR}/temp"
  kubectl apply -f "${DEPLOY_DIR}"/temp
}

clean-deployment() {
  log-info "cleaning minikube deployment..."
  if kubectl get ns -o jsonpath='{..name}'| grep "${NAMESPACE}" &> /dev/null; then
    log-debug "kubectl delete all -l 'app in (eda-ui, eda-postgres)' -n ${NAMESPACE}"
    kubectl delete all -l 'app in (eda-ui, eda-postgres)' -n "${NAMESPACE}"
  else
    log-warn "${NAMESPACE} does not exist"
  fi

  if [ -d "${DEPLOY_DIR}"/temp ]; then
    log-debug "rm -rf ${DEPLOY_DIR}/temp"
    rm -rf "${DEPLOY_DIR}"/temp
  else
    log-warn "${DEPLOY_DIR}/temp does not exist"
  fi
}

# forward localhost port to pod
port-forward() {
  local _pod_name=${1}
  local _local_port=${2}
  local _pod_port=${3}

  log-info "kubectl port-forward ${_pod_name} ${_local_port}:${_pod_port}"
  kubectl port-forward "${_pod_name}" "${_local_port}":"${_pod_port}"
}

port-forward-ui() {
  local _local_port=${1}
  local _pod_name=$(kubectl get pods --template '{{range .items}}{{.metadata.name}}{{end}}' --selector=app=eda-ui)

  log-debug "kubectl wait --for=condition=Ready pod/${_pod_name} --timeout=120s"
  kubectl wait --for=condition=Ready pod/"${_pod_name}" --timeout=120s

  log-debug "port-forward ${_pod_name} ${_local_port} 8080"
  port-forward "${_pod_name}" "${_local_port}" 8080
}

#
# execute
#
case ${CMD} in
  "build") build "${IMAGE}" ;;
  "clean") clean-deployment ;;
  "deploy") deploy "${IMAGE}" ;;
  "port-forward-ui") port-forward-ui "${UI_LOCAL_PORT}" ;;
  "help") usage ;;
   *) usage ;;
esac
