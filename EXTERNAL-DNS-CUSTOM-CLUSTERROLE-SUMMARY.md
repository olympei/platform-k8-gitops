# External DNS Custom ClusterRole - Summary

## Overview

Added custom ClusterRole YAML file for External DNS that provides extended RBAC permissions beyond the default Helm chart. This enables External DNS to watch additional resource types including Gateway API, Istio, and various ingress controllers.

## Files Created

### 1. `charts/external-dns/custom-clusterrole.yaml`
Complete RBAC configuration with:
- **Extended ClusterRole**: Permissions for 15+ resource types
- **ClusterRoleBindings**: Binds permissions to External DNS service account
- **CRD Reader Role**: Optional role for reading CRD definitions
- **Namespace Role**: Namespace-scoped permissions for ConfigMaps, Secrets, Leases
- **Inline Documentation**: Usage instructions, security notes, troubleshooting

### 2. `charts/external-dns/CUSTOM-CLUSTERROLE-GUIDE.md`
Comprehensive deployment and usage guide covering:
- What's included in the custom ClusterRole
- 4 different deployment methods
- Verification steps and commands
- Customization instructions
- Use cases and examples
- Troubleshooting guide
- Security best practices
- CI/CD integration examples

### 3. Updated `charts/external-dns/DEPLOYMENT-COMMANDS.md`
Added custom ClusterRole deployment steps to existing deployment commands.

## Key Features

### Extended Permissions

The custom ClusterRole provides permissions to watch:

**Standard Resources:**
- Services, Endpoints, Pods, Nodes, Ingresses

**Gateway API (Kubernetes Gateway API):**
- Gateways, HTTPRoutes, TLSRoutes, TCPRoutes, UDPRoutes, GRPCRoutes

**Service Mesh & Ingress Controllers:**
- Istio: Gateways, VirtualServices
- Contour: HTTPProxies
- Ambassador: Hosts, Mappings
- Traefik: IngressRoutes (HTTP, TCP, UDP)
- F5: VirtualServers
- OpenShift: Routes
- Kong: TCPIngresses
- Gloo Edge: Proxies, VirtualServices
- Skipper: RouteGroups

**Custom Resources:**
- DNSEndpoint CRD for custom DNS management
- CustomResourceDefinitions (for discovery)

**Additional Permissions:**
- Event creation (for debugging)
- ConfigMaps and Secrets (namespace-scoped)
- Leases (for leader election in multi-replica setups)


## Deployment

### Quick Start

```bash
# 1. Apply custom ClusterRole
kubectl apply -f charts/external-dns/custom-clusterrole.yaml

# 2. Deploy External DNS with Helm
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns \
  --create-namespace

# 3. Verify permissions
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

### Deployment Methods

1. **With Helm Release** (Recommended)
   - Deploy Helm chart first
   - Apply custom ClusterRole after
   - No restart needed

2. **Before Helm Release**
   - Create namespace
   - Apply custom ClusterRole
   - Deploy Helm chart

3. **GitOps (ArgoCD/Flux)**
   - Include in Application manifest
   - Use PreSync hook
   - Automatic synchronization

4. **Kustomize**
   - Combine with Helm chart
   - Single deployment command

## Use Cases

### 1. Gateway API Support
Enable External DNS to create DNS records for Gateway API resources:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: gateway.example.com
```

### 2. Istio Integration
Watch Istio VirtualServices for DNS management:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app.example.com
```

### 3. DNSEndpoint CRD
Custom DNS management without Ingress/Service:
```yaml
apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: custom-dns
spec:
  endpoints:
    - dnsName: custom.example.com
      recordType: A
      targets: ["192.0.2.1"]
```

### 4. Multi-Replica High Availability
Leader election for multiple External DNS replicas:
```yaml
replicaCount: 3
extraArgs:
  - --leader-election=true
```

## Verification

### Check ClusterRole
```bash
kubectl get clusterrole external-dns-extended
kubectl get clusterrolebinding external-dns-extended
```

### Test Permissions
```bash
# Gateway API
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Istio
kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns

# DNSEndpoint
kubectl auth can-i list dnsendpoints.externaldns.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

### Check Logs
```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns \
  | grep -i "watching\|source"
```

## Security

### Least Privilege
- Only read permissions (get, list, watch)
- No write permissions to cluster resources
- No delete permissions
- DNS changes only via AWS IAM

### Namespace Isolation
- ClusterRole for cluster-wide resources
- Role for namespace-specific resources
- Separate bindings for each scope

### Audit Trail
- Event creation for debugging
- TXT records for ownership tracking
- CloudWatch integration for monitoring

## Customization

### Change Namespace
```bash
sed -i 's/namespace: external-dns/namespace: kube-system/g' \
  charts/external-dns/custom-clusterrole.yaml
```

### Change Service Account
```bash
sed -i 's/name: external-dns/name: my-sa/g' \
  charts/external-dns/custom-clusterrole.yaml
```

### Add Custom Resources
Edit `custom-clusterrole.yaml` and add:
```yaml
- apiGroups: ["your-api.example.com"]
  resources: ["yourcustomresources"]
  verbs: ["get", "list", "watch"]
```

### Remove Unused Permissions
Comment out or remove unused apiGroups sections for ingress controllers you don't use.

## Troubleshooting

### Permission Denied
```bash
# Check ClusterRoleBinding
kubectl get clusterrolebinding external-dns-extended -o yaml

# Verify service account
kubectl get sa -n external-dns external-dns

# Reapply ClusterRole
kubectl apply -f charts/external-dns/custom-clusterrole.yaml
```

### Can't Watch Resources
```bash
# Check if CRDs exist
kubectl get crd gateways.gateway.networking.k8s.io

# Test permissions
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Check logs for errors
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns \
  | grep -i "forbidden\|unauthorized"
```

## Integration with Existing Setup

### Compatible With
- ✓ Existing External DNS Helm deployments
- ✓ IRSA (IAM Roles for Service Accounts)
- ✓ EKS Pod Identity
- ✓ Multi-cluster setups
- ✓ GitOps workflows (ArgoCD, Flux)

### No Impact On
- Existing DNS records
- Current RBAC from Helm chart
- IAM permissions
- Route53 configuration

### Adds Support For
- Gateway API resources
- Istio service mesh
- Additional ingress controllers
- Custom DNS management via CRD
- Multi-replica leader election

## Best Practices

1. **Deploy After Testing**
   - Test in dev environment first
   - Verify permissions with `kubectl auth can-i`
   - Check External DNS logs

2. **Use Least Privilege**
   - Remove unused resource types
   - Only add permissions you need
   - Regular permission audits

3. **Document Changes**
   - Note which resources you're watching
   - Document custom modifications
   - Include in runbooks

4. **Monitor Access**
   - Enable audit logging
   - Monitor External DNS logs
   - Alert on permission errors

5. **Version Control**
   - Keep custom-clusterrole.yaml in Git
   - Track changes over time
   - Use GitOps for deployment

## Maintenance

### Updating Permissions
```bash
# Edit file
vim charts/external-dns/custom-clusterrole.yaml

# Apply changes
kubectl apply -f charts/external-dns/custom-clusterrole.yaml

# No restart needed - RBAC changes apply immediately
```

### Removing Custom ClusterRole
```bash
# Delete bindings
kubectl delete clusterrolebinding external-dns-extended
kubectl delete clusterrolebinding external-dns-crd-reader

# Delete roles
kubectl delete clusterrole external-dns-extended
kubectl delete clusterrole external-dns-crd-reader

# Delete namespace resources
kubectl delete role external-dns-namespace -n external-dns
kubectl delete rolebinding external-dns-namespace -n external-dns
```

## Documentation

- **Deployment Guide**: `charts/external-dns/CUSTOM-CLUSTERROLE-GUIDE.md`
- **YAML File**: `charts/external-dns/custom-clusterrole.yaml`
- **Deployment Commands**: `charts/external-dns/DEPLOYMENT-COMMANDS.md`

## Additional Resources

- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Istio External DNS](https://istio.io/latest/docs/tasks/traffic-management/ingress/)

## Conclusion

The custom ClusterRole extends External DNS capabilities to support modern Kubernetes networking patterns including Gateway API and service meshes, while maintaining security through least-privilege RBAC. It's optional but recommended for environments using these technologies.

