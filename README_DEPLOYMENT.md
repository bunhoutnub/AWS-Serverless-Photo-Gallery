# AWS Serverless Photo Gallery

A serverless web application that enables users to upload, view, manage, and search photos through a web interface. Photos are automatically resized into thumbnails, and metadata is stored for quick retrieval. Built entirely with AWS services - no servers to manage.

## Features

- Upload photos through web interface
- Automatic thumbnail generation
- View photo gallery with thumbnails
- Click to view full-size images
- Delete photos
- Search by tags/date
- Fully serverless and scalable

## Architecture

```
User Browser
    ↓
S3 Static Website (frontend/)
    ↓
API Gateway (REST API)
    ↓
Lambda Functions (lambda/)
    ↓
S3 Buckets (photos + thumbnails) + DynamoDB (metadata)
```

## Project Structure

```
photo-gallery/
├── frontend/
│   ├── index.html          # Main gallery page
│   ├── styles.css          # Styling
│   └── app.js              # Frontend logic
├── lambda/
│   ├── upload_handler/
│   │   └── lambda_function.py
│   ├── thumbnail_generator/
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── list_photos/
│   │   └── lambda_function.py
│   └── delete_photo/
│       └── lambda_function.py
└── README.md
```

## AWS Services Used

- **S3**: Website hosting + photo storage
- **Lambda**: 4 functions (upload, thumbnail, list, delete)
- **API Gateway**: REST API with 3 endpoints
- **DynamoDB**: Photo metadata storage
- **IAM**: Permissions and security
- **CloudWatch**: Logging and monitoring

## Setup Instructions

### Prerequisites

- AWS Account ([Sign up here](https://aws.amazon.com/))
- AWS CLI configured ([Installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- Python 3.11+
- Basic knowledge of AWS services

### Infrastructure Setup

Follow these steps to deploy the photo gallery to AWS:

#### 1. Create S3 Buckets

```bash
# Replace {account-id} with your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1  # Change to your preferred region

# Create Photo Bucket
aws s3 mb s3://photo-gallery-photos-${AWS_ACCOUNT_ID} --region ${AWS_REGION}

# Create Thumbnail Bucket
aws s3 mb s3://photo-gallery-thumbnails-${AWS_ACCOUNT_ID} --region ${AWS_REGION}

# Create Frontend Bucket
aws s3 mb s3://photo-gallery-frontend-${AWS_ACCOUNT_ID} --region ${AWS_REGION}

# Block public access for Photo Bucket (access via presigned URLs)
aws s3api put-public-access-block \
    --bucket photo-gallery-photos-${AWS_ACCOUNT_ID} \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable public read for Thumbnail Bucket (optional - can use presigned URLs instead)
aws s3api put-bucket-policy \
    --bucket photo-gallery-thumbnails-${AWS_ACCOUNT_ID} \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::photo-gallery-thumbnails-'${AWS_ACCOUNT_ID}'/*"
        }]
    }'
```

#### 2. Configure S3 Static Website Hosting

```bash
# Enable static website hosting for Frontend Bucket
aws s3 website s3://photo-gallery-frontend-${AWS_ACCOUNT_ID} \
    --index-document index.html \
    --error-document index.html

# Make frontend files publicly readable
aws s3api put-bucket-policy \
    --bucket photo-gallery-frontend-${AWS_ACCOUNT_ID} \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::photo-gallery-frontend-'${AWS_ACCOUNT_ID}'/*"
        }]
    }'

# Upload frontend files
aws s3 sync frontend/ s3://photo-gallery-frontend-${AWS_ACCOUNT_ID}/

# Get website URL
echo "Frontend URL: http://photo-gallery-frontend-${AWS_ACCOUNT_ID}.s3-website-${AWS_REGION}.amazonaws.com"
```

#### 3. Create DynamoDB Table

```bash
aws dynamodb create-table \
    --table-name photo-gallery-metadata \
    --attribute-definitions AttributeName=photoId,AttributeType=S \
    --key-schema AttributeName=photoId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${AWS_REGION}
```

#### 4. Create IAM Roles for Lambda Functions

**Upload Handler Role:**
```bash
# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
    --role-name PhotoGalleryUploadHandlerRole \
    --assume-role-policy-document file://trust-policy.json

# Attach basic Lambda execution policy
aws iam attach-role-policy \
    --role-name PhotoGalleryUploadHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create and attach custom policy for S3 access
cat > upload-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject"],
    "Resource": "arn:aws:s3:::photo-gallery-photos-${AWS_ACCOUNT_ID}/*"
  }]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryUploadHandlerRole \
    --policy-name S3Access \
    --policy-document file://upload-handler-policy.json
```

**Thumbnail Generator Role:**
```bash
aws iam create-role \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > thumbnail-generator-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::photo-gallery-photos-${AWS_ACCOUNT_ID}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::photo-gallery-thumbnails-${AWS_ACCOUNT_ID}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/photo-gallery-metadata"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryThumbnailGeneratorRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file://thumbnail-generator-policy.json
```

**List Handler Role:**
```bash
aws iam create-role \
    --role-name PhotoGalleryListHandlerRole \
    --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
    --role-name PhotoGalleryListHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > list-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["dynamodb:Scan"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/photo-gallery-metadata"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": [
        "arn:aws:s3:::photo-gallery-photos-${AWS_ACCOUNT_ID}/*",
        "arn:aws:s3:::photo-gallery-thumbnails-${AWS_ACCOUNT_ID}/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryListHandlerRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file://list-handler-policy.json
```

**Delete Handler Role:**
```bash
aws iam create-role \
    --role-name PhotoGalleryDeleteHandlerRole \
    --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
    --role-name PhotoGalleryDeleteHandlerRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > delete-handler-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::photo-gallery-photos-${AWS_ACCOUNT_ID}/*",
        "arn:aws:s3:::photo-gallery-thumbnails-${AWS_ACCOUNT_ID}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/photo-gallery-metadata"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name PhotoGalleryDeleteHandlerRole \
    --policy-name S3DynamoDBAccess \
    --policy-document file://delete-handler-policy.json
```

#### 5. Create Lambda Layer for Pillow

```bash
# Create directory for layer
mkdir -p pillow-layer/python

# Install Pillow in the layer directory
pip install Pillow==10.2.0 -t pillow-layer/python

# Create zip file
cd pillow-layer
zip -r ../pillow-layer.zip .
cd ..

# Create Lambda layer
aws lambda publish-layer-version \
    --layer-name pillow-layer \
    --description "Pillow library for image processing" \
    --zip-file fileb://pillow-layer.zip \
    --compatible-runtimes python3.11 \
    --region ${AWS_REGION}

# Note the LayerVersionArn from the output - you'll need it for the thumbnail generator
```

#### 6. Deploy Lambda Functions

**Upload Handler:**
```bash
cd lambda/upload_handler
zip function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-upload-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryUploadHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{PHOTO_BUCKET_NAME=photo-gallery-photos-${AWS_ACCOUNT_ID}}" \
    --region ${AWS_REGION}

cd ../..
```

**Thumbnail Generator:**
```bash
cd lambda/thumbnail_generator
zip function.zip lambda_function.py

# Replace {LAYER_ARN} with the LayerVersionArn from step 5
aws lambda create-function \
    --function-name photo-gallery-thumbnail-generator \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryThumbnailGeneratorRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --layers {LAYER_ARN} \
    --timeout 60 \
    --memory-size 512 \
    --environment Variables="{PHOTO_BUCKET_NAME=photo-gallery-photos-${AWS_ACCOUNT_ID},THUMBNAIL_BUCKET_NAME=photo-gallery-thumbnails-${AWS_ACCOUNT_ID},METADATA_TABLE_NAME=photo-gallery-metadata,THUMBNAIL_MAX_SIZE=200}" \
    --region ${AWS_REGION}

cd ../..
```

**List Handler:**
```bash
cd lambda/list_photos
zip function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-list-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryListHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{METADATA_TABLE_NAME=photo-gallery-metadata,PHOTO_BUCKET_NAME=photo-gallery-photos-${AWS_ACCOUNT_ID},THUMBNAIL_BUCKET_NAME=photo-gallery-thumbnails-${AWS_ACCOUNT_ID},URL_EXPIRATION=3600}" \
    --region ${AWS_REGION}

cd ../..
```

**Delete Handler:**
```bash
cd lambda/delete_photo
zip function.zip lambda_function.py

aws lambda create-function \
    --function-name photo-gallery-delete-handler \
    --runtime python3.11 \
    --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/PhotoGalleryDeleteHandlerRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment Variables="{METADATA_TABLE_NAME=photo-gallery-metadata,PHOTO_BUCKET_NAME=photo-gallery-photos-${AWS_ACCOUNT_ID},THUMBNAIL_BUCKET_NAME=photo-gallery-thumbnails-${AWS_ACCOUNT_ID}}" \
    --region ${AWS_REGION}

cd ../..
```

#### 7. Configure S3 Event Notification

```bash
# Add permission for S3 to invoke Lambda
aws lambda add-permission \
    --function-name photo-gallery-thumbnail-generator \
    --statement-id s3-trigger \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::photo-gallery-photos-${AWS_ACCOUNT_ID} \
    --region ${AWS_REGION}

# Create notification configuration
cat > notification.json << EOF
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
    --bucket photo-gallery-photos-${AWS_ACCOUNT_ID} \
    --notification-configuration file://notification.json
```

#### 8. Create API Gateway

```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name photo-gallery-api \
    --description "Photo Gallery REST API" \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

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
    --output text)

# Create POST method for /upload
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_RESOURCE_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${AWS_REGION}

# Integrate with Upload Handler Lambda
aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${UPLOAD_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-upload-handler/invocations \
    --region ${AWS_REGION}

# Create /photos resource
PHOTOS_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part photos \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

# Create GET method for /photos
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_RESOURCE_ID} \
    --http-method GET \
    --authorization-type NONE \
    --region ${AWS_REGION}

# Integrate with List Handler Lambda
aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTOS_RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-list-handler/invocations \
    --region ${AWS_REGION}

# Create /photos/{photoId} resource
PHOTO_ID_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${PHOTOS_RESOURCE_ID} \
    --path-part '{photoId}' \
    --region ${AWS_REGION} \
    --query 'id' \
    --output text)

# Create DELETE method for /photos/{photoId}
aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_RESOURCE_ID} \
    --http-method DELETE \
    --authorization-type NONE \
    --region ${AWS_REGION}

# Integrate with Delete Handler Lambda
aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${PHOTO_ID_RESOURCE_ID} \
    --http-method DELETE \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:photo-gallery-delete-handler/invocations \
    --region ${AWS_REGION}

# Deploy API
aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${AWS_REGION}

# Add Lambda permissions for API Gateway
aws lambda add-permission \
    --function-name photo-gallery-upload-handler \
    --statement-id apigateway-upload \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION}

aws lambda add-permission \
    --function-name photo-gallery-list-handler \
    --statement-id apigateway-list \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION}

aws lambda add-permission \
    --function-name photo-gallery-delete-handler \
    --statement-id apigateway-delete \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
    --region ${AWS_REGION}

# Print API URL
echo "API Gateway URL: https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod"
```

#### 9. Configure CORS

```bash
# Enable CORS for all resources (upload, photos, photos/{photoId})
# This is handled automatically by Lambda functions returning CORS headers
# But you can also configure it at API Gateway level if needed
```

#### 10. Update Frontend Configuration

```bash
# Update the API_BASE_URL in frontend/app.js
API_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod"
sed -i "s|YOUR_API_GATEWAY_URL|${API_URL}|g" frontend/app.js

# Re-upload frontend files
aws s3 sync frontend/ s3://photo-gallery-frontend-${AWS_ACCOUNT_ID}/
```

#### 11. Set Up CloudWatch Alarms (Optional)

```bash
# Create billing alarm
aws cloudwatch put-metric-alarm \
    --alarm-name photo-gallery-billing-alarm \
    --alarm-description "Alert when estimated charges exceed $10" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 21600 \
    --evaluation-periods 1 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --region us-east-1
```

### Testing the Deployment

1. Open the frontend URL in your browser
2. Upload a test photo
3. Wait a few seconds for thumbnail generation
4. Refresh the page to see your photo in the gallery
5. Click on the photo to view full size
6. Test the delete functionality

### Cleanup (To Remove All Resources)

```bash
# Delete Lambda functions
aws lambda delete-function --function-name photo-gallery-upload-handler
aws lambda delete-function --function-name photo-gallery-thumbnail-generator
aws lambda delete-function --function-name photo-gallery-list-handler
aws lambda delete-function --function-name photo-gallery-delete-handler

# Delete Lambda layer
aws lambda delete-layer-version --layer-name pillow-layer --version-number 1

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id ${API_ID}

# Delete DynamoDB table
aws dynamodb delete-table --table-name photo-gallery-metadata

# Empty and delete S3 buckets
aws s3 rm s3://photo-gallery-photos-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://photo-gallery-photos-${AWS_ACCOUNT_ID}

aws s3 rm s3://photo-gallery-thumbnails-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://photo-gallery-thumbnails-${AWS_ACCOUNT_ID}

aws s3 rm s3://photo-gallery-frontend-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://photo-gallery-frontend-${AWS_ACCOUNT_ID}

# Delete IAM roles and policies
aws iam delete-role-policy --role-name PhotoGalleryUploadHandlerRole --policy-name S3Access
aws iam detach-role-policy --role-name PhotoGalleryUploadHandlerRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name PhotoGalleryUploadHandlerRole

aws iam delete-role-policy --role-name PhotoGalleryThumbnailGeneratorRole --policy-name S3DynamoDBAccess
aws iam detach-role-policy --role-name PhotoGalleryThumbnailGeneratorRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name PhotoGalleryThumbnailGeneratorRole

aws iam delete-role-policy --role-name PhotoGalleryListHandlerRole --policy-name S3DynamoDBAccess
aws iam detach-role-policy --role-name PhotoGalleryListHandlerRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name PhotoGalleryListHandlerRole

aws iam delete-role-policy --role-name PhotoGalleryDeleteHandlerRole --policy-name S3DynamoDBAccess
aws iam detach-role-policy --role-name PhotoGalleryDeleteHandlerRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name PhotoGalleryDeleteHandlerRole
```

## Development

This project follows a spec-driven development approach. See `.kiro/specs/photo-gallery/` for:
- `requirements.md` - Detailed requirements and acceptance criteria
- `design.md` - Architecture and design decisions
- `tasks.md` - Implementation task list

## Testing

The project uses a dual testing approach:
- **Unit tests**: Specific examples and edge cases
- **Property-based tests**: Universal properties across random inputs

Testing libraries:
- Python: `hypothesis` for property-based testing
- JavaScript: `fast-check` for frontend property-based testing

## License

MIT
