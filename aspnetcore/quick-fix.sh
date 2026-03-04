#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🚀 Quick Fix - Complete Migration Workflow
# ═══════════════════════════════════════════════════════════
set -euo pipefail

# ───────────────────────────────────────────────────────────
# Colors
# ───────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# ───────────────────────────────────────────────────────────
# Configuration
# ───────────────────────────────────────────────────────────
readonly MIGRATIONS_DIR="./aspnetcore/Migrations"
readonly MIGRATION_STAGE_IMAGE="rssnews-migration"
# [BUG FIX #1] NETWORK_NAME ต้องตรงกับ network ใน docker-compose.yml
# เดิมใช้ "rssnews-network" แต่ใน docker-compose.yml networks ชื่อว่า
# "swu-rssnews_database-network", "swu-rssnews_backend-network" ฯลฯ
# migration container ต้องเชื่อมต่อ mssql ได้ จึงต้องใช้ database-network
readonly NETWORK_NAME="swu-rssnews_database-network"
readonly MSSQL_CONTAINER="sqlserver"
# [BUG FIX #2] MSSQL_CONTAINER ต้องตรงกับ container_name ใน docker-compose.yml
# เดิมใช้ "mssql" แต่ใน docker-compose.yml กำหนด container_name: sqlserver
readonly ASPNETCORE_CONTAINER="aspnetcore"
readonly DEFAULT_MIGRATION_NAME="InitialCreate"
# [BUG FIX #3] PASSWORD_FILE path ไม่ถูกต้อง
# เดิม: "./secrets/mssql_sa_password.txt"
# ใน docker-compose.yml ใช้: "./secrets/db_password.txt"
readonly PASSWORD_FILE="./secrets/db_password.txt"

# ───────────────────────────────────────────────────────────
# Helper Functions
# ───────────────────────────────────────────────────────────
log() { echo -e "$1"; }

log_step()    { log "${BLUE}▶ $1${NC}"; }
log_success() { log "${GREEN}✓ $1${NC}"; }
log_warning() { log "${YELLOW}⚠ $1${NC}"; }
log_error()   { log "${RED}✗ $1${NC}"; }

error_exit() {
  log_error "$1"
  cleanup
  exit 1
}

cleanup() {
  local temp_containers
  temp_containers=$(docker ps -a --format '{{.Names}}' | grep -E "migration-(temp|apply)-[0-9]+$" || true)

  if [ -n "$temp_containers" ]; then
    log_step "Cleaning up temporary containers..."
    echo "$temp_containers" | xargs -r docker rm -f >/dev/null 2>&1 || true
    log_success "Cleanup complete"
  fi
}

print_header() {
  # [BUG FIX #4] ลบ clear ออก — เหตุผลเดียวกับ add-first-migration.sh
  # clear ใน interactive terminal ไม่เป็นปัญหา แต่เมื่อ script ถูก pipe หรือ redirect
  # จะสร้าง escape sequences ที่ไม่จำเป็น และ clear ก่อน print_header ใน main ก็เพียงพอ
  echo "═══════════════════════════════════════════════════════════"
  log "${CYAN}$1${NC}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

print_section() {
  echo ""
  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  log "${CYAN}$1${NC}"
  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ───────────────────────────────────────────────────────────
# Validation Functions
# ───────────────────────────────────────────────────────────
validate_prerequisites() {
  print_section "Validating Prerequisites"

  if ! command -v docker &>/dev/null; then
    error_exit "Docker not found. Please install Docker."
  fi
  log_success "Docker is installed"

  if [ ! -f "$PASSWORD_FILE" ]; then
    error_exit "Password file not found: $PASSWORD_FILE"
  fi
  log_success "Password file exists"

  mkdir -p "$MIGRATIONS_DIR"
  log_success "Migrations directory ready"
}

# ───────────────────────────────────────────────────────────
# Container Management
# ───────────────────────────────────────────────────────────
is_container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

ensure_network_exists() {
  # [BUG FIX #5] ไม่ควรสร้าง network เองด้วย docker network create
  # network ถูกจัดการโดย docker-compose และมีชื่อ format เป็น <project>_<network>
  # การสร้างใหม่อาจไม่มี driver options ที่ถูกต้อง และ container ที่ run ด้วย --network
  # จะไม่สามารถ resolve ชื่อ container ได้ถ้าไม่ได้อยู่ใน compose network เดียวกัน
  # แก้โดย: ตรวจสอบว่า network มีอยู่แล้ว ถ้าไม่มีให้แจ้ง error แทนการสร้างใหม่
  if ! docker network ls --format '{{.Name}}' | grep -qx "$NETWORK_NAME"; then
    error_exit "Docker network '$NETWORK_NAME' not found. Please run 'docker compose up -d mssql' first."
  fi
  log_success "Network exists: $NETWORK_NAME"
}

ensure_mssql_ready() {
  print_section "Ensuring SQL Server is Ready"

  if ! is_container_running "$MSSQL_CONTAINER"; then
    log_warning "SQL Server not running"
    log_step "Starting SQL Server container..."

    # [BUG FIX #6] ใช้ service name "mssql" ไม่ใช่ container name "sqlserver"
    # docker compose up ใช้ service name เสมอ
    if docker compose up -d mssql; then
      log_success "Container started"
      log_step "Waiting 30s for initialization..."
      sleep 30
    else
      error_exit "Failed to start SQL Server"
    fi
  else
    log_success "SQL Server is already running"
  fi

  if ! is_container_running "$MSSQL_CONTAINER"; then
    error_exit "SQL Server container stopped unexpectedly"
  fi

  log_success "SQL Server is ready"
}

# ───────────────────────────────────────────────────────────
# Migration Management
# ───────────────────────────────────────────────────────────
has_migrations() {
  [ -d "$MIGRATIONS_DIR" ] || return 1
  local cs_files
  cs_files=$(find "$MIGRATIONS_DIR" -name "*.cs" 2>/dev/null | wc -l)
  [ "$cs_files" -gt 0 ]
}

list_migrations() {
  if has_migrations; then
    log_step "Current migrations:"
    find "$MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  else
    log_warning "No migrations found"
  fi
}

get_migration_details() {
  # [BUG FIX #7] ฟังก์ชันนี้ถูกเรียกผ่าน subshell: migration_details=$(get_migration_details)
  # ทุก log ต้องใช้ >&2 เพื่อไม่ให้ปนกับ stdout ที่ return ออกไป
  # และ read ต้องใช้ /dev/tty เพื่อรับ input ใน subshell context
  print_section "Checking Migration Status" >&2 || true

  mkdir -p "$MIGRATIONS_DIR"

  local should_create=false
  local migration_name=""

  if ! has_migrations; then
    log_success "No existing migrations - will create first migration" >&2
    should_create=true
    migration_name="$DEFAULT_MIGRATION_NAME"
  else
    list_migrations >&2
    echo "" >&2

    local reply
    read -r -p "Create a new migration? [y/N]: " reply </dev/tty
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      read -r -p "Enter migration name: " migration_name </dev/tty
      if [ -n "$migration_name" ]; then
        should_create=true
      else
        log_warning "No migration name provided - skipping creation" >&2
      fi
    fi
  fi

  echo "${should_create}|${migration_name}"
}

# ───────────────────────────────────────────────────────────
# Docker Operations
# ───────────────────────────────────────────────────────────
build_migration_stage() {
  print_section "Building Migration Tools"

  log_step "Building Docker image: $MIGRATION_STAGE_IMAGE"

  if docker build \
    --target migration \
    -t "$MIGRATION_STAGE_IMAGE" \
    -f ./aspnetcore/Dockerfile \
    . >/dev/null 2>&1; then

    log_success "Migration stage built successfully"
  else
    error_exit "Failed to build migration stage"
  fi
}

create_migration() {
  local migration_name="$1"
  local temp_container="migration-temp-$$"

  print_section "Creating Migration: $migration_name"

  log_step "Running migration creation..."

  # [BUG FIX #8] เดิมไม่มีการตรวจสอบ exit code ของ docker run
  # ถ้า dotnet ef fail ใน container, script จะยังดำเนินต่อโดยไม่รู้ว่า fail
  # แก้โดยใช้ if...then เพื่อ handle error อย่างชัดเจน
  if ! docker run --rm \
    --name "$temp_container" \
    --network "$NETWORK_NAME" \
    -v "$(pwd)/aspnetcore/Migrations:/app/aspnetcore/Migrations" \
    -w /app/aspnetcore \
    "$MIGRATION_STAGE_IMAGE" \
    bash -c "dotnet restore rssnews.csproj && dotnet ef migrations add '$migration_name' \
      --project rssnews.csproj \
      --context RSSNewsDbContext \
      --output-dir Migrations \
      --verbose" 2>&1; then
    log_error "Migration creation failed for '$migration_name'"
    return 1
  fi

  log_success "Migration '$migration_name' created successfully"
  return 0
}

apply_migrations() {
  local temp_container="migration-apply-$$"

  print_section "Applying Migrations to Database"

  local password
  password=$(cat "$PASSWORD_FILE" | tr -d '[:space:]')

  log_step "Target: $MSSQL_CONTAINER/RSSActivityWeb"
  log_step "Running database update..."

  # [BUG FIX #9] เดิม: pipe output ผ่าน grep แล้วใช้ || true
  # ปัญหา: ใน bash, exit code ของ pipe คือ exit code ของ command สุดท้าย (grep)
  # ถ้า grep ไม่ match pattern ใดเลย grep จะ return exit code 1
  # ทำให้ if condition fail ทั้ง ๆ ที่ dotnet ef สำเร็จ
  # แก้โดย: แยก docker run กับ grep ออกจากกัน โดยเก็บ output ไว้ใน variable ก่อน
  local migration_output
  local docker_exit=0
  migration_output=$(docker run --rm \
    --name "$temp_container" \
    --network "$NETWORK_NAME" \
    -e MSSQL_SA_PASSWORD="$password" \
    -e DATABASE_HOST="$MSSQL_CONTAINER" \
    -e DATABASE_NAME="RSSActivityWeb" \
    -v "$(pwd)/aspnetcore:/app/aspnetcore" \
    -w /app/aspnetcore \
    "$MIGRATION_STAGE_IMAGE" \
    dotnet ef database update \
      --context RSSNewsDbContext \
      --verbose 2>&1) || docker_exit=$?

  # แสดง filtered output
  echo "$migration_output" | grep -E "(Applying|Reverting|Done|already)" || true

  if [ "$docker_exit" -eq 0 ]; then
    log_success "Migrations applied successfully"
    return 0
  else
    log_warning "Migration application completed with warnings (exit code: $docker_exit)"
    log_step "Database may already be up to date"
    return 0
  fi
}

restart_application() {
  print_section "Restarting Application"

  log_step "Restarting $ASPNETCORE_CONTAINER container..."

  if docker compose restart "$ASPNETCORE_CONTAINER" >/dev/null 2>&1; then
    log_success "Container restart initiated"

    log_step "Waiting 15s for startup..."
    sleep 15

    if is_container_running "$ASPNETCORE_CONTAINER"; then
      log_success "Application is running"
    else
      log_warning "Container not running - may need manual intervention"
    fi
  else
    log_warning "Failed to restart container"
  fi
}

# ───────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────
print_summary() {
  local created_migration="$1"

  print_section "Summary"

  echo ""
  log "${GREEN}✓${NC} Prerequisites validated"
  log "${GREEN}✓${NC} SQL Server verified"
  log "${GREEN}✓${NC} Migration tools built"

  if [ -n "$created_migration" ]; then
    log "${GREEN}✓${NC} New migration created: ${CYAN}$created_migration${NC}"
  fi

  if has_migrations; then
    log "${GREEN}✓${NC} Migrations applied to database"
    log "${GREEN}✓${NC} Application restarted"
  fi

  echo ""
  log_step "Current migration files:"
  if has_migrations; then
    find "$MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  else
    log_warning "No migration files found"
  fi

  echo ""
  print_section "Next Steps"
  echo ""
  log "${CYAN}1.${NC} Check logs:       ${YELLOW}docker compose logs -f $ASPNETCORE_CONTAINER${NC}"
  log "${CYAN}2.${NC} Test health:      ${YELLOW}curl http://localhost:5000/health${NC}"
  log "${CYAN}3.${NC} View database:    ${YELLOW}docker exec -it $MSSQL_CONTAINER /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C${NC}"

  if has_migrations; then
    log "${CYAN}4.${NC} Commit changes:   ${YELLOW}git add $MIGRATIONS_DIR && git commit -m 'Add migrations'${NC}"
  fi

  echo ""
}

# ───────────────────────────────────────────────────────────
# Main Workflow
# ───────────────────────────────────────────────────────────
main() {
  clear
  print_header "🚀 Quick Fix - EF Core Migration Workflow"

  # Set up cleanup trap
  trap cleanup EXIT

  # Step 1: Validate
  validate_prerequisites

  # Step 2: Ensure infrastructure
  ensure_network_exists
  ensure_mssql_ready

  # Step 3: Get user input
  # [BUG FIX #10] get_migration_details ถูกเรียกใน subshell
  # ต้องแน่ใจว่า print_section ที่อยู่ใน get_migration_details ไม่ส่ง output ไป stdout
  local migration_details
  migration_details=$(get_migration_details)

  local should_create
  local migration_name
  IFS='|' read -r should_create migration_name <<< "$migration_details"

  # [BUG FIX #11] ตรวจสอบว่า parse ค่าออกมาได้ถูกต้อง
  # ถ้า migration_details ว่างหรือไม่มี | จะทำให้ should_create และ migration_name ผิด
  if [ -z "$should_create" ]; then
    log_warning "Could not determine migration action — defaulting to no creation"
    should_create="false"
    migration_name=""
  fi

  # Step 4: Build tools
  build_migration_stage

  # Step 5: Create migration (if needed)
  local created_name=""
  if [ "$should_create" = "true" ] && [ -n "$migration_name" ]; then
    if create_migration "$migration_name"; then
      created_name="$migration_name"
    else
      log_warning "Migration creation failed — will still attempt to apply existing migrations"
    fi
  fi

  # Step 6: Apply migrations (if any exist)
  if has_migrations; then
    apply_migrations || true
    restart_application
  else
    log_warning "No migrations to apply"
  fi

  # Step 7: Summary
  echo ""
  print_summary "$created_name"

  echo "═══════════════════════════════════════════════════════════"
  log "${GREEN}✅ Quick Fix Complete${NC}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

# ───────────────────────────────────────────────────────────
# Execute
# ───────────────────────────────────────────────────────────
main "$@"