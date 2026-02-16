# Frontend - Photo Gallery Website

## Purpose
The user-facing web application hosted on S3 as a static website.

## Files

### index.html
The main HTML structure with:
- Upload form
- Search/filter controls
- Photo gallery grid
- Full-size photo modal

### app.js
JavaScript that handles:
- **Upload** - Gets presigned URL, uploads to S3
- **Display** - Fetches and renders photo gallery
- **View** - Opens full-size photo in modal
- **Delete** - Removes photos
- **Filter** - Search by tags/date (not yet implemented)

### styles.css
All the styling to make it look good:
- Responsive grid layout
- Upload button styling
- Modal overlay
- Photo cards with hover effects

## Configuration

The API URL is set at the top of `app.js`:
```javascript
const API_BASE_URL = 'https://njoff2es13.execute-api.us-east-1.amazonaws.com/prod';
```

## Deployment

To update the website:
```bash
aws s3 sync frontend/ s3://photo-gallery-frontend-355339423972/
```

## Live URL
http://photo-gallery-frontend-355339423972.s3-website-us-east-1.amazonaws.com

## How It Works

1. **User uploads photo** → Frontend gets presigned URL from API → Uploads directly to S3
2. **S3 triggers Lambda** → Thumbnail generated → Metadata saved to DynamoDB
3. **User views gallery** → Frontend calls API → Gets photo list with presigned URLs
4. **User deletes photo** → Frontend calls API → Lambda removes everything
