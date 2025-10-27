# Makefile for EKS Add-ons IAM Terraform

.PHONY: help init plan apply destroy validate fmt lint clean dev prod

# Default environment
ENV ?= dev

# Colors for output
RED    := \033[31m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m
RESET  := \033[0m

help: ## Show this help message
	@echo "$(BLUE)EKS Add-ons IAM Terraform$(RESET)"
	@echo ""
	@echo "$(YELLOW)Usage:$(RESET)"
	@echo "  make <target> [ENV=dev|prod]"
	@echo ""
	@echo "$(YELLOW)Targets:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(RESET)"
	terraform init

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(RESET)"
	terraform validate

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(RESET)"
	terraform fmt -recursive

lint: ## Lint Terraform files
	@echo "$(BLUE)Linting Terraform files...$(RESET)"
	terraform fmt -check -recursive
	terraform validate

plan: ## Plan Terraform deployment
	@echo "$(BLUE)Planning Terraform deployment for $(ENV)...$(RESET)"
	@if [ ! -f "environments/$(ENV).tfvars" ]; then \
		echo "$(RED)Error: environments/$(ENV).tfvars not found$(RESET)"; \
		exit 1; \
	fi
	terraform plan -var-file="environments/$(ENV).tfvars"

apply: ## Apply Terraform configuration
	@echo "$(BLUE)Applying Terraform configuration for $(ENV)...$(RESET)"
	@if [ ! -f "environments/$(ENV).tfvars" ]; then \
		echo "$(RED)Error: environments/$(ENV).tfvars not found$(RESET)"; \
		exit 1; \
	fi
	terraform apply -var-file="environments/$(ENV).tfvars"

destroy: ## Destroy Terraform resources
	@echo "$(RED)Destroying Terraform resources for $(ENV)...$(RESET)"
	@echo "$(YELLOW)This will destroy all resources. Are you sure? [y/N]$(RESET)"
	@read -r REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		terraform destroy -var-file="environments/$(ENV).tfvars"; \
	else \
		echo "$(YELLOW)Aborted.$(RESET)"; \
	fi

output: ## Show Terraform outputs
	@echo "$(BLUE)Terraform outputs for $(ENV):$(RESET)"
	terraform output

dev: ## Quick deploy to dev environment
	@$(MAKE) plan ENV=dev
	@$(MAKE) apply ENV=dev

prod: ## Quick deploy to prod environment
	@$(MAKE) plan ENV=prod
	@$(MAKE) apply ENV=prod

clean: ## Clean Terraform files
	@echo "$(BLUE)Cleaning Terraform files...$(RESET)"
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*
	rm -f *.tfplan

check-vars: ## Check required variables
	@echo "$(BLUE)Checking required variables for $(ENV)...$(RESET)"
	@if [ ! -f "terraform.tfvars" ] && [ ! -f "environments/$(ENV).tfvars" ]; then \
		echo "$(RED)Error: No tfvars file found$(RESET)"; \
		echo "$(YELLOW)Copy terraform.tfvars.example to terraform.tfvars and update values$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Variables file found$(RESET)"

setup: ## Initial setup (copy example files)
	@echo "$(BLUE)Setting up Terraform configuration...$(RESET)"
	@if [ ! -f "terraform.tfvars" ]; then \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "$(YELLOW)Created terraform.tfvars from example$(RESET)"; \
		echo "$(YELLOW)Please update terraform.tfvars with your values$(RESET)"; \
	fi

# Environment-specific targets
plan-dev: ## Plan for dev environment
	@$(MAKE) plan ENV=dev

apply-dev: ## Apply for dev environment
	@$(MAKE) apply ENV=dev

plan-prod: ## Plan for prod environment
	@$(MAKE) plan ENV=prod

apply-prod: ## Apply for prod environment
	@$(MAKE) apply ENV=prod

# Utility targets
show-roles: ## Show created IAM roles
	@echo "$(BLUE)IAM Roles created:$(RESET)"
	@terraform output -json helm_role_arns | jq -r 'to_entries[] | "  \(.key): \(.value)"'

show-policies: ## Show created IAM policies
	@echo "$(BLUE)IAM Policies created:$(RESET)"
	@terraform output -json | jq -r '.[] | select(.value | type == "string" and contains("policy")) | .value'

show-associations: ## Show Pod Identity associations
	@echo "$(BLUE)Pod Identity Associations:$(RESET)"
	@terraform output -json pod_identity_associations | jq -r 'to_entries[] | "  \(.key): \(.value)"'