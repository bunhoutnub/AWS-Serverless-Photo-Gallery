#!/bin/bash

# AWS Serverless Photo Gallery - CloudFront CDN Setup
# This script creates a CloudFront distribution for faster global access and HTTPS

set -e

echo "=========================================="
echo "CloudFront CDN Setup"
echo "=========================================="
echo ""

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
FRONTEND_BUCKET="photo-gallery-frontend-${AWS_ACCOUNT_ID}"

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo ""

# Create CloudFront Origin Access Identity
echo "Step 1: Creating CloudFront Origin Access Identity..."
OAI_ID=$(aws cloudfront create-cloud-front-origin-access-identity \
    --cloud-front-origin-access-identity-config \
    CallerReference="photo-gallery-$(date +%s)",Comment="Photo Gallery OAI" \
    --query 'CloudFrontOriginAccessIdentity.Id' \
    --output text 2>/dev/null || \
    aws cloudfront list-cloud-front-origin-access-identities \
    --query "CloudFrontOriginAccessIdentityList.Items[?Comment=='Photo Gallery OAI'].Id | [0]" \
    --output text)

echo "OAI ID: $OAI_ID"

# Update S3 bucket policy to allow CloudFront access
echo ""
echo "Step 2: Updating S3 bucket policy..."

# Get the canonical user ID for the OAI
CANONICAL_USER=$(aws cloudfront get-cloud-front-origin-access-identity \
    --id ${OAI_ID} \
    --query 'CloudFrontOriginAccessIdentity.S3CanonicalUserId' \
    --output text)

cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAI",
      "Effect": "Allow",
      "Principal": {
        "CanonicalUser": "${CANONICAL_USER}"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${FRONTEND_BUCKET}/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${FRONTEND_BUCKET} \
    --policy file:///tmp/bucket-policy.json

echo "✓ Bucket policy updated"

# Create CloudFront distribution
echo ""
echo "Step 3: Creating CloudFront distribution..."
cat > /tmp/distribution-config.json << EOF
{
  "CallerReference": "photo-gallery-$(date +%s)",
  "Comment": "Photo Gallery CDN",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-${FRONTEND_BUCKET}",
        "DomainName": "${FRONTEND_BUCKET}.s3.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": "origin-access-identity/cloudfront/${OAI_ID}"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${FRONTEND_BUCKET}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "PriceClass": "PriceClass_100"
}
EOF

DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/distribution-config.json \
    --query 'Distribution.Id' \
    --output text 2>/dev/null || echo "")

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "Distribution may already exist. Checking..."
    DISTRIBUTION_ID=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[?Comment=='Photo Gallery CDN'].Id | [0]" \
        --output text)
fi

DOMAIN_NAME=$(aws cloudfront get-distribution \
    --id ${DISTRIBUTION_ID} \
    --query 'Distribution.DomainName' \
    --output text)

echo "✓ CloudFront distribution created"
echo ""
echo "=========================================="
echo "CloudFront Setup Complete!"
echo "=========================================="
echo ""
echo "Distribution ID: ${DISTRIBUTION_ID}"
echo "CloudFront URL: https://${DOMAIN_NAME}"
echo ""
echo "Note: CloudFront deployment takes 15-20 minutes to complete."
echo "Your site will be available at the CloudFront URL once deployed."
echo ""
echo "Benefits:"
echo "  - HTTPS enabled automatically"
echo "  - Faster global access via CDN"
echo "  - Reduced S3 costs"
echo ""
