#!/bin/bash

# IAM access key and policy lifecycle test using AWS CLI
# Creates a bucket, access key, IAM policy limiting access to that bucket,
# attaches the policy, then cleans up in reverse order

set -Eeuo pipefail

env_var() {
    local key="$1"
    local default="$2"
    echo "${!key:-$default}"
}

S3_ENDPOINT=$(env_var "S3_ENDPOINT" "https://acceleratedprod.com")
IAM_ENDPOINT=$(env_var "IAM_ENDPOINT" "$S3_ENDPOINT")
if [ -n "${AWS_REGION:-}" ]; then
    REGION="$AWS_REGION"
elif [ -n "${AWS_DEFAULT_REGION:-}" ]; then
    REGION="$AWS_DEFAULT_REGION"
else
    REGION=$(env_var "IAM_REGION" "global")
fi

ACCESS_KEY_ID=""
USER_NAME=""
POLICY_ARN=""
BUCKET_NAME=""

cleanup() {
    # Cleanup in reverse order
    if [ -n "$POLICY_ARN" ] && [ -n "$USER_NAME" ]; then
        aws iam detach-user-policy \
            --user-name "$USER_NAME" \
            --policy-arn "$POLICY_ARN" \
            --endpoint-url "$IAM_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
        aws iam delete-policy \
            --policy-arn "$POLICY_ARN" \
            --endpoint-url "$IAM_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
    fi
    if [ -n "$ACCESS_KEY_ID" ]; then
        aws iam delete-access-key \
            --access-key-id "$ACCESS_KEY_ID" \
            --endpoint-url "$IAM_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
    fi
    if [ -n "$BUCKET_NAME" ]; then
        aws s3api delete-bucket \
            --bucket "$BUCKET_NAME" \
            --endpoint-url "$S3_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

echo "Using endpoint: $IAM_ENDPOINT"
echo "Region:        $REGION"
echo "Target user:   [current IAM identity]"

# Create a test bucket
BUCKET_NAME="iam-policy-test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT" \
    --output json >/dev/null
echo "Created test bucket: $BUCKET_NAME"

# Create access key
CREATE_OUTPUT=$(aws iam create-access-key \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json)
ACCESS_KEY_ID=$(echo "$CREATE_OUTPUT" | jq -r '.AccessKey.AccessKeyId // empty')
if [ -z "$ACCESS_KEY_ID" ]; then
    echo "ERROR: Failed to create access key" >&2
    exit 1
fi
# For policy attachment, UserName parameter should be the access key ID
USER_NAME="$ACCESS_KEY_ID"
MASKED_KEY="${ACCESS_KEY_ID:0:4}****"
echo "Created access key: $MASKED_KEY"

# List access keys to verify
KEY_LIST=$(aws iam list-access-keys \
    --endpoint-url "$IAM_ENDPOINT" \
    --query 'AccessKeyMetadata[].AccessKeyId' \
    --output text)
if ! echo "$KEY_LIST" | grep -q "$ACCESS_KEY_ID"; then
    echo "ERROR: Created access key not found in list" >&2
    exit 2
fi
echo "Listed access keys (found created key)"

# Create a policy document limiting access to the specific bucket
POLICY_NAME="S3BucketPolicy-$(uuidgen)"
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
)

CREATE_POLICY_OUTPUT=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT" \
    --description "Allow all S3 operations on bucket $BUCKET_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json)
POLICY_ARN=$(echo "$CREATE_POLICY_OUTPUT" | jq -r '.Policy.Arn // empty')
if [ -z "$POLICY_ARN" ]; then
    echo "ERROR: Failed to create policy" >&2
    exit 3
fi
echo "Created policy: $POLICY_NAME"
echo "Policy ARN: $POLICY_ARN"

# Attach the policy to the access key (user)
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Attached policy to access key (user)"

# List attached policies to verify
ATTACHED_POLICIES=$(aws iam list-attached-user-policies \
    --user-name "$USER_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --query 'AttachedPolicies[].PolicyArn' \
    --output text)
if ! echo "$ATTACHED_POLICIES" | grep -q "$POLICY_ARN"; then
    echo "ERROR: Policy not found in attached policies" >&2
    exit 4
fi
echo "Verified policy attachment"

# Extract secret access key from the create response
SECRET_ACCESS_KEY=$(echo "$CREATE_OUTPUT" | jq -r '.AccessKey.SecretAccessKey // empty')
if [ -z "$SECRET_ACCESS_KEY" ]; then
    echo "ERROR: Failed to get secret access key" >&2
    exit 5
fi

# Test policy enforcement using the limited access key
export AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY"

# Test 1: Verify we CAN access the allowed bucket (should succeed)
if aws s3api head-bucket \
    --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT" \
    --output json >/dev/null 2>&1; then
    echo "✓ Policy allows access to bucket: $BUCKET_NAME"
else
    echo "ERROR: Policy should allow access to $BUCKET_NAME" >&2
    exit 6
fi

# Test 2: Try to create a DIFFERENT bucket (should fail due to policy restriction)
UNAUTHORIZED_BUCKET="unauthorized-bucket-$(uuidgen | tr '[:upper:]' '[:lower:]')"
if aws s3api create-bucket \
    --bucket "$UNAUTHORIZED_BUCKET" \
    --endpoint-url "$S3_ENDPOINT" \
    --output json >/dev/null 2>&1; then
    echo "ERROR: Policy should have denied creating bucket: $UNAUTHORIZED_BUCKET" >&2
    # Clean up if it somehow succeeded
    aws s3api delete-bucket --bucket "$UNAUTHORIZED_BUCKET" --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    exit 7
else
    echo "✓ Policy correctly denied access to unauthorized bucket: $UNAUTHORIZED_BUCKET"
fi

# Test 3: Verify we CAN put an object in the allowed bucket (should succeed)
TEST_KEY="test-object-$(uuidgen).txt"
if echo "test data" | aws s3api put-object \
    --bucket "$BUCKET_NAME" \
    --key "$TEST_KEY" \
    --body /dev/stdin \
    --endpoint-url "$S3_ENDPOINT" \
    --output json >/dev/null 2>&1; then
    echo "✓ Policy allows writing to bucket: $BUCKET_NAME/$TEST_KEY"
    # Clean up test object
    aws s3api delete-object \
        --bucket "$BUCKET_NAME" \
        --key "$TEST_KEY" \
        --endpoint-url "$S3_ENDPOINT" \
        --output json >/dev/null 2>&1
    echo "  Cleaned up test object: $TEST_KEY"
else
    echo "ERROR: Policy should allow writing to $BUCKET_NAME" >&2
    exit 8
fi

# Restore original credentials
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

# Update access key status
aws iam update-access-key \
    --access-key-id "$ACCESS_KEY_ID" \
    --status Inactive \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Updated access key to inactive"

# Detach the policy before deleting the access key
aws iam detach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Detached policy from access key (user)"

# Delete the policy
aws iam delete-policy \
    --policy-arn "$POLICY_ARN" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Deleted policy"
POLICY_ARN=""

# Delete the access key
aws iam delete-access-key \
    --access-key-id "$ACCESS_KEY_ID" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Deleted access key"
ACCESS_KEY_ID=""

# Delete the test bucket
aws s3api delete-bucket \
    --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT" \
    --output json >/dev/null
echo "Deleted test bucket: $BUCKET_NAME"
BUCKET_NAME=""

echo "IAM access key and policy test succeeded ✔"

