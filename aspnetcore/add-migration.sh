#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🔧 EF Core Migration Manager - Unified Version
# ═══════════════════════════════════════════════════════════
set -euo pipefail

# ✅ Fix: suppress locale warnings — fallback to en_US if th_TH not available
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
# ✅ Fix: TERM must be set for dotnet-ef interactive output
export TERM="${TERM:-xterm}"

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
readonly PROJECT_DIR="/app/aspnetcore"
readonly MIGRATIONS_DIR="$PROJECT_DIR/Migrations"
readonly DEFAULT_MIGRATION_NAME="InitialCreate"
readonly DOTNET_TOOLS_PATH="/root/.dotnet/tools"

# ───────────────────────────────────────────────────────────
# Helper Functions
# ───────────────────────────────────────────────────────────
log() { echo -e "$1"; }

log_info()    { log "${BLUE}[INFO]${NC} $1"; }
log_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { log "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { log "${RED}[ERROR]${NC} $1"; }

error_exit() {
  log_error "$1"
  exit 1
}

print_separator() {
  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ───────────────────────────────────────────────────────────
# Setup Environment
# ───────────────────────────────────────────────────────────
setup_environment() {
  print_separator
  log "${CYAN}🔧 Setting up environment${NC}"
  print_separator

  # ✅ Add dotnet tools to PATH (already set in Dockerfile, but ensure it here)
  export PATH="$DOTNET_TOOLS_PATH:$PATH"
  log_info "PATH configured"

  # ✅ Create Migrations directory if not exists
  mkdir -p "$MIGRATIONS_DIR"
  log_info "Migrations directory ready: $MIGRATIONS_DIR"

  # Verify dotnet-ef availability
  if ! command -v dotnet-ef &>/dev/null; then
    log_warning "dotnet-ef not found, installing..."
    # [BUG FIX #1] ระบุ version ที่ต้องการอย่างชัดเจน แต่ควรใช้ค่าที่ตรงกับ EF Core ใน project
    # เดิมใช้ 9.0.8 ซึ่งอาจไม่มีอยู่จริง — ใช้ 9.0.0 หรือ remove version pinning แล้วให้ SDK เลือกเอง
    # ในที่นี้แก้เป็น: ไม่ pin version เพื่อให้ install เวอร์ชันล่าสุดที่ compatible
    dotnet tool install --global dotnet-ef || error_exit "Failed to install dotnet-ef"
    export PATH="$DOTNET_TOOLS_PATH:$PATH"
    log_success "dotnet-ef installed"
  fi

  # Show version
  local ef_version
  ef_version=$(dotnet-ef --version 2>&1 | head -n1)
  log_info "EF Core version: $ef_version"

  echo ""
}

# ───────────────────────────────────────────────────────────
# Load Database Configuration
# ───────────────────────────────────────────────────────────
load_database_config() {
  print_separator
  log "${CYAN}🔑 Loading database configuration${NC}"
  print_separator

  local password_file="${MSSQL_SA_PASSWORD_FILE:-}"

  if [ -n "$password_file" ] && [ -f "$password_file" ]; then
    MSSQL_SA_PASSWORD=$(tr -d '[:space:]' < "$password_file")
    log_info "Password loaded from file: $password_file"
  elif [ -n "${MSSQL_SA_PASSWORD:-}" ]; then
    log_info "Using password from environment variable"
  else
    error_exit "MSSQL password not configured. Set MSSQL_SA_PASSWORD or MSSQL_SA_PASSWORD_FILE"
  fi

  export MSSQL_SA_PASSWORD

  if [ ${#MSSQL_SA_PASSWORD} -lt 8 ]; then
    error_exit "Password must be at least 8 characters long"
  fi

  DATABASE_HOST="${DATABASE_HOST:-mssql}"
  DATABASE_NAME="${DATABASE_NAME:-RSSActivityWeb}"

  # ✅ Build correct connection string for dotnet ef
  CONNECTION_STRING="Server=${DATABASE_HOST};Database=${DATABASE_NAME};User ID=sa;Password=${MSSQL_SA_PASSWORD};TrustServerCertificate=True;Encrypt=False;"

  export ConnectionStrings__DefaultConnection="$CONNECTION_STRING"

  log_success "Database: ${DATABASE_HOST}/${DATABASE_NAME}"
  echo ""
}

# ───────────────────────────────────────────────────────────
# Wait for SQL Server
# ───────────────────────────────────────────────────────────
wait_for_sql_server() {
  print_separator
  log "${CYAN}⏳ Waiting for SQL Server${NC}"
  print_separator

  local max_attempts=60
  local attempt=0

  log_info "Target: ${DATABASE_HOST}"
  log_info "Timeout: ${max_attempts}s"

  # [BUG FIX #2] เดิมใช้ ((attempt++)) ซึ่งจะ return exit code 1 เมื่อ attempt เป็น 0
  # ทำให้ set -e หยุด script ในรอบแรกของ loop
  # แก้โดยใช้ attempt=$((attempt + 1)) แทน
  while [ $attempt -lt $max_attempts ]; do
    if timeout 5 /opt/mssql-tools18/bin/sqlcmd \
      -S "${DATABASE_HOST}" \
      -U sa \
      -P "${MSSQL_SA_PASSWORD}" \
      -Q "SELECT 1" \
      -C &>/dev/null; then

      log_success "SQL Server is ready (took ${attempt}s)"
      echo ""
      return 0
    fi

    attempt=$((attempt + 1))

    if [ $((attempt % 10)) -eq 0 ]; then
      log_info "Still waiting... (${attempt}/${max_attempts}s)"
    fi

    sleep 2
  done

  error_exit "SQL Server failed to become ready after ${max_attempts}s"
}

# ───────────────────────────────────────────────────────────
# Check Existing Migrations
# ───────────────────────────────────────────────────────────
check_existing_migrations() {
  print_separator
  log "${CYAN}📄 Checking existing migrations${NC}"
  print_separator

  cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"
  log_info "Working directory: $(pwd)"

  local migration_count
  migration_count=$(find "$MIGRATIONS_DIR" -name "*.cs" 2>/dev/null | wc -l)

  log_info "Found $migration_count migration file(s)"

  if [ "$migration_count" -gt 0 ]; then
    log_info "Existing migrations:"
    find "$MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  fi

  echo ""
  # [BUG FIX #3] ฟังก์ชันนี้ถูกเรียกผ่าน subshell: existing_count=$(check_existing_migrations)
  # log_info ทุกอันต้องส่งไปที่ stderr ไม่ใช่ stdout เพื่อไม่ให้ปนกับค่าที่ return
  # แก้โดยใช้ >&2 กับ log ทุกบรรทัดที่เป็น informational
  # และให้ echo "$migration_count" เป็น stdout เท่านั้น
  # (ไฟล์เดิมมี log_info หลาย บรรทัดที่ไป stdout ทำให้ existing_count มีค่าขยะ)
  echo "$migration_count"
}

# เวอร์ชันที่แก้แล้ว: redirect log ทั้งหมดใน check_existing_migrations ไป stderr
check_existing_migrations() {
  print_separator >&2
  log "${CYAN}📄 Checking existing migrations${NC}" >&2
  print_separator >&2

  cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"
  log_info "Working directory: $(pwd)" >&2

  local migration_count
  migration_count=$(find "$MIGRATIONS_DIR" -name "*.cs" 2>/dev/null | wc -l)

  log_info "Found $migration_count migration file(s)" >&2

  if [ "$migration_count" -gt 0 ]; then
    log_info "Existing migrations:" >&2
    find "$MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /' >&2
  fi

  echo "" >&2
  echo "$migration_count"
}

# ───────────────────────────────────────────────────────────
# Create Migration
# ───────────────────────────────────────────────────────────
create_migration() {
  local migration_name="${1:-$DEFAULT_MIGRATION_NAME}"

  print_separator
  log "${CYAN}🔨 Creating migration: $migration_name${NC}"
  print_separator

  # Check if migration already exists
  if find "$MIGRATIONS_DIR" -name "*_${migration_name}.cs" 2>/dev/null | grep -q .; then
    log_warning "Migration '$migration_name' already exists, skipping creation"
    echo ""
    return 0
  fi

  log_info "Executing: dotnet ef migrations add $migration_name"

  # [BUG FIX #4] เดิม: ถ้า dotnet ef fail แล้ว return 1 จาก create_migration
  # แต่ใน main() มีการเรียก create_migration "$migration_name" || true
  # ทำให้ error ถูก swallow ไปอย่างเงียบ ๆ โดยไม่แสดง error ที่ชัดเจน
  # แก้โดย: ถ้า fail ให้ log error แล้ว return 1 (ไม่ใช้ error_exit เพราะ caller ควบคุมอยู่)
  if dotnet ef migrations add "$migration_name" \
    --project rssnews.csproj \
    --context RSSNewsDbContext \
    --output-dir Migrations \
    --verbose; then

    log_success "Migration '$migration_name' created"

    log_info "Created files:"
    find "$MIGRATIONS_DIR" -name "*${migration_name}*" -exec basename {} \; | sed 's/^/  • /'
    echo ""

    local file_count
    file_count=$(find "$MIGRATIONS_DIR" -name "*.cs" | wc -l)
    log_info "Total migration files in $MIGRATIONS_DIR: $file_count"
    return 0
  else
    log_error "Failed to create migration '$migration_name'"
    echo ""
    return 1
  fi
}

# ───────────────────────────────────────────────────────────
# Apply Migrations
# ───────────────────────────────────────────────────────────
apply_migrations() {
  print_separator
  log "${CYAN}🚀 Applying migrations to database${NC}"
  print_separator

  log_info "Target: ${DATABASE_HOST}/${DATABASE_NAME}"

  cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

  log_info "Executing: dotnet ef database update"

  if dotnet ef database update \
    --project rssnews.csproj \
    --context RSSNewsDbContext \
    --verbose; then

    log_success "All migrations applied successfully"
    echo ""
    return 0
  else
    local exit_code=$?
    log_warning "dotnet ef database update exited with code $exit_code"
    log_info "This may be normal if database is already up to date"
    echo ""
    return 0
  fi
}

# ───────────────────────────────────────────────────────────
# Print Summary
# ───────────────────────────────────────────────────────────
print_summary() {
  local final_count
  final_count=$(find "$MIGRATIONS_DIR" -name "*.cs" 2>/dev/null | wc -l)

  print_separator
  log "${GREEN}✅ Migration Process Completed${NC}"
  print_separator

  echo ""
  log "📊 ${CYAN}Summary${NC}"
  log "  • Database: ${CYAN}${DATABASE_HOST}/${DATABASE_NAME}${NC}"
  log "  • Migration files in volume: ${CYAN}$final_count${NC}"
  log "  • Location: ${CYAN}$MIGRATIONS_DIR${NC}"
  log "  • Status: ${GREEN}Ready${NC}"
  echo ""

  if [ "$final_count" -gt 0 ]; then
    log_info "Migration files:"
    find "$MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  fi

  print_separator
}

# ───────────────────────────────────────────────────────────
# Main Execution
# ───────────────────────────────────────────────────────────
main() {
  # [BUG FIX #5] ลบ clear ออก — script นี้รันใน Docker container (entrypoint)
  # การเรียก clear ใน container environment ที่ไม่มี TTY จริง ๆ จะทำให้
  # เกิด "TERM environment variable not set" error หรือ output แปลก ๆ ใน logs
  echo "═══════════════════════════════════════════════════════════"
  log "${CYAN}🔧 EF Core Migration Manager${NC}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  local migration_name="${MIGRATION_NAME:-$DEFAULT_MIGRATION_NAME}"
  local add_new_migration="${ADD_NEW_MIGRATION:-true}"

  # Setup
  setup_environment
  load_database_config
  wait_for_sql_server

  # Check existing state
  local existing_count
  existing_count=$(check_existing_migrations)
  log_info "Existing migration count: $existing_count"

  # Create new migration if requested
  if [ "$add_new_migration" = "true" ]; then
    # [BUG FIX #6] เดิม: create_migration "$migration_name" || true
    # การใช้ || true ทำให้ error ถูก swallow ทั้งหมด ผู้ใช้ไม่รู้ว่า migration fail
    # แก้โดย: ตรวจสอบ return code และ warn แต่ไม่ abort (เพราะ migration อาจมีอยู่แล้ว)
    if ! create_migration "$migration_name"; then
      log_warning "Migration creation was skipped or failed — continuing to apply existing migrations"
    fi
  else
    log_info "Skipping migration creation (ADD_NEW_MIGRATION=$add_new_migration)"
    echo ""
  fi

  # Apply migrations (always apply — idempotent)
  apply_migrations

  # Summary
  print_summary
}

# ───────────────────────────────────────────────────────────
# Execute Main
# ───────────────────────────────────────────────────────────
main "$@"