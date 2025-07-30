#!/usr/bin/env bash

# Test Framework for Ubuntu Setup Script
# Simple testing utilities and functions

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test output functions
test_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

test_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

test_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

test_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Initialize test run
init_tests() {
    echo "============================================"
    echo "Ubuntu Setup Script Test Framework"
    echo "============================================"
    echo ""
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    test_info "Running: $test_name"
    
    if eval "$test_command"; then
        test_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        test_error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert functions
assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        echo "Command '$cmd' not found"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    else
        echo "File '$file' does not exist"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    else
        echo "Directory '$dir' does not exist"
        return 1
    fi
}

assert_file_executable() {
    local file="$1"
    if [[ -x "$file" ]]; then
        return 0
    else
        echo "File '$file' is not executable"
        return 1
    fi
}

assert_service_active() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        echo "Service '$service' is not active"
        return 1
    fi
}

assert_port_listening() {
    local port="$1"
    if ss -tln | grep -q ":$port "; then
        return 0
    else
        echo "Port '$port' is not listening"
        return 1
    fi
}

assert_package_installed() {
    local package="$1"
    if dpkg -l | grep -q "^ii.*$package "; then
        return 0
    else
        echo "Package '$package' is not installed"
        return 1
    fi
}

assert_user_exists() {
    local user="$1"
    if id "$user" >/dev/null 2>&1; then
        return 0
    else
        echo "User '$user' does not exist"
        return 1
    fi
}

assert_group_exists() {
    local group="$1"
    if getent group "$group" >/dev/null 2>&1; then
        return 0
    else
        echo "Group '$group' does not exist"
        return 1
    fi
}

assert_string_contains() {
    local string="$1"
    local substring="$2"
    if [[ "$string" == *"$substring"* ]]; then
        return 0
    else
        echo "String '$string' does not contain '$substring'"
        return 1
    fi
}

assert_string_equals() {
    local expected="$1"
    local actual="$2"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "Expected '$expected', got '$actual'"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    
    $command
    local actual_code=$?
    
    if [[ $actual_code -eq $expected_code ]]; then
        return 0
    else
        echo "Expected exit code $expected_code, got $actual_code"
        return 1
    fi
}

# Finalize test run and show summary
finalize_tests() {
    echo ""
    echo "============================================"
    echo "Test Summary"
    echo "============================================"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Helper function to skip tests if not running as appropriate user
skip_if_not_root() {
    if [[ $EUID -ne 0 ]]; then
        test_warning "Skipping test (requires root privileges)"
        return 0
    fi
    return 1
}

skip_if_not_user() {
    if [[ $EUID -eq 0 ]]; then
        test_warning "Skipping test (should not run as root)"
        return 0
    fi
    return 1
}