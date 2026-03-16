# MicroK8s DevOps Platform

Ubuntu VM 위에 MicroK8s를 설치하고 DevOps 서비스들을 자동 배포하는 IaC 프로젝트.

- **Terraform** — vSphere에 Ubuntu VM 생성 (선택)
- **Ansible** — MicroK8s 설치 + Helm/Docker-Compose로 서비스 배포
- **GitHub Actions** — CI (Lint/Validate) + CD (수동 배포)

## 배포되는 서비스

| 서비스 | 용도 | 배포 방식 |
|--------|------|-----------|
| **ArgoCD** | GitOps CD | K8s (Helm) |
| **Nexus** | Artifact Repository | Docker-Compose |
| **SonarQube** | 코드 정적 분석 | Docker-Compose |
| **Keycloak** | SSO / 인증 | Docker-Compose |
| **n8n** | Workflow Automation | Docker-Compose |

**인프라 컴포넌트** (K8s): MetalLB, NFS CSI Driver, Ingress-NGINX

## 프로젝트 구조

```
├── deploy.sh                          # 통합 실행 스크립트
├── .github/workflows/
│   ├── ci.yml                         # CI: Lint & Validate (push/PR 자동)
│   ├── cd-deploy.yml                  # CD: Ansible 배포 (수동 트리거)
│   └── cd-infra.yml                   # CD: Terraform + Ansible (수동 트리거)
├── vsphere-terraform/                 # (선택) VM 생성
│   ├── main.tf                        # vSphere VM 리소스 + cloud-init
│   ├── variables.tf                   # VM 스펙, 네트워크, 인증 변수
│   ├── outputs.tf                     # VM IP, inventory 경로 출력
│   ├── ansible.tf                     # Ansible inventory 자동 생성
│   └── terraform.tfvars.example       # 변수 예시 파일
└── ansible/                           # MicroK8s + 서비스 배포
    ├── ansible.cfg
    ├── requirements.yml               # Ansible Galaxy 의존성
    ├── inventory/
    │   ├── hosts.ini                  # 수동 inventory (기존 VM용)
    │   └── group_vars/
    │       └── all.yml                # 공통 변수 (계정, 포트, 네트워크 등)
    ├── playbooks/
    │   └── site.yml                   # 전체 실행
    └── roles/
        ├── microk8s/                  # MicroK8s 설치 role
        ├── helm-apps/                 # K8s 배포 role (ArgoCD + 인프라)
        │   ├── defaults/main.yml
        │   └── templates/
        │       └── argocd-values.yml.j2
        └── docker-apps/              # Docker-Compose 배포 role
            ├── defaults/main.yml
            ├── tasks/
            │   ├── main.yml
            │   ├── post-setup-nexus.yml
            │   └── post-setup-sonarqube.yml
            └── templates/
                ├── nexus-compose.yml.j2
                ├── sonarqube-compose.yml.j2
                ├── keycloak-compose.yml.j2
                └── n8n-compose.yml.j2
```

## 사전 요구사항

- Ansible 2.9+
- 대상 서버: Ubuntu 22.04/24.04, SSH 접속 가능, sudo 권한
- (선택) Terraform 1.0+, vSphere 환경

## 사용법

### 기존 VM이 있는 경우

inventory 파일을 편집하고 바로 배포합니다.

```bash
# 1) inventory 편집 — 서버 IP, 사용자, SSH 키 입력
vi ansible/inventory/hosts.ini
```

```ini
[microk8s]
server1 ansible_host=10.100.64.171 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

```bash
# 2) 전체 배포 (MicroK8s + ArgoCD + Docker-Compose 앱)
./deploy.sh deploy

# 특정 서비스만 배포
./deploy.sh deploy --apps nexus              # docker-compose 앱
./deploy.sh deploy --apps argocd             # K8s 앱
./deploy.sh deploy --apps nexus,sonarqube    # 여러 앱
```

### VM이 없는 경우 (Terraform으로 생성)

```bash
# 1) Terraform 변수 설정
cd vsphere-terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars    # vSphere 인증, VM 스펙, IP 등 수정

# 2) VM 생성만
./deploy.sh infra

# 3) VM 생성 + 배포 한 번에
./deploy.sh deploy --terraform

# 4) VM 생성 + 특정 서비스만
./deploy.sh deploy --terraform --apps sonarqube
```

### VM 삭제

```bash
./deploy.sh destroy
```

## deploy.sh 명령어 요약

| 명령어 | 설명 |
|--------|------|
| `./deploy.sh deploy` | 기존 VM에 배포 (`hosts.ini` 사용) |
| `./deploy.sh deploy --terraform` | VM 생성 후 배포 (`hosts.terraform.ini` 자동 생성) |
| `./deploy.sh deploy --apps <app>` | 특정 서비스만 배포 |
| `./deploy.sh deploy -i <path>` | 커스텀 inventory 파일 사용 |
| `./deploy.sh infra` | Terraform VM 생성만 |
| `./deploy.sh destroy` | Terraform VM 삭제 |

## GitHub Actions (CI/CD)

### CI — 자동 실행

push/PR 시 자동으로 코드 검증이 실행됩니다.

| 검증 항목 | 도구 | 대상 |
|-----------|------|------|
| Shell 스크립트 | ShellCheck | `deploy.sh` |
| YAML 문법 | yamllint | `ansible/` |
| Ansible 품질 | ansible-lint | playbooks, roles |
| Terraform 문법 | terraform fmt/validate | `vsphere-terraform/` |

### CD — 수동 실행

GitHub Actions 탭에서 **Run workflow** 버튼으로 실행합니다.

| 워크플로우 | 용도 | Environment | Runner |
|-----------|------|-------------|--------|
| **CD - Deploy (Ansible)** | 기존 VM에 앱 배포 | `production` | self-hosted |
| **CD - Infrastructure (Terraform)** | VM 생성/삭제 ± 배포 | `infrastructure` | self-hosted |

#### CD - Deploy 입력값

- **apps**: 배포할 앱 (콤마 구분, 비우면 전체)

#### CD - Infrastructure 입력값

- **action**: `create-and-deploy` / `create-only` / `destroy`
- **apps**: 배포할 앱 (create-and-deploy 시에만 적용)

### Self-Hosted Runner 설정

CD 워크플로우는 vSphere/대상 VM에 네트워크 접근이 가능한 self-hosted runner가 필요합니다.

```bash
# Runner 머신에 필요한 패키지
sudo apt install -y python3 python3-pip git curl jq sshpass

# GitHub Settings > Actions > Runners > New self-hosted runner 의 안내를 따라 설치
```

### GitHub Secrets 설정

Repository > Settings > Secrets and variables > Actions 에서 설정합니다.

**CD - Deploy 필수:**

| Secret | 설명 |
|--------|------|
| `TARGET_HOST` | 대상 VM IP |
| `VM_USER` | SSH 접속 사용자명 |
| `VM_PASSWORD` | SSH 접속 비밀번호 |
| `NEXUS_ADMIN_PASSWORD` | Nexus 관리자 비밀번호 |
| `SONARQUBE_DB_PASSWORD` | SonarQube DB 비밀번호 |
| `SONARQUBE_ADMIN_PASSWORD` | SonarQube 관리자 비밀번호 |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak 관리자 비밀번호 |
| `N8N_ADMIN_PASSWORD` | n8n 관리자 비밀번호 |

**CD - Infrastructure 추가:**

| Secret | 설명 |
|--------|------|
| `VSPHERE_USER` | vSphere 사용자 |
| `VSPHERE_PASSWORD` | vSphere 비밀번호 |
| `VSPHERE_SERVER` | vCenter 주소 |
| `SSH_PUBLIC_KEY` | VM에 주입할 SSH 공개키 |

## 초기 계정 설정

모든 앱의 초기 계정은 `ansible/inventory/group_vars/all.yml`에서 설정합니다.

### 환경변수 방식 (컨테이너 생성 시 적용)

| App | User 변수 | Password 변수 |
|-----|-----------|---------------|
| **Keycloak** | `keycloak_admin_user` | `keycloak_admin_password` |
| **n8n** | `n8n_admin_email` | `n8n_admin_password` |

### Post-setup 방식 (배포 후 API로 자동 변경)

| App | User | Password 변수 | 비고 |
|-----|------|---------------|------|
| **Nexus** | `admin` (고정) | `nexus_admin_password` | 초기 비밀번호 파일 읽어서 API로 변경 |
| **SonarQube** | `admin` (고정) | `sonarqube_admin_password` | 기본 `admin/admin`에서 API로 변경 (12자 이상 필요) |

### K8s 앱

| App | User | Password 확인 방법 |
|-----|------|--------------------|
| **ArgoCD** | `admin` | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |

### 설정 예시 (group_vars/all.yml)

```yaml
# Keycloak
keycloak_admin_user: "admin"
keycloak_admin_password: "changeme"

# Nexus
nexus_admin_password: "changeme"

# SonarQube (12자 이상 필요)
sonarqube_admin_password: "Admin@gooddi123"

# n8n
n8n_admin_email: "admin@gooddi.lab"
n8n_admin_password: "changeme"
```

## 멱등성 (Idempotent)

`deploy.sh deploy`를 여러 번 실행해도 안전합니다:

- **의존성 설치**: 이미 설치된 경우 스킵 (ansible-galaxy, helm, pip)
- **MicroK8s**: 이미 설치/실행 중이면 스킵, not running이면 자동 start
- **MicroK8s addons**: 이미 활성화된 addon은 스킵
- **Helm charts**: 변경사항 없으면 스킵
- **Docker-Compose**: `docker compose up -d`로 변경분만 반영
- **Post-setup**: 이미 비밀번호가 변경되었으면 스킵 (API 인증 체크)

## Ansible만 직접 실행

```bash
cd ansible

# 전체
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 특정 서비스만
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -e "deploy_apps=['nexus']"
```

## 상태 확인

```bash
# Docker-Compose 앱 확인
ssh <server> "docker compose -f /opt/nexus/docker-compose.yml ps"
ssh <server> "docker compose -f /opt/sonarqube/docker-compose.yml ps"

# K8s 앱 확인
kubectl --kubeconfig ansible/kubeconfig get pods -n argocd
```

## MetalLB + Ingress

MetalLB를 Helm으로 설치하여 LoadBalancer 타입 서비스를 지원하고, 호스트명 기반 Ingress 라우팅을 구성합니다.

`ansible/inventory/group_vars/all.yml`에서 설정:

```yaml
# MetalLB
enable_metallb: true
metallb_ip_range: "10.100.64.174-10.100.64.179"

# Ingress
ingress_domain: "gooddi.lab"
enable_ingress: true
```

ArgoCD는 `argocd.{{ ingress_domain }}` 형식의 호스트명을 사용합니다 (예: `argocd.gooddi.lab`).

## VM 스펙 (Terraform)

`vsphere-terraform/terraform.tfvars`에서 설정:

```hcl
vm_name_prefix = "ujmoon"
vm_count       = 1
num_cpus       = 8
memory         = 16384
disk_size      = 300      # GB, cloud-init으로 자동 파티션 확장
```

## 아키텍처

```
                    deploy.sh
                   ┌────┴────┐
                   │         │
            (선택) Terraform  Ansible
                   │         │
            vSphere VM   ┌───┼───────────┐
            생성 + SSH    │   │           │
            대기       microk8s helm-apps docker-apps
                      role    role       role
                       │       │           │
                  snap install │       docker compose up
                  + addons     │      ┌──┼──┬──┐
                            ArgoCD  Nexus │ Keycloak
                            MetalLB  Sonar   n8n
                            NFS CSI    │
                            Ingress  post-setup
                                    (API로 초기 계정 설정)
```

## CI/CD 아키텍처

```
  GitHub Repository
        │
  ┌─────┼──────────────┐
  │     │              │
push/PR │         Run workflow (수동)
  │     │         ┌────┴────┐
  ▼     │         ▼         ▼
ci.yml  │   cd-deploy.yml  cd-infra.yml
(lint)  │   (Ansible)      (Terraform±Ansible)
  │     │         │              │
GitHub  │    self-hosted    self-hosted
hosted  │      runner        runner
runner  │         │              │
        │    ┌────┴────┐    ┌───┴───┐
        │    │ sshpass  │    │  TF   │
        │    │ ansible  │    │ apply │
        │    │ deploy   │    │   +   │
        │    └────┬────┘    │ansible│
        │         │         └───┬───┘
        │         ▼             ▼
        │      Target VM     vSphere
        │     (password SSH)  + VM
        │
  ShellCheck / yamllint
  ansible-lint / tf validate
```
