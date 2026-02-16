# Thumbnail Generator Lambda

## Purpose
Automatically creates thumbnail versions of uploaded photos and stores metadata in DynamoDB.

## How It Works
1. Triggered automatically when photo uploaded to S3
2. Downloads original photo from S3
3. Resizes to 200px max dimension using Pillow
4. Uploads thumbnail to thumbnails bucket
5. Saves metadata (filename, dates, dimensions) to DynamoDB

## Environment Variables
- `PHOTO_BUCKET_NAME` - Source bucket with original photos
- `THUMBNAIL_BUCKET_NAME` - Destination bucket for thumbnails
- `METADATA_TABLE_NAME` - DynamoDB table name
- `THUMBNAIL_MAX_SIZE` - Max thumbnail dimension (default: 200)

## Trigger
S3 Event: `ObjectCreated:*` on `photos/` prefix

## Dependencies
- **Pillow** (via Lambda Layer) - Image processing library

## What It Stores in DynamoDB
```json
{
  "photoId": "uuid",
  "filename": "photo.jpg",
  "photoKey": "photos/uuid/photo.jpg",
  "thumbnailKey": "thumbnails/uuid/photo.jpg",
  "uploadDate": "2024-01-01T12:00:00Z",
  "dimensions": {
    "width": 1920,
    "height": 1080
  },
  "tags": []
}
```

## Timeout
60 seconds (for large images)

## Memory
512 MB (needed for image processing)
