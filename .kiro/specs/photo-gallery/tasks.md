# Implementation Plan: AWS Serverless Photo Gallery

## Overview

This implementation plan breaks down the serverless photo gallery into discrete, incremental coding tasks. The approach follows the phased implementation strategy: starting with infrastructure setup, then building core upload functionality, adding thumbnail generation, implementing gallery display, and finally adding deletion and search features. Each task builds on previous work, with testing integrated throughout to validate functionality early.

## Tasks

- [x] 1. Set up project structure and configuration files
  - Create directory structure for frontend and Lambda functions
  - Create requirements.txt for each Lambda function (Pillow for thumbnail_generator)
  - Create package.json or configuration for frontend dependencies if needed
  - Create README.md with project overview and setup instructions
  - _Requirements: 10.3_

- [ ] 2. Implement Upload Handler Lambda function
  - [x] 2.1 Create upload_handler/lambda_function.py with presigned URL generation
    - Implement handler function that accepts filename and contentType
    - Validate content type against allowed image formats (image/jpeg, image/png, image/gif)
    - Generate unique photo ID using UUID
    - Construct S3 key with pattern: photos/{photoId}/{filename}
    - Generate presigned POST URL with 5-minute expiration using boto3
    - Return response with uploadUrl, photoId, and key
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  
  - [ ]* 2.2 Write property test for upload ID uniqueness
    - **Property 3: Upload ID uniqueness**
    - **Validates: Requirements 1.2**
    - Generate multiple upload requests and verify all photo IDs are unique
  
  - [ ]* 2.3 Write property test for valid image acceptance
    - **Property 1: Valid image upload acceptance**
    - **Validates: Requirements 1.1, 1.2, 1.3**
    - Generate random valid image content types and verify acceptance
  
  - [ ]* 2.4 Write property test for invalid file rejection
    - **Property 2: Invalid file rejection**
    - **Validates: Requirements 1.4, 1.6**
    - Generate random non-image content types and verify rejection with error messages
  
  - [ ]* 2.5 Write unit tests for Upload Handler edge cases
    - Test missing parameters (filename, contentType)
    - Test empty filename
    - Test special characters in filename
    - Test S3 client exceptions
    - _Requirements: 1.4, 1.6_

- [ ] 3. Implement Thumbnail Generator Lambda function
  - [x] 3.1 Create thumbnail_generator/lambda_function.py with image processing
    - Implement handler function that processes S3 event notifications
    - Extract bucket name and object key from event
    - Download photo from S3 to /tmp directory using boto3
    - Open image with Pillow (PIL)
    - Calculate thumbnail dimensions (max 200x200, maintain aspect ratio)
    - Resize image using LANCZOS resampling
    - Save thumbnail to /tmp
    - Upload thumbnail to Thumbnail_Bucket with key: thumbnails/{photoId}/{filename}
    - Extract metadata (file size, dimensions, upload timestamp)
    - Write metadata to DynamoDB including all required fields
    - Clean up /tmp files
    - Implement error handling with CloudWatch logging
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4_
  
  - [ ]* 3.2 Write property test for thumbnail dimension constraints
    - **Property 4: Thumbnail dimension constraints**
    - **Validates: Requirements 2.2**
    - Generate random image dimensions and verify thumbnails are max 200x200 with aspect ratio maintained
  
  - [ ]* 3.3 Write property test for thumbnail storage consistency
    - **Property 5: Thumbnail storage consistency**
    - **Validates: Requirements 2.3, 2.4**
    - Generate random photos and verify thumbnails are stored with correct keys and metadata is written
  
  - [ ]* 3.4 Write property test for metadata completeness
    - **Property 7: Metadata completeness**
    - **Validates: Requirements 3.1, 4.3**
    - Generate random photos and verify all required metadata fields are present
  
  - [ ]* 3.5 Write property test for thumbnail generation resilience
    - **Property 6: Thumbnail generation resilience**
    - **Validates: Requirements 2.5, 11.2**
    - Generate invalid/corrupted images and verify errors are logged without crashing
  
  - [ ]* 3.6 Write unit tests for Thumbnail Generator edge cases
    - Test corrupted image file
    - Test unsupported image format
    - Test very large image (memory constraints)
    - Test S3 download failure
    - Test DynamoDB write failure
    - _Requirements: 2.5, 11.2_

- [ ] 4. Checkpoint - Ensure upload and thumbnail generation tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement List Photos Lambda function
  - [x] 5.1 Create list_photos/lambda_function.py with metadata retrieval
    - Implement handler function that scans DynamoDB Metadata Table
    - Generate presigned URLs or construct public URLs for photos and thumbnails
    - Format response with all required fields (photoId, filename, uploadDate, thumbnailUrl, photoUrl, tags, dimensions)
    - Sort results by uploadDate (newest first)
    - Return JSON response with photos array
    - Implement error handling for DynamoDB scan failures
    - _Requirements: 4.2, 4.3, 4.5_
  
  - [ ]* 5.2 Write property test for complete photo retrieval
    - **Property 10: Complete photo retrieval**
    - **Validates: Requirements 4.2**
    - Generate random photo metadata in DynamoDB and verify all are returned
  
  - [ ]* 5.3 Write property test for response structure completeness
    - **Property 11: Response structure completeness**
    - **Validates: Requirements 4.3, 4.5**
    - Generate random photos and verify response includes all required fields
  
  - [ ]* 5.4 Write unit tests for List Handler edge cases
    - Test empty database (no photos)
    - Test DynamoDB scan failure
    - Test presigned URL generation failure
    - _Requirements: 4.2, 4.3_

- [ ] 6. Implement Delete Photo Lambda function
  - [x] 6.1 Create delete_photo/lambda_function.py with deletion logic
    - Implement handler function that accepts photoId
    - Query DynamoDB for photo metadata using photoId
    - Extract S3 keys for photo and thumbnail
    - Delete photo from Photo_Bucket using boto3
    - Delete thumbnail from Thumbnail_Bucket
    - Delete metadata record from DynamoDB
    - Return success response with photoId
    - Implement error handling for photo not found (404)
    - Implement error handling for S3 and DynamoDB failures
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [ ]* 6.2 Write property test for complete deletion
    - **Property 12: Complete deletion**
    - **Validates: Requirements 6.2, 6.3, 6.4, 6.5**
    - Generate random photos and verify deletion removes all traces (S3 objects and DynamoDB record)
  
  - [ ]* 6.3 Write property test for deletion idempotence
    - **Property 13: Deletion idempotence**
    - **Validates: Requirements 6.2, 6.3, 6.4**
    - Delete same photoId multiple times and verify no errors occur
  
  - [ ]* 6.4 Write unit tests for Delete Handler edge cases
    - Test photo not found (404 response)
    - Test S3 deletion failure
    - Test DynamoDB deletion failure
    - Test partial deletion scenarios
    - _Requirements: 6.2, 6.3, 6.4_

- [ ] 7. Checkpoint - Ensure all Lambda function tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement frontend HTML structure
  - [x] 8.1 Create frontend/index.html with gallery interface
    - Create HTML structure with upload form (file input, submit button)
    - Create gallery grid container for displaying thumbnails
    - Create modal/overlay for full-size photo viewing
    - Add delete buttons for each photo
    - Add search/filter input fields (tag search, date filter)
    - Include references to styles.css and app.js
    - _Requirements: 10.2, 10.3_

- [ ] 9. Implement frontend styling
  - [x] 9.1 Create frontend/styles.css with responsive design
    - Style upload form with clear visual hierarchy
    - Style gallery grid with responsive layout (CSS Grid or Flexbox)
    - Style thumbnail cards with hover effects
    - Style full-size photo modal with overlay and close button
    - Style delete buttons with confirmation visual feedback
    - Style search/filter inputs
    - Implement responsive design for mobile and desktop
    - _Requirements: 10.3, 10.4_

- [ ] 10. Implement frontend JavaScript functionality
  - [ ] 10.1 Create frontend/app.js with core API integration
    - Configure API Gateway base URL
    - Implement uploadPhoto(file) function:
      - Request presigned URL from Upload Handler
      - Upload file to S3 using presigned URL
      - Handle upload success and error responses
      - Update UI with upload status
    - Implement loadGallery() function:
      - Fetch photo list from List Handler
      - Render thumbnails in gallery grid
      - Display photo metadata (filename, date)
      - Handle empty gallery state
    - Implement viewFullSize(photoId) function:
      - Open modal with full-size photo
      - Display photo metadata
      - Provide close functionality
    - Implement deletePhoto(photoId) function:
      - Send delete request to Delete Handler
      - Remove photo from gallery display on success
      - Handle delete errors
    - Implement filterPhotos(searchTerm) function:
      - Filter displayed photos by tag (substring match)
      - Update gallery display with filtered results
    - Implement filterByDate(startDate, endDate) function:
      - Filter displayed photos by date range
      - Update gallery display with filtered results
    - Add event listeners for upload form, thumbnail clicks, delete buttons, search inputs
    - Implement error handling and user feedback for all operations
    - _Requirements: 1.1, 4.1, 4.4, 5.1, 5.2, 5.3, 6.1, 6.6, 7.1, 7.2, 7.3_
  
  - [ ]* 10.2 Write property test for tag search accuracy
    - **Property 14: Tag search accuracy**
    - **Validates: Requirements 7.2**
    - Generate random photos with tags and verify search returns only matching photos
  
  - [ ]* 10.3 Write property test for date range filtering
    - **Property 15: Date range filtering**
    - **Validates: Requirements 7.3**
    - Generate random photos with dates and verify filtering returns only photos in range
  
  - [ ]* 10.4 Write unit tests for frontend functions
    - Test uploadPhoto with successful upload
    - Test uploadPhoto with network failure
    - Test loadGallery with empty results
    - Test deletePhoto with successful deletion
    - Test filterPhotos with various search terms
    - Test filterByDate with various date ranges
    - _Requirements: 1.1, 4.1, 6.1, 7.1, 7.2, 7.3_

- [ ] 11. Implement property test for metadata write-read consistency
  - [ ]* 11.1 Write property test for metadata round-trip
    - **Property 8: Metadata write-read consistency**
    - **Validates: Requirements 3.2, 3.4**
    - Generate random metadata, write to DynamoDB, read back, and verify equality

- [ ] 12. Implement property test for tag preservation
  - [ ]* 12.1 Write property test for tag storage and retrieval
    - **Property 9: Tag preservation**
    - **Validates: Requirements 3.3**
    - Generate random photos with tags, upload, retrieve, and verify tags are preserved

- [ ] 13. Implement property test for error response consistency
  - [ ]* 13.1 Write property test for API error responses
    - **Property 16: Error response consistency**
    - **Validates: Requirements 1.6, 8.5**
    - Generate various error scenarios and verify appropriate status codes and messages

- [ ] 14. Implement property tests for logging
  - [ ]* 14.1 Write property test for Lambda execution logging
    - **Property 17: Lambda execution logging**
    - **Validates: Requirements 11.1**
    - Execute Lambda functions and verify CloudWatch logs contain execution details
  
  - [ ]* 14.2 Write property test for error logging completeness
    - **Property 18: Error logging completeness**
    - **Validates: Requirements 11.2**
    - Generate error scenarios and verify CloudWatch logs contain error messages and stack traces

- [ ] 15. Implement property test for concurrent upload processing
  - [ ]* 15.1 Write property test for concurrent uploads
    - **Property 19: Concurrent upload processing**
    - **Validates: Requirements 12.2**
    - Upload multiple photos simultaneously and verify all are processed successfully

- [ ] 16. Create infrastructure deployment documentation
  - [x] 16.1 Document AWS resource setup in README.md
    - Document S3 bucket creation (Photo_Bucket, Thumbnail_Bucket, Frontend_Bucket)
    - Document S3 static website hosting configuration
    - Document DynamoDB table creation with schema
    - Document Lambda function deployment steps
    - Document Lambda layer creation for Pillow dependency
    - Document API Gateway setup with endpoint configuration
    - Document S3 event notification configuration for thumbnail generation
    - Document IAM role creation for each Lambda function with required permissions
    - Document CORS configuration for API Gateway
    - Document CloudWatch log group setup
    - Include AWS CLI commands or CloudFormation/SAM template references
    - _Requirements: 8.1, 8.4, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 10.1, 10.5, 11.3_

- [ ] 17. Final checkpoint - Ensure all tests pass and documentation is complete
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Lambda functions require AWS SDK (boto3) which is included in Python Lambda runtime
- Thumbnail Generator requires Pillow library - deploy as Lambda layer or include in deployment package
- Frontend can be tested locally before S3 deployment by running a local web server
- Property tests should run with minimum 100 iterations for comprehensive coverage
- Integration testing will require actual AWS resources or LocalStack for local testing
- Consider using AWS SAM or CloudFormation for infrastructure-as-code deployment
