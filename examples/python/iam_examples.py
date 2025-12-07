#!/usr/bin/env python3
import json
import os
import sys
import uuid

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError


def env(key: str, default: str) -> str:
    value = os.getenv(key)
    return value if value else default


def main() -> int:
    endpoint_url = env("IAM_ENDPOINT", env("S3_ENDPOINT", "https://acceleratedprod.com"))
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or env("IAM_REGION", "global")

    iam_client = boto3.client(
        "iam",
        endpoint_url=endpoint_url,
        region_name=region,
        config=Config(signature_version="v4"),
    )

    s3_client = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=region,
        config=Config(signature_version="v4", s3={"addressing_style": "virtual"}),
    )

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print("User:          [current IAM identity]")

    access_key_id = None
    user_name = None
    policy_arn = None
    bucket_name = None

    try:
        # Create a test bucket
        bucket_name = f"iam-policy-test-{uuid.uuid4()}"
        s3_client.create_bucket(Bucket=bucket_name)
        print(f"Created test bucket: {bucket_name}")

        # Create access key
        created = iam_client.create_access_key()
        access_key_id = created.get("AccessKey", {}).get("AccessKeyId")
        if not access_key_id:
            print("ERROR: Failed to create access key", file=sys.stderr)
            return 1
        print(f"Created access key: {access_key_id[:4]}****")
        
        # For policy attachment, UserName parameter should be the access key ID
        user_name = access_key_id

        # List access keys to verify
        listed = iam_client.list_access_keys()
        ids = {meta["AccessKeyId"] for meta in listed.get("AccessKeyMetadata", [])}
        if access_key_id not in ids:
            print("ERROR: Created access key not found in list_access_keys", file=sys.stderr)
            return 2
        print("Listed access keys (found created key)")

        # Create a policy document limiting access to the specific bucket
        policy_document = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": "s3:*",
                    "Resource": [
                        f"arn:aws:s3:::{bucket_name}",
                        f"arn:aws:s3:::{bucket_name}/*",
                    ],
                }
            ],
        }

        policy_name = f"S3BucketPolicy-{uuid.uuid4()}"
        create_policy_response = iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document),
            Description=f"Allow all S3 operations on bucket {bucket_name}",
        )
        policy_arn = create_policy_response.get("Policy", {}).get("Arn")
        if not policy_arn:
            print("ERROR: Failed to create policy", file=sys.stderr)
            return 3
        print(f"Created policy: {policy_name}")
        print(f"Policy ARN: {policy_arn}")

        # Attach the policy to the access key (user)
        iam_client.attach_user_policy(UserName=user_name, PolicyArn=policy_arn)
        print("Attached policy to access key (user)")

        # List attached policies to verify
        attached_policies = iam_client.list_attached_user_policies(UserName=user_name)
        policy_arns = {p["PolicyArn"] for p in attached_policies.get("AttachedPolicies", [])}
        if policy_arn not in policy_arns:
            print("ERROR: Policy not found in attached policies", file=sys.stderr)
            return 4
        print("Verified policy attachment")

        # Test policy enforcement: Create a new S3 client with the limited access key
        secret_key = created.get("AccessKey", {}).get("SecretAccessKey")
        if not secret_key:
            print("ERROR: Failed to get secret access key", file=sys.stderr)
            return 5
        
        limited_s3_client = boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            region_name=region,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_key,
            config=Config(signature_version="v4", s3={"addressing_style": "virtual"}),
        )

        # Test 1: Verify we CAN access the allowed bucket (should succeed)
        try:
            limited_s3_client.head_bucket(Bucket=bucket_name)
            print(f"✓ Policy allows access to bucket: {bucket_name}")
        except ClientError as e:
            print(f"ERROR: Policy should allow access to {bucket_name}: {e}", file=sys.stderr)
            return 6

        # Test 2: Try to create a DIFFERENT bucket (should fail due to policy restriction)
        unauthorized_bucket = f"unauthorized-bucket-{uuid.uuid4()}"
        try:
            limited_s3_client.create_bucket(Bucket=unauthorized_bucket)
            print(f"ERROR: Policy should have denied creating bucket: {unauthorized_bucket}", file=sys.stderr)
            # Clean up if it somehow succeeded
            try:
                limited_s3_client.delete_bucket(Bucket=unauthorized_bucket)
            except Exception:
                pass
            return 7
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            if error_code in ["AccessDenied", "Forbidden"]:
                print(f"✓ Policy correctly denied access to unauthorized bucket: {unauthorized_bucket}")
            else:
                print(f"WARNING: Expected AccessDenied but got {error_code}: {e}", file=sys.stderr)

        # Test 3: Verify we CAN put an object in the allowed bucket (should succeed)
        test_key = f"test-object-{uuid.uuid4()}.txt"
        try:
            limited_s3_client.put_object(Bucket=bucket_name, Key=test_key, Body=b"test data")
            print(f"✓ Policy allows writing to bucket: {bucket_name}/{test_key}")
            # Clean up test object
            limited_s3_client.delete_object(Bucket=bucket_name, Key=test_key)
            print(f"  Cleaned up test object: {test_key}")
        except ClientError as e:
            print(f"ERROR: Policy should allow writing to {bucket_name}: {e}", file=sys.stderr)
            return 8

        # Update access key status
        iam_client.update_access_key(AccessKeyId=access_key_id, Status="Inactive")
        print("Updated access key to inactive")

        # Detach the policy before deleting the access key
        iam_client.detach_user_policy(UserName=user_name, PolicyArn=policy_arn)
        print("Detached policy from access key (user)")

        # Delete the policy
        iam_client.delete_policy(PolicyArn=policy_arn)
        print("Deleted policy")
        policy_arn = None

        # Delete the access key
        iam_client.delete_access_key(AccessKeyId=access_key_id)
        print("Deleted access key")
        access_key_id = None

        # Clean up the test bucket
        s3_client.delete_bucket(Bucket=bucket_name)
        print(f"Deleted test bucket: {bucket_name}")
        bucket_name = None

        print("IAM access key and policy test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        # Cleanup in reverse order
        if policy_arn and user_name:
            try:
                iam_client.detach_user_policy(UserName=user_name, PolicyArn=policy_arn)
            except Exception:
                pass
            try:
                iam_client.delete_policy(PolicyArn=policy_arn)
            except Exception:
                pass
        if access_key_id:
            try:
                iam_client.delete_access_key(AccessKeyId=access_key_id)
            except Exception:
                pass
        if bucket_name:
            try:
                s3_client.delete_bucket(Bucket=bucket_name)
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())


