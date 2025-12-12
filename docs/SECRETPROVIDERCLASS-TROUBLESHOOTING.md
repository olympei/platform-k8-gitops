# SecretProviderClass Troubleshooting Guide

## Issue: Kubernetes Secrets Not Created from SecretProviderClass

### Understanding How It Works

**IMPORTANT**: Kubernetes secrets defined in `secretObjects` are **ONLY created when a pod mounts the CSI volume**. They won't appear just by creating the SecretProviderClass.

```
1. Create SecretProviderClass ✅ (You did this)
2. Create Pod with CSI volume mount ❓ (Need to verify)
3. Pod starts and mounts volume → Secrets are created ✅
```

## Diagnostic Steps

### Step 1: Verify AWS Secrets Manager Provider is Running

```bash
# Check if the AWS provider DaemonSet is deployed
kubectl get daemonset -n secrets-store-csi-driver

# Expected output:
NAME                                      DESIRED   CURRENT   READY
secrets-store-csi-driver                  3         3         3
secrets-store-csi-driver-provider-aws     3         3         3  ← Must be present!
```

**If `secrets-store-csi-driver-provider-aws` is missing:**
- Deploy it using: `deploy:secrets-store-provider-aws:dev` job in GitLab
- Or follow: `docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md`

### Step 2: Check Provider Pods

```bash
# Check AWS provider pods
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# Check logs for errors
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws --tail=50
```

### Step 3: Verify SecretProviderClass

```bash
# Check if SecretProviderClass exists
kubectl get secretproviderclass -n gs

# Describe it to see any events
kubectl describe secretproviderclass edm-app-gold100-spc -n gs
```

### Step 4: Check if Pod is Mounting the Volume

**This is the most common issue!** Secrets won't be created until a pod mounts the volume.

```bash
# List pods in the namespace
kubectl get pods -n gs

# Check if any pod has the CSI volume mounted
kubectl get pods -n gs -o yaml | grep -A 10 "csi:"

# Describe a specific pod to see volume mounts
kubectl describe pod <pod-name> -n gs
```

### Step 5: Check Pod Events and Logs

```bash
# Check pod events for mount errors
kubectl describe pod <pod-name> -n gs

# Look for errors like:
# - "FailedMount"
# - "provider not found"
# - "AccessDeniedException"
# - "SecretNotFound"

# Check pod logs
kubectl logs <pod-name> -n gs
```

### Step 6: Verify IAM Permissions

```bash
# Check if pod has IAM role annotation
kubectl get pod <pod-name> -n gs -o yaml | grep eks.amazonaws.com/role-arn

# Check service account
kubectl get sa -n gs -o yaml | grep eks.amazonaws.com/role-arn
```

## Common Issues and Solutions

### Issue 1: Secrets Not Created (No Pod Mounting)

**Symptom**: SecretProviderClass exists but no secrets in namespace

**Cause**: No pod is mounting the CSI volume yet

**Solution**: Create a pod that mounts the volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-secrets-mount
  namespace: gs
spec:
  serviceAccountName: <your-service-account>  # Must have IAM role annotation
  containers:
  - name: app
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
        secretProviderClass: "edm-app-gold100-spc"
```

After the pod starts successfully, check:
```bash
kubectl get secrets -n gs | grep edm-gold100
```

### Issue 2: Provider Not Found

**Symptom**: Pod events show `provider not found: provider "aws"`

**Cause**: AWS Secrets Manager Provider not installed

**Solution**: Deploy the AWS provider:
```bash
# Via GitLab CI/CD
# Run job: deploy:secrets-store-provider-aws:dev

# Or via Helm
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
```

Then restart CSI driver:
```bash
kubectl rollout restart daemonset/secrets-store-csi-driver -n secrets-store-csi-driver
```

### Issue 3: AccessDeniedException

**Symptom**: Pod logs show `AccessDeniedException: User is not authorized`

**Cause**: IAM role doesn't have permissions or not attached to pod

**Solution**:

1. **Verify service account has IAM role annotation:**
```bash
kubectl get sa <service-account-name> -n gs -o yaml

# Should show:
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/YourRole
```

2. **Add annotation if missing:**
```bash
kubectl annotate sa <service-account-name> -n gs \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/YourRole
```

3. **Verify IAM role has correct permissions:**
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
      "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:*"
    }
  ]
}
```

4. **Verify IAM role trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:gs:<service-account-name>"
        }
      }
    }
  ]
}
```

### Issue 4: Secret Not Found in AWS

**Symptom**: Pod logs show `ResourceNotFoundException: Secrets Manager can't find the specified secret`

**Cause**: Secret doesn't exist in AWS Secrets Manager or wrong name/region

**Solution**:

1. **Verify secret exists in AWS:**
```bash
aws secretsmanager list-secrets --region us-east-1 | grep edm-gold100
```

2. **Check specific secret:**
```bash
aws secretsmanager describe-secret \
  --secret-id edm-gold100-certificate-passphrase-secret \
  --region us-east-1
```

3. **Verify region in SecretProviderClass matches:**
```yaml
spec:
  parameters:
    region: "us-east-1"  # Must match where secrets are stored
```

### Issue 5: JMESPath Errors

**Symptom**: Secrets mount but values are wrong or empty

**Cause**: Incorrect JMESPath expressions

**Solution**:

1. **Check secret structure in AWS:**
```bash
aws secretsmanager get-secret-value \
  --secret-id edm-gold100-certificate-passphrase-secret \
  --region us-east-1 \
  --query SecretString \
  --output text
```

2. **For simple string secrets (not JSON):**
```yaml
- objectName: "edm-gold100-certificate-passphrase-secret"
  objectType: secretsmanager
  # Don't use jmesPath for simple string secrets
```

3. **For JSON secrets:**
```yaml
- objectName: "edm-gold100-certificate-passphrase-secret"
  objectType: secretsmanager
  jmesPath:
    - path: Certificate_identityKeyStorePassphrase  # JSON key
      objectAlias: Certificate_identityKeyStorePassphrase
```

### Issue 6: Secrets Created But Values Wrong

**Symptom**: Kubernetes secrets exist but contain wrong data

**Cause**: Mismatch between `objectName` in parameters and `objectName` in secretObjects

**Solution**: Ensure consistency:

```yaml
spec:
  parameters:
    objects: |
      - objectName: "my-secret"
        objectType: secretsmanager
        jmesPath:
          - path: password
            objectAlias: db_password  # ← This is what you reference below
  
  secretObjects:
  - secretName: my-k8s-secret
    type: Opaque
    data:
    - key: password
      objectName: db_password  # ← Must match objectAlias above
```

## Verification Checklist

Use this checklist to verify everything is working:

- [ ] AWS Secrets Manager Provider DaemonSet is running
- [ ] SecretProviderClass is created in correct namespace
- [ ] Pod is created with CSI volume mount
- [ ] Pod's service account has IAM role annotation
- [ ] IAM role has correct permissions for Secrets Manager
- [ ] IAM role trust policy allows the service account
- [ ] Secrets exist in AWS Secrets Manager in correct region
- [ ] Pod successfully started (check `kubectl get pods`)
- [ ] Pod mounted the volume (check `kubectl describe pod`)
- [ ] Kubernetes secrets are created (check `kubectl get secrets`)

## Testing Your SecretProviderClass

Create a test pod to verify everything works:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-edm-secrets
  namespace: gs
spec:
  serviceAccountName: <your-service-account>  # Replace with actual SA
  containers:
  - name: test
    image: busybox:latest
    command:
      - sh
      - -c
      - |
        echo "Checking mounted secrets..."
        ls -la /mnt/secrets/
        echo "---"
        cat /mnt/secrets/Certificate_identityKeyStorePassphrase || echo "File not found"
        echo "---"
        echo "Sleeping..."
        sleep 3600
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
        secretProviderClass: "edm-app-gold100-spc"
```

Deploy and check:
```bash
kubectl apply -f test-pod.yaml

# Wait for pod to start
kubectl wait --for=condition=Ready pod/test-edm-secrets -n gs --timeout=60s

# Check if secrets were created
kubectl get secrets -n gs | grep edm-gold100

# Check mounted files
kubectl exec test-edm-secrets -n gs -- ls -la /mnt/secrets/

# Check logs
kubectl logs test-edm-secrets -n gs
```

## Quick Debug Commands

```bash
# 1. Check provider is running
kubectl get daemonset -n secrets-store-csi-driver secrets-store-csi-driver-provider-aws

# 2. Check provider logs
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws --tail=100

# 3. Check CSI driver logs
kubectl logs -n secrets-store-csi-driver -l app=secrets-store-csi-driver --tail=100

# 4. Check SecretProviderClass
kubectl describe secretproviderclass edm-app-gold100-spc -n gs

# 5. Check pod mounting the volume
kubectl get pods -n gs
kubectl describe pod <pod-name> -n gs

# 6. Check secrets
kubectl get secrets -n gs | grep edm-gold100

# 7. Test IAM role from pod
kubectl exec <pod-name> -n gs -- env | grep AWS
kubectl exec <pod-name> -n gs -- aws sts get-caller-identity

# 8. Check service account
kubectl get sa -n gs -o yaml | grep -A 5 annotations
```

## Next Steps

1. **Verify AWS provider is installed** - Most common issue
2. **Create a test pod** that mounts the CSI volume
3. **Check pod events** for mount errors
4. **Verify IAM permissions** if you see access denied errors
5. **Check AWS secrets exist** in the correct region

## Related Documentation

- [AWS Secrets Manager Provider Setup](./AWS-SECRETS-MANAGER-PROVIDER-SETUP.md)
- [Secrets Store AWS Provider Fix](./SECRETS-STORE-AWS-PROVIDER-FIX.md)
- [Usage Examples](../examples/secrets-store-csi-driver-usage.yaml)
- [Official Troubleshooting](https://secrets-store-csi-driver.sigs.k8s.io/troubleshooting.html)
