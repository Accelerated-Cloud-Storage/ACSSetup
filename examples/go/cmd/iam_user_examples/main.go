package main

import (
	"context"
	"fmt"
	"os"

	"s3setup/internal/common"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
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

	fmt.Printf("Using endpoint: %s\n", endpoint)
	fmt.Printf("Region:        %s\n", region)
	fmt.Println("User:          [current IAM identity]")

	initialUserName := fmt.Sprintf("iam-user-test-%s", uuid.New().String())
	currentUserName := initialUserName

	defer func() {
		if currentUserName != "" {
			_, _ = iamClient.DeleteUser(ctx, &iam.DeleteUserInput{
				UserName: aws.String(currentUserName),
			})
		}
	}()

	// CreateUser
	createResp, err := iamClient.CreateUser(ctx, &iam.CreateUserInput{
		UserName: aws.String(initialUserName),
	})
	if err != nil || createResp.User == nil || createResp.User.UserName == nil || *createResp.User.UserName != initialUserName {
		fmt.Fprintf(os.Stderr, "create user error: %v\n", err)
		return 1
	}
	fmt.Printf("CreateUser succeeded: %s\n", currentUserName)

	// GetUser
	getResp, err := iamClient.GetUser(ctx, &iam.GetUserInput{
		UserName: aws.String(currentUserName),
	})
	if err != nil || getResp.User == nil || getResp.User.UserName == nil || *getResp.User.UserName != currentUserName {
		fmt.Fprintf(os.Stderr, "get user error: %v\n", err)
		return 2
	}
	fmt.Printf("GetUser succeeded: %s\n", *getResp.User.UserName)

	// UpdateUser
	updatedUserName := currentUserName + "-updated"
	if len(updatedUserName) > 64 {
		updatedUserName = updatedUserName[:64]
	}
	if _, err := iamClient.UpdateUser(ctx, &iam.UpdateUserInput{
		UserName:    aws.String(currentUserName),
		NewUserName: aws.String(updatedUserName),
	}); err != nil {
		fmt.Fprintf(os.Stderr, "update user error: %v\n", err)
		return 1
	}
	currentUserName = updatedUserName
	fmt.Printf("UpdateUser succeeded: renamed to %s\n", currentUserName)

	// ListUsers
	found := false
	paginator := iam.NewListUsersPaginator(iamClient, &iam.ListUsersInput{})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "list users error: %v\n", err)
			return 1
		}
		for _, user := range page.Users {
			if user.UserName != nil && *user.UserName == currentUserName {
				found = true
				break
			}
		}
		if found {
			break
		}
	}
	if !found {
		fmt.Fprintln(os.Stderr, "ERROR: updated user not found in list_users")
		return 3
	}
	fmt.Println("ListUsers succeeded: found updated user")

	// DeleteUser
	if _, err := iamClient.DeleteUser(ctx, &iam.DeleteUserInput{
		UserName: aws.String(currentUserName),
	}); err != nil {
		fmt.Fprintf(os.Stderr, "delete user error: %v\n", err)
		return 1
	}
	fmt.Printf("DeleteUser succeeded: %s\n", currentUserName)
	currentUserName = ""

	fmt.Println("IAM user API test succeeded ✔")
	return 0
}

