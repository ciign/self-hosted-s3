# Django Integration with Self-Hosted MinIO

This guide shows how to integrate your Django application with the self-hosted MinIO S3 storage for local development and demos.

## Prerequisites

- Self-hosted MinIO running (see main README.md)
- Django project with `django-storages` and `boto3` installed

## 1. Update Django Settings

Update your Django `settings.py` to use MinIO for local development:

```python
import os

# Determine if we're using MinIO (local) or AWS S3 (production)
USE_MINIO = os.getenv("USE_MINIO", "True") == "True"

if USE_MINIO:
    # MinIO Configuration for Local Development
    AWS_S3_ENDPOINT_URL = os.getenv("AWS_S3_ENDPOINT_URL", "http://localhost:9000")
    AWS_S3_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID", "minioadmin")
    AWS_S3_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "changeme123!")
    AWS_S3_REGION_NAME = os.getenv("AWS_S3_REGION_NAME", "us-east-1")
    AWS_S3_USE_SSL = False
    AWS_S3_VERIFY = False
    AWS_S3_SIGNATURE_VERSION = 's3v4'
    
    # For docker-compose, use service name instead of localhost
    if os.getenv("DOCKER_COMPOSE", "False") == "True":
        AWS_S3_ENDPOINT_URL = "http://minio-server:9000"
else:
    # AWS S3 Configuration for Production
    AWS_S3_ENDPOINT_URL = None  # Use default AWS endpoints
    AWS_S3_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
    AWS_S3_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
    AWS_S3_REGION_NAME = os.getenv("AWS_S3_BUCKET_REGION", "us-east-1")
    AWS_S3_USE_SSL = True
    AWS_S3_VERIFY = True
    AWS_S3_SIGNATURE_VERSION = 's3v4'

# Common S3 settings
AWS_STORAGE_BUCKET_NAME = os.getenv("AWS_S3_BUCKET_NAME", "media")
AWS_S3_FILE_OVERWRITE = False
AWS_DEFAULT_ACL = None
AWS_S3_OBJECT_PARAMETERS = {
    'CacheControl': 'max-age=86400',
}

# Storage configuration
STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3boto3.S3Boto3Storage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

# Media files configuration
MEDIA_URL = "/media/"
DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
```

## 2. Environment Variables

Create or update your `.env` file for local development:

```bash
# MinIO Settings (Local Development)
USE_MINIO=True
AWS_S3_ENDPOINT_URL=http://localhost:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=changeme123!
AWS_S3_BUCKET_NAME=media
AWS_S3_REGION_NAME=us-east-1

# For Docker Compose
# DOCKER_COMPOSE=True
# AWS_S3_ENDPOINT_URL=http://minio-server:9000
```

For production (AWS S3):

```bash
# AWS S3 Settings (Production)
USE_MINIO=False
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_S3_BUCKET_NAME=your-bucket-name
AWS_S3_BUCKET_REGION=us-east-1
```

## 3. Docker Compose Integration

If running your Django app with Docker Compose, add this to your `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Your Django application
  backend:
    build: .
    container_name: django_backend
    ports:
      - "8000:8000"
    environment:
      - USE_MINIO=True
      - DOCKER_COMPOSE=True
      - AWS_S3_ENDPOINT_URL=http://minio-server:9000
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=changeme123!
      - AWS_S3_BUCKET_NAME=media
      - AWS_S3_REGION_NAME=us-east-1
    networks:
      - app_network
      - self-hosted-s3_minio_network  # Connect to MinIO network

  # Your other services (postgres, redis, etc.)
  # ...

networks:
  app_network:
    driver: bridge
  self-hosted-s3_minio_network:
    external: true  # Use the existing MinIO network
```

## 4. Create Buckets for Your App

Create the necessary buckets for your Django application:

```bash
# Create buckets
./manage-minio.sh buckets create media
./manage-minio.sh buckets create static
./manage-minio.sh buckets create backups

# Make media bucket publicly readable (if needed)
docker exec minio_client mc anonymous set download local/media

# Or set it to private
docker exec minio_client mc anonymous set none local/media
```

## 5. Testing the Integration

### Python Script Test

Create a test script `test_s3.py`:

```python
import boto3
from botocore.client import Config

# Configure S3 client for MinIO
s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='changeme123!',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1',
    verify=False
)

# Test: Create a bucket
bucket_name = 'test-bucket'
try:
    s3_client.create_bucket(Bucket=bucket_name)
    print(f"✓ Bucket '{bucket_name}' created")
except Exception as e:
    print(f"✗ Error creating bucket: {e}")

# Test: Upload a file
try:
    s3_client.put_object(
        Bucket=bucket_name,
        Key='test-file.txt',
        Body=b'Hello from Django!',
        ContentType='text/plain'
    )
    print(f"✓ File uploaded to '{bucket_name}'")
except Exception as e:
    print(f"✗ Error uploading file: {e}")

# Test: List objects
try:
    response = s3_client.list_objects_v2(Bucket=bucket_name)
    if 'Contents' in response:
        print(f"✓ Files in bucket:")
        for obj in response['Contents']:
            print(f"  - {obj['Key']}")
except Exception as e:
    print(f"✗ Error listing objects: {e}")

# Test: Download file
try:
    response = s3_client.get_object(Bucket=bucket_name, Key='test-file.txt')
    content = response['Body'].read()
    print(f"✓ Downloaded file content: {content.decode()}")
except Exception as e:
    print(f"✗ Error downloading file: {e}")
```

Run it:

```bash
python test_s3.py
```

### Django Shell Test

```bash
python manage.py shell
```

```python
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage

# Test file upload
content = ContentFile(b'Hello from Django!')
path = default_storage.save('test/hello.txt', content)
print(f"File saved to: {path}")

# Test file exists
exists = default_storage.exists(path)
print(f"File exists: {exists}")

# Test file URL
url = default_storage.url(path)
print(f"File URL: {url}")

# Test file read
with default_storage.open(path, 'r') as f:
    content = f.read()
    print(f"File content: {content}")

# Test file delete
default_storage.delete(path)
print("File deleted")
```

## 6. Common Issues & Solutions

### Issue: Connection Refused

**Problem**: Django can't connect to MinIO

**Solution**:
```bash
# Check MinIO is running
./manage-minio.sh status

# Check endpoint URL
# For host machine: http://localhost:9000
# For docker-compose: http://minio-server:9000
```

### Issue: Access Denied

**Problem**: 403 Forbidden errors

**Solution**:
```bash
# Verify credentials in .env match MinIO
# Check bucket exists
./manage-minio.sh buckets list

# Set bucket policy if needed
docker exec minio_client mc anonymous set download local/media
```

### Issue: SSL Verification Failed

**Problem**: SSL errors with MinIO

**Solution**:
```python
# In settings.py, ensure:
AWS_S3_USE_SSL = False
AWS_S3_VERIFY = False
```

### Issue: Presigned URLs Not Working

**Problem**: Generated URLs don't work

**Solution**:
```python
# In settings.py, add:
AWS_S3_ADDRESSING_STYLE = "path"
AWS_QUERYSTRING_AUTH = True
AWS_QUERYSTRING_EXPIRE = 3600  # 1 hour
```

## 7. Development Workflow

### Starting Everything

```bash
# Start MinIO
cd /path/to/self-hosted-s3
./manage-minio.sh start

# Create buckets (first time only)
./manage-minio.sh buckets create media
./manage-minio.sh buckets create static

# Start Django
cd /path/to/your-django-project
python manage.py runserver

# Or with docker-compose
docker-compose up
```

### Monitoring Storage

```bash
# View storage metrics
./manage-minio.sh monitor

# List files in a bucket
./manage-minio.sh list media

# Access web console
open http://localhost:9001
```

### Backup & Restore

```bash
# Backup all data
./manage-minio.sh backup

# Restore from backup
./manage-minio.sh restore backups/minio_backup_20251015_120000.tar.gz
```

## 8. Production Deployment

When deploying to production with real AWS S3:

1. Update environment variables:
```bash
USE_MINIO=False
AWS_ACCESS_KEY_ID=your-real-aws-key
AWS_SECRET_ACCESS_KEY=your-real-aws-secret
AWS_S3_BUCKET_NAME=your-production-bucket
```

2. Django will automatically use AWS S3 instead of MinIO

3. Keep MinIO for local development and demos!

## 9. Viewing Files in Console

Access the MinIO Web Console at http://localhost:9001:

1. **Login** with your credentials
2. **Browse** → Select your bucket (e.g., "media")
3. **Upload** files via drag-and-drop
4. **Download** files by clicking on them
5. **Delete** files using the trash icon
6. **View** storage metrics in the dashboard

## Additional Resources

- [Django Storages Documentation](https://django-storages.readthedocs.io/)
- [MinIO Python SDK](https://min.io/docs/minio/linux/developers/python/minio-py.html)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)