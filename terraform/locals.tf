locals {
  # Service account configurations for each add-on
  service_accounts = {
    efs-csi-controller = {
      addon_name      = "aws-efs-csi-driver"
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
      policy_name     = "EKS-EFS-CSI-DriverPolicy"
      role_name       = "EKS-EFS-CSI-DriverRole"
    }
    efs-csi-node = {
      addon_name      = "aws-efs-csi-driver"
      namespace       = "kube-system"
      service_account = "efs-csi-node-sa"
      policy_name     = "EKS-EFS-CSI-DriverPolicy"
      role_name       = "EKS-EFS-CSI-DriverRole"
    }
    external-secrets = {
      addon_name      = "external-secrets-operator"
      namespace       = "external-secrets-system"
      service_account = "external-secrets-sa"
      policy_name     = "EKS-ExternalSecrets-Policy"
      role_name       = "EKS-ExternalSecrets-Role"
    }
    ingress-nginx = {
      addon_name      = "ingress-nginx"
      namespace       = "ingress-nginx"
      service_account = "ingress-nginx"
      policy_name     = "EKS-IngressNginx-Policy"
      role_name       = "EKS-IngressNginx-Role"
    }
    pod-identity-agent = {
      addon_name      = "pod-identity"
      namespace       = "kube-system"
      service_account = "eks-pod-identity-agent"
      policy_name     = "EKS-PodIdentity-Policy"
      role_name       = "EKS-PodIdentity-Role"
    }
    secrets-store-csi-driver = {
      addon_name      = "secrets-store-csi-driver"
      namespace       = "kube-system"
      service_account = "csi-secrets-store-provider-aws"
      policy_name     = "EKS-SecretsStore-Policy"
      role_name       = "EKS-SecretsStore-Role"
    }
    cluster-autoscaler = {
      addon_name      = "cluster-autoscaler"
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
      policy_name     = "EKS-ClusterAutoscaler-Policy"
      role_name       = "EKS-ClusterAutoscaler-Role"
    }
    metrics-server = {
      addon_name      = "metrics-server"
      namespace       = "kube-system"
      service_account = "metrics-server"
      policy_name     = "EKS-MetricsServer-Policy"
      role_name       = "EKS-MetricsServer-Role"
    }
    external-dns = {
      addon_name      = "external-dns"
      namespace       = "external-dns"
      service_account = "external-dns"
      policy_name     = "EKS-ExternalDNS-Policy"
      role_name       = "EKS-ExternalDNS-Role"
    }
    aws-load-balancer-controller = {
      addon_name      = "aws-load-balancer-controller"
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      policy_name     = "EKS-AWSLoadBalancerController-Policy"
      role_name       = "EKS-AWSLoadBalancerController-Role"
    }
  }

  # Unique policies (some service accounts share the same policy)
  unique_policies = {
    "EKS-EFS-CSI-DriverPolicy" = {
      name        = "EKS-EFS-CSI-DriverPolicy"
      description = "Policy for AWS EFS CSI Driver"
      policy_file = "aws-efs-csi-driver-policy.json"
    }
    "EKS-ExternalSecrets-Policy" = {
      name        = "EKS-ExternalSecrets-Policy"
      description = "Policy for External Secrets Operator"
      policy_file = "external-secrets-operator-policy.json"
    }
    "EKS-IngressNginx-Policy" = {
      name        = "EKS-IngressNginx-Policy"
      description = "Policy for Ingress NGINX Controller"
      policy_file = "ingress-nginx-policy.json"
    }
    "EKS-PodIdentity-Policy" = {
      name        = "EKS-PodIdentity-Policy"
      description = "Policy for Pod Identity Agent"
      policy_file = "pod-identity-policy.json"
    }
    "EKS-SecretsStore-Policy" = {
      name        = "EKS-SecretsStore-Policy"
      description = "Policy for Secrets Store CSI Driver"
      policy_file = "secrets-store-csi-driver-policy.json"
    }
    "EKS-ClusterAutoscaler-Policy" = {
      name        = "EKS-ClusterAutoscaler-Policy"
      description = "Policy for Cluster Autoscaler"
      policy_file = "cluster-autoscaler-policy.json"
    }
    "EKS-MetricsServer-Policy" = {
      name        = "EKS-MetricsServer-Policy"
      description = "Policy for Metrics Server"
      policy_file = "metrics-server-policy.json"
    }
    "EKS-ExternalDNS-Policy" = {
      name        = "EKS-ExternalDNS-Policy"
      description = "Policy for External DNS"
      policy_file = "external-dns-policy.json"
    }
    "EKS-AWSLoadBalancerController-Policy" = {
      name        = "EKS-AWSLoadBalancerController-Policy"
      description = "Policy for AWS Load Balancer Controller"
      policy_file = "aws-load-balancer-controller-policy.json"
    }
  }

  # Unique roles (some service accounts share the same role)
  unique_roles = {
    "EKS-EFS-CSI-DriverRole" = {
      name         = "EKS-EFS-CSI-DriverRole"
      description  = "Role for AWS EFS CSI Driver"
      policy_names = ["EKS-EFS-CSI-DriverPolicy"]
    }
    "EKS-ExternalSecrets-Role" = {
      name         = "EKS-ExternalSecrets-Role"
      description  = "Role for External Secrets Operator"
      policy_names = ["EKS-ExternalSecrets-Policy"]
    }
    "EKS-IngressNginx-Role" = {
      name         = "EKS-IngressNginx-Role"
      description  = "Role for Ingress NGINX Controller"
      policy_names = ["EKS-IngressNginx-Policy"]
    }
    "EKS-PodIdentity-Role" = {
      name         = "EKS-PodIdentity-Role"
      description  = "Role for Pod Identity Agent"
      policy_names = ["EKS-PodIdentity-Policy"]
    }
    "EKS-SecretsStore-Role" = {
      name         = "EKS-SecretsStore-Role"
      description  = "Role for Secrets Store CSI Driver"
      policy_names = ["EKS-SecretsStore-Policy"]
    }
    "EKS-ClusterAutoscaler-Role" = {
      name         = "EKS-ClusterAutoscaler-Role"
      description  = "Role for Cluster Autoscaler"
      policy_names = ["EKS-ClusterAutoscaler-Policy"]
    }
    "EKS-MetricsServer-Role" = {
      name         = "EKS-MetricsServer-Role"
      description  = "Role for Metrics Server"
      policy_names = ["EKS-MetricsServer-Policy"]
    }
    "EKS-ExternalDNS-Role" = {
      name         = "EKS-ExternalDNS-Role"
      description  = "Role for External DNS"
      policy_names = ["EKS-ExternalDNS-Policy"]
    }
    "EKS-AWSLoadBalancerController-Role" = {
      name         = "EKS-AWSLoadBalancerController-Role"
      description  = "Role for AWS Load Balancer Controller"
      policy_names = ["EKS-AWSLoadBalancerController-Policy"]
    }
  }

  # Common tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    Cluster     = var.cluster_name
  })
}