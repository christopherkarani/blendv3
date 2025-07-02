#!/bin/bash

# BlendOracleService Test Runner
# Script for running comprehensive tests with different configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCHEME="Blendv3"
DESTINATION="platform=iOS Simulator,name=iPhone 15"
TEST_CLASS="BlendOracleServiceEnhancedTests"
ENABLE_COVERAGE="YES"
PARALLEL_TESTING="YES"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run tests with specific configuration
run_tests() {
    local test_name="$1"
    local test_filter="$2"
    local additional_args="$3"
    
    print_status "Running $test_name..."
    
    local cmd="xcodebuild test \
        -scheme $SCHEME \
        -destination '$DESTINATION' \
        -only-testing:Blendv3Tests/$TEST_CLASS$test_filter \
        -enableCodeCoverage $ENABLE_COVERAGE \
        -enableThreadSanitizer YES \
        -parallel-testing-enabled $PARALLEL_TESTING \
        $additional_args"
    
    if eval $cmd; then
        print_success "$test_name completed successfully"
        return 0
    else
        print_error "$test_name failed"
        return 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
BlendOracleService Test Runner

Usage: $0 [OPTIONS] [TEST_CATEGORY]

Options:
    -h, --help              Show this help message
    -s, --scheme SCHEME     Xcode scheme to use (default: $SCHEME)
    -d, --destination DEST  Test destination (default: $DESTINATION)
    -c, --coverage BOOL     Enable code coverage (default: $ENABLE_COVERAGE)
    -p, --parallel BOOL     Enable parallel testing (default: $PARALLEL_TESTING)
    -v, --verbose           Enable verbose output
    --clean                 Clean build before testing

Test Categories:
    all                     Run all tests (default)
    init                    Run initialization tests
    core                    Run core functionality tests
    error                   Run error handling tests
    retry                   Run retry logic tests
    cache                   Run caching tests
    concurrency            Run concurrency tests
    performance            Run performance tests
    edge                   Run edge case tests
    integration            Run integration tests
    
Examples:
    $0                      # Run all tests
    $0 performance          # Run only performance tests
    $0 --clean --verbose    # Clean build and run all tests with verbose output
    $0 -s MyScheme core     # Run core tests with custom scheme

EOF
}

# Parse command line arguments
VERBOSE=false
CLEAN=false
TEST_CATEGORY="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -c|--coverage)
            ENABLE_COVERAGE="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL_TESTING="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        all|init|core|error|retry|cache|concurrency|performance|edge|integration)
            TEST_CATEGORY="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_status "Starting BlendOracleService test execution"
print_status "Scheme: $SCHEME"
print_status "Destination: $DESTINATION"
print_status "Test Category: $TEST_CATEGORY"
print_status "Code Coverage: $ENABLE_COVERAGE"
print_status "Parallel Testing: $PARALLEL_TESTING"

# Clean build if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning build..."
    xcodebuild clean -scheme $SCHEME
    print_success "Build cleaned"
fi

# Set verbose output if requested
VERBOSE_ARGS=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_ARGS="-verbose"
fi

# Track overall test results
FAILED_TESTS=()
TOTAL_TESTS=0
PASSED_TESTS=0

# Function to track test results
track_result() {
    local test_name="$1"
    local result="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ $result -eq 0 ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS+=("$test_name")
    fi
}

# Run tests based on category
case $TEST_CATEGORY in
    "all")
        print_status "Running comprehensive test suite..."
        run_tests "All Oracle Service Tests" "" "$VERBOSE_ARGS"
        track_result "All Tests" $?
        ;;
    "init")
        print_status "Running initialization tests..."
        run_tests "Initialization Tests" "/testInit*" "$VERBOSE_ARGS"
        track_result "Initialization Tests" $?
        ;;
    "core")
        print_status "Running core functionality tests..."
        run_tests "Core Functionality Tests" "/testGet*" "$VERBOSE_ARGS"
        track_result "Core Functionality Tests" $?
        ;;
    "error")
        print_status "Running error handling tests..."
        run_tests "Error Handling Tests" "/test*Error*" "$VERBOSE_ARGS"
        track_result "Error Handling Tests" $?
        ;;
    "retry")
        print_status "Running retry logic tests..."
        run_tests "Retry Logic Tests" "/test*Retry*" "$VERBOSE_ARGS"
        track_result "Retry Logic Tests" $?
        ;;
    "cache")
        print_status "Running caching tests..."
        run_tests "Caching Tests" "/test*Cache*" "$VERBOSE_ARGS"
        track_result "Caching Tests" $?
        ;;
    "concurrency")
        print_status "Running concurrency tests..."
        run_tests "Concurrency Tests" "/testConcurrent*" "$VERBOSE_ARGS"
        track_result "Concurrency Tests" $?
        run_tests "Data Race Tests" "/testDataRace*" "$VERBOSE_ARGS"
        track_result "Data Race Tests" $?
        ;;
    "performance")
        print_status "Running performance tests..."
        run_tests "Performance Tests" "/test*performance*" "$VERBOSE_ARGS"
        track_result "Performance Tests" $?
        run_tests "Memory Management Tests" "/testMemoryManagement*" "$VERBOSE_ARGS"
        track_result "Memory Management Tests" $?
        ;;
    "edge")
        print_status "Running edge case tests..."
        run_tests "Edge Case Tests" "/test*withVery*" "$VERBOSE_ARGS"
        track_result "Edge Case Tests" $?
        run_tests "Validation Tests" "/test*withZero*" "$VERBOSE_ARGS"
        track_result "Validation Tests" $?
        ;;
    "integration")
        print_status "Running integration tests..."
        run_tests "Integration Tests" "/testCompleteWorkflow*" "$VERBOSE_ARGS"
        track_result "Integration Tests" $?
        run_tests "Error Recovery Tests" "/testErrorRecovery*" "$VERBOSE_ARGS"
        track_result "Error Recovery Tests" $?
        ;;
esac

# Print summary
echo ""
print_status "Test Execution Summary"
echo "======================="
print_status "Total Test Categories: $TOTAL_TESTS"
print_success "Passed: $PASSED_TESTS"

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    print_success "All tests passed! ✅"
    exit 0
else
    print_error "Failed: ${#FAILED_TESTS[@]}"
    print_error "Failed test categories:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    print_error "Some tests failed! ❌"
    exit 1
fi 