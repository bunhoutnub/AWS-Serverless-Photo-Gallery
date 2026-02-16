# 📁 Project Structure

## Overview
This is a serverless photo gallery application built with AWS services.

```
AWS-Serverless-Photo-Gallery/
├── 📄 README.md                    # Main documentation & setup guide
│
├── 🌐 frontend/                    # Website files (hosted on S3)
│   ├── index.html                  # Main HTML page
│   ├── app.js                      # Frontend JavaScript logic
│   └── styles.css                  # Styling
│
├── ⚡ lambda/                       # AWS Lambda functions (backend)
│   ├── upload_handler/             # Generates presigned URLs for uploads
│   │   ├── lambda_function.py      # Main code
│   │   └── function.zip            # Deployment package
│   │
│   ├── thumbnail_generator/        # Creates thumbnails automatically
│   │   ├── lambda_function.py      # Main code
│   │   ├── requirements.txt        # Python dependencies (Pillow)
│   │   └── function.zip            # Deployment package
│   │
│   ├── list_photos/                # Returns all photos for gallery
│   │   ├── lambda_function.py      # Main code
│   │   └── function.zip            # Deployment package
│   │
│   └── delete_photo/               # Deletes photos & metadata
│       ├── lambda_function.py      # Main code
│       └── function.zip            # Deployment package
│
├── 🚀 Deployment Scripts
│   ├── deploy.sh                   # Full deployment script
│   ├── deploy-simple.sh            # Simplified deployment
│   ├── finish-deployment.sh        # Complete remaining setup
│   └── setup-https.sh              # HTTPS configuration
│
└── 📋 .kiro/specs/                 # Project specifications
    └── photo-gallery/
        ├── requirements.md         # Feature requirements
        ├── design.md               # Architecture design
        └── tasks.md                # Implementation tasks
```

## 🔧 What Each Component Does

### Frontend (Website)
- **index.html** - The webpage users see
- **app.js** - Handles upload, display, delete actions
- **styles.css** - Makes it look nice

### Lambda Functions (Backend)
1. **upload_handler** - Creates secure upload URLs
2. **thumbnail_generator** - Automatically resizes photos (triggered by S3)
3. **list_photos** - Fetches all photos for the gallery
4. **delete_photo** - Removes photos from S3 and database

### AWS Resources (Not in folders, but deployed)
- **S3 Buckets** (3):
  - `photo-gallery-photos-{account-id}` - Original photos
  - `photo-gallery-thumbnails-{account-id}` - Resized thumbnails
  - `photo-gallery-frontend-{account-id}` - Website files

- **API Gateway** - REST API that connects frontend to Lambda functions
- **DynamoDB** - Database storing photo metadata
- **IAM Roles** - Permissions for Lambda functions

## 🌐 Your Live Application
**Website:** http://photo-gallery-frontend-355339423972.s3-website-us-east-1.amazonaws.com
**API:** https://njoff2es13.execute-api.us-east-1.amazonaws.com/prod

## 📝 Quick Reference

### To modify the website:
Edit files in `frontend/` then run:
```bash
aws s3 sync frontend/ s3://photo-gallery-frontend-355339423972/
```

### To update a Lambda function:
1. Edit the `lambda_function.py` file
2. Zip it: `zip function.zip lambda_function.py`
3. Update: `aws lambda update-function-code --function-name {name} --zip-file fileb://function.zip`

### To view logs:
```bash
aws logs tail /aws/lambda/{function-name} --follow
```
