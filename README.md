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

- AWS Account
- AWS CLI configured
- Python 3.11+
- Basic knowledge of AWS services

### Infrastructure Setup

Detailed infrastructure setup instructions will be added in Task 16.

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
