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

	bucket := fmt.Sprintf("%s-%s", common.Env("BUCKET_PREFIX", "smoketest"), time.Now().UTC().Format("20060102150405"))
	objectKey := "hello.txt"
	body := []byte("hello world\n")

	fmt.Printf("Using endpoint: %s\n", cfg.Endpoint)
	fmt.Printf("Region:        %s\n", cfg.Region)
	fmt.Printf("Bucket:        %s\n", bucket)
	fmt.Printf("Addressing:    %s\n", cfg.AddressingStyle)

	defer func() {
		_, _ = client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &bucket, Key: &objectKey})
		_, _ = client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: &bucket})
	}()

	_, err = client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket})
	if err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Created bucket")

	_, err = client.PutObject(ctx, &s3.PutObjectInput{Bucket: &bucket, Key: &objectKey, Body: common.BytesReader(body)})
	if err != nil {
		fmt.Fprintf(os.Stderr, "put object error: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Put object: %s\n", objectKey)

	getOut, err := client.GetObject(ctx, &s3.GetObjectInput{Bucket: &bucket, Key: &objectKey})
	if err != nil {
		fmt.Fprintf(os.Stderr, "get object error: %v\n", err)
		os.Exit(1)
	}
	data, err := common.ReadAll(getOut.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read body error: %v\n", err)
		os.Exit(1)
	}
	if string(data) != string(body) {
		fmt.Fprintf(os.Stderr, "ERROR: content mismatch\n")
		os.Exit(2)
	}
	fmt.Printf("Got object: %s (%d bytes)\n", objectKey, len(data))

	fmt.Println("basics test succeeded ✔")
}

// helpers removed; using common.ReadAll and common.BytesReader
