#!/bin/bash

# IAM user lifecycle test using AWS CLI
# Exercises: CreateUser, GetUser, UpdateUser, ListUsers, DeleteUser

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

INITIAL_USER_NAME="iam-user-test-$(uuidgen | tr '[:upper:]' '[:lower:]')"
CURRENT_USER_NAME=""

cleanup() {
    if [ -n "$CURRENT_USER_NAME" ]; then
        aws iam delete-user \
            --user-name "$CURRENT_USER_NAME" \
            --endpoint-url "$IAM_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

echo "Using endpoint: $IAM_ENDPOINT"
echo "Region:        $REGION"
echo "User:          [current IAM identity]"

# CreateUser
CREATE_OUTPUT=$(aws iam create-user \
    --user-name "$INITIAL_USER_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json)
CREATED_NAME=$(echo "$CREATE_OUTPUT" | jq -r '.User.UserName // empty')
if [ "$CREATED_NAME" != "$INITIAL_USER_NAME" ]; then
    echo "ERROR: create-user returned unexpected user" >&2
    exit 1
fi
CURRENT_USER_NAME="$INITIAL_USER_NAME"
echo "CreateUser succeeded: $CURRENT_USER_NAME"

# GetUser
GET_OUTPUT=$(aws iam get-user \
    --user-name "$CURRENT_USER_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json)
FETCHED_NAME=$(echo "$GET_OUTPUT" | jq -r '.User.UserName // empty')
if [ "$FETCHED_NAME" != "$CURRENT_USER_NAME" ]; then
    echo "ERROR: get-user returned unexpected user" >&2
    exit 2
fi
echo "GetUser succeeded: $FETCHED_NAME"

# UpdateUser
UPDATED_USER_NAME="${INITIAL_USER_NAME}-updated"
UPDATED_USER_NAME="${UPDATED_USER_NAME:0:64}"
aws iam update-user \
    --user-name "$CURRENT_USER_NAME" \
    --new-user-name "$UPDATED_USER_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
CURRENT_USER_NAME="$UPDATED_USER_NAME"
echo "UpdateUser succeeded: renamed to $CURRENT_USER_NAME"

# ListUsers
USER_LIST=$(aws iam list-users \
    --endpoint-url "$IAM_ENDPOINT" \
    --query 'Users[].UserName' \
    --output text)
if ! echo "$USER_LIST" | grep -Fq "$CURRENT_USER_NAME"; then
    echo "ERROR: updated user not found in list-users" >&2
    exit 3
fi
echo "ListUsers succeeded: found updated user"

# DeleteUser
aws iam delete-user \
    --user-name "$CURRENT_USER_NAME" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "DeleteUser succeeded: $CURRENT_USER_NAME"
CURRENT_USER_NAME=""

echo "IAM user API test succeeded ✔"

