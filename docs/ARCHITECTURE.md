# Architecture Overview

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USER BROWSER                                │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CloudFront CDN (Global Edge Locations)                │
│                         Distribution: E1ECJ4KNIZL20T                     │
│                   https://d1wu6qrhlfijph.cloudfront.net                 │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Origin Request
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    S3 Static Website Hosting                             │
│              Bucket: photo-gallery-frontend-355339423972                 │
│                   (index.html, app.js, styles.css)                       │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ API Calls (HTTPS)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         API Gateway (REST API)                           │
│                      ID: njoff2es13 (us-east-1)                         │
│                                                                          │
│  Endpoints:                                                              │
│    POST   /upload        → Upload Handler Lambda                        │
│    GET    /photos        → List Photos Lambda                           │
│    DELETE /photos/{id}   → Delete Photo Lambda                          │
└──────────────┬──────────────────┬──────────────────┬────────────────────┘
               │                  │                  │
               ▼                  ▼                  ▼
    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │  Lambda Function │ │  Lambda Function │ │  Lambda Function │
    │ Upload Handler   │ │   List Photos    │ │  Delete Photo    │
    │  (Python 3.11)   │ │  (Python 3.11)   │ │  (Python 3.11)   │
    └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
             │                    │                    │
             │                    │                    │
             ▼                    ▼                    ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    S3 Bucket (Photos)                        │
    │          photo-gallery-photos-355339423972                   │
    │                  (Original Images)                           │
    └────────────────────────┬────────────────────────────────────┘
                             │
                             │ S3 Event Notification
                             │ (ObjectCreated:*)
                             ▼
                    ┌──────────────────────┐
                    │   Lambda Function    │
                    │ Thumbnail Generator  │
                    │   (Python 3.11)      │
                    │   + Pillow Layer     │
                    └──────┬───────┬───────┘
                           │       │
                ┌──────────┘       └──────────┐
                ▼                             ▼
    ┌────────────────────────┐    ┌────────────────────────┐
    │   S3 Bucket            │    │      DynamoDB          │
    │   (Thumbnails)         │    │   photo-gallery-       │
    │ photo-gallery-         │    │      metadata          │
    │ thumbnails-355339423972│    │                        │
    │ (Resized Images)       │    │  Stores: photoId,      │
    │                        │    │  filename, uploadDate, │
    │                        │    │  fileSize, contentType │
    └────────────────────────┘    └────────────────────────┘
```

## Data Flow

### 1. Upload Photo Flow
```
User → CloudFront → S3 Website → API Gateway → Upload Handler Lambda
                                                        ↓
                                              Generate Presigned URL
                                                        ↓
User ← CloudFront ← S3 Website ← API Gateway ← Return Presigned URL
                                                        
User uploads directly to S3 Photos Bucket using presigned URL
                                                        ↓
                                              S3 Event Trigger
                                                        ↓
                                          Thumbnail Generator Lambda
                                                   ↓        ↓
                                    Create Thumbnail    Save Metadata
                                                   ↓        ↓
                                        S3 Thumbnails   DynamoDB
```

### 2. View Gallery Flow
```
User → CloudFront → S3 Website → API Gateway → List Photos Lambda
                                                        ↓
                                              Query DynamoDB
                                                        ↓
                                    Generate Presigned URLs for S3
                                                        ↓
User ← CloudFront ← S3 Website ← API Gateway ← Return Photo List + URLs
                                                        
User views thumbnails and full images via presigned URLs
```

### 3. Delete Photo Flow
```
User → CloudFront → S3 Website → API Gateway → Delete Photo Lambda
                                                        ↓
                                              Delete from S3 Photos
                                                        ↓
                                            Delete from S3 Thumbnails
                                                        ↓
                                            Delete from DynamoDB
                                                        ↓
User ← CloudFront ← S3 Website ← API Gateway ← Return Success
```

## AWS Services Used

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **CloudFront** | CDN for HTTPS and global delivery | Distribution with OAI for S3 access |
| **S3** | Static website hosting + object storage | 3 buckets (frontend, photos, thumbnails) |
| **API Gateway** | REST API endpoints | CORS enabled, Lambda proxy integration |
| **Lambda** | Serverless compute | 4 functions (Python 3.11) |
| **DynamoDB** | NoSQL database for metadata | Single table with photoId as key |
| **IAM** | Access control | 4 roles with least-privilege policies |
| **Lambda Layer** | Pillow library for image processing | Shared across thumbnail generator |

## Security Features

- **CloudFront OAI**: S3 bucket only accessible via CloudFront
- **Presigned URLs**: Temporary, secure access to S3 objects
- **CORS**: Restricted to specific origins
- **IAM Roles**: Least-privilege access for each Lambda
- **HTTPS**: All traffic encrypted via CloudFront

## Scalability

- **Auto-scaling**: Lambda scales automatically with demand
- **Global CDN**: CloudFront serves content from 400+ edge locations
- **Serverless**: No servers to manage or provision
- **Pay-per-use**: Only charged for actual usage

## Cost Optimization

- **CloudFront caching**: Reduces S3 data transfer costs
- **Lambda**: Only runs when needed (no idle costs)
- **S3 Lifecycle**: Can add policies to archive old photos
- **DynamoDB on-demand**: Pay only for reads/writes

## Performance

- **CloudFront**: <50ms latency globally
- **Lambda**: Cold start ~1-2s, warm ~100ms
- **S3**: 99.99% availability
- **DynamoDB**: Single-digit millisecond latency

---

**Note:** This architecture is fully serverless, requiring zero server management while providing high availability, scalability, and performance.
