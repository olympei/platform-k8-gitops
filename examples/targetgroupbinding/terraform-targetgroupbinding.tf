# Terraform Configuration for ALB with Target Groups for TargetGroupBinding
# This creates infrastructure that Kubernetes TargetGroupBinding will use

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

# Data source for VPC CIDR
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "alb-tgb-${var.environment}-"
  description = "Security group for ALB with TargetGroupBinding"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "alb-tgb-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "alb-tgb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  idle_timeout                     = 60

  tags = {
    Name        = "alb-tgb-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
    Cluster     = var.eks_cluster_name
  }
}

# Target Group for Web Application
resource "aws_lb_target_group" "web_app" {
  name_prefix = "web-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Must match TargetGroupBinding targetType

  # Health check configuration
  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  # Deregistration delay
  deregistration_delay = 30

  # Stickiness (optional)
  stickiness {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  tags = {
    Name                                = "web-app-tg-${var.environment}"
    Environment                         = var.environment
    ManagedBy                          = "terraform"
    "kubernetes.io/service-name"       = "web-service"
    "kubernetes.io/namespace"          = "default"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for API Application
resource "aws_lb_target_group" "api_app" {
  name_prefix = "api-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = {
    Name                                = "api-app-tg-${var.environment}"
    Environment                         = var.environment
    ManagedBy                          = "terraform"
    "kubernetes.io/service-name"       = "api-service"
    "kubernetes.io/namespace"          = "default"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.certificate_arn

  # Default action - return 404
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = {
    Name        = "https-listener-${var.environment}"
    Environment = var.environment
  }
}

# HTTP Listener - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name        = "http-listener-${var.environment}"
    Environment = var.environment
  }
}

# Listener Rule for Web App (app.example.com)
resource "aws_lb_listener_rule" "web_app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app.arn
  }

  condition {
    host_header {
      values = ["app.example.com", "www.example.com"]
    }
  }

  tags = {
    Name        = "web-app-rule-${var.environment}"
    Environment = var.environment
  }
}

# Listener Rule for API App (api.example.com)
resource "aws_lb_listener_rule" "api_app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 90

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_app.arn
  }

  condition {
    host_header {
      values = ["api.example.com"]
    }
  }

  tags = {
    Name        = "api-app-rule-${var.environment}"
    Environment = var.environment
  }
}

# Listener Rule for API Path-based routing
resource "aws_lb_listener_rule" "api_path" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 95

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_app.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = {
    Name        = "api-path-rule-${var.environment}"
    Environment = var.environment
  }
}

# Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB for Route53"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "web_target_group_arn" {
  description = "ARN of the web app target group - Use this in TargetGroupBinding"
  value       = aws_lb_target_group.web_app.arn
}

output "api_target_group_arn" {
  description = "ARN of the API app target group - Use this in TargetGroupBinding"
  value       = aws_lb_target_group.api_app.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# Output for easy copy-paste into Kubernetes manifests
output "targetgroupbinding_config" {
  description = "Configuration values for TargetGroupBinding manifests"
  value = {
    web_target_group_arn     = aws_lb_target_group.web_app.arn
    api_target_group_arn     = aws_lb_target_group.api_app.arn
    alb_security_group_id    = aws_security_group.alb.id
    alb_dns_name             = aws_lb.main.dns_name
  }
}

# Example terraform.tfvars:
# vpc_id             = "vpc-0123456789abcdef0"
# public_subnet_ids  = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
# certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
# environment        = "dev"
# eks_cluster_name   = "my-eks-cluster"

