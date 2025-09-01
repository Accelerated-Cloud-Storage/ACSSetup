package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"s3examples/internal/common"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
	ctx := context.Background()
	client, cfg, err := common.NewS3Client(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "init error: %v\n", err)
		os.Exit(1)
	}

	bucket := fmt.Sprintf("%s-%s", common.Env("BUCKET_PREFIX", "acs-bucket-test"), time.Now().UTC().Format("20060102150405"))

	fmt.Printf("Using endpoint: %s\n", cfg.Endpoint)
	fmt.Printf("Region:        %s\n", cfg.Region)
	fmt.Printf("Bucket:        %s\n", bucket)
	fmt.Printf("Addressing:    %s\n", cfg.AddressingStyle)

	defer func() {
		_, _ = client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: &bucket})
	}()

	if _, err := client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket}); err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Created bucket")

	if _, err := client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &bucket}); err != nil {
		fmt.Fprintf(os.Stderr, "head bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Head bucket OK")

	lb, err := client.ListBuckets(ctx, &s3.ListBucketsInput{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "list buckets error: %v\n", err)
		os.Exit(1)
	}
	found := false
	for _, b := range lb.Buckets {
		if b.Name != nil && *b.Name == bucket {
			found = true
			break
		}
	}
	if !found {
		fmt.Fprintln(os.Stderr, "ERROR: Created bucket not found in list_buckets()")
		os.Exit(2)
	}
	fmt.Println("List buckets contains created bucket")

	fmt.Println("Bucket lifecycle test succeeded ✔")
}
