# Upload Handler Lambda Function
# Generates presigned URLs for photo uploads

import json
import os
import uuid
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')

ALLOWED_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/gif']
PHOTO_BUCKET_NAME = os.environ.get('PHOTO_BUCKET_NAME', 'photo-gallery-photos')

def lambda_handler(event, context):
    """
    Generate presigned URL for photo upload
    
    Expected input:
    {
        "filename": str,
        "contentType": str
    }
    
    Returns:
    {
        "uploadUrl": str,
        "photoId": str,
        "key": str
    }
    """
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', event)
        
        # Validate required parameters
        filename = body.get('filename')
        content_type = body.get('contentType')
        
        if not filename:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required parameters: filename and contentType'
                })
            }
        
        if not content_type:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required parameters: filename and contentType'
                })
            }
        
        # Validate content type
        if content_type not in ALLOWED_CONTENT_TYPES:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Invalid file type. Only JPEG, PNG, and GIF images are allowed.'
                })
            }
        
        # Generate unique photo ID
        photo_id = str(uuid.uuid4())
        
        # Construct S3 key
        s3_key = f'photos/{photo_id}/{filename}'
        
        # Generate presigned POST URL with 5-minute expiration
        presigned_post = s3_client.generate_presigned_post(
            Bucket=PHOTO_BUCKET_NAME,
            Key=s3_key,
            Fields={'Content-Type': content_type},
            Conditions=[
                {'Content-Type': content_type},
                ['content-length-range', 0, 10485760]  # Max 10MB
            ],
            ExpiresIn=300  # 5 minutes
        )
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'uploadUrl': presigned_post['url'],
                'fields': presigned_post['fields'],
                'photoId': photo_id,
                'key': s3_key
            })
        }
        
    except ClientError as e:
        print(f'S3 ClientError: {str(e)}')
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Failed to generate upload URL. Please try again.'
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
