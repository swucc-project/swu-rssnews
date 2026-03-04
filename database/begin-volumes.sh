#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Improved SQL Server Volume Initialization Script
#  With enhanced error handling and logging
# ═══════════════════════════════════════════════════════════

set -euo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VOLUMES_DIR="${PROJECT_ROOT}/volumes"
PROJECT_NAME="swu-rssnews"

# SQL Server configuration
readonly MSSQL_UID=10001
readonly MSSQL_GID=0
readonly MSSQL_USER="mssql"

# Directories to create
readonly REQUIRED_DIRS=(
    "mssql-system"
    "mssql-data"
    "mssql-logs"
    "mssql-backups"
)

# Docker volumes to create
readonly DOCKER_VOLUMES=(
    "dotnet-accessories:ASP.NET Core global tooling"
    "web-logs:RSSNews web logs"
    "nodejs-libraries:Frontend node_modules cache"
    "frontend-libraries:Shared wwwroot assets"
    "grpc-batch:gRPC shared artifacts"
    "nginx-logs:NginX logs"
)

# ═══════════════════════════════════════════════════════════
# Colors and Logging
# ═══════════════════════════════════════════════════════════

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly NC=''
fi

log_header() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

log_section() {
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

log_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
log_error()   { echo -e "${RED}❌ $1${NC}" >&2; }

# ═══════════════════════════════════════════════════════════
# Prerequisite Checks
# ═══════════════════════════════════════════════════════════

check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local errors=0
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        ((errors++))
    else
        log_success "Docker is installed"
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        ((errors++))
    else
        log_success "Docker daemon is running"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && \
       ! docker compose version >/dev/null 2>&1; then
        log_warn "Docker Compose not found (optional)"
    else
        log_success "Docker Compose is available"
    fi
    
    # Check permissions for sudo (if available)
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
            log_success "sudo is available without password"
        else
            log_info "sudo requires password (will prompt if needed)"
        fi
    else
        log_info "sudo not available, will use Docker method"
    fi
    
    echo ""
    
    if [[ $errors -gt 0 ]]; then
        log_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi
    
    log_success "All prerequisites satisfied"
    return 0
}

# ═══════════════════════════════════════════════════════════
# Directory Creation
# ═══════════════════════════════════════════════════════════

create_local_directories() {
    log_section "Creating Local Directories"
    
    # Create volumes root if needed
    if [[ ! -d "$VOLUMES_DIR" ]]; then
        mkdir -p "$VOLUMES_DIR"
        log_success "Created volumes directory: $VOLUMES_DIR"
    fi
    
    # Create required subdirectories
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        if [[ -d "$path" ]]; then
            log_info "  ✓ $dir already exists"
        else
            mkdir -p "$path"
            log_success "  📦 Created $dir"
        fi
    done
    
    echo ""
}

# ═══════════════════════════════════════════════════════════
# Permission Management
# ═══════════════════════════════════════════════════════════

set_permissions_with_retry() {
    local path="$1"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        # Method 1: Try sudo first
        if command -v sudo >/dev/null 2>&1; then
            if sudo -n chown -R "${MSSQL_UID}:${MSSQL_GID}" "$path" 2>/dev/null; then
                sudo chmod -R 755 "$path"
                return 0
            fi
        fi
        
        # Method 2: Use Docker container
        if docker run --rm \
            -v "$path:/target" \
            alpine:latest sh -c "
                chown -R ${MSSQL_UID}:${MSSQL_GID} /target && \
                chmod -R 755 /target
            " 2>/dev/null; then
            return 0
        fi
        
        log_warn "Attempt $attempt/$max_attempts failed"
        
        if [[ $attempt -lt $max_attempts ]]; then
            sleep 2
        fi
        
        ((attempt++))
    done
    
    return 1
}

set_mssql_permissions() {
    log_section "Setting SQL Server Permissions"
    
    log_info "Target ownership: UID:GID = ${MSSQL_UID}:${MSSQL_GID}"
    echo ""
    
    local failed_dirs=()
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        
        echo -e "${CYAN}🔧 Processing $dir...${NC}"
        
        if set_permissions_with_retry "$path"; then
            log_success "  Permissions set successfully"
        else
            log_error "  Failed to set permissions"
            failed_dirs+=("$dir")
        fi
    done
    
    echo ""
    
    # Create SQL Server subdirectories
    log_info "Creating SQL Server subdirectories..."
    
    if docker run --rm \
        -v "${VOLUMES_DIR}/mssql-system:/var/opt/mssql" \
        --user "${MSSQL_UID}:${MSSQL_GID}" \
        alpine:latest sh -c '
            mkdir -p /var/opt/mssql/.system
            mkdir -p /var/opt/mssql/secrets
            chmod 755 /var/opt/mssql/.system
            chmod 755 /var/opt/mssql/secrets
        ' 2>/dev/null; then
        log_success "Subdirectories created"
    else
        log_warn "Failed to create subdirectories"
    fi
    
    echo ""
    
    if [[ ${#failed_dirs[@]} -eq 0 ]]; then
        return 0
    else
        log_error "Failed to set permissions for: ${failed_dirs[*]}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Docker Volume Management
# ═══════════════════════════════════════════════════════════

create_docker_volume() {
    local vol_name="$1"
    local description="$2"
    local full_name="${PROJECT_NAME}_${vol_name}"
    
    if docker volume inspect "$full_name" >/dev/null 2>&1; then
        log_info "  ✓ $full_name already exists"
        return 0
    else
        if docker volume create "$full_name" >/dev/null 2>&1; then
            log_success "  📦 Created $full_name ($description)"
            return 0
        else
            log_error "  ❌ Failed to create $full_name"
            return 1
        fi
    fi
}

create_application_volumes() {
    log_section "Creating Application Volumes"
    
    local failed_volumes=()
    
    for volume_entry in "${DOCKER_VOLUMES[@]}"; do
        local vol_name="${volume_entry%%:*}"
        local description="${volume_entry##*:}"
        
        if ! create_docker_volume "$vol_name" "$description"; then
            failed_volumes+=("$vol_name")
        fi
    done
    
    echo ""
    
    if [[ ${#failed_volumes[@]} -eq 0 ]]; then
        log_success "All application volumes created"
        return 0
    else
        log_error "Failed to create volumes: ${failed_volumes[*]}"
        return 1
    fi
}

set_application_permissions() {
    log_section "Setting Application Volume Permissions"
    
    # Frontend volumes
    log_info "Setting frontend volume permissions..."
    docker run --rm \
        -v "${PROJECT_NAME}_nodejs-libraries:/node_modules" \
        -v "${PROJECT_NAME}_frontend-libraries:/frontend" \
        alpine:latest sh -c '
            mkdir -p /node_modules /frontend
            chmod -R 777 /node_modules /frontend
        ' 2>/dev/null && log_success "  Frontend volumes configured"
    
    # Log volumes
    log_info "Setting log volume permissions..."
    docker run --rm \
        -v "${PROJECT_NAME}_web-logs:/weblogs" \
        -v "${PROJECT_NAME}_nginx-logs:/nginx-logs" \
        alpine:latest sh -c '
            mkdir -p /weblogs /nginx-logs
            chmod -R 777 /weblogs /nginx-logs
        ' 2>/dev/null && log_success "  Log volumes configured"
    
    # gRPC volume
    log_info "Setting gRPC volume permissions..."
    docker run --rm \
        -v "${PROJECT_NAME}_grpc-batch:/grpc" \
        alpine:latest sh -c '
            mkdir -p /grpc
            chmod -R 777 /grpc
        ' 2>/dev/null && log_success "  gRPC volume configured"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════
# Verification
# ═══════════════════════════════════════════════════════════

verify_volumes() {
    log_section "Verifying Volumes"
    
    local all_ok=true
    
    # Check Docker volumes
    echo -e "${CYAN}Docker Volumes:${NC}"
    for volume_entry in "${DOCKER_VOLUMES[@]}"; do
        local vol_name="${volume_entry%%:*}"
        local full_name="${PROJECT_NAME}_${vol_name}"
        
        if docker volume inspect "$full_name" >/dev/null 2>&1; then
            log_info " ✓ $full_name"
        else
            log_error " ✗ $full_name - MISSING!"
            all_ok=false
        fi
    done
    
    echo ""
    
    # Check local directories
    echo -e "${CYAN}Local Directories:${NC}"
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        
        if [[ -d "$path" ]]; then
            # Get ownership and permissions
            local owner
            local perms
            owner=$(stat -c "%u:%g" "$path" 2>/dev/null || \
                    stat -f "%u:%g" "$path" 2>/dev/null || \
                    echo "???")
            perms=$(stat -c "%a" "$path" 2>/dev/null || \
                    stat -f "%Lp" "$path" 2>/dev/null || \
                    echo "???")
            
            # Check if ownership is correct
            if [[ "$owner" == "${MSSQL_UID}:${MSSQL_GID}" ]]; then
                log_info " ✓ $dir ($owner, $perms)"
            else
                log_warn " ⚠ $dir ($owner, $perms) - Wrong ownership!"
                all_ok=false
            fi
        else
            log_error " ✗ $dir - MISSING!"
            all_ok=false
        fi
    done
    
    echo ""
    
    # Report disk space
    log_info "Disk Space Usage:"
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        if [[ -d "$path" ]]; then
            local size
            size=$(du -sh "$path" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        fi
    done
    
    local available
    available=$(df -h "$VOLUMES_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    echo "  Available: $available"
    
    echo ""
    
    if [[ "$all_ok" == "true" ]]; then
        log_success "All volumes verified successfully"
        return 0
    else
        log_error "Some volumes failed verification!"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════

clean_volumes() {
    log_header "Clean Mode - Volume Cleanup"
    
    log_warn "This will DELETE all volumes and their data!"
    echo ""
    
    read -rp "Are you sure? Type 'yes' to confirm: " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Operation cancelled"
        return 0
    fi
    
    echo ""
    
    # Offer backup
    read -rp "Create backup before cleaning? (y/n): " create_backup
    
    if [[ "$create_backup" =~ ^[Yy] ]]; then
        local backup_dir="${VOLUMES_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup at $backup_dir..."
        
        if cp -r "$VOLUMES_DIR" "$backup_dir" 2>/dev/null; then
            log_success "Backup created successfully"
        else
            log_error "Backup failed - aborting cleanup"
            return 1
        fi
        echo ""
    fi
    
    # Stop containers
    log_info "Stopping containers..."
    docker compose down -v 2>/dev/null || true
    
    # Remove Docker volumes
    log_info "Removing Docker volumes..."
    for volume_entry in "${DOCKER_VOLUMES[@]}"; do
        local vol_name="${volume_entry%%:*}"
        local full_name="${PROJECT_NAME}_${vol_name}"
        
        if docker volume ls -q | grep -q "^${full_name}$"; then
            if docker volume rm -f "$full_name" 2>/dev/null; then
                log_success "  Removed $full_name"
            else
                log_warn "  Failed to remove $full_name"
            fi
        fi
    done
    
    # Remove local directories
    if [[ -d "$VOLUMES_DIR" ]]; then
        log_info "Removing local directories..."
        if rm -rf "${VOLUMES_DIR:?}"/* 2>/dev/null; then
            log_success "  Local directories removed"
        else
            log_warn "  Some directories could not be removed"
        fi
    fi
    
    echo ""
    log_success "Cleanup completed"
}

# ═══════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --clean, -c     Clean mode: remove all volumes and data
  --verify, -v    Verify mode: check volumes without creating
  --help, -h      Show this help message

Examples:
  $0              # Initialize volumes (default)
  $0 --clean      # Clean all volumes
  $0 --verify     # Verify existing volumes

EOF
}

main() {
    # Parse arguments
    case "${1:-}" in
        --clean|-c)
            log_header "SQL Server Volume Cleanup"
            clean_volumes
            exit $?
            ;;
        --verify|-v)
            log_header "SQL Server Volume Verification"
            verify_volumes
            exit $?
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        "")
            # Normal initialization
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    # Main initialization flow
    log_header "SQL Server Volume Initialization"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Create directories
    create_local_directories
    
    # Set SQL Server permissions
    if ! set_mssql_permissions; then
        log_error "Failed to set SQL Server permissions"
        exit 1
    fi
    
    # Create Docker volumes
    if ! create_application_volumes; then
        log_error "Failed to create application volumes"
        exit 1
    fi
    
    # Set application permissions
    set_application_permissions
    
    # Verify everything
    if ! verify_volumes; then
        log_warn "Verification found issues, but continuing"
    fi
    
    # Success message
    echo ""
    log_header "Initialization Complete"
    
    echo -e "${CYAN}📝 Next Steps:${NC}"
    echo "  1. Run: make build"
    echo "  2. Run: make install"
    echo "  3. Run: make dev"
    echo ""
    echo -e "${CYAN}💡 Useful Commands:${NC}"
    echo "  • Verify volumes:  $0 --verify"
    echo "  • Clean volumes:   $0 --clean"
    echo "  • View logs:       docker compose logs -f"
    echo ""
}

# Trap errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"