### S3 Examples (boto3)

These examples demonstrate S3-compatible operations using boto3, the AWS SDK for Python. They showcase essential S3 operations including bucket management, object CRUD operations, copying, and multipart uploads with proper error handling and resource cleanup.

### Prerequisites

- Python 3.9+
- Network access to your S3 endpoint

### 1) Create and activate a virtual environment

```bash
cd /home/ec2-user/ACSExamples/examples/python
python3 -m venv .venv
source .venv/bin/activate
```

### 2) Install dependencies

```bash
pip install --upgrade pip
pip install boto3
```

### 3) Configure your environment for an S3-compatible endpoint

Set the endpoint, region, addressing style, and credentials so boto3 targets ACS S3-compatible store:

```bash
export S3_ENDPOINT="https://acceleratedprod.com"   # ACS S3-compatible endpoint URL
export AWS_REGION="global"                          # Or set AWS_DEFAULT_REGION
export S3_ADDRESSING_STYLE="virtual"               # virtual 

# S3-compatible credentials (standard AWS env vars)
export AWS_ACCESS_KEY_ID="<YOUR_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_ACCESS_KEY>"
```

### 4) Run the examples

Each script creates any required buckets/objects and cleans up after itself where applicable.

```bash
python s3_basics.py          # create bucket, put/get a small object
python s3_bucket_test.py     # bucket create/head/list/delete
python s3_object_test.py     # object put/head/get/list
python s3_copy_test.py       # copy an object within a bucket
python s3_multipart_test.py  # multipart upload (5 MiB + 2 MiB)
```

### How client initialization works in these examples

- The client is created with `endpoint_url=S3_ENDPOINT` to target your endpoint.
- Region is taken from `AWS_REGION`/`AWS_DEFAULT_REGION` (fallback: `S3_REGION`).
- Credentials use the default AWS provider chain (env vars, profiles, IAM, etc.).
- Addressing style defaults to virtual; override with `S3_ADDRESSING_STYLE`.

### Notes

- To deactivate the virtual environment, run:

```bash
deactivate
```


