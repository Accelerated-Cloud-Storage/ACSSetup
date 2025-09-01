package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"time"

	"s3examples/internal/common"

	"github.com/aws/aws-sdk-go-v2/aws"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

func main() {
	ctx := context.Background()
	client, cfg, err := common.NewS3Client(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "init error: %v\n", err)
		os.Exit(1)
	}

	bucket := fmt.Sprintf("%s-%s", common.Env("BUCKET_PREFIX", "mpuploadtest"), time.Now().UTC().Format("20060102150405"))
	key := "large/data.bin"

	part1 := bytes.Repeat([]byte("a"), 5*1024*1024)
	part2 := bytes.Repeat([]byte("b"), 2*1024*1024)
	totalLen := len(part1) + len(part2)

	fmt.Printf("Using endpoint: %s\n", cfg.Endpoint)
	fmt.Printf("Region:        %s\n", cfg.Region)
	fmt.Printf("Bucket:        %s\n", bucket)
	fmt.Printf("Addressing:    %s\n", cfg.AddressingStyle)

	var uploadID *string
	defer func() {
		if uploadID != nil {
			_, _ = client.AbortMultipartUpload(ctx, &s3.AbortMultipartUploadInput{Bucket: &bucket, Key: &key, UploadId: uploadID})
		}
		_, _ = client.DeleteObject(ctx, &s3.DeleteObjectInput{Bucket: &bucket, Key: &key})
		_, _ = client.DeleteBucket(ctx, &s3.DeleteBucketInput{Bucket: &bucket})
	}()

	if _, err := client.CreateBucket(ctx, &s3.CreateBucketInput{Bucket: &bucket}); err != nil {
		fmt.Fprintf(os.Stderr, "create bucket error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Created bucket")

	initOut, err := client.CreateMultipartUpload(ctx, &s3.CreateMultipartUploadInput{Bucket: &bucket, Key: &key, ContentType: awsString("application/octet-stream")})
	if err != nil || initOut.UploadId == nil {
		fmt.Fprintf(os.Stderr, "init MPU error: %v\n", err)
		os.Exit(1)
	}
	uploadID = initOut.UploadId
	fmt.Printf("Initiated MPU: %s\n", *uploadID)

	up1, err := client.UploadPart(ctx, &s3.UploadPartInput{Bucket: &bucket, Key: &key, PartNumber: aws.Int32(1), UploadId: uploadID, Body: bytes.NewReader(part1)})
	if err != nil || up1.ETag == nil {
		fmt.Fprintf(os.Stderr, "upload part1 error: %v\n", err)
		os.Exit(1)
	}
	etag1 := *up1.ETag
	fmt.Println("Uploaded part 1")

	up2, err := client.UploadPart(ctx, &s3.UploadPartInput{Bucket: &bucket, Key: &key, PartNumber: aws.Int32(2), UploadId: uploadID, Body: bytes.NewReader(part2)})
	if err != nil || up2.ETag == nil {
		fmt.Fprintf(os.Stderr, "upload part2 error: %v\n", err)
		os.Exit(1)
	}
	etag2 := *up2.ETag
	fmt.Println("Uploaded part 2")

	comp, err := client.CompleteMultipartUpload(ctx, &s3.CompleteMultipartUploadInput{
		Bucket:   &bucket,
		Key:      &key,
		UploadId: uploadID,
		MultipartUpload: &types.CompletedMultipartUpload{
			Parts: []types.CompletedPart{
				{ETag: &etag1, PartNumber: aws.Int32(1)},
				{ETag: &etag2, PartNumber: aws.Int32(2)},
			},
		},
	})
	if err != nil || comp.ETag == nil {
		fmt.Fprintf(os.Stderr, "complete MPU error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Completed MPU")

	// Verify
	h, err := client.HeadObject(ctx, &s3.HeadObjectInput{Bucket: &bucket, Key: &key})
	if err != nil || h.ContentLength == nil || int(*h.ContentLength) != totalLen {
		fmt.Fprintln(os.Stderr, "ERROR: Head size mismatch after MPU")
		os.Exit(2)
	}

	g, err := client.GetObject(ctx, &s3.GetObjectInput{Bucket: &bucket, Key: &key})
	if err != nil {
		fmt.Fprintf(os.Stderr, "get object error: %v\n", err)
		os.Exit(1)
	}
	data, err := common.ReadAll(g.Body)
	if err != nil || len(data) != totalLen {
		fmt.Fprintln(os.Stderr, "ERROR: Retrieved content mismatch after MPU")
		os.Exit(2)
	}
	for i := 0; i < len(part1); i++ {
		if data[i] != 'a' {
			fmt.Fprintln(os.Stderr, "ERROR: Retrieved content mismatch after MPU")
			os.Exit(2)
		}
	}
	for i := 0; i < len(part2); i++ {
		if data[len(part1)+i] != 'b' {
			fmt.Fprintln(os.Stderr, "ERROR: Retrieved content mismatch after MPU")
			os.Exit(2)
		}
	}

	fmt.Println("Multipart upload test succeeded ✔")
}

func awsString(s string) *string { return &s }
