# AWS Secrets Manager Provider Setup Guide

## Overview

This guide covers the setup and deployment of the AWS Secrets Manager Provider for the Secrets Store CSI Driver using Helm.

## What is the AWS Secrets Manager Provider?

The AWS Secrets Manager Provider is a component that enables the Secrets Store CSI Driver to fetch secrets from:
- **AWS Secrets Manager** - For storing and managing application secrets
- **AWS Systems Manager Parameter Store** - For storing configuration data and secrets

## Architecture

```
Application Pod
    ↓ (mounts volume)
Secrets Store CSI Driver
    ↓ (calls provider via gRPC)
AWS Secrets Manager Provider ← This chart installs this
    ↓ (fetches secrets)
AWS Secrets Manager / SSM Parameter Store
```

## Prerequisites

Before installing the AWS provider, ensure you have:

1. ✅ **Secrets Store CSI Driver** installed (via `secrets-store-csi-driver` chart)
2. ✅ **IAM Role** created with appropriate permissions
3. ✅ **Pod Identity or IRSA** configured on your EKS cluster
4. ✅ **AWS Account ID** ready for configuration

## Chart Location

```
charts/secrets-store-csi-driver-provider-aws/
├── Chart.yaml                          # Chart metadata
├── README.md                           # Chart documentation
├── values-dev.yaml                     # Dev environment values
├── values-prod.yaml                    # Prod environment values
└── charts/
    └── secrets-store-csi-driver-provider-aws-2.1.1.tgz  # Upstream chart
```

## Configuration Steps

### 1. Update AWS Account ID

Edit both values files and replace `ACCOUNT_ID` with your actual AWS account ID:

**File: `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`**
```yaml
podAnnotations:
  eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
  eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
```

**File: `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`**
```yaml
podAnnotations:
  eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
  eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
```

### 2. Update AWS Region (if needed)

The default region is `us-east-1`. Update if your cluster is in a different region:

```yaml
secrets-store-csi-driver-provider-aws:
  awsRegion: "us-west-2"  # Change to your region
```

### 3. Verify IAM Role Exists

The IAM role should already exist from your Terraform setup:
- Dev: `EKS-SecretsStore-Role-dev`
- Prod: `EKS-SecretsStore-Role-prod`

Check the role has these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/*"
    }
  ]
}
```

## Deployment

### Method 1: GitLab CI/CD (Recommended)

1. **Update the values files** with your AWS account ID (see Configuration Steps above)

2. **Commit and push** your changes:
   ```bash
   git add charts/secrets-store-csi-driver-provider-aws/
   git commit -m "Configure AWS Secrets Manager Provider"
   git push
   ```

3. **Run the deployment job** in GitLab:
   - For dev: `deploy:secrets-store-provider-aws:dev`
   - For prod: `deploy:secrets-store-provider-aws:prod`

### Method 2: Manual Helm Deployment

```bash
# Deploy to dev environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml \
  --wait --timeout 5m

# Deploy to prod environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml \
  --wait --timeout 5m
```

## Verification

### 1. Check Helm Release

```bash
helm list -n secrets-store-csi-driver

# Expected output:
NAME                                    NAMESPACE                       STATUS
secrets-store-csi-driver                secrets-store-csi-driver        deployed
secrets-store-csi-driver-provider-aws   secrets-store-csi-driver        deployed
```

### 2. Check DaemonSet

```bash
kubectl get daemonset -n secrets-store-csi-driver

# Expected output:
NAME                                      DESIRED   CURRENT   READY
secrets-store-csi-driver                  3         3         3
secrets-store-csi-driver-provider-aws     3         3         3
```

### 3. Check Pods

```bash
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# Expected output:
NAME                                          READY   STATUS    RESTARTS   AGE
secrets-store-csi-driver-provider-aws-abc12   1/1     Running   0          2m
secrets-store-csi-driver-provider-aws-def34   1/1     Running   0          2m
secrets-store-csi-driver-provider-aws-ghi56   1/1     Running   0          2m
```

### 4. Check Logs

```bash
# Check provider logs
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws --tail=50

# Should see logs like:
# I0101 12:00:00.000000       1 main.go:xx] Starting provider
# I0101 12:00:00.000000       1 server.go:xx] Listening on unix socket
```

### 5. Verify Provider Registration

```bash
# Check if AWS provider is registered with CSI driver
kubectl exec -it -n secrets-store-csi-driver \
  $(kubectl get pod -n secrets-store-csi-driver -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /var/run/secrets-store-csi-providers/

# Should show: aws provider socket
```

## Testing

### Create a Test Secret in AWS

```bash
# Create a test secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name test/my-app/db-password \
  --secret-string "my-super-secret-password" \
  --region us-east-1
```

### Create a SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-aws-secrets
  namespace: default
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "test/my-app/db-password"
        objectType: "secretsmanager"
```

### Create a Test Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-secrets-pod
  namespace: default
spec:
  serviceAccountName: default
  containers:
  - name: busybox
    image: busybox:latest
    command:
      - sleep
      - "3600"
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
        secretProviderClass: "test-aws-secrets"
```

### Verify Secret is Mounted

```bash
# Check if secret is mounted
kubectl exec test-secrets-pod -- cat /mnt/secrets/test/my-app/db-password

# Should output: my-super-secret-password
```

## Troubleshooting

### Issue: Provider Not Found

**Error:**
```
failed to mount secrets store object content: error connecting to provider "aws": provider not found
```

**Solution:**
1. Check DaemonSet is running:
   ```bash
   kubectl get daemonset -n secrets-store-csi-driver secrets-store-csi-driver-provider-aws
   ```

2. Restart CSI driver pods:
   ```bash
   kubectl rollout restart daemonset/secrets-store-csi-driver -n secrets-store-csi-driver
   ```

### Issue: Permission Denied

**Error:**
```
failed to get secret: AccessDeniedException: User is not authorized to perform: secretsmanager:GetSecretValue
```

**Solution:**
1. Verify IAM role ARN in pod annotations:
   ```bash
   kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws -o yaml | grep eks.amazonaws.com/role-arn
   ```

2. Check IAM role trust policy includes Pod Identity or IRSA

3. Verify IAM role has correct permissions

### Issue: Pods Not Starting

**Check:**
```bash
kubectl describe daemonset secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver
kubectl describe pod -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
```

**Common causes:**
- Image pull errors
- Node selector mismatch
- Resource constraints

## Uninstallation

### Using GitLab CI/CD

Set the uninstall variable and run the job:
```bash
# Set in GitLab CI/CD variables:
UNINSTALL_SECRETS_STORE_CSI_DRIVER_PROVIDER_AWS=true

# Then run:
uninstall:secrets-store-provider-aws:dev
# or
uninstall:secrets-store-provider-aws:prod
```

### Using Helm

```bash
helm uninstall secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver
```

## Related Documentation

- [Chart README](../charts/secrets-store-csi-driver-provider-aws/README.md)
- [Secrets Store AWS Provider Fix](./SECRETS-STORE-AWS-PROVIDER-FIX.md)
- [AWS Secrets Manager CSI Provider GitHub](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Usage Examples](../examples/secrets-store-csi-driver-usage.yaml)

## Next Steps

After successful deployment:

1. ✅ Create secrets in AWS Secrets Manager or SSM Parameter Store
2. ✅ Create SecretProviderClass resources for your applications
3. ✅ Update your application deployments to mount secrets
4. ✅ Test secret rotation (AWS provider supports automatic rotation)
5. ✅ Monitor logs for any issues

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs: `kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws`
3. Consult the [official documentation](https://github.com/aws/secrets-store-csi-driver-provider-aws)
