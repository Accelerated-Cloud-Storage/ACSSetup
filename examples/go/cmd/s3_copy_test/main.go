package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"s3setup/internal/common"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
	ctx := context.Background()
	client, cfg, err := common.NewS3Client(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "init error: %v\n", err)
		os.Exit(1)
	}

	bucket := fmt.Sprintf("%s-%s", common.Env("BUCKET_PREFIX", "copytest"), time.Now().UTC().Format("20060102150405"))
	srcKey := "src/hello.txt"
	dstKey := "dst/hello-copy.txt"
	body := []byte("hello copy api\n")

	fmt.Printf("Using endpoint: %s\n", cfg.Endpoint)
	fmt.Printf("Region:        %s\n", cfg.Region)
	fmt.Printf("Bucket:        %s\n", bucket)
	fmt.Printf("Addressing:    %s\n", cfg.AddressingStyle)

	defer func() {
		_, _ = client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &bucket, Key: &srcKey})
		_, _ = client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &bucket, Key: &dstKey})
		_, _ = client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: &bucket})
	}()

	if _, err := client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket}); err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Created bucket")

	if _, err := client.PutObject(ctx, &s3.PutObjectInput{Bucket: &bucket, Key: &srcKey, Body: common.BytesReader(body), ContentType: awsString("text/plain")}); err != nil {
		fmt.Fprintf(os.Stderr, "put src object error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Put source object")

	src := s3.CopyObjectInput{
		Bucket:     &bucket,
		Key:        &dstKey,
		CopySource: awsString(fmt.Sprintf("%s/%s", bucket, srcKey)),
	}
	if _, err := client.CopyObject(ctx, &src); err != nil {
		fmt.Fprintf(os.Stderr, "copy object error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Copied object")

	g, err := client.GetObject(ctx, &s3.GetObjectInput{Bucket: &bucket, Key: &dstKey})
	if err != nil {
		fmt.Fprintf(os.Stderr, "get dst object error: %v\n", err)
		os.Exit(1)
	}
	data, err := common.ReadAll(g.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read body error: %v\n", err)
		os.Exit(1)
	}
	if string(data) != string(body) {
		fmt.Fprintln(os.Stderr, "ERROR: Copied object content mismatch")
		os.Exit(2)
	}
	fmt.Println("Copy verification OK")

	fmt.Println("Copy object test succeeded ✔")
}

func awsString(s string) *string { return &s }
