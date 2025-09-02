#!/usr/bin/env python3
import os
import sys
import uuid
from contextlib import closing
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
    bucket_prefix = env("BUCKET_PREFIX", "copytest")
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
    src_key = "src/hello.txt"
    dst_key = "dst/hello-copy.txt"
    body = b"hello copy api\n"

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print(f"Bucket:        {bucket_name}")
    print(f"Addressing:    {addressing_style}")

    try:
        s3.create_bucket(Bucket=bucket_name)
        print("Created bucket")

        s3.put_object(Bucket=bucket_name, Key=src_key, Body=body, ContentType="text/plain")
        print("Put source object")

        # Copy using dict form to avoid path encoding issues
        s3.copy({"Bucket": bucket_name, "Key": src_key}, bucket_name, dst_key)
        print("Copied object")

        # Verify
        g = s3.get_object(Bucket=bucket_name, Key=dst_key)
        with closing(g["Body"]) as body_stream:
            data = body_stream.read()
        if data != body:
            print("ERROR: Copied object content mismatch", file=sys.stderr)
            return 2
        print("Copy verification OK")

        print("Copy object test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        for k in (src_key, dst_key):
            try:
                s3.delete_object(Bucket=bucket_name, Key=k)
            except Exception:
                pass
        try:
            s3.delete_bucket(Bucket=bucket_name)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
