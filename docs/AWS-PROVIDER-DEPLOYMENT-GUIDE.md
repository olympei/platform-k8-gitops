# AWS Secrets Manager Provider - Complete Deployment Guide

## Overview

This guide covers deploying the AWS Secrets Manager Provider with proper IAM role configuration.

## Important Note About Service Account

The upstream Helm chart **does not support** adding annotations to the service account via values.yaml. Therefore, we must annotate the service account **after** deployment.

The GitLab CI/CD jobs handle this automatically, or you can do it manually.

## Prerequisites

1. ✅ Secrets Store CSI Driver installed
2. ✅ IAM role created: `EKS-SecretsStore-Role-{env}`
3. ✅ AWS Account ID available

## Deployment Methods

### Method 1: GitLab CI/CD (Recommended - Automated)

The GitLab jobs automatically deploy the chart AND annotate the service account.

#### Step 1: Set AWS Account ID in CI/CD Variables

In GitLab, go to: **Settings → CI/CD → Variables**

Add variable:
- **Key**: `AWS_ACCOUNT_ID`
- **Value**: Your AWS account ID (e.g., `123456789012`)
- **Protected**: Yes
- **Masked**: No

#### Step 2: Run Deployment Job

Trigger the job in GitLab:
- For dev: `deploy:secrets-store-provider-aws:dev`
- For prod: `deploy:secrets-store-provider-aws:prod`

The job will:
1. Deploy the Helm chart
2. Automatically annotate the service account with IAM role
3. Restart the DaemonSet to apply changes
4. Show deployment status

**That's it!** The service account will be properly configured.

---

### Method 2: Helm + Script (Semi-Automated)

Deploy with Helm, then run the annotation script.

#### Step 1: Deploy with Helm

```bash
# For dev
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml \
  --wait --timeout 5m

# For prod
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml \
  --wait --timeout 5m
```

#### Step 2: Run Annotation Script

```bash
# For dev
./scripts/annotate-aws-provider-sa.sh -e dev -a YOUR_ACCOUNT_ID

# For prod
./scripts/annotate-aws-provider-sa.sh -e prod -a YOUR_ACCOUNT_ID
```

The script will:
- Add IAM role annotations to the service account
- Restart the DaemonSet
- Verify the configuration

---

### Method 3: Helm + Manual Annotation

Deploy with Helm, then manually annotate.

#### Step 1: Deploy with Helm

```bash
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
```

#### Step 2: Annotate Service Account

```bash
# Replace ACCOUNT_ID with your AWS account ID
# Replace 'dev' with 'prod' for production

kubectl annotate sa secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev \
  --overwrite

kubectl annotate sa secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver \
  eks.amazonaws.com/pod-identity-association-role-arn=arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev \
  --overwrite
```

#### Step 3: Restart DaemonSet

```bash
kubectl rollout restart daemonset/secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver
```

---

### Method 4: Kubectl Patch

Use Kubernetes patch files.

#### Step 1: Deploy with Helm

```bash
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
```

#### Step 2: Update Patch File

Edit `k8s-resources/patches/aws-provider-sa-dev.yaml` and replace `ACCOUNT_ID` with your AWS account ID.

#### Step 3: Apply Patch

```bash
# For dev
kubectl patch sa secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver \
  --patch-file k8s-resources/patches/aws-provider-sa-dev.yaml

# For prod
kubectl patch sa secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver \
  --patch-file k8s-resources/patches/aws-provider-sa-prod.yaml
```

#### Step 4: Restart DaemonSet

```bash
kubectl rollout restart daemonset/secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver
```

---

## Verification

After deployment, verify everything is working:

### 1. Check Helm Release

```bash
helm list -n secrets-store-csi-driver

# Expected output:
NAME                                    STATUS
secrets-store-csi-driver                deployed
secrets-store-csi-driver-provider-aws   deployed
```

### 2. Check DaemonSet

```bash
kubectl get daemonset -n secrets-store-csi-driver

# Expected output:
NAME                                      DESIRED   CURRENT   READY
secrets-store-csi-driver                  3         3         3
secrets-store-csi-driver-provider-aws     3         3         3
```

### 3. Check Service Account Annotations

```bash
kubectl get sa secrets-store-csi-driver-provider-aws \
  -n secrets-store-csi-driver \
  -o yaml | grep -A 5 annotations

# Expected output:
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev
    eks.amazonaws.com/pod-identity-association-role-arn: arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev
```

### 4. Check Pods

```bash
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# All pods should be Running
```

### 5. Check Logs

```bash
kubectl logs -n secrets-store-csi-driver \
  -l app=csi-secrets-store-provider-aws \
  --tail=50

# Should see successful startup logs, no errors
```

### 6. Test with a Pod

Create a test pod to verify the provider works:

```bash
kubectl apply -f examples/edm-gold100-deployment-example.yaml
```

Check if secrets are created:

```bash
kubectl get secrets -n gs | grep edm-gold100
```

---

## Troubleshooting

### Issue: Service Account Not Annotated

**Symptom**: Pods can't access AWS Secrets Manager

**Check**:
```bash
kubectl get sa secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver -o yaml
```

**Fix**: Run the annotation script or manually annotate (see methods above)

### Issue: Pods Not Restarting After Annotation

**Fix**: Manually restart the DaemonSet:
```bash
kubectl rollout restart daemonset/secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver
kubectl rollout status daemonset/secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver
```

### Issue: IAM Role Not Assumed

**Check pod environment**:
```bash
kubectl exec -it -n secrets-store-csi-driver \
  $(kubectl get pod -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep AWS
```

**Verify IAM role trust policy** includes the service account:
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:secrets-store-csi-driver:secrets-store-csi-driver-provider-aws"
    }
  }
}
```

---

## Files Reference

- **Helm Chart**: `charts/secrets-store-csi-driver-provider-aws/`
- **Values Files**: 
  - `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
  - `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`
- **Annotation Script**: `scripts/annotate-aws-provider-sa.sh`
- **Patch Files**:
  - `k8s-resources/patches/aws-provider-sa-dev.yaml`
  - `k8s-resources/patches/aws-provider-sa-prod.yaml`
- **GitLab CI**: `.gitlab-ci.yml` (search for `deploy:secrets-store-provider-aws`)

---

## Summary

**Recommended Approach**: Use GitLab CI/CD (Method 1)
- Set `AWS_ACCOUNT_ID` in CI/CD variables
- Run the deployment job
- Everything is automated!

**Alternative**: Use Helm + Script (Method 2)
- Deploy with Helm
- Run `./scripts/annotate-aws-provider-sa.sh`
- Quick and reliable

The key point: **The service account must be annotated after deployment** because the upstream chart doesn't support this configuration.
