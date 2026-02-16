# 📸 AWS Serverless Photo Gallery

A fully serverless photo gallery application built with AWS services. Upload, view, and manage photos with automatic thumbnail generation - no servers to manage!

## 🌐 Live Demo

**Website:** http://photo-gallery-frontend-355339423972.s3-website-us-east-1.amazonaws.com

Try it out! Upload sample photos and see the serverless architecture in action.

## ✨ Features

- ✅ Upload photos (JPEG, PNG, GIF, HEIC)
- ✅ Automatic thumbnail generation
- ✅ View gallery with thumbnails
- ✅ Full-size photo viewer
- ✅ Delete photos
- ✅ Responsive design
- ✅ 100% serverless - scales automatically

## 🏗️ Architecture

```
User Browser
    ↓
S3 Static Website (frontend)
    ↓
API Gateway (REST API)
    ↓
Lambda Functions (backend)
    ↓
S3 (storage) + DynamoDB (metadata)
```

## 🛠️ Tech Stack

**Frontend:**
- HTML5, CSS3, JavaScript
- Hosted on S3 Static Website

**Backend:**
- AWS Lambda (Python 3.11)
- API Gateway (REST API)
- S3 (object storage)
- DynamoDB (NoSQL database)
- Pillow (image processing)

**Infrastructure:**
- 4 Lambda Functions
- 3 S3 Buckets
- 1 API Gateway
- 1 DynamoDB Table
- IAM Roles for security

## 📁 Project Structure

```
AWS-Serverless-Photo-Gallery/
├── frontend/           # Website (HTML, CSS, JS)
├── backend/            # Lambda functions (Python)
│   ├── upload_handler/
│   ├── thumbnail_generator/
│   ├── list_photos/
│   └── delete_photo/
└── docs/              # Documentation
```

## 🚀 Key Features Demonstrated

### 1. Serverless Architecture
- No servers to manage or maintain
- Auto-scaling based on demand
- Pay only for what you use

### 2. Event-Driven Processing
- S3 triggers Lambda on photo upload
- Automatic thumbnail generation
- Asynchronous processing

### 3. RESTful API Design
- `POST /upload` - Generate presigned URLs
- `GET /photos` - List all photos
- `DELETE /photos/{id}` - Remove photos

### 4. Security Best Practices
- IAM roles with least privilege
- Presigned URLs for secure uploads
- CORS configuration
- Private S3 buckets

### 5. Image Processing
- Automatic thumbnail generation using Pillow
- Maintains aspect ratio
- Stores metadata (dimensions, upload date)

## 💡 What I Learned

- Building serverless applications on AWS
- Lambda function development and deployment
- S3 event notifications and triggers
- API Gateway configuration and CORS
- DynamoDB NoSQL database operations
- Image processing with Python Pillow
- Infrastructure as Code concepts

## 🔧 Local Development

```bash
# Clone the repository
git clone https://github.com/yourusername/aws-serverless-photo-gallery.git

# Update Lambda function
cd backend/upload_handler
zip function.zip lambda_function.py
aws lambda update-function-code --function-name photo-gallery-upload-handler --zip-file fileb://function.zip

# Update frontend
cd frontend
aws s3 sync . s3://photo-gallery-frontend-{account-id}/
```

## 📊 Cost Optimization

This project uses AWS Free Tier eligible services:
- Lambda: 1M free requests/month
- S3: 5GB free storage
- DynamoDB: 25GB free storage
- API Gateway: 1M free requests/month

**Estimated monthly cost:** $0-5 for typical usage

## 🎯 Future Enhancements

- [ ] User authentication (AWS Cognito)
- [ ] AI-powered tagging (AWS Rekognition)
- [ ] Search and filter functionality
- [ ] Bulk upload support
- [ ] Photo editing features
- [ ] Custom domain with HTTPS
- [ ] CloudFront CDN integration

## 📝 License

MIT License - Feel free to use this project for learning!

## 👤 Author

Built as a portfolio project to demonstrate AWS serverless architecture skills.

---

**Note:** This is a demo project. Feel free to upload sample photos to test the functionality!
