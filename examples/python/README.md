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

### 3) Configure your client for ACS (endpoint, region, addressing style)

Set the endpoint, region, addressing style, and credentials so boto3 targets ACS:

```bash
export S3_ENDPOINT="https://acceleratedprod.com"   # ACS S3 endpoint
export S3_REGION="global"                           # ACS region
export S3_ADDRESSING_STYLE="virtual"               # virtual | path | auto (ACS defaults to virtual)

export S3_ACCESS_KEY="ExampleAccessKey"
export S3_SECRET_KEY="ExampleSecretKey"
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

### Notes

- If your endpoint uses a self-signed certificate, you may need to configure system trust or set the AWS_CA_BUNDLE environment variable to your CA bundle path.
- To deactivate the virtual environment, run:

```bash
deactivate
```


