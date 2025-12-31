# External DNS Examples and Testing

## Overview

External DNS automatically creates and manages DNS records in Route53 based on Kubernetes resources (Ingress, Service). These examples demonstrate how to test and verify External DNS functionality with various configurations.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Route53                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Hosted Zone: example.com                              │ │
│  │  • app.example.com    → ALB DNS                        │ │
│  │  • api.example.com    → ALB DNS                        │ │
│  │  • service.example.com → NLB DNS                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ Create/Update/Delete DNS Records
                              │
┌─────────────────────────────┼───────────────────────────────┐
│                    External DNS Controller                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • Watches Ingress resources                           │ │
│  │  • Watches Service resources (LoadBalancer)            │ │
│  │  • Extracts hostnames from annotations                 │ │
│  │  • Creates A/CNAME records in Route53                  │ │
│  │  • Updates records when endpoints change               │ │
│  │  • Deletes records when resources are removed          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Resources                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Ingress with external-dns.alpha.kubernetes.io/hostname│ │
│  │  Service (LoadBalancer) with annotations               │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Examples in This Directory

### 1. Basic Ingress DNS (`01-basic-ingress-dns.yaml`)
Simple Ingress with External DNS creating Route53 records

### 2. Multiple Hostnames (`02-multiple-hostnames.yaml`)
Single Ingress with multiple DNS records

### 3. Service LoadBalancer DNS (`03-service-loadbalancer-dns.yaml`)
External DNS with Service type LoadBalancer (NLB)

### 4. Wildcard DNS (`04-wildcard-dns.yaml`)
Wildcard DNS records for dynamic subdomains

### 5. Private Hosted Zone (`05-private-hosted-zone.yaml`)
DNS records in private Route53 hosted zone

### 6. TTL and Record Type Control (`06-ttl-record-control.yaml`)
Custom TTL and record type configuration

### 7. DNS Ownership (`07-dns-ownership.yaml`)
TXT record ownership for multi-tenant scenarios

### 8. Testing and Verification (`08-testing-verification.yaml`)
Complete testing scenarios with verification commands

## Prerequisites

### Required

1. **External DNS installed** in your cluster
   ```bash
   kubectl get deployment -n external-dns external-dns
   ```

2. **Route53 Hosted Zone** configured
   ```bash
   aws route53 list-hosted-zones
   ```

3. **IAM Permissions** for External DNS:
   - `route53:ChangeResourceRecordSets`
   - `route53:ListResourceRecordSets`
   - `route53:ListHostedZones`

4. **Domain ownership** verified in Route53

### Optional

- AWS Load Balancer Controller (for Ingress examples)
- Certificate Manager certificates (for HTTPS)

## Quick Start

### Step 1: Verify External DNS Installation

```bash
# Check External DNS deployment
kubectl get deployment -n external-dns external-dns

# Check logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# Verify configuration
kubectl get deployment -n external-dns external-dns -o yaml | grep -A 10 args
```

### Step 2: Get Your Hosted Zone ID

```bash
# List hosted zones
aws route53 list-hosted-zones

# Get specific zone
ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='example.com.'].Id" \
  --output text | cut -d'/' -f3)

echo "Hosted Zone ID: $ZONE_ID"
```

### Step 3: Deploy Test Application

```bash
# Deploy basic example
kubectl apply -f 01-basic-ingress-dns.yaml

# Wait for Ingress to get ALB
kubectl get ingress test-app-ingress -w

# Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20
```

### Step 4: Verify DNS Record Creation

```bash
# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='test-app.example.com.']"

# Test DNS resolution
nslookup test-app.example.com

# Test with dig
dig test-app.example.com
```

## Common Annotations

### External DNS Annotations

```yaml
annotations:
  # Hostname for DNS record
  external-dns.alpha.kubernetes.io/hostname: app.example.com
  
  # Multiple hostnames (comma-separated)
  external-dns.alpha.kubernetes.io/hostname: app.example.com,www.example.com
  
  # Custom TTL (default: 300)
  external-dns.alpha.kubernetes.io/ttl: "60"
  
  # Record type (A, CNAME, TXT)
  external-dns.alpha.kubernetes.io/record-type: CNAME
  
  # Target hostname (for CNAME)
  external-dns.alpha.kubernetes.io/target: alb-xxxxx.us-east-1.elb.amazonaws.com
  
  # Ownership ID (for multi-tenant)
  external-dns.alpha.kubernetes.io/owner-id: my-cluster
  
  # Internal hostname (private hosted zone)
  external-dns.alpha.kubernetes.io/internal-hostname: app.internal.example.com
```

### AWS Load Balancer Controller Annotations

```yaml
annotations:
  # ALB configuration
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
  
  # Group for shared ALB
  alb.ingress.kubernetes.io/group.name: shared-alb
```

## Testing Scenarios

### Scenario 1: Basic DNS Creation

```bash
# 1. Deploy application
kubectl apply -f 01-basic-ingress-dns.yaml

# 2. Wait for ALB creation
kubectl get ingress test-app-ingress -w

# 3. Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep test-app

# 4. Verify DNS record
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='test-app.example.com.']"

# 5. Test resolution
nslookup test-app.example.com

# 6. Test HTTP access
curl http://test-app.example.com
```

### Scenario 2: DNS Update on Change

```bash
# 1. Deploy initial version
kubectl apply -f 01-basic-ingress-dns.yaml

# 2. Note current ALB DNS
ALB_DNS=$(kubectl get ingress test-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Current ALB: $ALB_DNS"

# 3. Update Ingress (change annotation or recreate)
kubectl annotate ingress test-app-ingress test=update --overwrite

# 4. Check if DNS record updated
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='test-app.example.com.'].ResourceRecords"
```

### Scenario 3: DNS Deletion

```bash
# 1. Deploy application
kubectl apply -f 01-basic-ingress-dns.yaml

# 2. Verify DNS exists
nslookup test-app.example.com

# 3. Delete Ingress
kubectl delete -f 01-basic-ingress-dns.yaml

# 4. Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20

# 5. Verify DNS record deleted
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='test-app.example.com.']"

# 6. Test resolution (should fail)
nslookup test-app.example.com
```

### Scenario 4: Multiple Hostnames

```bash
# 1. Deploy with multiple hostnames
kubectl apply -f 02-multiple-hostnames.yaml

# 2. Verify all DNS records created
for hostname in app.example.com www.example.com api.example.com; do
  echo "Checking $hostname..."
  nslookup $hostname
done

# 3. Check Route53
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?contains(Name, 'example.com')]"
```

### Scenario 5: Service LoadBalancer

```bash
# 1. Deploy Service with LoadBalancer
kubectl apply -f 03-service-loadbalancer-dns.yaml

# 2. Wait for NLB creation
kubectl get svc test-nlb-service -w

# 3. Get NLB DNS
NLB_DNS=$(kubectl get svc test-nlb-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "NLB DNS: $NLB_DNS"

# 4. Verify DNS record
nslookup service.example.com

# 5. Test connectivity
curl http://service.example.com
```

## Verification Commands

### Check External DNS Status

```bash
# View External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=100

# Follow logs in real-time
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f

# Check for errors
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep -i error

# Check specific domain
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep "example.com"
```

### Check Route53 Records

```bash
# List all records in hosted zone
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID

# Filter by name
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='app.example.com.']"

# Show only A records
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Type=='A']"

# Show records with TTL
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[*].[Name,Type,TTL]" \
  --output table
```

### Test DNS Resolution

```bash
# Using nslookup
nslookup app.example.com

# Using dig (more detailed)
dig app.example.com

# Check specific DNS server
dig @8.8.8.8 app.example.com

# Check TTL
dig app.example.com | grep -A 1 "ANSWER SECTION"

# Trace DNS resolution
dig +trace app.example.com
```

### Test HTTP/HTTPS Access

```bash
# Test HTTP
curl -v http://app.example.com

# Test HTTPS
curl -v https://app.example.com

# Test with specific Host header
curl -H "Host: app.example.com" http://<alb-dns-name>

# Check response headers
curl -I https://app.example.com
```

## Troubleshooting

### DNS Records Not Created

**Check External DNS logs:**
```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50
```

**Common issues:**
1. **Missing annotation**
   - Verify `external-dns.alpha.kubernetes.io/hostname` exists
   
2. **IAM permissions**
   - Check External DNS has Route53 permissions
   
3. **Hosted zone not found**
   - Verify domain matches hosted zone
   - Check External DNS `--domain-filter` configuration
   
4. **Ingress has no LoadBalancer**
   - Wait for ALB creation
   - Check AWS Load Balancer Controller logs

### DNS Records Not Updating

**Check if External DNS sees the change:**
```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep -A 5 "Desired change"
```

**Common issues:**
1. **Registry cache**
   - External DNS caches state
   - Wait for sync interval (default: 1 minute)
   
2. **Ownership conflict**
   - Check TXT records for ownership
   - Verify `--txt-owner-id` matches

### DNS Resolution Fails

**Check DNS propagation:**
```bash
# Check Route53 directly
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name=='app.example.com.']"

# Check with different DNS servers
dig @8.8.8.8 app.example.com
dig @1.1.1.1 app.example.com

# Check TTL and wait
dig app.example.com | grep TTL
```

**Common issues:**
1. **DNS propagation delay**
   - Wait for TTL to expire
   - Check with authoritative nameserver
   
2. **Wrong hosted zone**
   - Verify domain in correct hosted zone
   - Check public vs private zone

### External DNS Not Running

```bash
# Check deployment
kubectl get deployment -n external-dns external-dns

# Check pod status
kubectl get pods -n external-dns

# Describe pod for events
kubectl describe pod -n external-dns -l app.kubernetes.io/name=external-dns

# Check for CrashLoopBackOff
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --previous
```

## Best Practices

### 1. Use Specific Hostnames

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: app.example.com
  # Not: *.example.com (unless intentional)
```

### 2. Set Appropriate TTL

```yaml
annotations:
  external-dns.alpha.kubernetes.io/ttl: "60"  # Short TTL for testing
  # external-dns.alpha.kubernetes.io/ttl: "300"  # Default for production
```

### 3. Use Ownership IDs

```yaml
annotations:
  external-dns.alpha.kubernetes.io/owner-id: production-cluster
```

### 4. Monitor External DNS

```bash
# Set up CloudWatch logs
# Create alerts for errors
# Monitor DNS record count
```

### 5. Test Before Production

```bash
# Use test subdomain first
# Verify DNS creation/deletion
# Test failover scenarios
```

### 6. Document DNS Records

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app.example.com
    description: "Main application endpoint"
    owner: "platform-team"
```

## Integration with ALB

### Complete Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    # External DNS
    external-dns.alpha.kubernetes.io/hostname: app.example.com
    external-dns.alpha.kubernetes.io/ttl: "300"
    
    # AWS Load Balancer Controller
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
```

## Additional Resources

- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [External DNS AWS Provider](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

