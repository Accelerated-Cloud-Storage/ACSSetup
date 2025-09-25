#!/bin/bash

# Run all S3 CLI tests in sequence
# This script runs all the individual test scripts and reports overall results

# Note: Don't use 'set -e' here since we want to continue testing even if individual tests fail

echo "========================================="
echo "Running AWS CLI S3 Setup Test Suite"
echo "========================================="
echo ""

# Source configuration to ensure environment variables are set
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/configure.sh" ]; then
    echo "Loading configuration..."
    source "$SCRIPT_DIR/configure.sh"
    echo ""
else
    echo "⚠️  Warning: configure.sh not found, using environment defaults"
    echo ""
fi

TESTS=(
    "s3_basics.sh"
    "s3_bucket_test.sh"
    "s3_object_test.sh"
    "s3_copy_test.sh"
    "s3_multipart_test.sh"
)

PASSED=0
FAILED=0
FAILED_TESTS=()

for test in "${TESTS[@]}"; do
    echo "----------------------------------------"
    echo "Running: $test"
    echo "----------------------------------------"
    
    # Run the test and handle success/failure
    if "$SCRIPT_DIR/$test"; then
        echo "✅ PASSED: $test"
        ((PASSED++))
    else
        echo "❌ FAILED: $test"
        ((FAILED++))
        FAILED_TESTS+=("$test")
    fi
    echo ""
done

echo "========================================="
echo "Test Results Summary"
echo "========================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    exit 1
else
    echo ""
    echo "🎉 All tests passed!"
    exit 0
fi
