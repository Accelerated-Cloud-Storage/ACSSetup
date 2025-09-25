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

	bucket := fmt.Sprintf("%s-%s", common.Env("BUCKET_PREFIX", "objecttest"), time.Now().UTC().Format("20060102150405"))
	key := "folder/hello.txt"
	body := []byte("hello object api\n")

	fmt.Printf("Using endpoint: %s\n", cfg.Endpoint)
	fmt.Printf("Region:        %s\n", cfg.Region)
	fmt.Printf("Bucket:        %s\n", bucket)
	fmt.Printf("Addressing:    %s\n", cfg.AddressingStyle)

	defer func() {
		_, _ = client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &bucket, Key: &key})
		_, _ = client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: &bucket})
	}()

	if _, err := client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket}); err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Created bucket")

	if _, err := client.PutObject(ctx, &s3.PutObjectInput{Bucket: &bucket, Key: &key, Body: common.BytesReader(body), ContentType: awsString("text/plain")}); err != nil {
		fmt.Fprintf(os.Stderr, "put object error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Put object")

	if _, err := client.HeadObject(ctx, &s3.HeadObjectInput{Bucket: &bucket, Key: &key}); err != nil {
		fmt.Fprintf(os.Stderr, "head object error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Head object OK")

	getOut, err := client.GetObject(ctx, &s3.GetObjectInput{Bucket: &bucket, Key: &key})
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
		fmt.Fprintln(os.Stderr, "ERROR: Get object content mismatch")
		os.Exit(2)
	}
	fmt.Println("Get object OK")

	// List with prefix
	out, err := client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{Bucket: &bucket, Prefix: &[]string{"folder/"}[0]})
	if err != nil {
		fmt.Fprintf(os.Stderr, "list objects v2 error: %v\n", err)
		os.Exit(1)
	}
	present := false
	for _, o := range out.Contents {
		if o.Key != nil && *o.Key == key {
			present = true
			break
		}
	}
	if !present {
		fmt.Fprintln(os.Stderr, "ERROR: Object not found in list_objects_v2")
		os.Exit(2)
	}
	fmt.Println("ListObjectsV2 OK")

	fmt.Println("Object CRUD test succeeded ✔")
}

func awsString(s string) *string { return &s }
