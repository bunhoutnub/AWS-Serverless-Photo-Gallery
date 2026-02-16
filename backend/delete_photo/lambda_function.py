# Delete Photo Lambda Function
# Deletes photo, thumbnail, and metadata

import json
import os
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

METADATA_TABLE_NAME = os.environ.get('METADATA_TABLE_NAME', 'photo-gallery-metadata')
PHOTO_BUCKET_NAME = os.environ.get('PHOTO_BUCKET_NAME', 'photo-gallery-photos')
THUMBNAIL_BUCKET_NAME = os.environ.get('THUMBNAIL_BUCKET_NAME', 'photo-gallery-thumbnails')

def lambda_handler(event, context):
    """
    Delete photo and associated data
    
    Expected input:
    {
        "photoId": str
    }
    
    Returns:
    {
        "message": str,
        "photoId": str
    }
    """
    try:
        # Parse request
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', event)
        
        # Get photoId from path parameters or body
        photo_id = event.get('pathParameters', {}).get('photoId') or body.get('photoId')
        
        if not photo_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required parameter: photoId'
                })
            }
        
        # Query DynamoDB for photo metadata
        table = dynamodb.Table(METADATA_TABLE_NAME)
        
        try:
            response = table.get_item(Key={'photoId': photo_id})
            
            if 'Item' not in response:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'Photo not found'
                    })
                }
            
            item = response['Item']
            photo_key = item.get('photoKey')
            thumbnail_key = item.get('thumbnailKey')
            
            print(f'Found photo {photo_id}: photoKey={photo_key}, thumbnailKey={thumbnail_key}')
        
        except ClientError as e:
            print(f'DynamoDB GetItem failed: {str(e)}')
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Failed to retrieve photo metadata. Please try again.'
                })
            }
        
        # Delete photo from Photo Bucket
        if photo_key:
            try:
                s3_client.delete_object(Bucket=PHOTO_BUCKET_NAME, Key=photo_key)
                print(f'Deleted photo from S3: {photo_key}')
            except ClientError as e:
                print(f'Failed to delete photo from S3: {str(e)}')
                # Continue with deletion even if S3 delete fails
        
        # Delete thumbnail from Thumbnail Bucket
        if thumbnail_key:
            try:
                s3_client.delete_object(Bucket=THUMBNAIL_BUCKET_NAME, Key=thumbnail_key)
                print(f'Deleted thumbnail from S3: {thumbnail_key}')
            except ClientError as e:
                print(f'Failed to delete thumbnail from S3: {str(e)}')
                # Continue with deletion even if S3 delete fails
        
        # Delete metadata from DynamoDB
        try:
            table.delete_item(Key={'photoId': photo_id})
            print(f'Deleted metadata from DynamoDB: {photo_id}')
        except ClientError as e:
            print(f'DynamoDB DeleteItem failed: {str(e)}')
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Failed to delete photo metadata.'
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Photo deleted successfully',
                'photoId': photo_id
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
