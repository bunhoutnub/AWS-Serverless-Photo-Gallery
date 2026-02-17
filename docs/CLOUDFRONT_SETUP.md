# CloudFront CDN Setup Guide

## What is CloudFront?

Amazon CloudFront is a Content Delivery Network (CDN) that caches your website content at edge locations worldwide, providing:

- **HTTPS by default** - Secure connections without certificates
- **Faster load times** - Content served from nearest edge location
- **Lower costs** - Reduced S3 data transfer charges
- **Better performance** - Cached content = faster delivery

## Setup Instructions

### 1. Run the Setup Script

```bash
cd scripts/
./setup-cloudfront.sh
```

This script will:
- Create a CloudFront Origin Access Identity (OAI)
- Update S3 bucket policy for CloudFront access
- Create CloudFront distribution with HTTPS
- Configure caching and error handling

### 2. Wait for Deployment

CloudFront deployment takes **15-20 minutes**. Check status:

```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Photo Gallery CDN'].[Id,Status,DomainName]" \
  --output table
```

Status will change from `InProgress` to `Deployed`.

### 3. Get Your CloudFront URL

```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Photo Gallery CDN'].DomainName | [0]" \
  --output text
```

Your site will be available at: `https://YOUR_DISTRIBUTION_ID.cloudfront.net`

## Updating Content

When you update frontend files, you need to invalidate the CloudFront cache:

```bash
# Upload new files
cd frontend/
aws s3 sync . s3://photo-gallery-frontend-355339423972/

# Invalidate CloudFront cache
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Photo Gallery CDN'].Id | [0]" \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"
```

## Benefits for Your Portfolio

Adding CloudFront demonstrates:

- **CDN knowledge** - Understanding of content delivery networks
- **Performance optimization** - Improving user experience globally
- **Security awareness** - HTTPS without managing certificates
- **Cost optimization** - Reducing data transfer costs
- **AWS expertise** - Using multiple AWS services together

## Architecture Impact

**Before CloudFront:**
```
User → S3 Website (HTTP only)
```

**After CloudFront:**
```
User → CloudFront Edge Location (HTTPS) → S3 Origin
```

## Troubleshooting

### Distribution not working?
- Wait 15-20 minutes for full deployment
- Check distribution status is "Deployed"
- Verify S3 bucket policy allows CloudFront OAI

### 403 Forbidden errors?
- Check S3 bucket policy includes CloudFront OAI
- Verify index.html exists in S3 bucket

### Old content showing?
- Create cache invalidation (see "Updating Content" above)
- Default cache TTL is 24 hours

## Cost Considerations

CloudFront pricing (as of 2024):
- **First 10 TB/month:** ~$0.085 per GB
- **HTTPS requests:** $0.01 per 10,000 requests
- **Free tier:** 1 TB data transfer out, 10M requests/month for 12 months

For a portfolio demo site, costs are typically **under $1/month**.

## Cleanup

To delete CloudFront distribution:

```bash
# Get distribution ID
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='Photo Gallery CDN'].Id | [0]" \
  --output text)

# Disable distribution
aws cloudfront get-distribution-config --id $DIST_ID > /tmp/dist-config.json
# Edit /tmp/dist-config.json and set "Enabled": false
aws cloudfront update-distribution --id $DIST_ID --if-match ETAG --distribution-config file:///tmp/dist-config.json

# Wait for deployment, then delete
aws cloudfront delete-distribution --id $DIST_ID --if-match ETAG
```

## Interview Talking Points

When discussing this feature:

1. **Problem:** S3 website hosting only supports HTTP, not HTTPS
2. **Solution:** CloudFront provides free HTTPS certificates
3. **Benefit:** Global edge locations reduce latency for international users
4. **Cost:** CloudFront caching reduces S3 data transfer costs
5. **Security:** HTTPS protects user data in transit

---

**Next Steps:** Consider adding a custom domain name with Route 53 for a professional URL.
