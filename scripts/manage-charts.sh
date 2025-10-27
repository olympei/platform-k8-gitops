#!/bin/bash

# Chart Management Helper Script
# This script helps manage chart installations in GitLab CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available charts
AVAILABLE_CHARTS=(
    "aws-efs-csi-driver"
    "external-secrets-operator"
    "ingress-nginx"
    "pod-identity"
    "secrets-store-csi-driver"
    "cluster-autoscaler"
    "metrics-server"
    "external-dns"
)

# Function to print usage
usage() {
    echo -e "${BLUE}Chart Management Helper${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list                    List all available charts"
    echo "  status                  Show current chart installation status"
    echo "  enable <chart>          Enable a chart for installation"
    echo "  disable <chart>         Disable a chart from installation"
    echo "  enable-all              Enable all charts"
    echo "  disable-all             Disable all charts"
    echo "  mark-uninstall <chart>  Mark a chart for uninstallation"
    echo "  unmark-uninstall <chart> Unmark a chart for uninstallation"
    echo "  generate-vars           Generate GitLab CI/CD variables"
    echo ""
    echo "Available charts:"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        echo "  - $chart"
    done
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 status"
    echo "  $0 enable aws-efs-csi-driver"
    echo "  $0 disable ingress-nginx"
    echo "  $0 mark-uninstall external-secrets-operator"
    echo "  $0 generate-vars"
}

# Function to get variable name for chart
get_var_name() {
    local chart=$1
    local action=${2:-"INSTALL"}
    echo "${action}_$(echo $chart | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
}

# Function to list all charts
list_charts() {
    echo -e "${BLUE}Available Charts:${NC}"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        echo "  - $chart"
    done
}

# Function to show current status
show_status() {
    echo -e "${BLUE}Current Chart Status:${NC}"
    echo ""
    
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        install_var_name=$(get_var_name "$chart" "INSTALL")
        uninstall_var_name=$(get_var_name "$chart" "UNINSTALL")
        install_value=${!install_var_name}
        uninstall_value=${!uninstall_var_name}
        
        # Installation status
        if [ -z "$install_value" ] || [ "$install_value" != "false" ] && [ "$install_value" != "0" ] && [ "$install_value" != "no" ]; then
            install_status="${GREEN}✅ enabled${NC}"
        else
            install_status="${RED}❌ disabled${NC}"
        fi
        
        # Uninstallation status
        if [ "$uninstall_value" = "true" ] || [ "$uninstall_value" = "1" ] || [ "$uninstall_value" = "yes" ]; then
            uninstall_status="${YELLOW}🗑️  marked for uninstall${NC}"
        else
            uninstall_status="⏭️  not marked"
        fi
        
        echo -e "  $chart:"
        echo -e "    Install: $install_status"
        echo -e "    Uninstall: $uninstall_status"
    done
}

# Function to enable a chart
enable_chart() {
    local chart=$1
    
    if [[ ! " ${AVAILABLE_CHARTS[@]} " =~ " ${chart} " ]]; then
        echo -e "${RED}Error: Chart '$chart' not found${NC}"
        echo "Available charts: ${AVAILABLE_CHARTS[*]}"
        exit 1
    fi
    
    var_name=$(get_var_name "$chart" "INSTALL")
    export $var_name="true"
    echo -e "${GREEN}✅ Enabled chart: $chart${NC}"
    echo "Set environment variable: $var_name=true"
}

# Function to disable a chart
disable_chart() {
    local chart=$1
    
    if [[ ! " ${AVAILABLE_CHARTS[@]} " =~ " ${chart} " ]]; then
        echo -e "${RED}Error: Chart '$chart' not found${NC}"
        echo "Available charts: ${AVAILABLE_CHARTS[*]}"
        exit 1
    fi
    
    var_name=$(get_var_name "$chart" "INSTALL")
    export $var_name="false"
    echo -e "${RED}❌ Disabled chart: $chart${NC}"
    echo "Set environment variable: $var_name=false"
}

# Function to enable all charts
enable_all() {
    echo -e "${BLUE}Enabling all charts...${NC}"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        var_name=$(get_var_name "$chart" "INSTALL")
        export $var_name="true"
        echo -e "  ${GREEN}✅ $chart${NC}"
    done
}

# Function to disable all charts
disable_all() {
    echo -e "${BLUE}Disabling all charts...${NC}"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        var_name=$(get_var_name "$chart" "INSTALL")
        export $var_name="false"
        echo -e "  ${RED}❌ $chart${NC}"
    done
}

# Function to mark a chart for uninstallation
mark_uninstall() {
    local chart=$1
    
    if [[ ! " ${AVAILABLE_CHARTS[@]} " =~ " ${chart} " ]]; then
        echo -e "${RED}Error: Chart '$chart' not found${NC}"
        echo "Available charts: ${AVAILABLE_CHARTS[*]}"
        exit 1
    fi
    
    var_name=$(get_var_name "$chart" "UNINSTALL")
    export $var_name="true"
    echo -e "${YELLOW}🗑️  Marked chart for uninstallation: $chart${NC}"
    echo "Set environment variable: $var_name=true"
}

# Function to unmark a chart for uninstallation
unmark_uninstall() {
    local chart=$1
    
    if [[ ! " ${AVAILABLE_CHARTS[@]} " =~ " ${chart} " ]]; then
        echo -e "${RED}Error: Chart '$chart' not found${NC}"
        echo "Available charts: ${AVAILABLE_CHARTS[*]}"
        exit 1
    fi
    
    var_name=$(get_var_name "$chart" "UNINSTALL")
    export $var_name="false"
    echo -e "${GREEN}✅ Unmarked chart for uninstallation: $chart${NC}"
    echo "Set environment variable: $var_name=false"
}

# Function to generate GitLab CI/CD variables
generate_vars() {
    echo -e "${BLUE}GitLab CI/CD Variables for Chart Control:${NC}"
    echo ""
    echo "Add these variables to your GitLab project settings:"
    echo "Project Settings > CI/CD > Variables"
    echo ""
    
    echo -e "${GREEN}Installation Control Variables:${NC}"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        var_name=$(get_var_name "$chart" "INSTALL")
        var_value=${!var_name:-"true"}
        echo "Variable: $var_name"
        echo "Value: $var_value"
        echo "Description: Enable/disable $chart chart installation"
        echo ""
    done
    
    echo -e "${YELLOW}Uninstallation Control Variables:${NC}"
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        var_name=$(get_var_name "$chart" "UNINSTALL")
        var_value=${!var_name:-"false"}
        echo "Variable: $var_name"
        echo "Value: $var_value"
        echo "Description: Mark $chart chart for uninstallation"
        echo ""
    done
    
    echo -e "${BLUE}Additional useful variables:${NC}"
    echo ""
    echo "Variable: HELM_RELEASES_DEV"
    echo "Value: aws-efs-csi-driver,external-secrets-operator,ingress-nginx,pod-identity"
    echo "Description: Comma-separated list of charts for dev environment"
    echo ""
    echo "Variable: HELM_RELEASES_PROD"
    echo "Value: aws-efs-csi-driver,external-secrets-operator,ingress-nginx,pod-identity"
    echo "Description: Comma-separated list of charts for prod environment"
}

# Function to validate chart directory
validate_charts() {
    echo -e "${BLUE}Validating chart directories...${NC}"
    
    for chart in "${AVAILABLE_CHARTS[@]}"; do
        chart_dir="charts/$chart"
        if [ -d "$chart_dir" ]; then
            echo -e "  ${GREEN}✅ $chart${NC} - directory exists"
            
            # Check for values files
            for env in dev prod; do
                values_file="$chart_dir/values-$env.yaml"
                if [ -f "$values_file" ]; then
                    echo -e "    ${GREEN}✅ values-$env.yaml${NC}"
                else
                    echo -e "    ${YELLOW}⚠️  values-$env.yaml missing${NC}"
                fi
            done
        else
            echo -e "  ${RED}❌ $chart${NC} - directory missing"
        fi
    done
}

# Main script logic
case "${1:-}" in
    "list")
        list_charts
        ;;
    "status")
        show_status
        ;;
    "enable")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Chart name required${NC}"
            usage
            exit 1
        fi
        enable_chart "$2"
        ;;
    "disable")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Chart name required${NC}"
            usage
            exit 1
        fi
        disable_chart "$2"
        ;;
    "enable-all")
        enable_all
        ;;
    "disable-all")
        disable_all
        ;;
    "mark-uninstall")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Chart name required${NC}"
            usage
            exit 1
        fi
        mark_uninstall "$2"
        ;;
    "unmark-uninstall")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Error: Chart name required${NC}"
            usage
            exit 1
        fi
        unmark_uninstall "$2"
        ;;
    "generate-vars")
        generate_vars
        ;;
    "validate")
        validate_charts
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '${1:-}'${NC}"
        echo ""
        usage
        exit 1
        ;;
esac