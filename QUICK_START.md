# 🚀 Quick Start Guide

## Your Photo Gallery is Live!

**Website:** http://photo-gallery-frontend-355339423972.s3-website-us-east-1.amazonaws.com

## What You Can Do

### Upload Photos
1. Click "Choose a photo"
2. Select JPG, PNG, or GIF (max 10MB)
3. Click "Upload"
4. Wait 3 seconds for thumbnail to generate
5. Refresh to see your photo

### View Photos
- Click any photo to see full size
- Click X or outside modal to close

### Delete Photos
- Click "Delete" button on any photo
- Confirm deletion
- Photo removed from everywhere (S3 + database)

## Common Tasks

### Update the Website
```bash
cd frontend/
# Edit index.html, app.js, or styles.css
aws s3 sync . s3://photo-gallery-frontend-355339423972/
```

### Update a Backend Function
```bash
cd backend/upload_handler/
# Edit lambda_function.py
zip function.zip lambda_function.py
aws lambda update-function-code \
  --function-name photo-gallery-upload-handler \
  --zip-file fileb://function.zip
```

### View Logs
```bash
# Upload handler logs
aws logs tail /aws/lambda/photo-gallery-upload-handler --follow

# Thumbnail generator logs
aws logs tail /aws/lambda/photo-gallery-thumbnail-generator --follow

# List photos logs
aws logs tail /aws/lambda/photo-gallery-list-handler --follow

# Delete handler logs
aws logs tail /aws/lambda/photo-gallery-delete-handler --follow
```

### Check What's in S3
```bash
# Original photos
aws s3 ls s3://photo-gallery-photos-355339423972/photos/ --recursive

# Thumbnails
aws s3 ls s3://photo-gallery-thumbnails-355339423972/ --recursive
```

### Check DynamoDB
```bash
# Count photos
aws dynamodb scan --table-name photo-gallery-metadata --select COUNT

# See all metadata
aws dynamodb scan --table-name photo-gallery-metadata
```

## Architecture

```
User Browser
    ↓
S3 Static Website (frontend)
    ↓
API Gateway (REST API)
    ↓
Lambda Functions
    ↓
S3 (photos/thumbnails) + DynamoDB (metadata)
```

## AWS Resources

- **S3 Buckets:** 3 (photos, thumbnails, frontend)
- **Lambda Functions:** 4 (upload, thumbnail, list, delete)
- **API Gateway:** 1 REST API
- **DynamoDB:** 1 table
- **IAM Roles:** 4 (one per Lambda)

## Need Help?

- Check `PROJECT_STRUCTURE.md` for file organization
- Check `README.md` for full setup instructions
- Check individual `lambda/*/README.md` for function details
