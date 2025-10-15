#!/bin/bash

# MinIO Management Script
# Comprehensive management tool for self-hosted MinIO S3 storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose-minio.yml"
ENV_FILE=".env.minio"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
}

check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        print_error "Environment file $ENV_FILE not found!"
        print_info "Creating from .env.minio.example..."
        if [ -f ".env.minio.example" ]; then
            cp .env.minio.example "$ENV_FILE"
            print_warning "Please edit $ENV_FILE and update the credentials!"
            exit 1
        else
            print_error ".env.minio.example not found!"
            exit 1
        fi
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed!"
        exit 1
    fi
}

# Main commands
cmd_start() {
    print_header "Starting MinIO S3 Storage"
    check_env
    check_docker

    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

    print_success "MinIO services started successfully!"
    print_info "Console UI: http://localhost:9001"
    print_info "S3 API: http://localhost:9000"
    print_info ""
    print_info "Waiting for services to be ready..."
    sleep 5
    cmd_status
}

cmd_stop() {
    print_header "Stopping MinIO S3 Storage"

    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down

    print_success "MinIO services stopped successfully!"
}

cmd_restart() {
    print_header "Restarting MinIO S3 Storage"
    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    print_header "MinIO Cluster Status"

    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps

    echo ""
    print_info "Checking MinIO server health..."

    if docker ps | grep -q "minio_server.*healthy"; then
        print_success "MinIO server is healthy"
    elif docker ps | grep -q "minio_server"; then
        print_warning "MinIO server is running but health check pending"
    else
        print_error "MinIO server is not running"
        return 1
    fi

    echo ""
    print_info "Quick Stats:"
    docker exec minio_client mc admin info local 2>/dev/null || print_warning "Could not fetch stats (server may still be starting)"
}

cmd_logs() {
    local service=${1:-all}

    print_header "MinIO Logs: $service"

    case $service in
        all)
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f
            ;;
        server)
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f minio-server
            ;;
        client)
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f minio-client
            ;;
        *)
            print_error "Unknown service: $service"
            print_info "Available services: all, server, client"
            exit 1
            ;;
    esac
}

cmd_monitor() {
    print_header "MinIO Storage Metrics"

    print_info "Server Information:"
    docker exec minio_client mc admin info local

    echo ""
    print_info "Storage Usage:"
    docker exec minio_client mc du local

    echo ""
    print_info "Active Services:"
    docker exec minio_client mc admin service list local
}

cmd_test() {
    print_header "Testing MinIO Storage"

    print_info "1. Creating test bucket..."
    docker exec minio_client mc mb local/test-bucket --ignore-existing
    print_success "Test bucket created"

    print_info "2. Creating test file..."
    docker exec minio_client sh -c "echo 'Hello from MinIO!' > /tmp/test-file.txt"

    print_info "3. Uploading test file..."
    docker exec minio_client mc cp /tmp/test-file.txt local/test-bucket/
    print_success "File uploaded successfully"

    print_info "4. Listing bucket contents..."
    docker exec minio_client mc ls local/test-bucket/

    print_info "5. Downloading test file..."
    docker exec minio_client mc cp local/test-bucket/test-file.txt /tmp/downloaded.txt
    print_success "File downloaded successfully"

    print_info "6. Verifying content..."
    CONTENT=$(docker exec minio_client cat /tmp/downloaded.txt)
    if [ "$CONTENT" = "Hello from MinIO!" ]; then
        print_success "Content verified!"
    else
        print_error "Content verification failed!"
        exit 1
    fi

    print_info "7. Cleaning up test files..."
    docker exec minio_client mc rm local/test-bucket/test-file.txt
    docker exec minio_client mc rb local/test-bucket

    print_success "All tests passed! MinIO is working correctly."
}

cmd_buckets() {
    local action=$1
    local bucket=$2

    case $action in
        list)
            print_header "Listing Buckets"
            docker exec minio_client mc ls local
            ;;
        create)
            if [ -z "$bucket" ]; then
                print_error "Bucket name required!"
                print_info "Usage: $0 buckets create <bucket-name>"
                exit 1
            fi
            print_info "Creating bucket: $bucket"
            docker exec minio_client mc mb "local/$bucket"
            print_success "Bucket created successfully"
            ;;
        delete)
            if [ -z "$bucket" ]; then
                print_error "Bucket name required!"
                print_info "Usage: $0 buckets delete <bucket-name>"
                exit 1
            fi
            print_warning "Deleting bucket: $bucket"
            docker exec minio_client mc rb "local/$bucket" --force
            print_success "Bucket deleted successfully"
            ;;
        info)
            if [ -z "$bucket" ]; then
                print_error "Bucket name required!"
                print_info "Usage: $0 buckets info <bucket-name>"
                exit 1
            fi
            print_info "Bucket information: $bucket"
            docker exec minio_client mc stat "local/$bucket"
            docker exec minio_client mc du "local/$bucket"
            ;;
        *)
            print_error "Unknown action: $action"
            print_info "Available actions: list, create, delete, info"
            exit 1
            ;;
    esac
}

cmd_upload() {
    local bucket=$1
    local file=$2

    if [ -z "$bucket" ] || [ -z "$file" ]; then
        print_error "Bucket name and file path required!"
        print_info "Usage: $0 upload <bucket-name> <file-path>"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        exit 1
    fi

    print_info "Uploading $file to bucket: $bucket"

    # Copy file to container first
    docker cp "$file" minio_client:/tmp/upload_file

    # Upload to MinIO
    docker exec minio_client mc cp /tmp/upload_file "local/$bucket/$(basename "$file")"

    print_success "File uploaded successfully"
}

cmd_download() {
    local bucket=$1
    local remote_file=$2
    local local_file=${3:-$(basename "$remote_file")}

    if [ -z "$bucket" ] || [ -z "$remote_file" ]; then
        print_error "Bucket name and remote file path required!"
        print_info "Usage: $0 download <bucket-name> <remote-file> [local-file]"
        exit 1
    fi

    print_info "Downloading $remote_file from bucket: $bucket"

    # Download from MinIO
    docker exec minio_client mc cp "local/$bucket/$remote_file" /tmp/download_file

    # Copy from container to host
    docker cp minio_client:/tmp/download_file "$local_file"

    print_success "File downloaded to: $local_file"
}

cmd_list() {
    local bucket=$1

    if [ -z "$bucket" ]; then
        print_error "Bucket name required!"
        print_info "Usage: $0 list <bucket-name>"
        exit 1
    fi

    print_header "Contents of bucket: $bucket"
    docker exec minio_client mc ls "local/$bucket"
}

cmd_delete_file() {
    local bucket=$1
    local file=$2

    if [ -z "$bucket" ] || [ -z "$file" ]; then
        print_error "Bucket name and file path required!"
        print_info "Usage: $0 delete <bucket-name> <file-path>"
        exit 1
    fi

    print_warning "Deleting $file from bucket: $bucket"
    docker exec minio_client mc rm "local/$bucket/$file"
    print_success "File deleted successfully"
}

cmd_backup() {
    print_header "Creating MinIO Backup"

    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/minio_backup_$TIMESTAMP.tar.gz"

    print_info "Backing up MinIO data..."
    docker exec minio_client mc mirror --preserve local "$BACKUP_DIR/temp_backup" 2>/dev/null || true

    # Create archive
    print_info "Creating backup archive..."
    tar -czf "$backup_file" -C "$BACKUP_DIR" temp_backup 2>/dev/null || print_warning "Some files may have been skipped"

    # Cleanup temp
    rm -rf "$BACKUP_DIR/temp_backup"

    print_success "Backup created: $backup_file"

    # Show backup size
    local size=$(du -h "$backup_file" | cut -f1)
    print_info "Backup size: $size"
}

cmd_restore() {
    local backup_file=$1

    if [ -z "$backup_file" ]; then
        print_error "Backup file required!"
        print_info "Usage: $0 restore <backup-file>"
        print_info "Available backups:"
        ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || print_warning "No backups found"
        exit 1
    fi

    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi

    print_header "Restoring MinIO Backup"
    print_warning "This will overwrite existing data!"

    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Restore cancelled"
        exit 0
    fi

    print_info "Extracting backup..."
    mkdir -p "$BACKUP_DIR/temp_restore"
    tar -xzf "$backup_file" -C "$BACKUP_DIR/temp_restore"

    print_info "Restoring data to MinIO..."
    docker exec minio_client mc mirror --overwrite "$BACKUP_DIR/temp_restore/temp_backup" local

    # Cleanup
    rm -rf "$BACKUP_DIR/temp_restore"

    print_success "Restore completed successfully!"
}

cmd_client() {
    print_header "MinIO Client Shell"
    print_info "You are now in the MinIO client container"
    print_info "Available commands: mc ls, mc cp, mc mb, mc rb, etc."
    print_info "Type 'exit' to return to host"

    docker exec -it minio_client sh
}

cmd_clean() {
    print_header "Clean MinIO Installation"
    print_error "⚠️  WARNING: This will delete ALL data! ⚠️"
    print_warning "This action cannot be undone!"
    print_info "This will remove: ./minio/data/"

    read -p "Type 'DELETE-ALL-DATA' to confirm: " confirm
    if [ "$confirm" != "DELETE-ALL-DATA" ]; then
        print_info "Clean cancelled"
        exit 0
    fi

    print_info "Stopping services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down

    print_info "Removing data directory..."
    rm -rf minio/data/*

    print_success "All data cleaned successfully!"
    print_info "Run './manage-minio.sh start' to create a fresh installation"
}

cmd_help() {
    cat << EOF

${BLUE}MinIO Management Script${NC}
═══════════════════════════════════════

${GREEN}Basic Operations:${NC}
  start                    Start MinIO services
  stop                     Stop MinIO services
  restart                  Restart MinIO services
  status                   Show cluster status

${GREEN}Monitoring & Testing:${NC}
  monitor                  Show storage metrics
  test                     Run comprehensive tests
  logs [service]           View logs (all, server, client)

${GREEN}Bucket Management:${NC}
  buckets list             List all buckets
  buckets create <n>    Create a new bucket
  buckets delete <n>    Delete a bucket
  buckets info <n>      Show bucket information

${GREEN}File Operations:${NC}
  upload <bucket> <file>                Upload file to bucket
  download <bucket> <file> [local]      Download file from bucket
  list <bucket>                         List files in bucket
  delete <bucket> <file>                Delete file from bucket

${GREEN}Backup & Restore:${NC}
  backup                   Create full backup
  restore <file>           Restore from backup file

${GREEN}Advanced:${NC}
  client                   Open MinIO client shell
  clean                    Remove all data (⚠️  destructive!)
  help                     Show this help message

${BLUE}Examples:${NC}
  ./manage-minio.sh start
  ./manage-minio.sh buckets create my-app-data
  ./manage-minio.sh upload my-app-data ./file.txt
  ./manage-minio.sh backup

${BLUE}Web Console:${NC}
  URL: http://localhost:9001
  API: http://localhost:9000

EOF
}

# Main script logic
main() {
    local command=$1
    shift || true

    case $command in
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        restart)
            cmd_restart
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs "$@"
            ;;
        monitor)
            cmd_monitor
            ;;
        test)
            cmd_test
            ;;
        buckets)
            cmd_buckets "$@"
            ;;
        upload)
            cmd_upload "$@"
            ;;
        download)
            cmd_download "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        delete)
            cmd_delete_file "$@"
            ;;
        backup)
            cmd_backup
            ;;
        restore)
            cmd_restore "$@"
            ;;
        client)
            cmd_client
            ;;
        clean)
            cmd_clean
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            print_error "Unknown command: $command"
            print_info "Run './manage-minio.sh help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"