# Argo CD Image Updater 적용 및 트러블슈팅 기록

## 목적

- `auth`, `flight`, `payment` 서비스의 이미지 태그를 ECR 기준으로 자동 감지하고
- Helm `values.yaml`의 `image.tag`를 Git write-back 방식으로 갱신해
- Argo CD가 자동 동기화하도록 구성하는 것이 목표였다.

## 시작 시점 진단

초기 상태는 아래와 같았다.

- `argocd-image-updater-controller` Deployment / Pod / ServiceAccount는 이미 클러스터에 존재했다.
- `airline-auth`, `airline-flight`, `airline-payment` Argo CD `Application`에는 Image Updater annotation이 이미 들어가 있었다.
- 하지만 실제 Deployment 이미지는 모두 `:latest`였다.
- Image Updater 로그에는 `No ImageUpdater CRs to process`가 찍혔다.

즉, 설치는 되어 있었지만 실제로 처리할 `ImageUpdater` 리소스가 없어서 자동 갱신이 돌지 않는 상태였다.

## 레포에서 수정한 파일

### 1. ImageUpdater CR 추가

파일:

- [image-updater.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/image-updater.yaml)

역할:

- `argocd` 네임스페이스의 `airline-auth`, `airline-flight`, `airline-payment` 애플리케이션을 스캔 대상으로 등록
- 각 `Application`에 이미 있던 annotation 설정을 그대로 사용하도록 `useAnnotations: true` 적용

핵심 내용:

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: airline-services
  namespace: argocd
spec:
  applicationRefs:
    - namePattern: airline-auth
      useAnnotations: true
    - namePattern: airline-flight
      useAnnotations: true
    - namePattern: airline-payment
      useAnnotations: true
```

### 2. ECR 인증 스크립트 수정

파일:

- [values.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/values.yaml)

수정 이유:

- 기존 `auth1.sh`는 `aws ecr get-authorization-token | base64 -d` 결과를 그대로 내보냈다.
- Image Updater는 외부 credential script 결과가 반드시 한 줄의 `<username>:<password>` 형식이어야 한다.
- 로그에서 `invalid script output, must be single line with syntax <username>:<password>` 에러가 발생했다.

변경 내용:

```yaml
authScripts:
  enabled: true
  scripts:
    auth1.sh: |
      #!/bin/sh
      # Argo CD Image Updater expects a single-line "<username>:<password>" value.
      printf 'AWS:%s' "$(aws ecr get-login-password --region ap-northeast-2)"
```

### 3. AWS CLI 캐시용 HOME 경로 지정

파일:

- [values.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/values.yaml)

수정 이유:

- Pod 안에서 `aws sts get-caller-identity` 실행 시 `/app/.aws`에 캐시를 만들려다가 `Read-only file system` 에러가 발생했다.
- 컨테이너의 `HOME`을 writable 경로로 변경해야 했다.

변경 내용:

```yaml
extraEnv:
  - name: HOME
    value: /tmp
```

### 4. Argo CD repo credential을 Secrets Manager + ExternalSecret 방식으로 추가

파일:

- [repo-credentials-external-secret.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/repo-credentials-external-secret.yaml)

구성 목적:

- GitHub 개인 PAT를 사람이 직접 Kubernetes Secret으로 넣지 않기 위해
- AWS Secrets Manager를 소스 오브 트루스로 사용하고
- External Secrets가 Argo CD repository secret을 생성하도록 구성

Secrets Manager secret 형식:

```json
{
  "type": "git",
  "url": "git@github.com:Megazone-Final/airline-eks.git",
  "sshPrivateKey": "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
}
```

### 5. Application repo URL을 HTTPS에서 SSH로 변경

파일:

- [auth-app.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/auth-app.yaml)
- [flight-app.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/flight-app.yaml)
- [payment-app.yaml](/Users/ms/Desktop/workings/MZC_final_project/airline-eks/platform/argocd/payment-app.yaml)

수정 이유:

- 개인 GitHub 비밀번호 / PAT를 Secrets Manager에 저장하는 방식은 피하고 싶었다.
- repo-scoped SSH deploy key를 사용하는 방식이 더 안전하고 운영 의도에 맞았다.
- Argo CD repository secret도 SSH private key 기반으로 생성되므로 `repoURL`도 SSH 형식으로 맞췄다.

변경 전:

```yaml
repoURL: https://github.com/Megazone-Final/airline-eks.git
```

변경 후:

```yaml
repoURL: git@github.com:Megazone-Final/airline-eks.git
```

## AWS / 클러스터에서 직접 수행한 작업

레포 변경과 별개로 아래 작업은 콘솔 또는 `kubectl` / `aws` CLI로 직접 반영했다.

### 1. ImageUpdater CR 적용

- `kubectl apply -f`로 `airline-services` ImageUpdater를 생성

결과:

- `kubectl get imageupdater -n argocd` 에서 `airline-services` 확인
- 로그에서 `Starting image update cycle, considering 3 application(s) for update` 확인

### 2. Image Updater auth script ConfigMap 핫픽스

- `argocd-image-updater-authscripts` ConfigMap의 `auth1.sh`를 새 형식으로 patch
- 이후 `argocd-image-updater-controller` Deployment 재시작

### 3. IRSA 부여

- `argocd-image-updater` ServiceAccount에 `eks.amazonaws.com/role-arn` 연결
- role: `argocd-image-updater-ecr-read`

### 4. VPC Endpoint 정책 수정

#### ECR API endpoint

- 대상: `com.amazonaws.ap-northeast-2.ecr.api`
- 목적: `ecr:GetAuthorizationToken`, `ecr:ListImages`, `ecr:DescribeImages`, `ecr:DescribeRepositories` 등 허용

#### ECR DKR endpoint

- 대상: `com.amazonaws.ap-northeast-2.ecr.dkr`
- 목적: Image Updater가 실제로 `.../v2/.../tags/list` 경로를 사용하면서 `ecr:ListImages`가 차단되던 문제 해결

### 5. Secrets Manager VPC Endpoint 정책 수정

- 대상: `com.amazonaws.ap-northeast-2.secretsmanager`
- 목적: `external-secrets-provider-aws`가 `airline/argocd/github-airline-eks` secret을 읽을 수 있도록 허용

### 6. external-secrets IAM role 권한 추가

- role: `eksctl-eks-an2-airline-main-addon-iamservicea-Role1-6H1VdeF1IWDJ`
- 권한: `secretsmanager:GetSecretValue`, `DescribeSecret`, `ListSecretVersionIds`
- 대상 secret:
  - `airline/service/prod-*`
  - `airline/argocd/github-airline-eks*`

### 7. GitHub Deploy Key 생성 및 등록

- `ssh-keygen -t ed25519 -f /tmp/argocd-airline-eks -N "" -C "argocd-image-updater"`
- 공개키 `/tmp/argocd-airline-eks.pub` 를 GitHub `Megazone-Final/airline-eks` repo의 Deploy Key로 등록
- `Allow write access` 활성화
- 개인키 `/tmp/argocd-airline-eks` 를 Secrets Manager의 `sshPrivateKey` 값으로 저장

## 트러블슈팅 타임라인

### 1. ImageUpdater 리소스 없음

증상:

- `kubectl get imageupdaters -A` 결과 없음
- 로그: `No ImageUpdater CRs to process`

조치:

- `platform/argocd/image-updater.yaml` 추가

결과:

- Image Updater가 `auth`, `flight`, `payment`를 실제 스캔하기 시작함

### 2. ECR 인증 스크립트 출력 형식 오류

증상:

- 로그: `invalid script output, must be single line with syntax <username>:<password>`

원인:

- script 출력 형식이 Image Updater 기대값과 다름

조치:

- `aws ecr get-login-password` 기반 `AWS:<password>` 형식으로 변경

### 3. AWS CLI 캐시 경로 쓰기 실패

증상:

- `/app/.aws` 에 쓰기 시도
- `Read-only file system`

조치:

- `HOME=/tmp` 추가

### 4. IRSA 미설정

증상:

- `Unable to locate credentials`

원인:

- `argocd-image-updater` ServiceAccount에 role annotation 없음

조치:

- IRSA role 연결

### 5. ECR VPC Endpoint 정책 차단

증상:

- 로그: `because no VPC endpoint policy allows the ecr:ListImages action`

원인:

- Image Updater가 ECR 태그 조회 시 endpoint policy에서 `ListImages`가 차단됨

조치:

- `ecr.api`, `ecr.dkr` endpoint 정책 모두 수정

참고:

- 단순 `aws ecr list-images` 성공만으로 끝이 아니었고
- Image Updater는 실제 Docker registry 경로(`.../v2/.../tags/list`)를 사용해 `ecr.dkr` 쪽 정책도 필요했다.

### 6. Argo CD repo credential 미설정

증상:

- 로그: `credentials for 'https://github.com/Megazone-Final/airline-eks.git' are not configured in Argo CD settings`

원인:

- Git write-back용 repository credential이 Argo CD에 없었음
- Application repoURL도 HTTPS 상태였음

조치:

- SSH deploy key 방식으로 전환
- repo credential ExternalSecret 추가
- Application repoURL을 SSH로 변경

### 7. external-secrets가 Secrets Manager secret을 읽지 못함

증상:

- `no VPC endpoint policy allows the secretsmanager:GetSecretValue action`
- 이후 `no identity-based policy allows the secretsmanager:GetSecretValue action`

원인:

- Secrets Manager endpoint 정책 부족
- external-secrets IRSA role IAM 권한 부족

조치:

- Secrets Manager VPC endpoint 정책 수정
- external-secrets role에 secret 읽기 IAM 권한 추가

결과:

- `kubectl describe externalsecret repo-airline-eks -n argocd`
- `Status: Ready=True`
- `Message: secret synced`
- `repo-airline-eks` Secret 생성 확인

## 확인된 동작 결과

Image Updater는 ECR 태그 조회와 후보 선택까지 정상 동작함을 확인했다.

로그에서 확인된 선택 결과:

- `auth` -> `1.0.9`
- `flight` -> `1.0.4`
- `payment` -> `1.0.6`

확인된 로그 예시:

- `Setting new image to .../auth:1.0.9`
- `Setting new image to .../flight:1.0.4`
- `Setting new image to .../payment:1.0.6`
- `Committing 1 parameter update(s) for application ...`

즉 아래 단계들은 정상 확인되었다.

- ImageUpdater CR 인식
- Argo CD Application 스캔
- ECR 태그 조회
- semver 필터링
- 신규 버전 선택
- write-back 시도 시작

## 최종 확인 필요 항목

문제 해결 과정상 거의 마지막 단계까지 확인했지만, 아래 항목은 마지막 로그 기준으로 추가 확인 대상이다.

- Git write-back이 실제로 성공해 `services/*/values.yaml` 의 `image.tag`가 변경되었는지
- Argo CD가 변경된 Git revision을 감지해 실제 Deployment 이미지가 `latest`에서 semver 태그로 변경되었는지
- branch protection이 direct push를 막는 경우, Image Updater push가 거절되지 않는지

권장 확인 명령:

```bash
kubectl logs -n argocd deployment/argocd-image-updater-controller --since=10m | egrep -i 'commit|push|write-back|error|warn'
kubectl get deploy auth -n airline-auth -o jsonpath='{.spec.template.spec.containers[*].image}'; echo
kubectl get deploy flight -n airline-flight -o jsonpath='{.spec.template.spec.containers[*].image}'; echo
kubectl get deploy payment -n airline-payment -o jsonpath='{.spec.template.spec.containers[*].image}'; echo
```

## 요약

이번 작업에서 해결한 핵심 포인트는 아래와 같다.

- 설치만 되어 있고 실제로 동작하지 않던 Image Updater에 `ImageUpdater` CR을 추가했다.
- ECR 인증 스크립트를 Image Updater 기대 형식에 맞게 수정했다.
- IRSA, `HOME=/tmp`, ECR / Secrets Manager VPC endpoint 정책, external-secrets IAM 권한을 모두 정리했다.
- GitHub 개인 비밀번호 / PAT 대신 `SSH deploy key + Secrets Manager + ExternalSecret` 구조로 전환했다.
- Argo CD Application repoURL을 SSH로 통일했다.

결과적으로 `argocd-image-updater`는 ECR에서 새 semver 태그를 읽고, 업데이트 대상 버전을 선택하는 단계까지 정상 진입했다.
