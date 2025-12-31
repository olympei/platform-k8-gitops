# Custom ClusterRole for External DNS - Deployment Guide

## Overview

The `custom-clusterrole.yaml` file provides extended RBAC permissions for External DNS beyond what the default Helm chart includes. This allows External DNS to watch additional resource types and integrate with various ingress controllers and service meshes.

## What's Included

### 1. Extended ClusterRole (`external-dns-extended`)

Provides permissions to watch:
- **Standard Resources**: Services, Endpoints, Pods, Nodes, Ingresses
- **Gateway API**: Gateways, HTTPRoutes, TLSRoutes, TCPRoutes, UDPRoutes, GRPCRoutes
- **Istio**: Gateways, VirtualServices
- **Contour**: HTTPProxies
- **Ambassador**: Hosts, Mappings
- **Traefik**: IngressRoutes (TCP, UDP)
- **F5**: VirtualServers
- **OpenShift**: Routes
- **Kong**: TCPIngresses
- **Gloo Edge**: Proxies, VirtualServices
- **Skipper**: RouteGroups
- **DNSEndpoint CRD**: Custom DNS endpoint resources

### 2. CRD Reader Role (`external-dns-crd-reader`)

Allows External DNS to:
- Read CustomResourceDefinitions
- Discover available CRDs dynamically
- Support custom integrations

### 3. Namespace Role (`external-dns-namespace`)

Provides namespace-scoped permissions for:
- **ConfigMaps**: Configuration management
- **Secrets**: Credential access (if not using IRSA/Pod Identity)
- **Leases**: Leader election for multi-replica deployments

## Deployment Methods

### Method 1: Deploy with Helm Release (Recommended)

```bash
# 1. Deploy External DNS with Helm
helm install external-dns ./charts/external-dns-1.19.0.tgz \
  -f values-dev-direct.yaml \
  -n external-dns \
  --create-namespace

# 2. Apply custom ClusterRole
kubectl apply -f custom-clusterrole.yaml

# 3. Verify deployment
kubectl get clusterrole external-dns-extended
kubectl get clusterrolebinding external-dns-extended
```

### Method 2: Deploy Before Helm Release

```bash
# 1. Create namespace
kubectl create namespace external-dns

# 2. Apply custom ClusterRole first
kubectl apply -f custom-clusterrole.yaml

# 3. Deploy External DNS with Helm
helm install external-dns ./charts/external-dns-1.19.0.tgz \
  -f values-dev-direct.yaml \
  -n external-dns
```

### Method 3: Include in GitOps (ArgoCD/Flux)

```yaml
# argocd/applications/external-dns.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-dns
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: charts/external-dns
    helm:
      valueFiles:
        - values-dev-direct.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: external-dns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  # Apply custom ClusterRole before Helm chart
  hooks:
    - name: custom-rbac
      kind: PreSync
      manifest: |
        # Include custom-clusterrole.yaml content here
```

### Method 4: Combine with Helm Chart

Create a Kustomization to combine both:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - custom-clusterrole.yaml

helmCharts:
  - name: external-dns
    repo: ./charts
    version: 1.19.0
    releaseName: external-dns
    namespace: external-dns
    valuesFile: values-dev-direct.yaml
```

Deploy with:
```bash
kubectl apply -k .
```

## Verification

### 1. Check ClusterRole Created

```bash
# List all External DNS ClusterRoles
kubectl get clusterrole | grep external-dns

# View extended ClusterRole
kubectl get clusterrole external-dns-extended -o yaml

# View CRD reader ClusterRole
kubectl get clusterrole external-dns-crd-reader -o yaml
```

### 2. Check ClusterRoleBindings

```bash
# List ClusterRoleBindings
kubectl get clusterrolebinding | grep external-dns

# View extended binding
kubectl get clusterrolebinding external-dns-extended -o yaml

# Verify subject (service account)
kubectl get clusterrolebinding external-dns-extended -o jsonpath='{.subjects[0]}'
```

### 3. Test Permissions

```bash
# Test standard resources
kubectl auth can-i list services \
  --as=system:serviceaccount:external-dns:external-dns

kubectl auth can-i list ingresses \
  --as=system:serviceaccount:external-dns:external-dns

# Test Gateway API resources
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

kubectl auth can-i list httproutes.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Test Istio resources
kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns

kubectl auth can-i list gateways.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns

# Test DNSEndpoint CRD
kubectl auth can-i list dnsendpoints.externaldns.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Test event creation
kubectl auth can-i create events \
  --as=system:serviceaccount:external-dns:external-dns
```

### 4. Check External DNS Logs

```bash
# View logs for permission issues
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns \
  | grep -i "forbidden\|unauthorized\|permission"

# View logs for resource watching
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns \
  | grep -i "watching\|source"

# Follow logs in real-time
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f
```

## Customization

### Change Namespace

If deploying External DNS in a different namespace (e.g., `kube-system`):

```bash
# Update custom-clusterrole.yaml
sed -i 's/namespace: external-dns/namespace: kube-system/g' custom-clusterrole.yaml

# Apply
kubectl apply -f custom-clusterrole.yaml
```

### Change Service Account Name

If using a different service account name:

```bash
# Update custom-clusterrole.yaml
sed -i 's/name: external-dns/name: my-external-dns-sa/g' custom-clusterrole.yaml

# Apply
kubectl apply -f custom-clusterrole.yaml
```

### Add Additional Resources

To watch additional custom resources:

```yaml
# Add to ClusterRole rules
- apiGroups:
    - your-custom-api.example.com
  resources:
    - yourcustomresources
  verbs:
    - get
    - list
    - watch
```

### Remove Unnecessary Permissions

If you don't use certain ingress controllers or service meshes:

```bash
# Edit custom-clusterrole.yaml
# Remove or comment out unused apiGroups sections
# For example, if not using Istio:
# - apiGroups:
#     - networking.istio.io
#   resources:
#     - gateways
#     - virtualservices
#   verbs:
#     - get
#     - list
#     - watch
```

## Use Cases

### 1. Gateway API Support

Enable External DNS to watch Gateway API resources:

```yaml
# Gateway API Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  annotations:
    external-dns.alpha.kubernetes.io/hostname: gateway.example.com
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      port: 80
      protocol: HTTP
```

External DNS will create DNS records for the Gateway.

### 2. Istio Integration

Watch Istio VirtualServices:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app.example.com
spec:
  hosts:
    - app.example.com
  gateways:
    - my-gateway
  http:
    - route:
        - destination:
            host: my-service
```

### 3. DNSEndpoint CRD

Use DNSEndpoint for custom DNS management:

```yaml
apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: custom-dns
  namespace: default
spec:
  endpoints:
    - dnsName: custom.example.com
      recordTTL: 300
      recordType: A
      targets:
        - 192.0.2.1
```

### 4. Multi-Replica with Leader Election

For high availability:

```yaml
# values-prod-direct.yaml
replicaCount: 3

extraArgs:
  - --leader-election=true
  - --leader-election-namespace=external-dns
```

The namespace Role provides lease permissions for leader election.

## Troubleshooting

### Issue: Permission Denied Errors

**Symptoms:**
```
Error: services is forbidden: User "system:serviceaccount:external-dns:external-dns" cannot list resource "services"
```

**Solution:**
```bash
# 1. Verify ClusterRoleBinding exists
kubectl get clusterrolebinding external-dns-extended

# 2. Check subject matches
kubectl get clusterrolebinding external-dns-extended -o yaml

# 3. Verify service account exists
kubectl get sa -n external-dns external-dns

# 4. Reapply ClusterRole
kubectl apply -f custom-clusterrole.yaml

# 5. Restart External DNS
kubectl rollout restart deployment -n external-dns external-dns
```

### Issue: Can't Watch Gateway API Resources

**Symptoms:**
```
Error: gateways.gateway.networking.k8s.io is forbidden
```

**Solution:**
```bash
# 1. Check if Gateway API CRDs are installed
kubectl get crd gateways.gateway.networking.k8s.io

# 2. If not installed, install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# 3. Verify permissions
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# 4. Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
```

### Issue: ClusterRoleBinding Not Working

**Symptoms:**
- Permissions still denied after applying ClusterRole

**Solution:**
```bash
# 1. Check if namespace matches
kubectl get clusterrolebinding external-dns-extended -o jsonpath='{.subjects[0].namespace}'
# Should output: external-dns

# 2. Check if service account name matches
kubectl get clusterrolebinding external-dns-extended -o jsonpath='{.subjects[0].name}'
# Should output: external-dns

# 3. Verify service account exists in correct namespace
kubectl get sa external-dns -n external-dns

# 4. If mismatch, update ClusterRoleBinding
kubectl edit clusterrolebinding external-dns-extended
```

### Issue: Events Not Created

**Symptoms:**
- No events visible for External DNS

**Solution:**
```bash
# 1. Check event permissions
kubectl auth can-i create events \
  --as=system:serviceaccount:external-dns:external-dns

# 2. Enable events in External DNS
# Add to values file:
extraArgs:
  - --events

# 3. Upgrade Helm release
helm upgrade external-dns ./charts/external-dns-1.19.0.tgz \
  -f values-dev-direct.yaml \
  -n external-dns

# 4. Check events
kubectl get events -n external-dns
```

## Security Best Practices

### 1. Least Privilege

The custom ClusterRole follows least privilege:
- Only read permissions (get, list, watch)
- No write permissions to cluster resources
- No delete permissions
- DNS changes only via AWS IAM (IRSA/Pod Identity)

### 2. Namespace Isolation

Separate roles for different scopes:
- ClusterRole: Cluster-wide resources
- Role: Namespace-specific resources
- Separate bindings for each

### 3. Regular Audits

Periodically review permissions:

```bash
# List all permissions
kubectl describe clusterrole external-dns-extended

# Check for unused permissions
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns \
  | grep "watching" | sort | uniq

# Remove unused resource types
```

### 4. Monitor Access

Enable audit logging for External DNS:

```yaml
# Kubernetes audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    users:
      - system:serviceaccount:external-dns:external-dns
    verbs: ["get", "list", "watch"]
```

## Maintenance

### Updating Permissions

When adding new resource types:

```bash
# 1. Edit custom-clusterrole.yaml
vim custom-clusterrole.yaml

# 2. Apply changes
kubectl apply -f custom-clusterrole.yaml

# 3. Verify new permissions
kubectl auth can-i list <new-resource> \
  --as=system:serviceaccount:external-dns:external-dns

# 4. No need to restart External DNS (RBAC changes apply immediately)
```

### Removing Custom ClusterRole

If you need to remove the custom permissions:

```bash
# 1. Delete ClusterRoleBindings
kubectl delete clusterrolebinding external-dns-extended
kubectl delete clusterrolebinding external-dns-crd-reader

# 2. Delete ClusterRoles
kubectl delete clusterrole external-dns-extended
kubectl delete clusterrole external-dns-crd-reader

# 3. Delete namespace Role and RoleBinding
kubectl delete role external-dns-namespace -n external-dns
kubectl delete rolebinding external-dns-namespace -n external-dns

# Note: External DNS will fall back to default Helm chart RBAC
```

## Integration with CI/CD

### GitLab CI Example

```yaml
# .gitlab-ci.yml
deploy-external-dns:
  stage: deploy
  script:
    # Apply custom ClusterRole
    - kubectl apply -f charts/external-dns/custom-clusterrole.yaml
    
    # Deploy with Helm
    - helm upgrade --install external-dns ./charts/external-dns-1.19.0.tgz \
        -f charts/external-dns/values-${ENVIRONMENT}-direct.yaml \
        -n external-dns \
        --create-namespace \
        --wait
    
    # Verify permissions
    - kubectl auth can-i list ingresses --as=system:serviceaccount:external-dns:external-dns
```

### GitHub Actions Example

```yaml
# .github/workflows/deploy-external-dns.yml
- name: Apply Custom ClusterRole
  run: |
    kubectl apply -f charts/external-dns/custom-clusterrole.yaml

- name: Deploy External DNS
  run: |
    helm upgrade --install external-dns ./charts/external-dns-1.19.0.tgz \
      -f charts/external-dns/values-${{ env.ENVIRONMENT }}-direct.yaml \
      -n external-dns \
      --create-namespace \
      --wait
```

## Additional Resources

- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Istio External DNS Integration](https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/)

