#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🔧 Create Initial EF Core Migration - Improved Version
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
readonly HOST_MIGRATIONS_DIR="./aspnetcore/Migrations"
readonly MIGRATION_STAGE_IMAGE="rssnews-migration"
readonly DEFAULT_MIGRATION_NAME="InitialCreate"

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
  temp_containers=$(docker ps -a --format '{{.Names}}' | grep -E "migration-temp-[0-9]+$" || true)

  if [ -n "$temp_containers" ]; then
    log_step "Cleaning up temporary containers..."
    echo "$temp_containers" | xargs -r docker rm -f >/dev/null 2>&1 || true
  fi
}

print_header() {
  # [BUG FIX #1] ลบ clear ออก — การเรียก clear ใน get_migration_name() ผ่าน subshell
  # ทำให้ output ที่ capture ด้วย $(...) มี escape sequences ปนมาด้วย
  # ทำให้ migration_name ที่ได้มีขยะ เช่น "\033[H\033[2J" นำหน้า
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
# Migration Checks
# ───────────────────────────────────────────────────────────
is_first_migration() {
  [ ! -d "$HOST_MIGRATIONS_DIR" ] && return 0

  local cs_files
  cs_files=$(find "$HOST_MIGRATIONS_DIR" -name "*.cs" 2>/dev/null | wc -l)
  [ "$cs_files" -eq 0 ]
}

list_existing_migrations() {
  if [ -d "$HOST_MIGRATIONS_DIR" ]; then
    find "$HOST_MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  fi
}

# ───────────────────────────────────────────────────────────
# Docker Operations
# ───────────────────────────────────────────────────────────
build_migration_stage() {
  log_step "Building migration stage image..."

  if docker build \
    --target migration \
    -t "$MIGRATION_STAGE_IMAGE" \
    -f ./aspnetcore/Dockerfile \
    . >/dev/null 2>&1; then

    log_success "Migration stage built: $MIGRATION_STAGE_IMAGE"
  else
    error_exit "Failed to build migration stage"
  fi
}

create_migration_file() {
  local migration_name="$1"
  local temp_container="migration-temp-$$"

  log_step "Creating migration: $migration_name"

  # [BUG FIX #2] ต้องตรวจสอบ exit code ของ docker run แยกออกมา
  # เดิม: docker run ... 2>&1 แล้วตรวจสอบไฟล์ทีหลัง
  # ปัญหา: set -e ทำให้ script หยุดถ้า docker run fail แต่ error message จะไม่ชัดเจน
  # และถ้า docker run สำเร็จแต่ dotnet ef fail ภายใน, exit code จะถูกส่งออกมาด้วย
  # การใช้ if...then ป้องกัน set -e ไม่ให้ exit ก่อนที่เราจะแสดง error message ที่ดี
  if ! docker run --rm \
    --name "$temp_container" \
    -v "$(pwd)/aspnetcore/Migrations:/app/aspnetcore/Migrations" \
    -w /app/aspnetcore \
    "$MIGRATION_STAGE_IMAGE" \
    bash -c "dotnet restore rssnews.csproj && dotnet ef migrations add '$migration_name' \
      --project rssnews.csproj \
      --context RSSNewsDbContext \
      --output-dir Migrations \
      --verbose" 2>&1; then
    error_exit "docker run failed while creating migration '$migration_name'"
  fi

  # ตรวจสอบว่าไฟล์ถูกสร้างจริง
  if find "$HOST_MIGRATIONS_DIR" -name "*.cs" | grep -q .; then
    log_success "Migration '$migration_name' created"
  else
    error_exit "No migration files were generated!"
  fi
}

# ───────────────────────────────────────────────────────────
# User Interaction
# ───────────────────────────────────────────────────────────
get_migration_name() {
  # [BUG FIX #3] ฟังก์ชันนี้ถูกเรียกผ่าน subshell: migration_name=$(get_migration_name)
  # การใช้ read -p ใน subshell จะไม่สามารถรับ input จาก terminal ได้ถูกต้อง
  # เพราะ stdin ถูก pipe และ /dev/tty อาจไม่พร้อมใช้งาน
  # แก้โดย redirect input/output ไปที่ /dev/tty โดยตรง
  # และย้าย print_section ออกมา print ก่อน subshell เพื่อหลีกเลี่ยง clear ปน output

  local is_first=false
  local migration_name=""

  mkdir -p "$HOST_MIGRATIONS_DIR"

  if is_first_migration; then
    is_first=true
    log_success "No existing migrations detected" >&2
    log_step "Will create first migration: $DEFAULT_MIGRATION_NAME" >&2
    migration_name="$DEFAULT_MIGRATION_NAME"
  else
    log_warning "Existing migrations found:" >&2
    list_existing_migrations >&2
    echo "" >&2

    local reply
    # [BUG FIX #4] ใช้ /dev/tty สำหรับ read เพื่อให้รับ input ได้ใน subshell context
    read -r -p "Delete existing migrations and start fresh? [y/N]: " reply </dev/tty

    if [[ "$reply" =~ ^[Yy]$ ]]; then
      log_step "Removing old migrations..." >&2
      rm -rf "$HOST_MIGRATIONS_DIR"
      mkdir -p "$HOST_MIGRATIONS_DIR"
      migration_name="$DEFAULT_MIGRATION_NAME"
      log_success "Old migrations removed" >&2
    else
      read -r -p "Enter new migration name (or Enter to cancel): " migration_name </dev/tty

      if [ -z "$migration_name" ]; then
        log_warning "Cancelled by user" >&2
        exit 0
      fi
    fi
  fi

  # [BUG FIX #5] echo ค่า migration_name ไปยัง stdout เท่านั้น (ไม่มี log อื่นปน)
  # log ทุกอันข้างบนต้องใช้ >&2 เพื่อให้ไปที่ stderr แทน stdout
  echo "$migration_name"
}

# ───────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────
print_summary() {
  local migration_name="$1"

  print_section "Summary"

  echo ""
  log "${GREEN}✓${NC} Migration created: ${CYAN}$migration_name${NC}"
  echo ""
  log_step "Generated files:"

  if [ -d "$HOST_MIGRATIONS_DIR" ]; then
    find "$HOST_MIGRATIONS_DIR" -name "*.cs" -exec basename {} \; | sort | sed 's/^/  • /'
  else
    log_warning "No files found in $HOST_MIGRATIONS_DIR"
  fi

  echo ""
  print_section "Next Steps"
  echo ""
  log "${CYAN}1.${NC} Review files:     ${YELLOW}ls -lah $HOST_MIGRATIONS_DIR${NC}"
  log "${CYAN}2.${NC} Apply migration:  ${YELLOW}./quick-fix.sh${NC}"
  log "${CYAN}3.${NC} Commit changes:   ${YELLOW}git add aspnetcore/Migrations && git commit -m 'Add $migration_name'${NC}"
  echo ""
}

# ───────────────────────────────────────────────────────────
# Main Workflow
# ───────────────────────────────────────────────────────────
main() {
  # [BUG FIX #6] ย้าย print_header มาเรียกก่อน get_migration_name
  # เพราะ get_migration_name ถูกเรียกใน subshell และ print_header เรียก clear
  # ถ้า clear อยู่ใน subshell จะทำให้ terminal กระพริบแปลก ๆ
  print_header "🔧 Create Initial EF Core Migration"

  # Set up cleanup trap
  trap cleanup EXIT

  # Step 1: Get migration name (subshell — ต้องไม่มี clear หรือ log ปน stdout)
  print_section "Migration Configuration"
  local migration_name
  migration_name=$(get_migration_name)

  # [BUG FIX #7] ตรวจสอบว่า migration_name ไม่ว่างหลัง subshell
  # กรณี user กด Enter แล้ว exit 0 ใน subshell, migration_name จะว่าง
  if [ -z "$migration_name" ]; then
    log_warning "No migration name returned — exiting"
    exit 0
  fi

  log_success "Migration name: $migration_name"

  # Step 2: Build migration tools
  print_section "Building Migration Tools"
  build_migration_stage

  # Step 3: Create migration
  print_section "Creating Migration"
  create_migration_file "$migration_name"

  # Step 4: Summary
  echo ""
  print_summary "$migration_name"

  echo "═══════════════════════════════════════════════════════════"
  log "${GREEN}✅ Initial Migration Complete${NC}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
}

# ───────────────────────────────────────────────────────────
# Execute
# ───────────────────────────────────────────────────────────
main "$@"