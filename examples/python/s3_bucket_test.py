#!/usr/bin/env python3
import os
import sys
import uuid
from datetime import datetime

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError


def env(key: str, default: str) -> str:
    value = os.getenv(key)
    return value if value else default


def main() -> int:
    # Configuration (override via env vars if needed)
    endpoint_url = env("S3_ENDPOINT", "https://acceleratedprod.com")
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or env("S3_REGION", "global")
    bucket_prefix = env("BUCKET_PREFIX", "acs-bucket-test")
    addressing_style = env("S3_ADDRESSING_STYLE", "virtual").lower()
    if addressing_style not in ("auto", "virtual", "path"):
        addressing_style = "virtual"

    # This is the only change needed to use ACS
    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=region,
        config=Config(signature_version="s3v4", s3={"addressing_style": addressing_style}),
    )

    bucket_name = f"{bucket_prefix}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:8]}".lower()

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print(f"Bucket:        {bucket_name}")
    print(f"Addressing:    {addressing_style}")

    try:
        # Create bucket
        s3.create_bucket(Bucket=bucket_name)
        print("Created bucket")

        # Head bucket
        s3.head_bucket(Bucket=bucket_name)
        print("Head bucket OK")

        # List buckets and verify presence
        resp = s3.list_buckets()
        names = {b["Name"] for b in resp.get("Buckets", [])}
        if bucket_name not in names:
            print("ERROR: Created bucket not found in list_buckets()", file=sys.stderr)
            return 2
        print("List buckets contains created bucket")

        print("Bucket lifecycle test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        try:
            s3.delete_bucket(Bucket=bucket_name)
            print("Deleted bucket")
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
