# List Photos Lambda Function
# Returns all photo metadata for gallery display

import json
import os
import boto3
from botocore.exceptions import ClientError
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

METADATA_TABLE_NAME = os.environ.get('METADATA_TABLE_NAME', 'photo-gallery-metadata')
PHOTO_BUCKET_NAME = os.environ.get('PHOTO_BUCKET_NAME', 'photo-gallery-photos')
THUMBNAIL_BUCKET_NAME = os.environ.get('THUMBNAIL_BUCKET_NAME', 'photo-gallery-thumbnails')
URL_EXPIRATION = int(os.environ.get('URL_EXPIRATION', '3600'))  # 1 hour default

def lambda_handler(event, context):
    """
    Retrieve all photo metadata from DynamoDB
    
    Returns:
    {
        "photos": [
            {
                "photoId": str,
                "filename": str,
                "uploadDate": str,
                "thumbnailUrl": str,
                "photoUrl": str,
                "tags": list,
                "dimensions": dict
            }
        ]
    }
    """
    try:
        # Scan DynamoDB table for all photos
        table = dynamodb.Table(METADATA_TABLE_NAME)
        
        try:
            response = table.scan()
            items = response.get('Items', [])
            
            # Handle pagination if there are more items
            while 'LastEvaluatedKey' in response:
                response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
                items.extend(response.get('Items', []))
            
            print(f'Retrieved {len(items)} photos from DynamoDB')
        
        except ClientError as e:
            print(f'DynamoDB scan failed: {str(e)}')
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Failed to retrieve photos. Please try again.'
                })
            }
        
        # Format photos for response
        photos = []
        for item in items:
            # Skip failed processing items
            if item.get('processingStatus') == 'failed':
                continue
            
            try:
                # Generate presigned URLs for photo and thumbnail
                photo_url = s3_client.generate_presigned_url(
                    'get_object',
                    Params={
                        'Bucket': PHOTO_BUCKET_NAME,
                        'Key': item['photoKey']
                    },
                    ExpiresIn=URL_EXPIRATION
                )
                
                thumbnail_url = s3_client.generate_presigned_url(
                    'get_object',
                    Params={
                        'Bucket': THUMBNAIL_BUCKET_NAME,
                        'Key': item['thumbnailKey']
                    },
                    ExpiresIn=URL_EXPIRATION
                )
                
                # Build photo object
                photo = {
                    'photoId': item['photoId'],
                    'filename': item['filename'],
                    'uploadDate': item['uploadDate'],
                    'fileSize': int(item.get('fileSize', 0)),
                    'thumbnailUrl': thumbnail_url,
                    'photoUrl': photo_url,
                    'tags': item.get('tags', []),
                    'dimensions': convert_decimals(item.get('dimensions', {})),
                    'thumbnailDimensions': convert_decimals(item.get('thumbnailDimensions', {}))
                }
                
                photos.append(photo)
            
            except ClientError as e:
                print(f'Failed to generate presigned URL for photo {item.get("photoId")}: {str(e)}')
                continue
        
        # Sort by upload date (newest first)
        photos.sort(key=lambda x: x['uploadDate'], reverse=True)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'photos': photos
            })
        }
    
    except Exception as e:
        print(f'Unexpected error: {str(e)}')
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'An unexpected error occurred. Please try again.'
            })
        }

def convert_decimals(obj):
    """Convert DynamoDB Decimal types to int/float for JSON serialization"""
    if isinstance(obj, list):
        return [convert_decimals(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj
