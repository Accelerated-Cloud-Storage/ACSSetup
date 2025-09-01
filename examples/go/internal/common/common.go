package common

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type ConfigValues struct {
	Endpoint        string
	Region          string
	AddressingStyle string
}

func Env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

// RandomSuffix returns a lower-hex string of n bytes (2n runes).
func RandomSuffix(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// NewS3Client builds an S3 client using env vars and returns the client and the resolved config values.
func NewS3Client(ctx context.Context) (*s3.Client, ConfigValues, error) {
	endpoint := Env("S3_ENDPOINT", "https://acceleratedprod.com")
	region := Env("S3_REGION", "global")
	accessKey := Env("S3_ACCESS_KEY", "ExampleAccessKey")
	secretKey := Env("S3_SECRET_KEY", "ExampleSecretKey")
	addr := Env("S3_ADDRESSING_STYLE", "virtual")
	if addr != "virtual" && addr != "path" && addr != "auto" {
		addr = "virtual"
	}

	// Load base AWS config with static creds and region
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(region),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
	)
	if err != nil {
		return nil, ConfigValues{}, err
	}

	usePath := addr == "path"

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		// Set a custom base endpoint for S3-compatible services
		o.BaseEndpoint = aws.String(endpoint)
		o.UsePathStyle = usePath
		o.Region = region
	})

	return client, ConfigValues{Endpoint: endpoint, Region: region, AddressingStyle: addr}, nil
}
