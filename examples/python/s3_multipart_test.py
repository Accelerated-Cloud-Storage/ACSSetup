#!/usr/bin/env python3
import io
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
    region = env("S3_REGION", "global")
    bucket_prefix = env("BUCKET_PREFIX", "mpuploadtest")
    access_key = env("S3_ACCESS_KEY", "ExampleAccessKey")
    secret_key = env("S3_SECRET_KEY", "ExampleSecretKey")
    addressing_style = env("S3_ADDRESSING_STYLE", "virtual").lower()
    if addressing_style not in ("auto", "virtual", "path"):
        addressing_style = "virtual"

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=region,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4", s3={"addressing_style": addressing_style}),
    )

    bucket_name = f"{bucket_prefix}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:8]}".lower()
    key = "large/data.bin"

    # Prepare 2 parts: 5 MiB (min) + 2 MiB
    part1 = b"a" * (5 * 1024 * 1024)
    part2 = b"b" * (2 * 1024 * 1024)
    total_len = len(part1) + len(part2)

    print(f"Using endpoint: {endpoint_url}")
    print(f"Region:        {region}")
    print(f"Bucket:        {bucket_name}")
    print(f"Addressing:    {addressing_style}")

    upload_id = None
    try:
        s3.create_bucket(Bucket=bucket_name)
        print("Created bucket")

        init = s3.create_multipart_upload(Bucket=bucket_name, Key=key, ContentType="application/octet-stream")
        upload_id = init["UploadId"]
        print(f"Initiated MPU: {upload_id}")

        # Upload part 1
        r1 = s3.upload_part(Bucket=bucket_name, Key=key, PartNumber=1, UploadId=upload_id, Body=io.BytesIO(part1))
        etag1 = r1["ETag"].strip('"')
        print("Uploaded part 1")

        # Upload part 2 (last part may be < 5 MiB)
        r2 = s3.upload_part(Bucket=bucket_name, Key=key, PartNumber=2, UploadId=upload_id, Body=io.BytesIO(part2))
        etag2 = r2["ETag"].strip('"')
        print("Uploaded part 2")

        comp = s3.complete_multipart_upload(
            Bucket=bucket_name,
            Key=key,
            UploadId=upload_id,
            MultipartUpload={
                "Parts": [
                    {"ETag": f'"{etag1}"', "PartNumber": 1},
                    {"ETag": f'"{etag2}"', "PartNumber": 2},
                ]
            },
        )
        print("Completed MPU")

        # Verify with HEAD and GET
        h = s3.head_object(Bucket=bucket_name, Key=key)
        if int(h.get("ContentLength", -1)) != total_len:
            print("ERROR: Head size mismatch after MPU", file=sys.stderr)
            return 2

        g = s3.get_object(Bucket=bucket_name, Key=key)
        data = g["Body"].read()
        if data != part1 + part2:
            print("ERROR: Retrieved content mismatch after MPU", file=sys.stderr)
            return 2

        print("Multipart upload test succeeded ✔")
        return 0

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1
    finally:
        # Cleanup
        try:
            s3.delete_object(Bucket=bucket_name, Key=key)
        except Exception:
            pass
        if upload_id:
            try:
                s3.abort_multipart_upload(Bucket=bucket_name, Key=key, UploadId=upload_id)
            except Exception:
                pass
        try:
            s3.delete_bucket(Bucket=bucket_name)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
