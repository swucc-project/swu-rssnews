#!/usr/bin/env bash
set -euo pipefail

: "${DEBUG:-DEBUG}"
: "${INFO:=INFO}"
: "${WARN:=WARN}"
: "${ERROR:=ERROR}"

log_debug() {
  echo "[$DEBUG] $*"
}

log_info() {
  echo "[$INFO] $*"
}

log_warn() {
  echo "[$WARN] $*"
}

log_error() {
  echo "[$ERROR] $*" >&2
}

# Prevent multiple sourcing
[[ -n "${__LOGGING_LIB_LOADED__:-}" ]] && return 0
__LOGGING_LIB_LOADED__=1

# ═══════════════════════════════════════════════════════════
# Color Definitions
# ═══════════════════════════════════════════════════════════

# Check if terminal supports colors
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly NC='\033[0m'  # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly MAGENTA=''
    readonly NC=''
fi

# ═══════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════

# ✅ FIXED: เพิ่ม default values และ quote variables properly
# Log level (DEBUG=0, INFO=1, WARN=2, ERROR=3)
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"

# Map log level names to numbers
declare -A LOG_LEVEL_MAP=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

init_logging() {
  CURRENT_LOG_LEVEL=$(get_log_level_num "${LOG_LEVEL}")
}

# Get numeric log level
get_log_level_num() {

    if [[ -n "${LOG_LEVEL_MAP[$level]:-}"  ]]; then
        echo "${LOG_LEVEL_MAP[$level]}"
    else
        echo "1"
    fi
}

# ✅ FIXED: เพิ่ม quotes รอบตัวแปร
CURRENT_LOG_LEVEL=$(get_log_level_num "${LOG_LEVEL}")

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

# Get timestamp if enabled
_get_timestamp() {
    if [[ "${LOG_TIMESTAMP:-true}" == "true" ]]; then
        date '+%Y-%m-%d %H:%M:%S'
    fi
}

# Write to log file if configured
_write_to_file() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$1" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Check if we should log at this level
_should_log() {
    local level="${1:-INFO}"
    local level_num=$(get_log_level_num "$level")
    [[ $level_num -ge ${CURRENT_LOG_LEVEL:-1} ]]
}

# ═══════════════════════════════════════════════════════════
# Core Logging Functions
# ═══════════════════════════════════════════════════════════

log_debug() {
    if ! _should_log "DEBUG"; then return 0; fi
    
    local msg="$1"
    local timestamp=$(_get_timestamp)
    local output="${CYAN}[DEBUG]${NC}"
    
    [[ -n "$timestamp" ]] && output="$output ${timestamp} -"
    output="$output $msg"
    
    echo -e "$output"
    _write_to_file "[DEBUG] ${timestamp:-} - $msg"
}

log_info() {
    if ! _should_log "INFO"; then return 0; fi
    
    local msg="$1"
    local timestamp=$(_get_timestamp)
    local output="${BLUE}ℹ️  [INFO]${NC}"
    
    [[ -n "$timestamp" ]] && output="$output ${timestamp} -"
    output="$output $msg"
    
    echo -e "$output"
    _write_to_file "[INFO] ${timestamp:-} - $msg"
}

log_success() {
    if ! _should_log "INFO"; then return 0; fi
    
    local msg="$1"
    local timestamp=$(_get_timestamp)
    local output="${GREEN}✅ [SUCCESS]${NC}"
    
    [[ -n "$timestamp" ]] && output="$output ${timestamp} -"
    output="$output $msg"
    
    echo -e "$output"
    _write_to_file "[SUCCESS] ${timestamp:-} - $msg"
}

log_warn() {
    if ! _should_log "WARN"; then return 0; fi
    
    local msg="$1"
    local timestamp=$(_get_timestamp)
    local output="${YELLOW}⚠️  [WARN]${NC}"
    
    [[ -n "$timestamp" ]] && output="$output ${timestamp} -"
    output="$output $msg"
    
    echo -e "$output" >&2
    _write_to_file "[WARN] ${timestamp:-} - $msg"
}

log_error() {
    if ! _should_log "ERROR"; then return 0; fi
    
    local msg="$1"
    local timestamp=$(_get_timestamp)
    local output="${RED}❌ [ERROR]${NC}"
    
    [[ -n "$timestamp" ]] && output="$output ${timestamp} -"
    output="$output $msg"
    
    echo -e "$output" >&2
    _write_to_file "[ERROR] ${timestamp:-} - $msg"
}

# ═══════════════════════════════════════════════════════════
# Specialized Logging Functions
# ═══════════════════════════════════════════════════════════

log_step() {
    local msg="$1"
    echo -e "\n${BLUE}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} $msg"
    echo -e "${BLUE}└─────────────────────────────────────────────────────┘${NC}"
    _write_to_file "[STEP] $msg"
}

log_header() {
    local msg="$1"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $msg${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    _write_to_file "[HEADER] $msg"
}

log_section() {
    local msg="$1"
    echo -e "${BLUE}━━━ $msg ━━━${NC}"
    echo ""
    _write_to_file "[SECTION] $msg"
}

# ═══════════════════════════════════════════════════════════
# Progress Functions
# ═══════════════════════════════════════════════════════════

# Simple spinner for long operations
log_spinner() {
    local pid=$1
    local msg="${2:-Processing...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % ${#spin} ))
        printf "\r${CYAN}${spin:$i:1}${NC} $msg"
        sleep 0.1
    done
    
    printf "\r"
}

# Progress bar
log_progress() {
    local current=$1
    local total=$2
    local msg="${3:-}"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    local bar=$(printf '%*s' "$filled" | tr ' ' '█')
    bar="${bar}$(printf '%*s' "$empty" | tr ' ' '░')"
    
    printf "\r${CYAN}[%s]${NC} %3d%% %s" "$bar" "$percent" "$msg"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════

# Log command execution
log_command() {
    local cmd="$1"
    log_debug "Executing: $cmd"
    
    if eval "$cmd" 2>&1 | while IFS= read -r line; do
        log_debug "  | $line"
    done; then
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code $exit_code: $cmd"
        return $exit_code
    fi
}

# Log with indent
log_indent() {
    local level="${1:-INFO}"
    local indent="${2:-0}"
    local msg="${3:-}"
    
    local spaces=$(printf '%*s' "$indent" '')
    
    case "$level" in
        DEBUG)   log_debug "${spaces}$msg" ;;
        INFO)    log_info "${spaces}$msg" ;;
        SUCCESS) log_success "${spaces}$msg" ;;
        WARN)    log_warn "${spaces}$msg" ;;
        ERROR)   log_error "${spaces}$msg" ;;
        *)       echo "${spaces}$msg" ;;
    esac
}

# ═══════════════════════════════════════════════════════════
# Context Management
# ═══════════════════════════════════════════════════════════

declare -a LOG_CONTEXT_STACK=()

log_push_context() {
    LOG_CONTEXT_STACK+=("$1")
}

log_pop_context() {
    unset 'LOG_CONTEXT_STACK[-1]'
}

log_get_context() {
    local IFS="/"
    echo "${LOG_CONTEXT_STACK[*]}"
}

log_with_context() {
    local level="$1"
    local msg="$2"
    local context=$(log_get_context)
    
    if [[ -n "$context" ]]; then
        msg="[$context] $msg"
    fi
    
    case "$level" in
        DEBUG)   log_debug "$msg" ;;
        INFO)    log_info "$msg" ;;
        SUCCESS) log_success "$msg" ;;
        WARN)    log_warn "$msg" ;;
        ERROR)   log_error "$msg" ;;
    esac
}

# ═══════════════════════════════════════════════════════════
# Examples (commented out)
# ═══════════════════════════════════════════════════════════

: <<'EXAMPLE_USAGE'

#!/bin/bash
source ./lib/logging.sh
init_logging

# Basic usage
log_info "Application starting..."
log_success "Connected to database"
log_warn "Cache miss, using default"
log_error "Failed to load configuration"

# Headers and sections
log_header "System Initialization"
log_step "Step 1: Checking dependencies"
log_section "Database Setup"

# With context
log_push_context "init"
log_push_context "database"
log_with_context INFO "Connecting to PostgreSQL"
log_pop_context
log_pop_context

# Progress
for i in {1..100}; do
    log_progress $i 100 "Loading data..."
    sleep 0.1
done

# Spinner (for background process)
long_running_command &
pid=$!
log_spinner $pid "Processing large file..."
wait $pid

# Command logging
log_command "npm install --production"

# File logging
LOG_FILE="/var/log/myapp.log" log_info "This goes to file too"

EXAMPLE_USAGE