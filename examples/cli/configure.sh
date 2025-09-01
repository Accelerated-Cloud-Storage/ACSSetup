#!/bin/bash

# Configuration helper for AWS CLI to target ACS
# Source this file: source ./configure.sh

# Default ACS configuration
export S3_ENDPOINT="${S3_ENDPOINT:-https://acceleratedprod.com}"
export S3_REGION="${S3_REGION:-global}"
export S3_ADDRESSING_STYLE="${S3_ADDRESSING_STYLE:-virtual}"

export S3_ACCESS_KEY="${S3_ACCESS_KEY:-ExampleAccessKey}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-ExampleSecretKey}"

# Set AWS environment variables (works without needing to write config files)
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
export AWS_DEFAULT_REGION="$S3_REGION"

# Configure AWS CLI with custom profile for ACS
ACS_PROFILE="acs-examples"
export AWS_PROFILE="$ACS_PROFILE"

# Ensure .aws directory exists with proper permissions
if mkdir -p "$HOME/.aws" 2>/dev/null && chmod 700 "$HOME/.aws" 2>/dev/null; then
    # Set AWS CLI configuration for custom profile
    aws configure set aws_access_key_id "$S3_ACCESS_KEY" --profile "$ACS_PROFILE" 2>/dev/null
    aws configure set aws_secret_access_key "$S3_SECRET_KEY" --profile "$ACS_PROFILE" 2>/dev/null
    aws configure set region "$S3_REGION" --profile "$ACS_PROFILE" 2>/dev/null
    
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
    if [ -n "$S3_ACCESS_KEY" ]; then
        ACCESS_DISPLAY="${S3_ACCESS_KEY:0:4}****"
    else
        ACCESS_DISPLAY="[unset]"
    fi
fi
echo "  Access Key:   $ACCESS_DISPLAY"
echo ""
echo "Environment variables set. You can now run the example scripts."
