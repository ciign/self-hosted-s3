#!/bin/bash

# Self-Hosted S3 (MinIO) Setup Script
# This script prepares your environment for running MinIO

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header "Self-Hosted S3 (MinIO) Setup"

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    print_info "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
print_success "Docker is installed"

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed!"
    print_info "Please install Docker Compose"
    exit 1
fi
print_success "Docker Compose is installed"

# Create directory structure
print_info "Creating directory structure..."

mkdir -p minio/data      # MinIO S3 data (buckets and objects stored here)
mkdir -p minio/init
mkdir -p minio/config
mkdir -p minio/scripts
mkdir -p backups

print_success "Directories created"
print_info "MinIO files will be stored in: ./minio/data/"

# Create environment file if it doesn't exist
if [ ! -f .env.minio ]; then
    print_info "Creating .env.minio from example..."

    if [ -f .env.minio.example ]; then
        cp .env.minio.example .env.minio
        print_success ".env.minio created"
        print_warning "Please edit .env.minio and change the default credentials!"
    else
        print_warning ".env.minio.example not found, creating default..."
        cat > .env.minio << 'EOF'
# MinIO Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=changeme123!
MINIO_REGION=us-east-1
MINIO_BROWSER=on
MINIO_DOMAIN=localhost
MINIO_BROWSER_REDIRECT_URL=http://localhost:9001
EOF
        print_success ".env.minio created with defaults"
        print_warning "Please edit .env.minio and change the credentials!"
    fi
else
    print_success ".env.minio already exists"
fi

# Make management script executable
if [ -f manage-minio.sh ]; then
    chmod +x manage-minio.sh
    print_success "manage-minio.sh is now executable"
fi

# Create a sample bucket creation script
cat > minio/scripts/setup-buckets.sh << 'EOF'
#!/bin/sh
# This script creates default buckets for your application

echo "Creating default buckets..."

mc mb local/media --ignore-existing
mc mb local/static --ignore-existing
mc mb local/backups --ignore-existing
mc mb local/uploads --ignore-existing

echo "Setting bucket policies..."
mc anonymous set download local/media
mc anonymous set download local/static

echo "Buckets setup complete!"
EOF

chmod +x minio/scripts/setup-buckets.sh
print_success "Created bucket setup script"

# Create storage monitoring script
cat > minio/scripts/monitor-storage.sh << 'EOF'
#!/bin/sh
# Monitor MinIO storage usage

echo "=== MinIO Storage Monitor ==="
echo ""

echo "Server Info:"
mc admin info local

echo ""
echo "Storage Usage by Bucket:"
mc du local

echo ""
echo "Active Services:"
mc admin service list local
EOF

chmod +x minio/scripts/monitor-storage.sh
print_success "Created monitoring script"

# Summary
print_header "Setup Complete!"

cat << EOF
${GREEN}✓${NC} Your MinIO environment is ready!

${BLUE}Next Steps:${NC}

1. ${YELLOW}Configure credentials:${NC}
   Edit .env.minio and change MINIO_ROOT_PASSWORD

2. ${YELLOW}Start MinIO:${NC}
   ./manage-minio.sh start

3. ${YELLOW}Access Web Console:${NC}
   Open http://localhost:9001 in your browser
   Login with credentials from .env.minio

4. ${YELLOW}Test the installation:${NC}
   ./manage-minio.sh test

${BLUE}Useful Commands:${NC}
  ./manage-minio.sh status    - Check cluster status
  ./manage-minio.sh monitor   - View storage metrics
  ./manage-minio.sh help      - Show all commands

${BLUE}Integration:${NC}
  S3 API Endpoint: http://localhost:9000
  Console UI:      http://localhost:9001

  Add to your application's .env:
  AWS_S3_ENDPOINT_URL=http://localhost:9000
  AWS_ACCESS_KEY_ID=minioadmin
  AWS_SECRET_ACCESS_KEY=<your-password>

${YELLOW}Important:${NC} The web console is built into MinIO!
No separate container needed.

EOF

print_info "For more information, see README.md"