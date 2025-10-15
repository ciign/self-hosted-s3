# Self-Hosted S3 (MinIO)

A production-ready MinIO S3-compatible object storage environment with monitoring, management tools, and multi-tenant capabilities.

- **MinIO Version**: Latest stable release from quay.io/minio/minio
- **Protocol**: S3-compatible API
- **Web UI**: Built-in console (included in main image) ✅
- **Interface**: Web console + CLI tools
- **Health**: Operational with automatic health checks
- **Data Storage**: Local directory `./minio/data/` (bind-mounted)

> **Note**: The MinIO console is **built into** the main MinIO server image. You don't need a separate console container!

## Quick Start (5 Minutes)

```bash
# 1. Clone or download this repository
git clone https://github.com/ciign/self-hosted-s3
cd self-hosted-s3

# 2. Run setup script
chmod +x setup.sh
./setup.sh

# 3. Configure credentials (IMPORTANT: Change password!)
nano .env.minio
# Change: MINIO_ROOT_PASSWORD=your-strong-password-here

# 4. Start MinIO
./manage-minio.sh start

# 5. Access Web Console
# URL: http://localhost:9001
# Username: minioadmin (or your MINIO_ROOT_USER)
# Password: (what you set in step 3)

# 6. Test everything works
./manage-minio.sh test
```

You should see:
```
✓ Test bucket created
✓ File uploaded successfully
✓ File downloaded successfully
✓ Content verified!
✓ All tests passed! MinIO is working correctly.
```

## Accessing the Web UI

The MinIO Console (Web UI) is **built into the main MinIO server** and automatically available:

- **URL**: http://localhost:9001
- **Username**: Value from `MINIO_ROOT_USER` in `.env.minio` (default: `minioadmin`)
- **Password**: Value from `MINIO_ROOT_PASSWORD` in `.env.minio`

**Features Available in Console:**
- Browse and manage buckets
- Upload/download files via drag-and-drop
- View storage metrics and usage
- Manage access policies
- Monitor server health
- Create and manage access keys

> **Important**: The console is served on port **9001**, while the S3 API is on port **9000**. Make sure both ports are exposed!

## Project Structure

```
self-hosted-s3/
├── docker-compose-minio.yml    # Main orchestration file
├── manage-minio.sh             # Management CLI tool
├── setup.sh                    # Initial setup script
├── .env.minio.example          # Environment template
├── .env.minio                  # Your credentials (git-ignored)
├── .gitignore                  # Git ignore rules
├── README.md                   # This file
├── DJANGO_INTEGRATION.md       # Django integration guide
├── LICENSE                     # MIT License
├── minio/
│   ├── data/                   # ⭐ MinIO S3 data stored here (buckets, objects)
│   ├── init/                   # Initialization scripts
│   ├── config/                 # MinIO configuration
│   └── scripts/
│       ├── setup-buckets.sh    # Bucket setup script
│       └── monitor-storage.sh  # Storage monitoring
└── backups/                    # Backup directory
```

### Where Are My Files Stored?

**All MinIO data (buckets and objects) are stored locally in:**
```bash
./minio/data/
```

This directory is **bind-mounted** into the MinIO container, so:
- ✅ You can see your files on your host machine
- ✅ Data persists even if you remove the container
- ✅ You can backup by copying this directory
- ✅ Easy to inspect what's stored

**Example:**
```bash
ls -la minio/data/
# You'll see MinIO's internal structure with your buckets

# After creating a bucket called "my-bucket"
ls -la minio/data/.minio.sys/buckets/my-bucket/
# Your uploaded files are here!
```

**Data Flow:**
```
Your App → S3 API (localhost:9000) → MinIO Container → ./minio/data/ (on your host)
                                                              ↓
                                                    Visible in your project folder!
```

**Managing Data:**
```bash
# Backup data (just copy the folder)
cp -r minio/data minio/data.backup

# Or use the management script
./manage-minio.sh backup

# Clean all data
./manage-minio.sh clean  # Removes ./minio/data/*

# Check disk usage
du -sh minio/data/
```

## Services Overview

| Service | Container Name | Port | Purpose |
|---------|---------------|------|---------|
| MinIO Server | minio_server | 9000 | S3 API endpoint |
| MinIO Console | minio_server | 9001 | Web-based management UI |
| MinIO Client | minio_client | - | CLI management tool |

## Management Commands

### Basic Operations
```bash
./manage-minio.sh start          # Start all services
./manage-minio.sh stop           # Stop all services
./manage-minio.sh restart        # Restart all services
./manage-minio.sh status         # Show cluster status
```

### Monitoring & Testing
```bash
./manage-minio.sh monitor        # Show storage metrics
./manage-minio.sh test           # Test storage is working
./manage-minio.sh logs all       # View all service logs
./manage-minio.sh logs server    # Server logs only
```

### Bucket Management
```bash
./manage-minio.sh buckets list   # List all buckets
./manage-minio.sh buckets create <n>  # Create bucket
./manage-minio.sh buckets delete <n>  # Delete bucket
./manage-minio.sh buckets info <n>    # Show bucket info
```

### File Operations
```bash
./manage-minio.sh upload <bucket> <file>     # Upload file
./manage-minio.sh download <bucket> <file>   # Download file
./manage-minio.sh list <bucket>              # List files in bucket
./manage-minio.sh delete <bucket> <file>     # Delete file
```

### Backup & Restore
```bash
./manage-minio.sh backup         # Create full backup
./manage-minio.sh restore <file> # Restore from backup
```

### Advanced
```bash
./manage-minio.sh client         # Open MinIO client shell
./manage-minio.sh clean          # Remove all data (WARNING: Data loss!)
./manage-minio.sh help           # Show all commands
```

## Configuration

### Environment Variables

Create `.env.minio` from the template:

```bash
cp .env.minio.example .env.minio
nano .env.minio
```

**Required settings:**
```bash
# Root User Credentials (CHANGE THESE!)
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=changeme123!

# MinIO Region
MINIO_REGION=us-east-1

# Console Browser
MINIO_BROWSER=on

# Domain (for virtual-host-style requests)
MINIO_DOMAIN=localhost

# Browser Redirect URL
MINIO_BROWSER_REDIRECT_URL=http://localhost:9001
```

### Security Considerations

The setup uses Docker networks for isolation. For production:
- Change default credentials immediately
- Use SSL/TLS certificates
- Configure IAM policies
- Enable encryption at rest
- Implement network segmentation

### Access Credentials

```bash
# S3 API Endpoint
http://localhost:9000

# Console UI
http://localhost:9001

# Credentials
Access Key: minioadmin (or your MINIO_ROOT_USER)
Secret Key: <your-password>
```

## Integration with Applications

### Environment Variables for Your App

```bash
# For your Django/Node/Python app
AWS_S3_ENDPOINT_URL=http://localhost:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=<your-password>
AWS_S3_REGION_NAME=us-east-1
AWS_S3_BUCKET_NAME=my-app-bucket
AWS_S3_USE_SSL=false
```

### Docker Compose Integration

```yaml
services:
  your-app:
    environment:
      - AWS_S3_ENDPOINT_URL=http://minio-server:9000
      - AWS_ACCESS_KEY_ID=${MINIO_ROOT_USER}
      - AWS_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD}
      - AWS_S3_BUCKET_NAME=my-app-bucket
    networks:
      - self-hosted-s3_minio_network

networks:
  self-hosted-s3_minio_network:
    external: true
```

### Python/Django Example

See [DJANGO_INTEGRATION.md](./DJANGO_INTEGRATION.md) for detailed Django setup.

Quick example:
```python
import boto3
from botocore.client import Config

# Configure S3 client for MinIO
s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='your-password',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# Upload file
s3_client.upload_file('local-file.txt', 'my-bucket', 'remote-file.txt')

# Download file
s3_client.download_file('my-bucket', 'remote-file.txt', 'downloaded-file.txt')

# List objects
response = s3_client.list_objects_v2(Bucket='my-bucket')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

## Manual Testing

```bash
# Check server health
curl http://localhost:9000/minio/health/live

# List buckets via API
docker exec minio_client mc ls local

# Create a test bucket
docker exec minio_client mc mb local/test-bucket

# Upload a file
echo "Hello World" > test.txt
./manage-minio.sh upload test-bucket test.txt

# List bucket contents
./manage-minio.sh list test-bucket

# Download file
./manage-minio.sh download test-bucket test.txt downloaded.txt
```

## Troubleshooting

### Server won't start
```bash
# Check if ports are in use
lsof -i :9000
lsof -i :9001

# Check logs
./manage-minio.sh logs server

# Complete reset
./manage-minio.sh clean
./manage-minio.sh start
```

### Cannot access console
```bash
# Verify browser setting
docker exec minio_server printenv | grep MINIO_BROWSER

# Check firewall
sudo ufw status

# Access logs
./manage-minio.sh logs server
```

### Client connection issues
```bash
# Test connectivity
docker exec minio_client mc config host add test http://minio-server:9000 minioadmin password

# Verify DNS resolution
docker exec minio_client nslookup minio-server

# Check network
docker network ls
docker network inspect self-hosted-s3_minio_network
```

### Storage issues
```bash
# Check disk space
df -h

# Monitor storage
./manage-minio.sh monitor

# Check data directory
ls -lah minio/data/
du -sh minio/data/
```

## Backup Strategy

```bash
# Add to crontab for daily backups at 2 AM
0 2 * * * cd /path/to/self-hosted-s3 && ./manage-minio.sh backup

# Create backup
./manage-minio.sh backup

# List backups
ls -la backups/

# Restore specific backup
./manage-minio.sh restore backups/minio_backup_20251015_120000.tar.gz
```

## Performance Tuning

Default settings for development:
- Storage class: STANDARD
- Versioning: Disabled
- Lifecycle policies: None

For production, consider:
- Enable versioning for important buckets
- Configure lifecycle policies for automatic cleanup
- Set up replication for high availability
- Adjust memory limits based on workload

## Requirements

- Docker Engine 20.10+
- Docker Compose 1.29+
- 1GB+ RAM recommended
- 10GB+ disk space for storage

## Health Checks

The MinIO service includes health checks:
- Liveness: Every 30s, checks `/minio/health/live`
- Readiness: Verifies server is accepting connections

## Important Notes

- MinIO is fully S3-compatible
- **Data stored in**: `./minio/data/` (local directory, visible on host)
- Console accessible at http://localhost:9001
- API accessible at http://localhost:9000
- Data persists across container restarts
- You can backup by simply copying the `./minio/data/` directory
- Use strong passwords in production

## Common Use Cases

### Local Development
Perfect for developing S3-based features without AWS costs or internet dependency.

### Demos and Presentations
Show S3 functionality in controlled environment without AWS account.

### CI/CD Testing
Fast, free S3 testing in your build pipelines.

### Learning S3 APIs
Practice with S3 API without fear of costs or mistakes.

## Status Indicators

When everything is working correctly:
- `./manage-minio.sh status` shows container healthy
- `./manage-minio.sh test` confirms storage works
- `./manage-minio.sh monitor` shows storage metrics
- Console accessible at http://localhost:9001
- API responds at http://localhost:9000

## Version Information

- **MinIO Version**: Latest stable release
- **Last Updated**: October 2025
- **Status**: Production-ready for development/testing environments

## License

This project configuration is provided as-is under the MIT License. See [LICENSE](./LICENSE) for details.

MinIO itself is licensed under GNU AGPLv3.

## Support

For MinIO-specific issues, consult the [official MinIO documentation](https://min.io/docs/minio/linux/index.html).

For issues with this configuration, please open an issue on GitHub.