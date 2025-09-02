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
    endpoint_url = env("S3_ENDPOINT", "https://acceleratedprod.com")
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or env("S3_REGION", "global")
    bucket_prefix = env("BUCKET_PREFIX", "objecttest")
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
    key = "folder/hello.txt"
    body = b"hello object api\n"

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print(f"Bucket:        {bucket_name}")
    print(f"Addressing:    {addressing_style}")

    try:
        s3.create_bucket(Bucket=bucket_name)
        print("Created bucket")

        # PUT with metadata
        s3.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=body,
            ContentType="text/plain",
            Metadata={"x-amz-meta-owner": "examples"},
        )
        print("Put object")

        # HEAD
        h = s3.head_object(Bucket=bucket_name, Key=key)
        if int(h.get("ContentLength", -1)) != len(body):
            print("ERROR: Head content length mismatch", file=sys.stderr)
            return 2
        print("Head object OK")

        # GET
        g = s3.get_object(Bucket=bucket_name, Key=key)
        data = g["Body"].read()
        if data != body:
            print("ERROR: Get object content mismatch", file=sys.stderr)
            return 2
        print("Get object OK")

        # LIST V2 with prefix
        resp = s3.list_objects_v2(Bucket=bucket_name, Prefix="folder/")
        keys = {c["Key"] for c in resp.get("Contents", [])}
        if key not in keys:
            print("ERROR: Object not found in list_objects_v2", file=sys.stderr)
            return 2
        print("ListObjectsV2 OK")

        print("Object CRUD test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        try:
            s3.delete_object(Bucket=bucket_name, Key=key)
        except Exception:
            pass
        try:
            s3.delete_bucket(Bucket=bucket_name)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
