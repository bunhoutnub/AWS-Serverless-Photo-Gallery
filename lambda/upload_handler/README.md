# Upload Handler Lambda

## Purpose
Generates secure presigned URLs that allow users to upload photos directly to S3 from their browser.

## How It Works
1. Frontend sends photo filename and type
2. Lambda generates a temporary upload URL (valid 5 minutes)
3. Frontend uploads photo directly to S3 using that URL
4. S3 upload triggers the thumbnail generator

## Environment Variables
- `PHOTO_BUCKET_NAME` - S3 bucket for original photos

## API Endpoint
`POST /upload`

**Request:**
```json
{
  "filename": "photo.jpg",
  "contentType": "image/jpeg"
}
```

**Response:**
```json
{
  "uploadUrl": "https://s3.amazonaws.com/...",
  "fields": {...},
  "photoId": "uuid",
  "key": "photos/uuid/photo.jpg"
}
```

## Allowed File Types
- image/jpeg
- image/png
- image/gif

## Max File Size
10 MB
