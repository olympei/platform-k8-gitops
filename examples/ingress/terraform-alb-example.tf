# Terraform Configuration for ALB that will be used by Kubernetes Ingress Controller
# This creates an ALB that the AWS Load Balancer Controller can add rules to

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

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_description = "Security group for Terraform-managed ALB"
  vpc_id      = var.vpc_id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "terraform-managed-alb-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "terraform-managed-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  # CRITICAL: This tag tells the AWS Load Balancer Controller which group this ALB belongs to
  # The Ingress resources must use the same group name
  tags = {
    Name                                = "terraform-managed-alb-${var.environment}"
    Environment                         = var.environment
    ManagedBy                          = "terraform"
    "ingress.k8s.aws/stack"            = "terraform-managed-alb"  # IMPORTANT: Group name
    "ingress.k8s.aws/resource"         = "LoadBalancer"
    "elbv2.k8s.aws/cluster"            = "my-eks-cluster"  # Your EKS cluster name
  }
}

# HTTPS Listener (443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.certificate_arn

  # Default action - return 404
  # Kubernetes Ingress will add rules to this listener
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = {
    "ingress.k8s.aws/stack"    = "terraform-managed-alb"
    "ingress.k8s.aws/resource" = "443"
  }
}

# HTTP Listener (80) - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - redirect to HTTPS
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    "ingress.k8s.aws/stack"    = "terraform-managed-alb"
    "ingress.k8s.aws/resource" = "80"
  }
}

# Outputs
output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "ingress_group_name" {
  description = "Group name to use in Kubernetes Ingress annotations"
  value       = "terraform-managed-alb"
}

# Example usage in terraform.tfvars:
# vpc_id             = "vpc-xxxxx"
# public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
# certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
# environment        = "dev"
