# Secrets Store CSI Driver - AWS Provider Fix

## Problem

Pods are failing to mount secrets with the error:
```
"failed to mount secrets store object content" err="error connecting to provider \"aws\": provider not found: provider \"aws\""
```

## Root Cause

The **Secrets Store CSI Driver** is installed, but the **AWS Secrets Manager Provider** (ASCP) is missing. The CSI driver needs a provider-specific component to communicate with AWS Secrets Manager.

## Solution

The AWS provider must be deployed as a separate DaemonSet that runs on all nodes.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Pod with SecretProviderClass                            │
│  └─ Volume mount: /mnt/secrets                          │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ Secrets Store CSI Driver (DaemonSet)                    │
│  └─ Communicates with provider via gRPC                 │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ AWS Secrets Manager Provider (DaemonSet) ← MISSING!    │
│  └─ Fetches secrets from AWS Secrets Manager/SSM       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ AWS Secrets Manager / Systems Manager Parameter Store  │
└─────────────────────────────────────────────────────────┘
```

## Files Created

### 1. Base Manifest
**File:** `k8s-resources/base/secrets-store-csi-driver-provider-aws.yaml`

Contains:
- ServiceAccount for the AWS provider
- DaemonSet that runs the AWS provider on all nodes

### 2. Environment Patches
**Files:**
- `k8s-resources/environments/dev/secrets-store-provider-aws-patch.yaml`
- `k8s-resources/environments/prod/secrets-store-provider-aws-patch.yaml`

Contains environment-specific IAM role ARNs.

### 3. Updated Kustomization
**Files:**
- `k8s-resources/environments/dev/kustomization.yaml`
- `k8s-resources/environments/prod/kustomization.yaml`

Now includes the AWS provider resources.

## Deployment

### Option 1: Using GitLab CI/CD (Recommended)

The pipeline includes Helm deployment jobs for the AWS provider:

```bash
# In GitLab, run:
deploy:secrets-store-provider-aws:dev   # For dev environment
deploy:secrets-store-provider-aws:prod  # For prod environment
```

### Option 2: Using Helm Directly

```bash
# Deploy to dev
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml

# Deploy to prod
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml
```

### Option 3: Using Kustomize (Alternative)

```bash
# Deploy to dev
kubectl apply -k k8s-resources/environments/dev

# Deploy to prod
kubectl apply -k k8s-resources/environments/prod
```

## Verification

### 1. Check DaemonSet is Running

```bash
kubectl get daemonset -n secrets-store-csi-driver

# Expected output:
NAME                                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
csi-secrets-store-provider-aws      3         3         3       3            3
secrets-store-csi-driver            3         3         3       3            3
```

### 2. Check Pods are Running

```bash
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# Expected output:
NAME                                   READY   STATUS    RESTARTS   AGE
csi-secrets-store-provider-aws-abc12   1/1     Running   0          2m
csi-secrets-store-provider-aws-def34   1/1     Running   0          2m
csi-secrets-store-provider-aws-ghi56   1/1     Running   0          2m
```

### 3. Check Provider is Registered

```bash
# Check if the AWS provider binary exists on nodes
kubectl exec -it -n secrets-store-csi-driver \
  $(kubectl get pod -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /etc/kubernetes/secrets-store-csi-providers/

# Expected output should show: aws provider binary
```

### 4. Check Logs

```bash
# Check AWS provider logs
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# Check CSI driver logs
kubectl logs -n secrets-store-csi-driver -l app=secrets-store-csi-driver
```

### 5. Test with a Pod

After deployment, your existing pods should be able to mount secrets:

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Should no longer see "provider not found" errors
```

## Configuration

### IAM Role ARNs

Update the role ARNs in the patch files with your actual AWS account ID:

**Dev:**
```yaml
eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
```

**Prod:**
```yaml
eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
```

### Image Version

The current image version is:
```
public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.r2-50-g5b4aca1-2023.06.09.21.19
```

To update to a newer version, edit:
```yaml
# k8s-resources/base/secrets-store-csi-driver-provider-aws.yaml
spec:
  template:
    spec:
      containers:
        - name: provider-aws-installer
          image: public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:NEW_VERSION
```

## Troubleshooting

### Issue: DaemonSet pods are not starting

**Check:**
```bash
kubectl describe daemonset csi-secrets-store-provider-aws -n secrets-store-csi-driver
kubectl describe pod -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
```

**Common causes:**
1. Image pull errors - Check if the image is accessible
2. Node selector mismatch - Verify nodes have `kubernetes.io/os: linux` label
3. Resource constraints - Check node resources

### Issue: Provider still not found after deployment

**Check:**
1. Verify DaemonSet is running on all nodes:
   ```bash
   kubectl get daemonset -n secrets-store-csi-driver csi-secrets-store-provider-aws
   ```

2. Check if provider volume is mounted correctly:
   ```bash
   kubectl exec -it -n secrets-store-csi-driver <csi-driver-pod> -- \
     ls -la /etc/kubernetes/secrets-store-csi-providers/
   ```

3. Restart CSI driver pods to pick up the new provider:
   ```bash
   kubectl rollout restart daemonset/secrets-store-csi-driver -n secrets-store-csi-driver
   ```

### Issue: Pods still can't access secrets

**Check IAM permissions:**

1. Verify the service account has the correct role annotation:
   ```bash
   kubectl get sa secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver -o yaml
   ```

2. Check if Pod Identity or IRSA is configured:
   ```bash
   # For Pod Identity
   aws eks list-pod-identity-associations --cluster-name your-cluster

   # For IRSA
   kubectl describe sa secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver
   ```

3. Test IAM role assumption:
   ```bash
   kubectl exec -it <your-pod> -n <namespace> -- aws sts get-caller-identity
   ```

### Issue: Permission denied errors

**Check:**
1. IAM role has correct permissions for Secrets Manager/SSM
2. Secret/Parameter exists in AWS
3. Secret/Parameter ARN is correct in SecretProviderClass

## Related Documentation

- [AWS Secrets Manager CSI Provider](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- `charts/secrets-store-csi-driver/values-dev.yaml` - Helm values
- `examples/secrets-store-csi-driver-usage.yaml` - Usage examples

## Next Steps

After deploying the AWS provider:

1. **Restart affected pods** to pick up the provider:
   ```bash
   kubectl rollout restart deployment/<deployment-name> -n <namespace>
   ```

2. **Monitor logs** for any remaining issues:
   ```bash
   kubectl logs -f -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
   ```

3. **Update SecretProviderClass** resources if needed to match your AWS secrets

4. **Test secret mounting** with a sample pod before rolling out to production
