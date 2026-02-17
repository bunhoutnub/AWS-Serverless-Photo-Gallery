# AWS Serverless Photo Gallery

A fully serverless photo gallery application built with AWS services. Upload, view, and manage photos with automatic thumbnail generation - no servers to manage!

## Live Demo

**Website:** http://photo-gallery-frontend-355339423972.s3-website-us-east-1.amazonaws.com

**CloudFront CDN (HTTPS):** https://d1wu6qrhlfijph.cloudfront.net

Try it out! Upload photos and see the serverless architecture in action.

## Features

- Upload photos (JPEG, PNG, GIF, HEIC) up to 50MB
- Automatic thumbnail generation
- View gallery with thumbnails
- Full-size photo viewer
- Delete photos
- Responsive design
- 100% serverless - scales automatically

## Architecture

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────┐
│   CloudFront    │  (CDN + HTTPS)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  S3 Website     │  (Frontend: HTML/CSS/JS)
└──────┬──────────┘
       │ API Calls
       ▼
┌─────────────────┐
│  API Gateway    │  (REST API)
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Lambda Functions│  (Upload, List, Delete, Thumbnail)
└──────┬──────────┘
       │
       ▼
┌──────────────────────────┐
│  S3 Buckets + DynamoDB   │  (Storage + Metadata)
└──────────────────────────┘
```

**[View Detailed Architecture Diagram →](docs/ARCHITECTURE.md)**

## Tech Stack

**Frontend:**
- HTML5, CSS3, JavaScript
- Hosted on S3 Static Website
- CloudFront CDN for HTTPS and global delivery

**Backend:**
- AWS Lambda (Python 3.11)
- API Gateway (REST API)
- S3 (object storage)
- DynamoDB (NoSQL database)
- CloudFront (CDN)
- Pillow (image processing)

## Project Structure

```
AWS-Serverless-Photo-Gallery/
├── README.md              # You are here
├── .gitignore             # Git ignore rules
│
├── frontend/              # Website files
│   ├── index.html         # Main page
│   ├── app.js             # JavaScript logic
│   ├── styles.css         # Styling
│   └── README.md          # Frontend docs
│
├── backend/               # Lambda functions
│   ├── upload_handler/    # Generates upload URLs
│   ├── thumbnail_generator/ # Creates thumbnails
│   ├── list_photos/       # Lists all photos
│   └── delete_photo/      # Deletes photos
│
├── docs/                  # Documentation
│   ├── PROJECT_STRUCTURE.md  # Detailed structure
│   ├── QUICK_START.md        # Quick commands
│   ├── PORTFOLIO_TIPS.md     # Interview prep
│   ├── GITHUB_SAFETY.md      # Security tips
│   └── README_DEPLOYMENT.md  # Full deployment guide
│
└── scripts/               # Deployment scripts
    ├── deploy.sh
    ├── deploy-simple.sh
    ├── finish-deployment.sh
    └── setup-https.sh
```

## Quick Start

### View Documentation
- [Architecture Diagram](docs/ARCHITECTURE.md) - Detailed system architecture
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Detailed file organization
- [Quick Start Guide](docs/QUICK_START.md) - Common commands
- [CloudFront CDN Setup](docs/CLOUDFRONT_SETUP.md) - Add HTTPS and global CDN
- [Portfolio Tips](docs/PORTFOLIO_TIPS.md) - Interview preparation
- [Deployment Guide](docs/README_DEPLOYMENT.md) - Full setup instructions

### Update Frontend
```bash
cd frontend/
aws s3 sync . s3://photo-gallery-frontend-355339423972/
# If using CloudFront, invalidate cache:
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
```

### Update Backend Function
```bash
cd backend/upload_handler/
zip function.zip lambda_function.py
aws lambda update-function-code \
  --function-name photo-gallery-upload-handler \
  --zip-file fileb://function.zip
```

## What I Learned

- Building serverless applications on AWS
- Lambda function development and deployment
- S3 event notifications and triggers
- API Gateway configuration and CORS
- DynamoDB NoSQL database operations
- Image processing with Python Pillow
- Infrastructure as Code concepts

## AWS Resources

- **S3 Buckets:** 3 (photos, thumbnails, frontend)
- **Lambda Functions:** 4 (upload, thumbnail, list, delete)
- **API Gateway:** 1 REST API
- **DynamoDB:** 1 table
- **IAM Roles:** 4 (one per Lambda)
- **CloudFront:** 1 distribution

## Future Enhancements

- [x] CloudFront CDN integration
- [ ] User authentication (AWS Cognito)
- [ ] AI-powered tagging (AWS Rekognition)
- [ ] Search and filter functionality
- [ ] Bulk upload support
- [ ] Custom domain name

## License

MIT License - Feel free to use this project for learning!

## Author

Built as a portfolio project to demonstrate AWS serverless architecture skills.

---

**Note:** This is a demo project showcasing serverless architecture on AWS.
