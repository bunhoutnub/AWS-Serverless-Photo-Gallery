#!/bin/bash

# Finish AWS Photo Gallery Deployment
# Creates API Gateway and deploys frontend

set -e

echo "=========================================="
echo "Finishing Photo Gallery Deployment"
echo "=========================================="
echo ""

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=${AWS_REGION:-us-east-1}

PHOTO_BUCKET="photo-gallery-photos-${AWS_ACCOUNT_ID}"
THUMBNAIL_BUCKET="photo-gallery-thumbnails-${AWS_ACCOUNT_ID}"
FRONTEND_BUCKET="photo-gallery-frontend-${AWS_ACCOUNT_ID}"

echo "Creating API Gateway..."
echo "-----------------------"

# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name photo-gallery-api \
    --description "Photo Gallery REST API" \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

echo "API ID: $API_ID"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${AWS_REGION} \
    --query 'items[0].id' \
    --output text)

# Create /upload
echo "Creating /upload endpoint..."
UPLOAD_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part upload \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${AWS_REGION}

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-upload-handler/invocations \
    --region ${AWS_REGION}

# Create /photos
echo "Creating /photos endpoint..."
PHOTOS_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part photos \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_ID} \
    --http-method GET \
    --authorization-type NONE \
    --region ${AWS_REGION}

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-list-handler/invocations \
    --region ${AWS_REGION}

# Create /photos/{photoId}
echo "Creating /photos/{photoId} endpoint..."
PHOTO_ID_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${PHOTOS_ID} \
    --path-part '{photoId}' \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_ID} \
    --http-method DELETE \
    --authorization-type NONE \
    --region ${AWS_REGION}

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_ID} \
    --http-method DELETE \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-delete-handler/invocations \
    --region ${AWS_REGION}

# Deploy API
echo "Deploying API..."
aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${AWS_REGION} > /dev/null

# Add Lambda permissions
echo "Adding Lambda permissions..."
aws lambda add-permission \
    --function-name photo-gallery-upload-handler \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} 2>/dev/null || true

aws lambda add-permission \
    --function-name photo-gallery-list-handler \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} 2>/dev/null || true

aws lambda add-permission \
    --function-name photo-gallery-delete-handler \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION} 2>/dev/null || true

API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod"
echo "✓ API Gateway created: $API_URL"
echo ""

echo "Deploying Frontend..."
echo "---------------------"

# Update API URL in frontend
sed "s|YOUR_API_GATEWAY_URL|${API_URL}|g" frontend/app.js > frontend/app-updated.js
mv frontend/app-updated.js frontend/app.js

# Configure bucket for website hosting
aws s3 website s3://${FRONTEND_BUCKET} \
    --index-document index.html

# Make bucket public
cat > /tmp/policy.json << EOF
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
    --policy file:///tmp/policy.json

# Upload files
aws s3 sync frontend/ s3://${FRONTEND_BUCKET}/ --quiet

FRONTEND_URL="http://${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"

echo "✓ Frontend deployed"
echo ""
echo "=========================================="
echo "✓✓✓ DEPLOYMENT COMPLETE! ✓✓✓"
echo "=========================================="
echo ""
echo "🎉 Your Photo Gallery is ready!"
echo ""
echo "Frontend URL: $FRONTEND_URL"
echo "API URL: $API_URL"
echo ""
echo "Open the Frontend URL in your browser to start using it!"
echo ""
