#!/bin/bash

# Simplified AWS Serverless Photo Gallery Deployment
# This version skips the Pillow layer to avoid connection issues

set -e

echo "=========================================="
echo "AWS Photo Gallery - Simplified Deployment"
echo "=========================================="
echo ""

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-us-east-1}

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

PHOTO_BUCKET="photo-gallery-photos-${AWS_ACCOUNT_ID}"
THUMBNAIL_BUCKET="photo-gallery-thumbnails-${AWS_ACCOUNT_ID}"
FRONTEND_BUCKET="photo-gallery-frontend-${AWS_ACCOUNT_ID}"
METADATA_TABLE="photo-gallery-metadata"

echo "Step 1: Deploying Lambda functions (without Pillow layer)..."
echo "-------------------------------------------------------------"

# Upload Handler
echo "Deploying Upload Handler..."
cd lambda/upload_handler
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

# List Handler
echo "Deploying List Handler..."
cd lambda/list_photos
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
cd lambda/delete_photo
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

echo "Step 2: Creating API Gateway..."
echo "--------------------------------"

# Check if API already exists
API_ID=$(aws apigateway get-rest-apis \
    --query "items[?name=='photo-gallery-api'].id" \
    --output text \
    --region ${AWS_REGION})

if [ -z "$API_ID" ]; then
    API_ID=$(aws apigateway create-rest-api \
        --name photo-gallery-api \
        --description "Photo Gallery REST API" \
        --region ${AWS_REGION} \
        --query 'id' \
        --output text)
fi

echo "API ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query 'items[0].id' \
    --output text)

# Create /upload resource
UPLOAD_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/upload'].id" \
    --output text)

if [ -z "$UPLOAD_RESOURCE_ID" ]; then
    UPLOAD_RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id ${API_ID} \
        --parent-id ${ROOT_ID} \
        --path-part upload \
        --region ${AWS_REGION} \
        --query 'id' \
        --output text)
fi

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
PHOTOS_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/photos'].id" \
    --output text)

if [ -z "$PHOTOS_RESOURCE_ID" ]; then
    PHOTOS_RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id ${API_ID} \
        --parent-id ${ROOT_ID} \
        --path-part photos \
        --region ${AWS_REGION} \
        --query 'id' \
        --output text)
fi

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
PHOTO_ID_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query "items[?path=='/photos/{photoId}'].id" \
    --output text)

if [ -z "$PHOTO_ID_RESOURCE_ID" ]; then
    PHOTO_ID_RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id ${API_ID} \
        --parent-id ${PHOTOS_RESOURCE_ID} \
        --path-part '{photoId}' \
        --region ${AWS_REGION} \
        --query 'id' \
        --output text)
fi

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

# Add Lambda permissions
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

echo "Step 3: Deploying frontend..."
echo "------------------------------"

# Update API URL in frontend
sed -i.bak "s|YOUR_API_GATEWAY_URL|${API_URL}|g" frontend/app.js
rm -f frontend/app.js.bak

# Configure frontend bucket
aws s3 website s3://${FRONTEND_BUCKET} \
    --index-document index.html \
    --error-document index.html

# Make frontend public
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

# Upload frontend
aws s3 sync frontend/ s3://${FRONTEND_BUCKET}/

FRONTEND_URL="http://${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"
echo "✓ Frontend deployed"
echo ""

echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo ""
echo "Frontend URL: $FRONTEND_URL"
echo "API Gateway URL: $API_URL"
echo ""
echo "NOTE: Thumbnail generation is disabled (Pillow layer skipped)"
echo "You can upload and view photos, but thumbnails won't be auto-generated"
echo ""
echo "Open the Frontend URL in your browser!"
echo ""
