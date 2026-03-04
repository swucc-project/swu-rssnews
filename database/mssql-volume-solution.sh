#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  🏥 SQL Server Volume Doctor
#  Automated health check and repair for SQL Server volumes
# ═══════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VOLUMES_DIR="${PROJECT_ROOT}/volumes"
REQUIRED_DIRS=("mssql-system" "mssql-data" "mssql-logs" "mssql-backups")
MSSQL_UID=10001
MSSQL_GID=0

# Health check results
ISSUES_FOUND=0
WARNINGS_FOUND=0
AUTO_FIX=false

# ═══════════════════════════════════════════════════════════
#  📋 Helper Functions
# ═══════════════════════════════════════════════════════════

print_header() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

issue() {
    echo -e "${RED}❌ ISSUE:${NC} $1"
    ((ISSUES_FOUND++))
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNINGS_FOUND++))
}

success() {
    echo -e "${GREEN}✅ OK:${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

# ═══════════════════════════════════════════════════════════
#  🔍 Health Checks
# ═══════════════════════════════════════════════════════════

check_docker() {
    print_section "Checking Docker"
    
    if ! command -v docker >/dev/null 2>&1; then
        issue "Docker not installed"
        return 1
    fi
    success "Docker is installed"
    
    if ! docker info >/dev/null 2>&1; then
        issue "Docker daemon is not running"
        return 1
    fi
    success "Docker daemon is running"
    
    return 0
}

check_directories() {
    print_section "Checking Directory Structure"
    
    local all_ok=true
    
    if [ ! -d "$VOLUMES_DIR" ]; then
        issue "Volumes directory missing: $VOLUMES_DIR"
        all_ok=false
    else
        success "Volumes directory exists"
    fi
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        if [ ! -d "$path" ]; then
            issue "Required directory missing: $dir"
            all_ok=false
        else
            success "Directory exists: $dir"
        fi
    done
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    
    return 0
}

check_permissions() {
    print_section "Checking Permissions"
    
    local all_ok=true
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        
        if [ ! -d "$path" ]; then
            continue
        fi
        
        # Get ownership
        local owner_uid=$(stat -c "%u" "$path" 2>/dev/null || stat -f "%u" "$path" 2>/dev/null || echo "unknown")
        local owner_gid=$(stat -c "%g" "$path" 2>/dev/null || stat -f "%g" "$path" 2>/dev/null || echo "unknown")
        
        # Get permissions
        local perms=$(stat -c "%a" "$path" 2>/dev/null || stat -f "%Lp" "$path" 2>/dev/null || echo "unknown")
        
        # Check ownership
        if [ "$owner_uid" != "$MSSQL_UID" ] || [ "$owner_gid" != "$MSSQL_GID" ]; then
            issue "$dir: Wrong ownership ($owner_uid:$owner_gid, should be $MSSQL_UID:$MSSQL_GID)"
            all_ok=false
        else
            success "$dir: Correct ownership ($owner_uid:$owner_gid)"
        fi
        
        # Check permissions
        if [ "$perms" != "755" ]; then
            warning "$dir: Permissions $perms (recommended: 755)"
        else
            success "$dir: Correct permissions ($perms)"
        fi
    done
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    
    return 0
}

check_container_status() {
    print_section "Checking SQL Server Container"
    
    if ! docker ps -a --format '{{.Names}}' | grep -q '^sqlserver$'; then
        warning "SQL Server container not found"
        return 1
    fi
    success "Container exists"
    
    local status=$(docker inspect sqlserver --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
    
    case "$status" in
        "running")
            success "Container is running"
            ;;
        "exited")
            issue "Container has exited"
            return 1
            ;;
        "created")
            warning "Container created but not started"
            return 1
            ;;
        *)
            issue "Container in unknown state: $status"
            return 1
            ;;
    esac
    
    # Check health
    local health=$(docker inspect sqlserver --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
    
    case "$health" in
        "healthy")
            success "Container is healthy"
            ;;
        "unhealthy")
            issue "Container is unhealthy"
            return 1
            ;;
        "starting")
            warning "Container health check is starting"
            ;;
        "none")
            warning "No health check configured"
            ;;
    esac
    
    return 0
}

check_volume_mounts() {
    print_section "Checking Volume Mounts"
    
    if ! docker ps --format '{{.Names}}' | grep -q '^sqlserver$'; then
        warning "Container not running, cannot check mounts"
        return 1
    fi
    
    local all_ok=true
    
    # Expected mounts
    local expected_mounts=(
        "/var/opt/mssql/data:mssql-data"
        "/var/opt/mssql/log:mssql-logs"
        "/var/opt/mssql/backups:mssql-backups"
        "/var/opt/mssql:mssql-system"
    )
    
    for mount_info in "${expected_mounts[@]}"; do
        local dest="${mount_info%%:*}"
        local name="${mount_info##*:}"
        
        if docker inspect sqlserver --format='{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' 2>/dev/null | grep -q "^${dest}$"; then
            success "$name mounted at $dest"
        else
            issue "$name not mounted at $dest"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    
    return 0
}

check_disk_space() {
    print_section "Checking Disk Space"
    
    local total_size=0
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        
        if [ -d "$path" ]; then
            local size=$(du -sh "$path" 2>/dev/null | cut -f1)
            info "$dir: $size"
        fi
    done
    
    # Check available space
    local available=$(df -h "$VOLUMES_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    
    if [ -n "$available" ]; then
        info "Available space: $available"
    fi
    
    return 0
}

check_container_logs() {
    print_section "Checking Container Logs for Errors"
    
    if ! docker ps -a --format '{{.Names}}' | grep -q '^sqlserver$'; then
        warning "Container not found"
        return 1
    fi
    
    # Check for common error patterns
    local errors=$(docker logs sqlserver 2>&1 | grep -i "error\|failed\|permission denied" | tail -10)
    
    if [ -n "$errors" ]; then
        warning "Errors found in container logs:"
        echo "$errors" | while IFS= read -r line; do
            echo "  ${YELLOW}→${NC} $line"
        done
        return 1
    else
        success "No errors in recent logs"
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════
#  🔧 Auto-Fix Functions
# ═══════════════════════════════════════════════════════════

fix_directories() {
    print_section "Creating Missing Directories"
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        if [ ! -d "$path" ]; then
            echo -e "${CYAN}Creating:${NC} $dir"
            mkdir -p "$path"
            success "Created $dir"
        fi
    done
}

fix_permissions() {
    print_section "Fixing Permissions"
    
    # Stop SQL Server if running
    if docker ps --format '{{.Names}}' | grep -q '^sqlserver$'; then
        echo -e "${YELLOW}Stopping SQL Server...${NC}"
        docker compose stop mssql 2>/dev/null || true
        sleep 2
    fi
    
    # Fix each directory
    for dir in "${REQUIRED_DIRS[@]}"; do
        local path="${VOLUMES_DIR}/${dir}"
        
        if [ ! -d "$path" ]; then
            continue
        fi
        
        echo -e "${CYAN}Fixing:${NC} $dir"
        
        # Try sudo first
        if command -v sudo >/dev/null 2>&1; then
            if sudo chown -R ${MSSQL_UID}:${MSSQL_GID} "$path" 2>/dev/null; then
                sudo chmod -R 755 "$path"
                success "Fixed via sudo"
                continue
            fi
        fi
        
        # Fallback to Docker
        docker run --rm \
            -v "$path:/target" \
            alpine:latest sh -c "
                chown -R ${MSSQL_UID}:${MSSQL_GID} /target && \
                chmod -R 755 /target
            " && success "Fixed via Docker" || warning "Failed to fix $dir"
    done
    
    # Restart SQL Server
    echo -e "${YELLOW}Restarting SQL Server...${NC}"
    docker compose up -d mssql 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════
#  📊 Report Generation
# ═══════════════════════════════════════════════════════════

generate_report() {
    echo ""
    print_header "Health Check Summary"
    
    if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
        echo -e "${GREEN}✨ All checks passed! System is healthy.${NC}"
    else
        if [ $ISSUES_FOUND -gt 0 ]; then
            echo -e "${RED}❌ Issues found: $ISSUES_FOUND${NC}"
        fi
        
        if [ $WARNINGS_FOUND -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Warnings: $WARNINGS_FOUND${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Recommendations:${NC}"
        
        if [ $ISSUES_FOUND -gt 0 ]; then
            echo "  1. Run with --fix to attempt automatic repair"
            echo "  2. Or manually run: make sql-volumes-fix"
        fi
        
        if [ $WARNINGS_FOUND -gt 0 ]; then
            echo "  3. Review warnings above for potential issues"
        fi
    fi
    
    echo ""
}

# ═══════════════════════════════════════════════════════════
#  🎯 Main Execution
# ═══════════════════════════════════════════════════════════

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check     Run health checks only (default)"
    echo "  --fix       Run health checks and fix issues automatically"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Check health"
    echo "  $0 --fix           # Check and fix"
    echo "  make sql-diagnose  # Alternative via Makefile"
}

main() {
    # Parse arguments
    case "${1:-}" in
        --fix)
            AUTO_FIX=true
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        --check|"")
            AUTO_FIX=false
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    print_header "SQL Server Volume Health Check"
    
    if [ "$AUTO_FIX" = true ]; then
        echo -e "${YELLOW}🔧 Auto-fix mode enabled${NC}"
        echo ""
    fi
    
    # Run checks
    check_docker || true
    check_directories || true
    check_permissions || true
    check_disk_space || true
    check_container_status || true
    check_volume_mounts || true
    check_container_logs || true
    
    # Auto-fix if requested
    if [ "$AUTO_FIX" = true ] && [ $ISSUES_FOUND -gt 0 ]; then
        echo ""
        print_header "Auto-Fix"
        
        fix_directories
        fix_permissions
        
        echo ""
        echo -e "${CYAN}Re-running health checks...${NC}"
        echo ""
        
        # Reset counters
        ISSUES_FOUND=0
        WARNINGS_FOUND=0
        
        # Re-run checks
        check_directories || true
        check_permissions || true
    fi
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [ $ISSUES_FOUND -gt 0 ]; then
        exit 1
    fi
    
    exit 0
}

# Run main
main "$@"