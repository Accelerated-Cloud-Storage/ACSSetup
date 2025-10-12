#!/usr/bin/env python3
import os
import sys

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

    access_key_id = None
    try:
        created = iam_client.create_access_key()
        access_key_id = created.get("AccessKey", {}).get("AccessKeyId")
        if not access_key_id:
            print("ERROR: Failed to create access key", file=sys.stderr)
            return 1
        print(f"Created access key: {access_key_id[:4]}****")

        listed = iam_client.list_access_keys()
        ids = {meta["AccessKeyId"] for meta in listed.get("AccessKeyMetadata", [])}
        if access_key_id not in ids:
            print("ERROR: Created access key not found in list_access_keys", file=sys.stderr)
            return 2
        print("Listed access keys (found created key)")

        iam_client.update_access_key(AccessKeyId=access_key_id, Status="Inactive")
        print("Updated access key to inactive")

        iam_client.delete_access_key(AccessKeyId=access_key_id)
        print("Deleted access key")
        access_key_id = None

        print("IAM access key test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        if access_key_id:
            try:
                iam_client.delete_access_key(AccessKeyId=access_key_id)
            except Exception:
                pass


if __name__ == "__main__":
    sys.exit(main())


