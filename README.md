# MicroK8s DevOps Platform

Ubuntu VM 위에 MicroK8s를 설치하고 DevOps 서비스들을 자동 배포하는 IaC 프로젝트.

- **Terraform** — vSphere에 Ubuntu VM 생성 (선택)
- **Ansible** — MicroK8s 설치 + Helm/Docker-Compose로 서비스 배포

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
├── vsphere-terraform/                 # (선택) VM 생성
│   ├── main.tf                        # vSphere VM 리소스
│   ├── variables.tf                   # VM 스펙, 네트워크, 인증 변수
│   ├── outputs.tf                     # VM IP, inventory 경로 출력
│   ├── ansible.tf                     # Ansible inventory 자동 생성
│   ├── terraform.tfvars.example       # 변수 예시 파일
│   └── templates/
│       └── ansible-inventory.tpl      # inventory 템플릿
└── ansible/                           # MicroK8s + 서비스 배포
    ├── ansible.cfg
    ├── inventory/
    │   └── hosts.ini                  # 수동 inventory (기존 VM용)
    ├── group_vars/
    │   └── all.yml                    # 공통 변수
    ├── playbooks/
    │   ├── site.yml                   # 전체 실행
    │   ├── microk8s.yml               # MicroK8s만
    │   └── apps.yml                   # 서비스만
    └── roles/
        ├── microk8s/                  # MicroK8s 설치 role
        ├── helm-apps/                 # K8s 배포 role (ArgoCD + 인프라)
        │   ├── defaults/main.yml
        │   └── templates/
        │       └── argocd-values.yml.j2
        └── docker-apps/              # Docker-Compose 배포 role
            ├── defaults/main.yml
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
server1 ansible_host=10.100.64.171 ansible_user=ujmoon ansible_ssh_private_key_file=~/.ssh/id_rsa
server2 ansible_host=10.100.64.172 ansible_user=ujmoon ansible_ssh_private_key_file=~/.ssh/id_rsa
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

## Ansible만 직접 실행

```bash
cd ansible

# 전체
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# MicroK8s만 설치
ansible-playbook -i inventory/hosts.ini playbooks/microk8s.yml

# 서비스만 배포
ansible-playbook -i inventory/hosts.ini playbooks/apps.yml

# 특정 서비스만
ansible-playbook -i inventory/hosts.ini playbooks/apps.yml -e "deploy_apps=['nexus']"
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

## 주요 변수 커스터마이징

`ansible/inventory/group_vars/all.yml`에서 변경 가능:

```yaml
microk8s_channel: "1.28/stable"     # MicroK8s 버전
microk8s_addons:                     # 활성화할 addons
  - dns
  - storage
  - ingress
  - helm3
  - rbac
```

`ansible/roles/docker-apps/defaults/main.yml`에서 Docker-Compose 앱 설정:

```yaml
nexus_port: 8081
sonarqube_port: 9000
sonarqube_db_password: "changeme"    # 반드시 변경
keycloak_port: 8080
keycloak_admin_user: "admin"
keycloak_admin_password: "changeme"  # 반드시 변경
n8n_port: 5678
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
                            NFS CSI
                            Ingress
```
