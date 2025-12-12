# AWS Secrets Manager Provider - Setup Verification Checklist

Use this checklist to verify that the AWS Secrets Manager Provider is properly configured and ready for deployment.

## Pre-Deployment Checklist

### 1. Helm Chart Configuration

- [ ] **Chart.yaml** exists with correct version (2.1.1)
  - Location: `charts/secrets-store-csi-driver-provider-aws/Chart.yaml`
  - Verify: `cat charts/secrets-store-csi-driver-provider-aws/Chart.yaml`

- [ ] **values-dev.yaml** configured
  - Location: `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
  - Update AWS Account ID in role ARNs
  - Update AWS region if needed
  - Verify service account name: `secrets-store-csi-driver-provider-aws`

- [ ] **values-prod.yaml** configured
  - Location: `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`
  - Update AWS Account ID in role ARNs
  - Update AWS region if needed
  - Verify service account name: `secrets-store-csi-driver-provider-aws`

- [ ] **Service Account Patch Template** exists
  - Location: `charts/secrets-store-csi-driver-provider-aws/templates/serviceaccount-patch.yaml`
  - Adds IAM role annotations to service account

### 2. Terraform Configuration

- [ ] **IAM Role** configured in `terraform/locals.tf`
  ```hcl
  secrets-store-csi-driver = {
    addon_name      = "secrets-store-csi-driver"
    namespace       = "kube-system"
    service_account = "secrets-store-csi-driver-provider-aws"
    policy_name     = "EKS-SecretsStore-Policy"
    role_name       = "EKS-SecretsStore-Role"
  }
  ```

- [ ] **Trust Policy** supports both IRSA and Pod Identity
  - Location: `terraform/data.tf`
  - Includes Pod Identity statement (pods.eks.amazonaws.com)
  - Includes IRSA statement (sts:AssumeRoleWithWebIdentity)

- [ ] **IAM Policy** has required permissions
  - Location: `terraform/iam-policies/secrets-store-csi-driver-policy.json`
  - secretsmanager:GetSecretValue
  - secretsmanager:DescribeSecret
  - ssm:GetParameter
  - ssm:GetParameters

### 3. Kustomize Configuration

- [ ] **Base kustomization** exists
  - Location: `k8s-resources/secrets-store-provider-aws/base/kustomization.yaml`
  - Namespace: `kube-system`

- [ ] **Dev overlay** configured
  - Location: `k8s-resources/secrets-store-provider-aws/overlays/dev/`
  - Service account patch with dev role ARN

- [ ] **Prod overlay** configured
  - Location: `k8s-resources/secrets-store-provider-aws/overlays/prod/`
  - Service account patch with prod role ARN

- [ ] **Environment kustomizations** reference the app
  - Dev: `k8s-resources/environments/dev/kustomization.yaml`
  - Prod: `k8s-resources/environments/prod/kustomization.yaml`

### 4. GitLab CI/CD Configuration

- [ ] **Deployment jobs** exist in `.gitlab-ci.yml`
  - `deploy:secrets-store-provider-aws:dev`
  - `deploy:secrets-store-provider-aws:prod`

- [ ] **Jobs extend** correct template
  - Extends: `.deploy_single_chart`
  - Chart name: `secrets-store-csi-driver-provider-aws`
  - Namespace: `kube-system`

### 5. ArgoCD Configuration

- [ ] **AppProject** exists
  - Location: `argocd/projects/platform.yaml`
  - Includes kube-system namespace

- [ ] **Application manifests** exist
  - Dev: `argocd/applications/k8s-secrets-store-provider-aws-dev.yaml`
  - Prod: `argocd/applications/k8s-secrets-store-provider-aws-prod.yaml`

- [ ] **App of Apps** includes the application
  - Dev: `argocd/app-of-apps/platform-dev.yaml`
  - Prod: `argocd/app-of-apps/platform-prod.yaml`

### 6. Documentation

- [ ] **README** exists in chart directory
  - Location: `charts/secrets-store-csi-driver-provider-aws/README.md`

- [ ] **Troubleshooting guides** available
  - `docs/SECRETPROVIDERCLASS-TROUBLESHOOTING.md`
  - `docs/SECRETS-STORE-AWS-PROVIDER-FIX.md`

- [ ] **Version compatibility** documented
  - `docs/SECRETS-STORE-VERSION-COMPATIBILITY.md`

- [ ] **Complete setup guide** available
  - `AWS-SECRETS-MANAGER-COMPLETE-SETUP.md`

## Deployment Checklist

### 1. Prerequisites

- [ ] **Secrets Store CSI Driver** already installed
  ```bash
  kubectl get daemonset secrets-store-csi-driver -n kube-system
  ```

- [ ] **Terraform applied** to create IAM roles
  ```bash
  cd terraform
  terraform plan
  terraform apply
  ```

- [ ] **AWS Account ID** updated in values files
  - Replace `ACCOUNT_ID` with actual AWS account ID

- [ ] **AWS Region** configured correctly
  - Default: `us-east-1`
  - Update if using different region

### 2. Deploy via Helm (Method 1)

- [ ] **Dev deployment**
  ```bash
  helm upgrade --install secrets-store-csi-driver-provider-aws \
    charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
    -n kube-system --create-namespace \
    -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
  ```

- [ ] **Prod deployment**
  ```bash
  helm upgrade --install secrets-store-csi-driver-provider-aws \
    charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
    -n kube-system --create-namespace \
    -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml
  ```

### 3. Deploy via GitLab CI/CD (Method 2)

- [ ] **Trigger dev deployment**
  - Run job: `deploy:secrets-store-provider-aws:dev`

- [ ] **Trigger prod deployment**
  - Run job: `deploy:secrets-store-provider-aws:prod`

### 4. Deploy via ArgoCD (Method 3)

- [ ] **Deploy AppProject**
  ```bash
  kubectl apply -f argocd/projects/platform.yaml
  ```

- [ ] **Deploy Application**
  ```bash
  kubectl apply -f argocd/applications/k8s-secrets-store-provider-aws-dev.yaml
  kubectl apply -f argocd/applications/k8s-secrets-store-provider-aws-prod.yaml
  ```

- [ ] **Or use App of Apps**
  ```bash
  kubectl apply -f argocd/app-of-apps/platform-dev.yaml
  ```

## Post-Deployment Verification

### 1. Check DaemonSet

- [ ] **DaemonSet exists**
  ```bash
  kubectl get daemonset secrets-store-csi-driver-provider-aws -n kube-system
  ```

- [ ] **All pods ready**
  ```bash
  # DESIRED should equal READY
  kubectl get daemonset secrets-store-csi-driver-provider-aws -n kube-system
  ```

### 2. Check Pods

- [ ] **Pods running**
  ```bash
  kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws
  ```

- [ ] **No errors in logs**
  ```bash
  kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50
  ```

### 3. Check Service Account

- [ ] **Service account exists**
  ```bash
  kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system
  ```

- [ ] **IAM role annotations present**
  ```bash
  kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system -o yaml | grep eks.amazonaws.com
  ```
  
  Should show:
  - `eks.amazonaws.com/role-arn`
  - `eks.amazonaws.com/pod-identity-association-role-arn`

### 4. Check Provider Registration

- [ ] **Provider socket exists**
  ```bash
  CSI_POD=$(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/
  ```
  
  Should show: `aws.sock`

### 5. Test IAM Role

- [ ] **IAM role assumption works**
  ```bash
  PROVIDER_POD=$(kubectl get pod -n kube-system -l app=csi-secrets-store-provider-aws -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -n kube-system $PROVIDER_POD -- aws sts get-caller-identity
  ```
  
  Should show: `EKS-SecretsStore-Role-{env}`

### 6. Test Secret Mounting

- [ ] **Create test SecretProviderClass**
  ```bash
  kubectl apply -f - <<EOF
  apiVersion: secrets-store.csi.x-k8s.io/v1
  kind: SecretProviderClass
  metadata:
    name: test-aws-provider
    namespace: default
  spec:
    provider: aws
    parameters:
      region: us-east-1
      objects: |
        - objectName: "test-secret"
          objectType: "secretsmanager"
  EOF
  ```

- [ ] **Create test pod** (requires actual secret in AWS)
  ```bash
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: test-secrets-mount
    namespace: default
  spec:
    serviceAccountName: default
    containers:
    - name: test
      image: busybox:latest
      command: ["sleep", "3600"]
      volumeMounts:
      - name: secrets-store
        mountPath: "/mnt/secrets"
        readOnly: true
    volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "test-aws-provider"
  EOF
  ```

- [ ] **Verify pod starts** (or check error message)
  ```bash
  kubectl get pod test-secrets-mount
  kubectl describe pod test-secrets-mount
  ```

- [ ] **Clean up test resources**
  ```bash
  kubectl delete pod test-secrets-mount
  kubectl delete secretproviderclass test-aws-provider
  ```

## Troubleshooting Checklist

If issues occur, check:

- [ ] **Provider not found**
  - Restart CSI driver: `kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system`
  - Check provider pods are running
  - Verify provider socket exists

- [ ] **Permission denied**
  - Verify IAM role trust policy
  - Check service account annotations
  - Test IAM role assumption
  - Verify IAM policy permissions

- [ ] **Secret not found**
  - Verify secret exists in AWS Secrets Manager
  - Check region matches
  - Verify secret name is correct (case-sensitive)

- [ ] **Secrets not created**
  - Ensure pod has volume mount
  - Pod must be running for secrets to be created
  - Check SecretProviderClass has `secretObjects` section

## Sign-Off

### Development Environment

- [ ] All pre-deployment checks passed
- [ ] Deployment successful
- [ ] All post-deployment verifications passed
- [ ] Test secret mounting works
- [ ] Documentation reviewed

**Deployed by**: ________________  
**Date**: ________________  
**Environment**: Dev  

### Production Environment

- [ ] All pre-deployment checks passed
- [ ] Deployment successful
- [ ] All post-deployment verifications passed
- [ ] Test secret mounting works
- [ ] Documentation reviewed
- [ ] Change management approval obtained

**Deployed by**: ________________  
**Date**: ________________  
**Environment**: Prod  

## Quick Reference

### Key Files
```
charts/secrets-store-csi-driver-provider-aws/
├── Chart.yaml
├── values-dev.yaml
├── values-prod.yaml
├── templates/
│   └── serviceaccount-patch.yaml
└── charts/
    └── secrets-store-csi-driver-provider-aws-2.1.1.tgz

terraform/
├── locals.tf
├── data.tf
├── iam-roles.tf
└── iam-policies/
    └── secrets-store-csi-driver-policy.json

k8s-resources/secrets-store-provider-aws/
├── base/
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── serviceaccount-patch.yaml
    └── prod/
        ├── kustomization.yaml
        └── serviceaccount-patch.yaml

argocd/
├── projects/
│   └── platform.yaml
├── applications/
│   ├── k8s-secrets-store-provider-aws-dev.yaml
│   └── k8s-secrets-store-provider-aws-prod.yaml
└── app-of-apps/
    ├── platform-dev.yaml
    └── platform-prod.yaml
```

### Key Commands
```bash
# Check status
kubectl get daemonset -n kube-system | grep secrets-store
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# View logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50

# Test provider
CSI_POD=$(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/

# Test IAM
PROVIDER_POD=$(kubectl get pod -n kube-system -l app=csi-secrets-store-provider-aws -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $PROVIDER_POD -- aws sts get-caller-identity
```

## Notes

- The AWS Provider is deployed to `kube-system` namespace (not `secrets-store-csi-driver`)
- Service account name is `secrets-store-csi-driver-provider-aws`
- IAM role supports both IRSA and Pod Identity authentication
- Secrets are only created when a pod mounts the volume
- Provider version 2.1.1 is compatible with CSI Driver 1.5.4

