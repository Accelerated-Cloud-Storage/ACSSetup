#!/usr/bin/env python3
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

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print("User:          [current IAM identity]")

    initial_user_name = f"iam-user-test-{uuid.uuid4()}"
    current_user_name = None

    try:
        # CreateUser
        created = iam_client.create_user(UserName=initial_user_name)
        created_name = created.get("User", {}).get("UserName")
        if created_name != initial_user_name:
            print("ERROR: create_user returned unexpected user", file=sys.stderr)
            return 1
        current_user_name = initial_user_name
        print(f"CreateUser succeeded: {current_user_name}")

        # GetUser
        fetched = iam_client.get_user(UserName=current_user_name)
        fetched_name = fetched.get("User", {}).get("UserName")
        if fetched_name != current_user_name:
            print("ERROR: get_user returned unexpected user", file=sys.stderr)
            return 2
        print(f"GetUser succeeded: {fetched_name}")

        # UpdateUser
        updated_user_name = f"{initial_user_name}-updated"
        if len(updated_user_name) > 64:
            updated_user_name = updated_user_name[:64]
        iam_client.update_user(UserName=current_user_name, NewUserName=updated_user_name)
        current_user_name = updated_user_name
        print(f"UpdateUser succeeded: renamed to {current_user_name}")

        # ListUsers
        found = False
        paginator = iam_client.get_paginator("list_users")
        for page in paginator.paginate():
            for user in page.get("Users", []):
                if user.get("UserName") == current_user_name:
                    found = True
                    break
            if found:
                break
        if not found:
            print("ERROR: updated user not found in list_users", file=sys.stderr)
            return 3
        print("ListUsers succeeded: found updated user")

        # DeleteUser
        iam_client.delete_user(UserName=current_user_name)
        print(f"DeleteUser succeeded: {current_user_name}")
        current_user_name = None

        print("IAM user API test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        if current_user_name:
            try:
                iam_client.delete_user(UserName=current_user_name)
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())

