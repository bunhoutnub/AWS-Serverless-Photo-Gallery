# List Photos Lambda

## Purpose
Retrieves all photos from DynamoDB and generates presigned URLs for viewing.

## How It Works
1. Scans DynamoDB for all photo metadata
2. Generates temporary presigned URLs for:
   - Original photos (1 hour expiration)
   - Thumbnails (1 hour expiration)
3. Returns list to frontend for display

## Environment Variables
- `METADATA_TABLE_NAME` - DynamoDB table name
- `PHOTO_BUCKET_NAME` - S3 bucket with original photos
- `THUMBNAIL_BUCKET_NAME` - S3 bucket with thumbnails
- `URL_EXPIRATION` - Presigned URL expiration in seconds (default: 3600)

## API Endpoint
`GET /photos`

**Response:**
```json
{
  "photos": [
    {
      "photoId": "uuid",
      "filename": "photo.jpg",
      "uploadDate": "2024-01-01T12:00:00Z",
      "photoUrl": "https://s3.amazonaws.com/...",
      "thumbnailUrl": "https://s3.amazonaws.com/...",
      "dimensions": {
        "width": 1920,
        "height": 1080
      },
      "tags": []
    }
  ]
}
```

## Why Presigned URLs?
S3 buckets are private. Presigned URLs allow temporary access without making buckets public.
