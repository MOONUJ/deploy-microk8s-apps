#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${SCRIPT_DIR}/vsphere-terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

usage() {
  cat <<EOF
Usage: $0 <COMMAND> [OPTIONS]

Commands:
  infra                 Terraform apply (VM 생성 + inventory 자동 생성)
  deploy                Ansible로 MicroK8s + 서비스 배포 (기존 VM 대상)
  deploy --terraform    Terraform VM 생성 후 자동으로 배포까지
  destroy               Terraform destroy (VM 삭제)

Options:
  --apps <app,...>      특정 서비스만 배포 (nexus, sonarqube, argocd, keycloak, n8n)
  --terraform           Terraform으로 생성된 VM 대상 (hosts.terraform.ini 사용)
  -i <inventory>        커스텀 inventory 파일 지정

Examples:
  # 기존 VM에 배포 (hosts.ini 수동 편집 후)
  $0 deploy

  # Terraform으로 VM 생성만
  $0 infra

  # Terraform VM 생성 + 배포까지 한 번에
  $0 deploy --terraform

  # 기존 VM에 특정 서비스만
  $0 deploy --apps nexus

  # 여러 서비스
  $0 deploy --apps nexus,argocd

  # Terraform VM에 특정 서비스만
  $0 deploy --terraform --apps argocd
EOF
}

terraform_apply() {
  echo "==> Creating VMs with Terraform..."
  cd "$TF_DIR"
  terraform init -input=false
  terraform apply -auto-approve
  echo "==> VMs created. Inventory: ansible/inventory/hosts.terraform.ini"
}

ensure_dependencies() {
  echo "==> Checking dependencies..."
  cd "$ANSIBLE_DIR"

  # Ansible collection: kubernetes.core
  if ansible-galaxy collection list kubernetes.core 2>/dev/null | grep -q 'kubernetes.core'; then
    echo "    kubernetes.core collection already installed, skipping."
  else
    echo "    Installing Ansible collection dependencies..."
    ansible-galaxy collection install -r requirements.yml
  fi

  # Python kubernetes client
  if python3 -c "import kubernetes" 2>/dev/null; then
    echo "    Python kubernetes client already installed, skipping."
  else
    echo "    Installing Python kubernetes client..."
    pip install kubernetes
  fi

  # Helm CLI
  if command -v helm &>/dev/null; then
    echo "    Helm CLI already installed, skipping."
  else
    echo "    Installing Helm CLI..."
    brew install helm
  fi
}

ansible_run() {
  local inventory="$1"
  shift
  ensure_dependencies
  echo "==> Running Ansible playbook (inventory: ${inventory})..."
  cd "$ANSIBLE_DIR"
  ansible-playbook -i "$inventory" playbooks/site.yml "$@"
  echo "==> Done."
}

case "${1:-help}" in
  infra)
    terraform_apply
    ;;
  deploy)
    shift
    USE_TF=false
    INVENTORY="inventory/hosts.ini"
    DEPLOY_APPS=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --terraform)
          USE_TF=true
          INVENTORY="inventory/hosts.terraform.ini"
          shift
          ;;
        -i)
          INVENTORY="$2"
          shift 2
          ;;
        --apps)
          DEPLOY_APPS="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    if [[ "$USE_TF" == true ]]; then
      terraform_apply
      echo "==> Waiting 30s for VMs to boot..."
      sleep 30
    fi

    if [[ -n "$DEPLOY_APPS" ]]; then
      # "nexus,argocd" → "['nexus','argocd']"
      APPS_LIST=$(echo "$DEPLOY_APPS" | sed "s/,/','/g" | sed "s/^/['/;s/$/']/" )
      ansible_run "$INVENTORY" -e "deploy_apps=${APPS_LIST}"
    else
      ansible_run "$INVENTORY"
    fi
    ;;
  destroy)
    echo "==> Destroying VMs with Terraform..."
    cd "$TF_DIR"
    terraform destroy -auto-approve
    ;;
  help|*)
    usage
    ;;
esac
