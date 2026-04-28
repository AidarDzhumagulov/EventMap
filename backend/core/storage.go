package core

import (
	"context"
	"fmt"
	"io"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

type Storage struct {
	client    *s3.Client
	bucket    string
	publicURL string
}

func NewStorage() *Storage {
	endpoint := os.Getenv("R2_ENDPOINT")
	accessKey := os.Getenv("R2_ACCESS_KEY_ID")
	secretKey := os.Getenv("R2_SECRET_ACCESS_KEY")
	bucket := os.Getenv("R2_BUCKET")
	publicURL := os.Getenv("R2_PUBLIC_URL")

	client := s3.New(s3.Options{
		Region:       "auto",
		Credentials:  credentials.NewStaticCredentialsProvider(accessKey, secretKey, ""),
		BaseEndpoint: aws.String(endpoint),
	})

	return &Storage{
		client:    client,
		bucket:    bucket,
		publicURL: publicURL,
	}
}

func (s *Storage) Upload(ctx context.Context, key string, body io.Reader, contentType string) (string, error) {
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        body,
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return "", fmt.Errorf("upload to R2: %w", err)
	}
	return fmt.Sprintf("%s/%s", s.publicURL, key), nil
}
