# airline-eks

`airline-eks` contains Kubernetes manifests and cluster-side operational assets for running the airline services on Amazon EKS.

## Purpose

This repository is the manifest layer for:

- service Deployments, Services, and HPAs
- shared Ingress resources
- namespace bootstrap
- Karpenter-related manifests
- cluster bootstrap references
- k6 load-test jobs and scripts

## Directory Layout

### `platform/`

Cluster platform components:

- `platform/namespaces/namespaces.yml`
- `platform/argocd/ingress.yaml`

### `services/`

Workload manifests per service:

- `services/auth-user-service/`
- `services/flight-service/`
- `services/payment-service/`

Included resources vary by service, such as:

- Deployment
- Service
- HPA
- ServiceAccount
- Secret reference

### `shared/`

Shared operational manifests:

- `shared/cluster/` : cluster bootstrap references and ENI/Karpenter setup
- `shared/ingress/` : public/admin ingress
- `shared/karpenter/` : Karpenter helper manifests

### `k6/`

Load-test assets:

- JavaScript scenarios for auth, search, checkout, mypage
- Kubernetes Jobs under `k6/k8s/`
- separate README in `k6/README.md`

## Namespaces

Current namespace bootstrap file creates:

- `argocd`
- `karpenter`
- `monitoring`
- `airline-payment`
- `airline-flight`
- `airline-auth`

## Public Entry Points

Ingress manifests currently reference:

- `izones.cloud`
- `admin.izones.cloud`
- `argocd.izones.cloud`

Service ingress routing is split by namespace/service and uses ALB ingress annotations.

## Manifest Inventory

CI validation reads the manifest set listed in:

- `manifests.txt`

That list currently includes:

- platform manifests
- service manifests
- shared ingress/cluster/Karpenter manifests
- k6 Kubernetes job manifests

## Validation

GitHub Actions workflow:

- `.github/workflows/eks.yaml`

What it does:

1. collect manifest files from `services`, `shared`, `platform`, and `k6/k8s`
2. validate them with `kubeconform`

This is validation-only. It does not apply manifests automatically.

## Operational Notes

- service manifests are split by bounded context rather than by environment
- some files under `shared/cluster/` are cluster bootstrap references rather than day-2 app manifests
- `payment-service/payment-secret.yaml` exists in this repo, so secret handling should be reviewed before treating this repo as broadly shareable

## k6

For load testing, start from:

- `k6/README.md`

Covered scenarios include:

- search smoke
- auth login/profile/logout
- auth burst for autoscaling checks
- mixed auth + search burst
- checkout flow
- mypage flow

## Typical Apply Order

When applying manually, the practical order is:

1. namespaces
2. cluster/shared prerequisites as needed
3. service Deployments and Services
4. HPA resources
5. ingress resources
6. optional k6 jobs
