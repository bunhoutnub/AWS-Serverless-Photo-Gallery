#!/bin/bash

# Setup HTTPS with CloudFront for Photo Gallery

set -e

echo "=========================================="
echo "Setting up HTTPS with CloudFront"
echo "=========================================="
echo ""

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-us-east-1}

FRONTEND_BUCKET="photo-gallery-frontend-${AWS_ACCOUNT_ID}"
WEBSITE_ENDPOINT="${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"

echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "Website Endpoint: $WEBSITE_ENDPOINT"
echo ""

echo "Creating CloudFront distribution..."
echo "This may take 10-15 minutes to fully deploy."
echo ""

# Create CloudFront distribution configuration
cat > /tmp/cloudfront-config.json << EOF
{
  "CallerReference": "photo-gallery-$(date +%s)",
  "Comment": "Photo Gallery HTTPS Distribution",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-Website-${WEBSITE_ENDPOINT}",
        "DomainName": "${WEBSITE_ENDPOINT}",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-Website-${WEBSITE_ENDPOINT}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "PriceClass": "PriceClass_100"
}
EOF

# Create the distribution
DISTRIBUTION_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cloudfront-config.json \
    --output json)

DISTRIBUTION_ID=$(echo $DISTRIBUTION_OUTPUT | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
DOMAIN_NAME=$(echo $DISTRIBUTION_OUTPUT | grep -o '"DomainName": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "✓ CloudFront distribution created!"
echo ""
echo "Distribution ID: $DISTRIBUTION_ID"
echo "CloudFront Domain: $DOMAIN_NAME"
echo ""
echo "Your new HTTPS URL: https://$DOMAIN_NAME"
echo ""
echo "=========================================="
echo "⏳ Deployment Status"
echo "=========================================="
echo ""
echo "CloudFront is now deploying your site globally."
echo "This takes 10-15 minutes to complete."
echo ""
echo "Current status: Deploying..."
echo ""
echo "You can check the status with:"
echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status' --output text"
echo ""
echo "When it shows 'Deployed', your HTTPS site will be ready at:"
echo "  https://$DOMAIN_NAME"
echo ""
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
