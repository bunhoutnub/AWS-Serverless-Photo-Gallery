# Delete Photo Lambda

## Purpose
Completely removes a photo and all associated data from the system.

## How It Works
1. Receives photoId from frontend
2. Looks up photo metadata in DynamoDB
3. Deletes original photo from S3
4. Deletes thumbnail from S3
5. Deletes metadata from DynamoDB

## Environment Variables
- `METADATA_TABLE_NAME` - DynamoDB table name
- `PHOTO_BUCKET_NAME` - S3 bucket with original photos
- `THUMBNAIL_BUCKET_NAME` - S3 bucket with thumbnails

## API Endpoint
`DELETE /photos/{photoId}`

**Response:**
```json
{
  "message": "Photo deleted successfully",
  "photoId": "uuid"
}
```

## Error Handling
- Returns 404 if photo not found
- Continues deletion even if S3 delete fails (logs error)
- Returns 500 if DynamoDB delete fails

## What Gets Deleted
✅ Original photo from S3  
✅ Thumbnail from S3  
✅ Metadata from DynamoDB  

Nothing is left behind!
