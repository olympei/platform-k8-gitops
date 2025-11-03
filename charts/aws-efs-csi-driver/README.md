# AWS EFS CSI Driver

This directory contains the AWS EFS CSI Driver chart (.tgz) and configuration values for deployment.

## Files

- `aws-efs-csi-driver-3.2.4.tgz` - The Helm chart package
- `values-dev.yaml` - Development environment configuration
- `values-prod.yaml` - Production environment configuration

## Deployment

Deploy directly from the .tgz file without needing a wrapper chart:

### Development Environment

```bash
helm upgrade --install aws-efs-csi-driver \
  charts/aws-efs-csi-driver/charts/aws-efs-csi-driver-3.2.4.tgz \
  -n kube-system \
  --create-namespace \
  -f charts/aws-efs-csi-driver/values-dev.yaml
```

### Production Environment

```bash
helm upgrade --install aws-efs-csi-driver \
  charts/aws-efs-csi-driver/charts/aws-efs-csi-driver-3.2.4.tgz \
  -n kube-system \
  --create-namespace \
  -f charts/aws-efs-csi-driver/values-prod.yaml
```

## Configuration

Before deploying, update the values files with your IAM role ARNs:

**Required fields:**
- `controller.serviceAccount.annotations.eks.amazonaws.com/role-arn` - IAM role ARN for controller
- `node.serviceAccount.annotations.eks.amazonaws.com/role-arn` - IAM role ARN for node

### Authentication Methods

The chart supports two authentication methods:

#### 1. Pod Identity (Recommended for EKS 1.24+)

```yaml
authMethod: "pod-identity"

controller:
  serviceAccount:
    annotations:
      eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::123456789012:role/EKS-EFS-CSI-DriverRole-prod"

podIdentity:
  enabled: true
  roleArn: "arn:aws:iam::123456789012:role/EKS-EFS-CSI-DriverRole-prod"
```

#### 2. IRSA (Legacy method)

```yaml
authMethod: "irsa"

controller:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-EFS-CSI-DriverRole-prod"
```

## Verification

Check the deployment:

```bash
# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-efs-csi-driver

# Check node daemonset
kubectl get daemonset -n kube-system efs-csi-node

# Check CSI driver
kubectl get csidrivers

# Check logs
kubectl logs -n kube-system -l app=efs-csi-controller --tail=50
```

## Usage Example

### Create StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
```

### Create PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

### Use in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: efs-claim
```

## Prerequisites

1. **EFS File System** - Create an EFS file system in your VPC
2. **Security Groups** - Configure security groups to allow NFS traffic (port 2049)
3. **IAM Role** - Create IAM role with EFS permissions (see `iam/aws-efs-csi-driver-policy.json`)
4. **Mount Targets** - Ensure EFS has mount targets in your subnets

## Uninstall

```bash
helm uninstall aws-efs-csi-driver -n kube-system
```

## IAM Configuration

The IAM policy and Terraform configuration are located in:
- IAM Policy: `iam/aws-efs-csi-driver-policy.json`
- Terraform: `terraform/locals.tf` (includes service account and role configuration)

## Troubleshooting

### Pods stuck in ContainerCreating

Check if EFS mount targets are accessible:
```bash
kubectl describe pod <pod-name>
kubectl logs -n kube-system -l app=efs-csi-node
```

### Permission denied errors

Verify IAM role permissions and service account annotations:
```bash
kubectl get sa efs-csi-controller-sa -n kube-system -o yaml
kubectl get sa efs-csi-node-sa -n kube-system -o yaml
```

### Mount failures

Check security group rules allow NFS traffic from EKS nodes:
```bash
# Security group should allow inbound port 2049 from node security group
```

## References

- [AWS EFS CSI Driver Documentation](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [EFS User Guide](https://docs.aws.amazon.com/efs/latest/ug/)
- [Helm Chart Repository](https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/charts/aws-efs-csi-driver)
