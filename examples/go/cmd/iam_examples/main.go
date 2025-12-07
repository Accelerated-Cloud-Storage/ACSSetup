package main

import (
	"context"
	"fmt"
	"os"

	"s3setup/internal/common"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	iamtypes "github.com/aws/aws-sdk-go-v2/service/iam/types"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
)

func main() {
	ctx := context.Background()
	code := run(ctx)
	os.Exit(code)
}

func run(ctx context.Context) int {
	endpoint := common.Env("IAM_ENDPOINT", common.Env("S3_ENDPOINT", "https://acceleratedprod.com"))
	region := common.Env("IAM_REGION", "")
	if region == "" {
		region = os.Getenv("AWS_REGION")
	}
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "global"
	}

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		fmt.Fprintf(os.Stderr, "init error: %v\n", err)
		return 1
	}

	iamClient := iam.NewFromConfig(cfg, func(o *iam.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.Region = region
	})

	s3Client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = false
		o.Region = region
	})

	fmt.Printf("Using endpoint: %s\n", endpoint)
	fmt.Printf("Region:        %s\n", region)
	fmt.Println("User:          [current IAM identity]")

	var accessKeyID *string
	var userName *string
	var policyArn *string
	var bucketName *string

	// Cleanup function
	defer func() {
		if policyArn != nil && userName != nil {
			_, _ = iamClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
				UserName:  userName,
				PolicyArn: policyArn,
			})
			_, _ = iamClient.DeletePolicy(ctx, &iam.DeletePolicyInput{PolicyArn: policyArn})
		}
		if accessKeyID != nil {
			_, _ = iamClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{AccessKeyId: accessKeyID})
		}
		if bucketName != nil {
			_, _ = s3Client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: bucketName})
		}
	}()

	// Create a test bucket
	bucketUUID := uuid.New().String()
	bucketName = aws.String(fmt.Sprintf("iam-policy-test-%s", bucketUUID))
	if _, err := s3Client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: bucketName}); err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		return 1
	}
	fmt.Printf("Created test bucket: %s\n", *bucketName)

	// Create access key
	created, err := iamClient.CreateAccessKey(ctx, &iam.CreateAccessKeyInput{})
	if err != nil || created.AccessKey == nil || created.AccessKey.AccessKeyId == nil {
		fmt.Fprintf(os.Stderr, "create access key error: %v\n", err)
		return 1
	}
	accessKeyID = created.AccessKey.AccessKeyId
	// For policy attachment, UserName parameter should be the access key ID
	userName = accessKeyID
	fmt.Printf("Created access key: %s****\n", (*accessKeyID)[:4])

	// List access keys to verify
	listed, err := iamClient.ListAccessKeys(ctx, &iam.ListAccessKeysInput{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "list access keys error: %v\n", err)
		return 1
	}
	found := false
	for _, meta := range listed.AccessKeyMetadata {
		if meta.AccessKeyId != nil && *meta.AccessKeyId == *accessKeyID {
			found = true
			break
		}
	}
	if !found {
		fmt.Fprintln(os.Stderr, "ERROR: Created access key not found in list_access_keys")
		return 2
	}
	fmt.Println("Listed access keys (found created key)")

	// Create a policy document limiting access to the specific bucket
	policyDocument := fmt.Sprintf(`{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::%s",
        "arn:aws:s3:::%s/*"
      ]
    }
  ]
}`, *bucketName, *bucketName)

	policyName := fmt.Sprintf("S3BucketPolicy-%s", uuid.New().String())
	createPolicyResp, err := iamClient.CreatePolicy(ctx, &iam.CreatePolicyInput{
		PolicyName:     aws.String(policyName),
		PolicyDocument: aws.String(policyDocument),
		Description:    aws.String(fmt.Sprintf("Allow all S3 operations on bucket %s", *bucketName)),
	})
	if err != nil || createPolicyResp.Policy == nil || createPolicyResp.Policy.Arn == nil {
		fmt.Fprintf(os.Stderr, "create policy error: %v\n", err)
		return 3
	}
	policyArn = createPolicyResp.Policy.Arn
	fmt.Printf("Created policy: %s\n", policyName)
	fmt.Printf("Policy ARN: %s\n", *policyArn)

	// Attach the policy to the access key (user)
	if _, err := iamClient.AttachUserPolicy(ctx, &iam.AttachUserPolicyInput{
		UserName:  userName,
		PolicyArn: policyArn,
	}); err != nil {
		fmt.Fprintf(os.Stderr, "attach user policy error: %v\n", err)
		return 1
	}
	fmt.Println("Attached policy to access key (user)")

	// List attached policies to verify
	attachedPolicies, err := iamClient.ListAttachedUserPolicies(ctx, &iam.ListAttachedUserPoliciesInput{
		UserName: userName,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "list attached user policies error: %v\n", err)
		return 1
	}
	policyFound := false
	for _, policy := range attachedPolicies.AttachedPolicies {
		if policy.PolicyArn != nil && *policy.PolicyArn == *policyArn {
			policyFound = true
			break
		}
	}
	if !policyFound {
		fmt.Fprintln(os.Stderr, "ERROR: Policy not found in attached policies")
		return 4
	}
	fmt.Println("Verified policy attachment")

	// Update access key status
	if _, err := iamClient.UpdateAccessKey(ctx, &iam.UpdateAccessKeyInput{
		AccessKeyId: accessKeyID,
		Status:      iamtypes.StatusTypeInactive,
	}); err != nil {
		fmt.Fprintf(os.Stderr, "update access key error: %v\n", err)
		return 1
	}
	fmt.Println("Updated access key to inactive")

	// Detach the policy before deleting the access key
	if _, err := iamClient.DetachUserPolicy(ctx, &iam.DetachUserPolicyInput{
		UserName:  userName,
		PolicyArn: policyArn,
	}); err != nil {
		fmt.Fprintf(os.Stderr, "detach user policy error: %v\n", err)
		return 1
	}
	fmt.Println("Detached policy from access key (user)")

	// Delete the policy
	if _, err := iamClient.DeletePolicy(ctx, &iam.DeletePolicyInput{PolicyArn: policyArn}); err != nil {
		fmt.Fprintf(os.Stderr, "delete policy error: %v\n", err)
		return 1
	}
	fmt.Println("Deleted policy")
	policyArn = nil

	// Delete the access key
	if _, err := iamClient.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{AccessKeyId: accessKeyID}); err != nil {
		fmt.Fprintf(os.Stderr, "delete access key error: %v\n", err)
		return 1
	}
	fmt.Println("Deleted access key")
	accessKeyID = nil

	// Delete the test bucket
	if _, err := s3Client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: bucketName}); err != nil {
		fmt.Fprintf(os.Stderr, "delete bucket error: %v\n", err)
		return 1
	}
	fmt.Printf("Deleted test bucket: %s\n", *bucketName)
	bucketName = nil

	fmt.Println("IAM access key and policy test succeeded ✔")
	return 0
}
