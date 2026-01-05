#!/usr/bin/env python3
"""
Script to split .gitlab-ci.yml into modular files
Usage: python3 scripts/split_gitlab_ci.py
"""

import os
import re
from pathlib import Path

def create_directory():
    """Create .gitlab-ci directory"""
    Path(".gitlab-ci").mkdir(exist_ok=True)
    print("✅ Created .gitlab-ci/ directory")

def backup_original():
    """Backup original .gitlab-ci.yml"""
    if os.path.exists(".gitlab-ci.yml"):
        with open(".gitlab-ci.yml", "r", encoding="utf-8") as src:
            with open(".gitlab-ci.yml.backup", "w", encoding="utf-8") as dst:
                dst.write(src.read())
        print("✅ Backed up original file to .gitlab-ci.yml.backup")

def find_job_boundaries(content):
    """Find boundaries of different job sections"""
    lines = content.split("\n")
    boundaries = {
        "validation_start": None,
        "validation_end": None,
        "helm_start": None,
        "helm_end": None,
        "k8s_start": None,
        "k8s_end": None,
        "verify_start": None,
        "verify_end": None,
    }
    
    for i, line in enumerate(lines):
        # Find validation jobs
        if line.startswith("validate:helm:"):
            boundaries["validation_start"] = i
        
        # Find helm deployment jobs
        if line.startswith(".deploy_helm_hybrid:"):
            boundaries["helm_start"] = i
            if boundaries["validation_start"] is not None:
                boundaries["validation_end"] = i - 1
        
        # Find k8s-resources jobs
        if line.startswith(".uninstall_k8s_apps:"):
            boundaries["k8s_start"] = i
            if boundaries["helm_start"] is not None:
                boundaries["helm_end"] = i - 1
        
        # Find verification jobs
        if line.startswith(".verify_template:"):
            boundaries["verify_start"] = i
            if boundaries["k8s_start"] is not None:
                boundaries["k8s_end"] = i - 1
    
    # Set end of verification to end of file
    boundaries["verify_end"] = len(lines) - 1
    
    return boundaries

def extract_section(content, start, end):
    """Extract a section of the file"""
    lines = content.split("\n")
    return "\n".join(lines[start:end+1])

def add_header(filename, content):
    """Add header to extracted file"""
    headers = {
        "validation-jobs.yml": "# Validation and Testing Jobs\n# Included in main .gitlab-ci.yml\n\n",
        "helm-jobs.yml": "# Helm Deployment and Uninstallation Jobs\n# Included in main .gitlab-ci.yml\n\n",
        "k8s-resources-jobs.yml": "# K8s-Resources Deployment and Uninstallation Jobs\n# Included in main .gitlab-ci.yml\n\n",
        "verification-jobs.yml": "# Verification and Status Jobs\n# Included in main .gitlab-ci.yml\n\n",
    }
    return headers.get(filename, "") + content

def create_main_file():
    """Create simplified main .gitlab-ci.yml"""
    main_content = """# GitLab CI/CD Pipeline for EKS Add-ons
# Modular structure for better maintainability
#
# Documentation: See individual job files in .gitlab-ci/ directory
# - validation-jobs.yml: Validation and testing
# - helm-jobs.yml: Helm chart deployment/uninstallation
# - k8s-resources-jobs.yml: K8s-resources deployment/uninstallation
# - verification-jobs.yml: Verification and status checking

stages:
  - validate
  - test
  - plan
  - deploy
  - verify
  - uninstall
  - status

default:
  image: alpine:3.20
  before_script:
    - echo "🔧 Setting up environment..."
    - apk add --no-cache bash curl git jq yq kubectl helm
    - mkdir -p ~/.kube
    - |
      if [ -n "$KUBECONFIG_DATA" ]; then
        echo "📝 Decoding kubeconfig..."
        echo "$KUBECONFIG_DATA" | base64 -d > ~/.kube/config
        export KUBECONFIG=~/.kube/config
        echo "✅ Kubeconfig configured"
      else
        echo "⚠️  KUBECONFIG_DATA not set (normal for some jobs)"
      fi
    - echo "🔍 Checking tool versions..."
    - helm version --short || echo "⚠️  Helm check skipped"
    - kubectl version --client || echo "⚠️  Kubectl check skipped"
    - echo "✅ Environment setup complete"

# Include modular job definitions
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs.yml'
  - local: '.gitlab-ci/k8s-resources-jobs.yml'
  - local: '.gitlab-ci/verification-jobs.yml'
"""
    return main_content

def main():
    print("🔧 Splitting .gitlab-ci.yml into modular files...")
    print("")
    
    # Create directory
    create_directory()
    
    # Backup original
    backup_original()
    
    # Read original file
    with open(".gitlab-ci.yml", "r", encoding="utf-8") as f:
        content = f.read()
    
    # Find boundaries
    print("📍 Finding job boundaries...")
    boundaries = find_job_boundaries(content)
    
    # Extract and save sections
    sections = {
        "validation-jobs.yml": (boundaries["validation_start"], boundaries["validation_end"]),
        "helm-jobs.yml": (boundaries["helm_start"], boundaries["helm_end"]),
        "k8s-resources-jobs.yml": (boundaries["k8s_start"], boundaries["k8s_end"]),
        "verification-jobs.yml": (boundaries["verify_start"], boundaries["verify_end"]),
    }
    
    for filename, (start, end) in sections.items():
        if start is not None and end is not None:
            print(f"📝 Extracting {filename} (lines {start}-{end})...")
            section_content = extract_section(content, start, end)
            section_with_header = add_header(filename, section_content)
            
            with open(f".gitlab-ci/{filename}", "w", encoding="utf-8") as f:
                f.write(section_with_header)
            print(f"✅ Created .gitlab-ci/{filename}")
        else:
            print(f"⚠️  Could not find boundaries for {filename}")
    
    # Create new main file
    print("📝 Creating new main .gitlab-ci.yml...")
    main_content = create_main_file()
    with open(".gitlab-ci-modular.yml", "w", encoding="utf-8") as f:
        f.write(main_content)
    print("✅ Created .gitlab-ci-modular.yml")
    
    print("")
    print("✅ Split complete!")
    print("")
    print("📋 Next steps:")
    print("1. Review the extracted files in .gitlab-ci/")
    print("2. Test with: mv .gitlab-ci-modular.yml .gitlab-ci.yml")
    print("3. Commit and push to test in GitLab")
    print("4. Original file backed up to .gitlab-ci.yml.backup")

if __name__ == "__main__":
    main()
