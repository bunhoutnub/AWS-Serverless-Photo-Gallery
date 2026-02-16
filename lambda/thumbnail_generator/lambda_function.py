# Thumbnail Generator Lambda Function
# Creates thumbnails when photos are uploaded to S3

import json
import os
import boto3
from PIL import Image
from datetime import datetime
from botocore.exceptions import ClientError
import traceback

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

PHOTO_BUCKET_NAME = os.environ.get('PHOTO_BUCKET_NAME', 'photo-gallery-photos')
THUMBNAIL_BUCKET_NAME = os.environ.get('THUMBNAIL_BUCKET_NAME', 'photo-gallery-thumbnails')
METADATA_TABLE_NAME = os.environ.get('METADATA_TABLE_NAME', 'photo-gallery-metadata')
THUMBNAIL_MAX_SIZE = int(os.environ.get('THUMBNAIL_MAX_SIZE', '200'))

def lambda_handler(event, context):
    """
    Process S3 event notification and generate thumbnail
    
    Triggered by S3 ObjectCreated event
    """
    try:
        # Extract S3 event details
        for record in event['Records']:
            bucket_name = record['s3']['bucket']['name']
            object_key = record['s3']['object']['key']
            
            print(f'Processing photo: {object_key} from bucket: {bucket_name}')
            
            # Extract photo ID and filename from key (photos/{photoId}/{filename})
            key_parts = object_key.split('/')
            if len(key_parts) < 3 or key_parts[0] != 'photos':
                print(f'Invalid key format: {object_key}')
                continue
            
            photo_id = key_parts[1]
            filename = '/'.join(key_parts[2:])
            
            # Download photo from S3 to /tmp
            tmp_photo_path = f'/tmp/{photo_id}_original'
            tmp_thumbnail_path = f'/tmp/{photo_id}_thumbnail'
            
            try:
                s3_client.download_file(bucket_name, object_key, tmp_photo_path)
                print(f'Downloaded photo to {tmp_photo_path}')
            except ClientError as e:
                print(f'S3 download failed: {str(e)}')
                update_metadata_with_error(photo_id, filename, object_key, 'S3 download failed')
                continue
            
            # Open image with Pillow
            try:
                with Image.open(tmp_photo_path) as img:
                    # Get original dimensions
                    original_width, original_height = img.size
                    print(f'Original dimensions: {original_width}x{original_height}')
                    
                    # Calculate thumbnail dimensions (max 200x200, maintain aspect ratio)
                    img.thumbnail((THUMBNAIL_MAX_SIZE, THUMBNAIL_MAX_SIZE), Image.Resampling.LANCZOS)
                    thumbnail_width, thumbnail_height = img.size
                    print(f'Thumbnail dimensions: {thumbnail_width}x{thumbnail_height}')
                    
                    # Save thumbnail to /tmp
                    img.save(tmp_thumbnail_path, format=img.format or 'JPEG')
                    print(f'Saved thumbnail to {tmp_thumbnail_path}')
            
            except Exception as e:
                print(f'Image processing failed: {str(e)}')
                print(traceback.format_exc())
                update_metadata_with_error(photo_id, filename, object_key, 'Image processing failed')
                cleanup_tmp_files(tmp_photo_path, tmp_thumbnail_path)
                continue
            
            # Upload thumbnail to Thumbnail Bucket
            thumbnail_key = f'thumbnails/{photo_id}/{filename}'
            try:
                s3_client.upload_file(tmp_thumbnail_path, THUMBNAIL_BUCKET_NAME, thumbnail_key)
                print(f'Uploaded thumbnail to {thumbnail_key}')
            except ClientError as e:
                print(f'Thumbnail upload failed: {str(e)}')
                update_metadata_with_error(photo_id, filename, object_key, 'Thumbnail upload failed')
                cleanup_tmp_files(tmp_photo_path, tmp_thumbnail_path)
                continue
            
            # Get file size
            file_size = os.path.getsize(tmp_photo_path)
            
            # Write metadata to DynamoDB
            try:
                table = dynamodb.Table(METADATA_TABLE_NAME)
                upload_date = datetime.utcnow().isoformat() + 'Z'
                
                table.put_item(
                    Item={
                        'photoId': photo_id,
                        'filename': filename,
                        'uploadDate': upload_date,
                        'fileSize': file_size,
                        'contentType': get_content_type(filename),
                        'photoKey': object_key,
                        'thumbnailKey': thumbnail_key,
                        'dimensions': {
                            'width': original_width,
                            'height': original_height
                        },
                        'thumbnailDimensions': {
                            'width': thumbnail_width,
                            'height': thumbnail_height
                        },
                        'processingStatus': 'completed',
                        'tags': []
                    }
                )
                print(f'Metadata written to DynamoDB for photo {photo_id}')
            
            except ClientError as e:
                print(f'DynamoDB write failed: {str(e)}')
                print(traceback.format_exc())
            
            # Clean up /tmp files
            cleanup_tmp_files(tmp_photo_path, tmp_thumbnail_path)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Thumbnail generation completed')
        }
    
    except Exception as e:
        print(f'Unexpected error in lambda_handler: {str(e)}')
        print(traceback.format_exc())
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def update_metadata_with_error(photo_id, filename, photo_key, error_message):
    """Update metadata with error status"""
    try:
        table = dynamodb.Table(METADATA_TABLE_NAME)
        upload_date = datetime.utcnow().isoformat() + 'Z'
        
        table.put_item(
            Item={
                'photoId': photo_id,
                'filename': filename,
                'uploadDate': upload_date,
                'photoKey': photo_key,
                'processingStatus': 'failed',
                'errorMessage': error_message,
                'tags': []
            }
        )
        print(f'Error metadata written for photo {photo_id}')
    except Exception as e:
        print(f'Failed to write error metadata: {str(e)}')

def cleanup_tmp_files(*file_paths):
    """Clean up temporary files"""
    for file_path in file_paths:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                print(f'Cleaned up {file_path}')
        except Exception as e:
            print(f'Failed to clean up {file_path}: {str(e)}')

def get_content_type(filename):
    """Determine content type from filename"""
    extension = filename.lower().split('.')[-1]
    content_types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif'
    }
    return content_types.get(extension, 'image/jpeg')
