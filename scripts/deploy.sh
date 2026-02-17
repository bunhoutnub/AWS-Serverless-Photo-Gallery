#!/bin/bash

# AWS Serverless Photo Gallery - Automated Deployment Script
# This script automates the deployment of Lambda functions, IAM roles, and API Gateway

set -e  # Exit on any error

echo "=========================================="
echo "AWS Serverless Photo Gallery Deployment"
echo "=========================================="
echo ""

# Get AWS Account ID and Region
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-us-east-1}

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# Bucket names
PHOTO_BUCKET="photo-gallery-photos-${AWS_ACCOUNT_ID}"
THUMBNAIL_BUCKET="photo-gallery-thumbnails-${AWS_ACCOUNT_ID}"
FRONTEND_BUCKET="photo-gallery-frontend-${AWS_ACCOUNT_ID}"
METADATA_TABLE="photo-gallery-metadata"

echo "Step 1: Creating IAM roles..."
echo "----------------------------"

# Create trust policy for Lambda
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Upload Handler Role
echo "Creating Upload Handler role..."
aws iam create-role \
    --role-name PhotoGalleryUploadHandlerRole \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name PhotoGalleryUploadHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    2>/dev/null || true

cat > /tmp/upload-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject"],
    "Resource": "arn:aws:s3:::${PHOTO_BUCKET}/*"
  }]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryUploadHandlerRole \
    --policy-name S3Access \
    --policy-document file:///tmp/upload-handler-policy.json

# Thumbnail Generator Role
echo "Creating Thumbnail Generator role..."
aws iam create-role \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    2>/dev/null || true

cat > /tmp/thumbnail-generator-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${PHOTO_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::${THUMBNAIL_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${METADATA_TABLE}"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file:///tmp/thumbnail-generator-policy.json

# List Handler Role
echo "Creating List Handler role..."
aws iam create-role \
    --role-name PhotoGalleryListHandlerRole \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name PhotoGalleryListHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    2>/dev/null || true

cat > /tmp/list-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["dynamodb:Scan"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${METADATA_TABLE}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": [
        "arn:aws:s3:::${PHOTO_BUCKET}/*",
        "arn:aws:s3:::${THUMBNAIL_BUCKET}/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryListHandlerRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file:///tmp/list-handler-policy.json

# Delete Handler Role
echo "Creating Delete Handler role..."
aws iam create-role \
    --role-name PhotoGalleryDeleteHandlerRole \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name PhotoGalleryDeleteHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    2>/dev/null || true

cat > /tmp/delete-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::${PHOTO_BUCKET}/*",
        "arn:aws:s3:::${THUMBNAIL_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${METADATA_TABLE}"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryDeleteHandlerRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file:///tmp/delete-handler-policy.json

echo "✓ IAM roles created"
echo ""
echo "Waiting 10 seconds for IAM roles to propagate..."
sleep 10

echo ""
echo "Step 2: Creating Lambda Layer for Pillow..."
echo "-------------------------------------------"

# Create Pillow layer
mkdir -p /tmp/pillow-layer/python
pip install Pillow==10.2.0 -t /tmp/pillow-layer/python --quiet
cd /tmp/pillow-layer
zip -r pillow-layer.zip . > /dev/null
cd -

LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name pillow-layer \
    --description "Pillow library for image processing" \
    --zip-file fileb:///tmp/pillow-layer/pillow-layer.zip \
    --compatible-runtimes python3.11 \
    --region ${AWS_REGION} \
    --query 'LayerVersionArn' \
    --output text)

echo "✓ Pillow layer created: $LAYER_ARN"
echo ""

echo "Step 3: Deploying Lambda functions..."
echo "--------------------------------------"

# Upload Handler
echo "Deploying Upload Handler..."
cd backend/upload_handler
zip -q function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-upload-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryUploadHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{PHOTO_BUCKET_NAME=${PHOTO_BUCKET}}" \
    --region ${AWS_REGION} \
    2>/dev/null || aws lambda update-function-code \
    --function-name photo-gallery-upload-handler \
    --zip-file fileb://function.zip \
    --region ${AWS_REGION} > /dev/null

cd ../..
echo "✓ Upload Handler deployed"

# Thumbnail Generator
echo "Deploying Thumbnail Generator..."
cd backend/thumbnail_generator
zip -q function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-thumbnail-generator \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryThumbnailGeneratorRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --layers ${LAYER_ARN} \
    --timeout 60 \
    --memory-size 512 \
    --environment Variables="{PHOTO_BUCKET_NAME=${PHOTO_BUCKET},THUMBNAIL_BUCKET_NAME=${THUMBNAIL_BUCKET},METADATA_TABLE_NAME=${METADATA_TABLE},THUMBNAIL_MAX_SIZE=200}" \
    --region ${AWS_REGION} \
    2>/dev/null || aws lambda update-function-code \
    --function-name photo-gallery-thumbnail-generator \
    --zip-file fileb://function.zip \
    --region ${AWS_REGION} > /dev/null

cd ../..
echo "✓ Thumbnail Generator deployed"

# List Handler
echo "Deploying List Handler..."
cd backend/list_photos
zip -q function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-list-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryListHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{METADATA_TABLE_NAME=${METADATA_TABLE},PHOTO_BUCKET_NAME=${PHOTO_BUCKET},THUMBNAIL_BUCKET_NAME=${THUMBNAIL_BUCKET},URL_EXPIRATION=3600}" \
    --region ${AWS_REGION} \
    2>/dev/null || aws lambda update-function-code \
    --function-name photo-gallery-list-handler \
    --zip-file fileb://function.zip \
    --region ${AWS_REGION} > /dev/null

cd ../..
echo "✓ List Handler deployed"

# Delete Handler
echo "Deploying Delete Handler..."
cd backend/delete_photo
zip -q function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-delete-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryDeleteHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{METADATA_TABLE_NAME=${METADATA_TABLE},PHOTO_BUCKET_NAME=${PHOTO_BUCKET},THUMBNAIL_BUCKET_NAME=${THUMBNAIL_BUCKET}}" \
    --region ${AWS_REGION} \
    2>/dev/null || aws lambda update-function-code \
    --function-name photo-gallery-delete-handler \
    --zip-file fileb://function.zip \
    --region ${AWS_REGION} > /dev/null

cd ../..
echo "✓ Delete Handler deployed"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run finish-deployment.sh to configure S3 triggers and API Gateway"
echo "2. Update frontend/app.js with your API Gateway URL"
echo "3. Deploy frontend with: aws s3 sync frontend/ s3://${FRONTEND_BUCKET}/"
echo ""THUMBNAIL_BUCKET}}" \
    --region ${AWS_REGION} \
    2>/dev/null || aws lambda update-function-code \
    --function-name photo-gallery-delete-handler \
    --zip-file fileb://function.zip \
    --region ${AWS_REGION} > /dev/null

cd ../..
echo "✓ Delete Handler deployed"
echo ""

echo "Step 4: Configuring S3 event notification..."
echo "---------------------------------------------"

# Add permission for S3 to invoke Lambda
aws lambda add-permission \
    --function-name photo-gallery-thumbnail-generator \
    --statement-id s3-trigger \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::${PHOTO_BUCKET} \
    --region ${AWS_REGION} \
    2>/dev/null || echo "Permission already exists"

# Create notification configuration
cat > /tmp/notification.json << EOF
{
  "LambdaFunctionConfigurations": [{
    "LambdaFunctionArn": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-thumbnail-generator",
    "Events": ["s3:ObjectCreated:*"],
    "Filter": {
      "Key": {
        "FilterRules": [{
          "Name": "prefix",
          "Value": "photos/"
        }]
      }
    }
  }]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket ${PHOTO_BUCKET} \
    --notification-configuration file:///tmp/notification.json

echo "✓ S3 event notification configured"
echo ""

echo "Step 5: Creating API Gateway..."
echo "--------------------------------"

# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name photo-gallery-api \
    --description "Photo Gallery REST API" \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text 2>/dev/null || aws apigateway get-rest-apis \
    --query "items[?name=='photo-gallery-api'].id" \
    --output text \
    --region ${AWS_REGION})

echo "API ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query 'items[0].id' \
    --output text)

# Create /upload resource
UPLOAD_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part upload \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text 2>/dev/null || aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/upload'].id" \
    --output text)

# Create POST method for /upload
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_RESOURCE_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${AWS_REGION} \
    2>/dev/null || true

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-upload-handler/invocations \
    --region ${AWS_REGION} \
    2>/dev/null || true

# Create /photos resource
PHOTOS_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part photos \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text 2>/dev/null || aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/photos'].id" \
    --output text)

# Create GET method for /photos
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_RESOURCE_ID} \
    --http-method GET \
    --authorization-type NONE \
    --region ${AWS_REGION} \
    2>/dev/null || true

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-list-handler/invocations \
    --region ${AWS_REGION} \
    2>/dev/null || true

# Create /photos/{photoId} resource
PHOTO_ID_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${PHOTOS_RESOURCE_ID} \
    --path-part '{photoId}' \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text 2>/dev/null || aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/photos/{photoId}'].id" \
    --output text)

# Create DELETE method for /photos/{photoId}
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_RESOURCE_ID} \
    --http-method DELETE \
    --authorization-type NONE \
    --region ${AWS_REGION} \
    2>/dev/null || true

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_RESOURCE_ID} \
    --http-method DELETE \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-delete-handler/invocations \
    --region ${AWS_REGION} \
    2>/dev/null || true

# Deploy API
aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${AWS_REGION} \
    > /dev/null

# Add Lambda permissions for API Gateway
aws lambda add-permission \
    --function-name photo-gallery-upload-handler \
    --statement-id apigateway-upload \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} \
    2>/dev/null || true

aws lambda add-permission \
    --function-name photo-gallery-list-handler \
    --statement-id apigateway-list \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} \
    2>/dev/null || true

aws lambda add-permission \
    --function-name photo-gallery-delete-handler \
    --statement-id apigateway-delete \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} \
    2>/dev/null || true

API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod"
echo "✓ API Gateway created: $API_URL"
echo ""

echo "Step 6: Updating and deploying frontend..."
echo "-------------------------------------------"

# Update API URL in frontend
sed -i.bak "s|YOUR_API_GATEWAY_URL|${API_URL}|g" frontend/app.js
rm -f frontend/app.js.bak

# Configure frontend bucket for static website hosting
aws s3 website s3://${FRONTEND_BUCKET} \
    --index-document index.html \
    --error-document index.html

# Make frontend files publicly readable
cat > /tmp/frontend-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${FRONTEND_BUCKET}/*"
    }]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${FRONTEND_BUCKET} \
    --policy file:///tmp/frontend-policy.json

# Upload frontend files
aws s3 sync frontend/ s3://${FRONTEND_BUCKET}/

FRONTEND_URL="http://${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"
echo "✓ Frontend deployed: $FRONTEND_URL"
echo ""

echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo ""
echo "Your Photo Gallery is ready!"
echo ""
echo "Frontend URL: $FRONTEND_URL"
echo "API Gateway URL: $API_URL"
echo ""
echo "Open the Frontend URL in your browser to start using your photo gallery!"
echo ""
