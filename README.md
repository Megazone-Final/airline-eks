# airline-eks

`airline-eks`는 Amazon EKS 환경에서 항공 서비스들을 운영하기 위한 Kubernetes 매니페스트와 운영 보조 자산을 담고 있습니다.

## 목적

이 저장소는 다음 항목의 매니페스트 계층입니다.

- 서비스별 Deployment, Service, HPA
- 공용 Ingress
- Namespace 초기 구성
- Karpenter 관련 설정
- 클러스터 부트스트랩 참고 파일
- k6 부하 테스트 스크립트와 Job 매니페스트

## 디렉터리 구조

### `platform/`

플랫폼 공통 구성:

- `platform/namespaces/namespaces.yml`
- `platform/argocd/ingress.yaml`
- `platform/fluentbit/fluentbit-configmap.yaml`

### `services/`

서비스별 워크로드 매니페스트:

- `services/auth-user-service/`
- `services/flight-service/`
- `services/payment-service/`

서비스에 따라 다음 리소스가 포함됩니다.

- Deployment
- Service
- HPA
- ServiceAccount
- Secret 참조

### `shared/`

공용 운영 매니페스트:

- `shared/cluster/` : 클러스터 생성 및 ENI/Karpenter 관련 참고 구성
- `shared/ingress/` : 서비스/관리용 Ingress
- `shared/karpenter/` : Karpenter 보조 매니페스트

### `k6/`

부하 테스트 자산:

- 인증, 검색, 체크아웃, 마이페이지 시나리오 스크립트
- `k6/k8s/` 하위 Kubernetes Job
- 상세 설명은 `k6/README.md`

## 네임스페이스

현재 네임스페이스 초기화 파일은 아래 네임스페이스를 생성합니다.

- `argocd`
- `karpenter`
- `monitoring`
- `airline-payment`
- `airline-flight`
- `airline-auth`

## 외부 진입점

Ingress 설정에 사용 중인 호스트:

- `izones.cloud`
- `admin.izones.cloud`
- `argocd.izones.cloud`

서비스 Ingress는 네임스페이스별로 분리되어 있으며 ALB Ingress 어노테이션을 사용합니다.

## 매니페스트 목록

CI 검증 기준 파일:

- `manifests.txt`

현재 포함 대상:

- platform 매니페스트
- 서비스 매니페스트
- shared ingress/cluster/Karpenter 매니페스트
- k6 Kubernetes Job 매니페스트

## 검증

GitHub Actions 워크플로:

- `.github/workflows/eks.yaml`

현재 동작:

1. `platform`, `shared`의 raw Kubernetes 매니페스트를 `kubeconform`으로 검증
2. `services/auth`, `services/flight`, `services/payment` Helm 차트를 `helm lint`
3. Helm 렌더링 결과를 다시 `kubeconform`으로 검증

주의:

- `k6` 관련 매니페스트는 이 워크플로의 검증 대상이 아닙니다.
- 이 워크플로는 검증만 수행합니다.
- 자동 배포나 `kubectl apply`는 수행하지 않습니다.

## 운영 메모

- 서비스 매니페스트는 환경 기준이 아니라 서비스 경계 기준으로 분리되어 있습니다.
- `shared/cluster/` 하위 파일 중 일부는 일상 운영용이 아니라 클러스터 부트스트랩 참고용입니다.
- `services/payment-service/payment-secret.yaml`가 저장소에 포함되어 있으므로 시크릿 관리 방식은 별도 점검이 필요합니다.

## k6

부하 테스트 시작점:

- `k6/README.md`

포함된 시나리오:

- 검색 스모크 테스트
- 로그인/프로필/로그아웃
- 인증 버스트 테스트
- 인증 + 검색 혼합 부하
- 체크아웃 플로우
- 마이페이지 조회

## 수동 적용 순서 예시

수동 적용 시 일반적인 순서는 다음과 같습니다.

1. 네임스페이스
2. 필요 시 cluster/shared 선행 리소스
3. 서비스 Deployment 및 Service
4. HPA
5. Ingress
6. 선택적으로 k6 Job
