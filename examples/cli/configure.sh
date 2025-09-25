#!/bin/bash

# Configuration helper for AWS CLI to target ACS
# Source this file: source ./configure.sh

# Default ACS configuration
export S3_ENDPOINT="${S3_ENDPOINT:-https://acceleratedprod.com}"
export S3_REGION="${S3_REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-global}}}"
export S3_ADDRESSING_STYLE="${S3_ADDRESSING_STYLE:-virtual}"

# Do not set placeholder credentials; require the user to export real values
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

# Validate required credentials to fail fast with a helpful message
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo "ERROR: Missing credentials. Please export valid AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (or run your setup command) and re-run:"
    echo "  export AWS_ACCESS_KEY_ID=\"<YOUR_ACCESS_KEY_ID>\""
    echo "  export AWS_SECRET_ACCESS_KEY=\"<YOUR_SECRET_ACCESS_KEY>\""
    return 1 2>/dev/null || exit 1
fi
# Respect pre-set AWS_REGION/AWS_DEFAULT_REGION; otherwise set AWS_DEFAULT_REGION from S3_REGION
if [ -z "${AWS_REGION:-}" ] && [ -z "${AWS_DEFAULT_REGION:-}" ]; then
    export AWS_DEFAULT_REGION="$S3_REGION"
fi

# Configure AWS CLI with custom profile for ACS
ACS_PROFILE="acs-setup"
export AWS_PROFILE="$ACS_PROFILE"

# Ensure .aws directory exists with proper permissions
if mkdir -p "$HOME/.aws" 2>/dev/null && chmod 700 "$HOME/.aws" 2>/dev/null; then
    # Set AWS CLI configuration for custom profile (only when provided)
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile "$ACS_PROFILE" 2>/dev/null
    fi
    if [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$ACS_PROFILE" 2>/dev/null
    fi
    if [ -n "${S3_REGION:-}" ]; then
        aws configure set region "$S3_REGION" --profile "$ACS_PROFILE" 2>/dev/null
    fi
    
    # Set addressing style for the custom profile
    if [ "$S3_ADDRESSING_STYLE" = "virtual" ]; then
        aws configure set s3.addressing_style virtual --profile "$ACS_PROFILE" 2>/dev/null
    else
        aws configure set s3.addressing_style path --profile "$ACS_PROFILE" 2>/dev/null
    fi
    
    # Verify the configuration worked
    CONFIGURED_STYLE=$(aws configure get s3.addressing_style --profile "$ACS_PROFILE" 2>/dev/null || echo "not_set")
    if [ "$CONFIGURED_STYLE" = "$S3_ADDRESSING_STYLE" ]; then
        echo "✅ AWS CLI profile '$ACS_PROFILE' configured successfully"
    else
        echo "⚠️  AWS CLI profile configuration may have issues (using environment variables as fallback)"
    fi
else
    echo "⚠️  Using environment variables only (could not write AWS CLI config files)"
fi

echo ""
echo "AWS CLI configured for ACS:"
echo "  Endpoint:     $S3_ENDPOINT"
echo "  Region:       $S3_REGION"
echo "  Profile:      $ACS_PROFILE"
echo "  Addressing:   $S3_ADDRESSING_STYLE"
# Determine safe display of access key (never print raw key)
ACCESS_DISPLAY="[REDACTED]"
if [ "${ACS_SECURE_DEBUG:-0}" = "1" ]; then
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        ACCESS_DISPLAY="${AWS_ACCESS_KEY_ID:0:4}****"
    else
        ACCESS_DISPLAY="[unset]"
    fi
fi
echo "  Access Key:   $ACCESS_DISPLAY"
echo ""
echo "Environment variables set. You can now run the example scripts."
