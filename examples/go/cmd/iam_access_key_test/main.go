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

	client := iam.NewFromConfig(cfg, func(o *iam.Options) {
		o.BaseEndpoint = aws.String(endpoint)
		o.Region = region
	})

	fmt.Printf("Using endpoint: %s\n", endpoint)
	fmt.Printf("Region:        %s\n", region)
	fmt.Println("User:          [current IAM identity]")

	var accessKeyID *string

	created, err := client.CreateAccessKey(ctx, &iam.CreateAccessKeyInput{})
	if err != nil || created.AccessKey == nil || created.AccessKey.AccessKeyId == nil {
		fmt.Fprintf(os.Stderr, "create access key error: %v\n", err)
		return 1
	}
	accessKeyID = created.AccessKey.AccessKeyId
	fmt.Printf("Created access key: %s****\n", (*accessKeyID)[:4])

	listed, err := client.ListAccessKeys(ctx, &iam.ListAccessKeysInput{})
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

	if _, err := client.UpdateAccessKey(ctx, &iam.UpdateAccessKeyInput{AccessKeyId: accessKeyID, Status: iamtypes.StatusTypeInactive}); err != nil {
		fmt.Fprintf(os.Stderr, "update access key error: %v\n", err)
		return 1
	}
	fmt.Println("Updated access key to inactive")

	if _, err := client.DeleteAccessKey(ctx, &iam.DeleteAccessKeyInput{AccessKeyId: accessKeyID}); err != nil {
		fmt.Fprintf(os.Stderr, "delete access key error: %v\n", err)
		return 1
	}
	accessKeyID = nil
	fmt.Println("Deleted access key")

	fmt.Println("IAM access key test succeeded ✔")
	return 0
}
