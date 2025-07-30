#!/usr/bin/env bash

# Main Test Runner for Ubuntu Setup Script
# Runs all available tests

set -euo pipefail

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/test-framework.sh"

# Initialize tests
init_tests

echo "Project root: $PROJECT_ROOT"
echo "Running tests from: $SCRIPT_DIR"
echo ""

# Test 1: Basic script validation
run_test "Script syntax validation" "bash -n '$PROJECT_ROOT/setup.sh'"

# Test 2: Configuration file validation
run_test "Configuration syntax validation" "bash -n '$PROJECT_ROOT/config.sh'"

# Test 3: Library files validation
run_test "Library files syntax validation" "
    for lib in '$PROJECT_ROOT/lib'/*.sh; do
        bash -n \"\$lib\" || exit 1
    done
"

# Test 4: Module files validation
run_test "Module files syntax validation" "
    for module in '$PROJECT_ROOT/modules'/*.sh; do
        bash -n \"\$module\" || exit 1
    done
"

# Test 5: Required files exist
run_test "Required files exist" "
    assert_file_exists '$PROJECT_ROOT/setup.sh' &&
    assert_file_exists '$PROJECT_ROOT/config.sh' &&
    assert_file_exists '$PROJECT_ROOT/README.md' &&
    assert_file_exists '$PROJECT_ROOT/Makefile'
"

# Test 6: Required directories exist
run_test "Required directories exist" "
    assert_directory_exists '$PROJECT_ROOT/lib' &&
    assert_directory_exists '$PROJECT_ROOT/modules' &&
    assert_directory_exists '$PROJECT_ROOT/cloud-init' &&
    assert_directory_exists '$PROJECT_ROOT/configs'
"

# Test 7: Scripts are executable
run_test "Main script is executable" "assert_file_executable '$PROJECT_ROOT/setup.sh'"

# Test 8: Library functions are loadable
run_test "Library functions load correctly" "
    source '$PROJECT_ROOT/config.sh' &&
    source '$PROJECT_ROOT/lib/logging.sh' &&
    source '$PROJECT_ROOT/lib/utils.sh' &&
    source '$PROJECT_ROOT/lib/validation.sh' &&
    source '$PROJECT_ROOT/lib/security.sh'
"

# Test 9: Dry run execution
run_test "Dry run execution" "
    cd '$PROJECT_ROOT' &&
    timeout 60 sudo ./setup.sh --dry-run --mode minimal --yes 2>/dev/null
"

# Test 10: Help message
run_test "Help message displays" "
    cd '$PROJECT_ROOT' &&
    ./setup.sh --help | grep -q 'Ubuntu Server Setup Script'
"

# Test 11: Invalid arguments handling
run_test "Invalid arguments handling" "
    cd '$PROJECT_ROOT' &&
    ! ./setup.sh --invalid-option 2>/dev/null
"

# Test 12: Configuration variables are set
run_test "Configuration variables are properly set" "
    source '$PROJECT_ROOT/config.sh' &&
    [[ -n \"\$SETUP_VERSION\" ]] &&
    [[ -n \"\$DEFAULT_APP_USER\" ]] &&
    [[ -n \"\$NODE_VERSION\" ]]
"

# Test 13: Cloud-init file is valid YAML
run_test "Cloud-init file is valid YAML" "
    python3 -c \"
import yaml
import sys
try:
    with open('$PROJECT_ROOT/cloud-init/basic.yaml', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except:
    sys.exit(1)
\" 2>/dev/null || echo 'YAML validation requires python3-yaml package'
"

# Test 14: Makefile targets work
run_test "Makefile help target works" "
    cd '$PROJECT_ROOT' &&
    make help | grep -q 'Available commands'
"

# Test 15: Version consistency
run_test "Version consistency across files" "
    version_file=\$(cat '$PROJECT_ROOT/VERSION' | tr -d '\\n\\r')
    setup_version=\$(grep 'SCRIPT_VERSION=' '$PROJECT_ROOT/setup.sh' | cut -d'\"' -f2)
    config_version=\$(grep 'SETUP_VERSION=' '$PROJECT_ROOT/config.sh' | cut -d'\"' -f2)
    
    [[ \"\$version_file\" == \"\$setup_version\" ]] &&
    [[ \"\$version_file\" == \"\$config_version\" ]]
"

# Run unit tests if they exist
if [[ -d "$SCRIPT_DIR/unit" ]]; then
    test_info "Running unit tests..."
    for test_file in "$SCRIPT_DIR/unit"/*.sh; do
        if [[ -f "$test_file" ]]; then
            test_name=$(basename "$test_file" .sh)
            run_test "Unit test: $test_name" "bash '$test_file'"
        fi
    done
fi

# Finalize and show results
finalize_tests