#!/usr/bin/env bash

# Unit Test: Prerequisites Module
# Tests the prerequisites module functionality

set -euo pipefail

# Get script directory and project root
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/../test-framework.sh"

# Source project files
source "$PROJECT_ROOT/config.sh"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/validation.sh"

# Test essential packages list
test_essential_packages() {
    local essential_count=${#ESSENTIAL_PACKAGES[@]}
    
    if [[ $essential_count -gt 0 ]]; then
        echo "Essential packages list contains $essential_count packages"
        return 0
    else
        echo "Essential packages list is empty"
        return 1
    fi
}

# Test development packages list
test_dev_packages() {
    local dev_count=${#DEV_PACKAGES[@]}
    
    if [[ $dev_count -gt 0 ]]; then
        echo "Development packages list contains $dev_count packages"
        return 0
    else
        echo "Development packages list is empty"
        return 1
    fi
}

# Test that required commands exist in essential packages
test_required_commands_in_packages() {
    local required_commands=("curl" "wget" "git" "make" "gcc")
    
    for cmd in "${required_commands[@]}"; do
        if [[ " ${ESSENTIAL_PACKAGES[*]} " =~ " ${cmd} " ]]; then
            continue
        else
            echo "Required command '$cmd' not found in essential packages"
            return 1
        fi
    done
    
    echo "All required commands found in essential packages"
    return 0
}

# Test package repository URLs are valid format
test_package_repos() {
    local repos=("$NGINX_REPO" "$NODEJS_REPO")
    
    for repo in "${repos[@]}"; do
        if [[ $repo =~ ^https?:// ]]; then
            continue
        else
            echo "Repository URL '$repo' is not a valid HTTP/HTTPS URL"
            return 1
        fi
    done
    
    echo "All repository URLs are valid"
    return 0
}

# Test software versions are set
test_software_versions() {
    local versions=("$NODE_VERSION" "$PYTHON_VERSION" "$NGINX_VERSION")
    
    for version in "${versions[@]}"; do
        if [[ -n "$version" ]]; then
            continue
        else
            echo "Software version is empty"
            return 1
        fi
    done
    
    echo "All software versions are set"
    return 0
}

# Test minimum requirements
test_minimum_requirements() {
    if [[ -n "$MIN_UBUNTU_VERSION" ]] && [[ -n "$MIN_DISK_SPACE" ]]; then
        echo "Minimum requirements are defined: Ubuntu $MIN_UBUNTU_VERSION, ${MIN_DISK_SPACE}GB disk"
        return 0
    else
        echo "Minimum requirements are not properly defined"
        return 1
    fi
}

# Run all tests
echo "Testing Prerequisites Module Configuration..."
echo "=============================================="

run_test "Essential packages list" "test_essential_packages"
run_test "Development packages list" "test_dev_packages"
run_test "Required commands in packages" "test_required_commands_in_packages"
run_test "Package repository URLs" "test_package_repos"
run_test "Software versions defined" "test_software_versions"
run_test "Minimum requirements defined" "test_minimum_requirements"

# Check if prerequisites module exists and is syntactically valid
run_test "Prerequisites module exists" "assert_file_exists '$PROJECT_ROOT/modules/01-prerequisites.sh'"
run_test "Prerequisites module syntax" "bash -n '$PROJECT_ROOT/modules/01-prerequisites.sh'"

echo "Prerequisites module tests completed."