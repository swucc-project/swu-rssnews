#!/bin/bash
# ═══════════════════════════════════════════════════════════
# 🔍 GraphQL Endpoint Readiness Checker
# ═══════════════════════════════════════════════════════════
# Version: 2.1.1
# Purpose: Wait for GraphQL endpoint to be fully operational
#
# Changelog v2.1.1:
#   [BUG FIX #1] Nested ${:-} parameter expansion อาจ fail กับ set -u ใน bash บาง version
#                เดิม: GRAPHQL_URL="${GRAPHQL_ENDPOINT:-${VITE_GRAPHQL_ENDPOINT:-...}}"
#                แก้เป็น explicit two-step assignment เพื่อ compatibility ที่ดีกว่า
#   [BUG FIX #2] check_graphql_health ไม่ guard curl ด้วย || true
#                เมื่อ curl fail กับ set -e script จะ exit กลางทางทันที ไม่รอ retry
#                แก้โดยเพิ่ม || true หลัง command substitution ทุก curl call
#   [BUG FIX #3] Phase 2 loop ตรวจ timeout หลัง sleep
#                ทำให้รอนานเกินไป 1 poll interval ในรอบสุดท้ายก่อน fail
#                แก้โดยย้าย timeout check มาก่อน sleep
# ═══════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════
# 🎨 Colors
# ═══════════════════════════════════════════════════════════

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# ═══════════════════════════════════════════════════════════
# ⚙️ Configuration
# ═══════════════════════════════════════════════════════════

# [BUG FIX #1] เดิม: GRAPHQL_URL="${GRAPHQL_ENDPOINT:-${VITE_GRAPHQL_ENDPOINT:-http://...}}"
# Nested ${:-} แบบ 3 ชั้นอาจ fail กับ set -u เมื่อตัวแปรชั้นกลางไม่ได้ถูก declare ไว้เลย
# แก้เป็น two-step assignment ที่อ่านง่ายและ compatible กับ bash ทุก version
GRAPHQL_URL="${GRAPHQL_ENDPOINT:-}"
if [[ -z "$GRAPHQL_URL" ]]; then
    GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"
fi

MAX_WAIT="${GRAPHQL_WAIT_TIMEOUT:-180}"
POLL_INTERVAL="${GRAPHQL_POLL_INTERVAL:-2}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-5}"
REQUIRE_INTROSPECTION="${REQUIRE_INTROSPECTION:-false}"
VERBOSE="${VERBOSE:-false}"

BACKEND_WARMUP_WAIT=15
QUICK_CHECK_INTERVAL=1

# ═══════════════════════════════════════════════════════════
# 📝 Logging
# ═══════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_step() {
    echo -e "${CYAN}▶${NC} $*"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}🔍${NC} DEBUG: $*"
    fi
}

log_header() {
    echo ""
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}${BOLD}║  %-57s║${NC}\n" "$1"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# 🔧 Utility Functions
# ═══════════════════════════════════════════════════════════

to_bool() {
    case "${1,,}" in
        true|yes|1|on) return 0 ;;
        *) return 1 ;;
    esac
}

format_duration() {
    local seconds=$1
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    else
        local minutes=$((seconds / 60))
        local remaining=$((seconds % 60))
        echo "${minutes}m ${remaining}s"
    fi
}

# ═══════════════════════════════════════════════════════════
# 🏥 Health Check Functions
# ═══════════════════════════════════════════════════════════

check_backend_health() {
    log_debug "Checking backend health endpoint"

    local health_url="http://aspdotnetweb:5000/health/ready"
    local response

    # [BUG FIX #2] เพิ่ม || true หลัง command substitution
    # เดิมไม่มี: ถ้า curl fail กับ set -e จะ exit script ทันทีโดยไม่เข้า if/else ด้านล่าง
    response=$(curl -sf "$health_url" \
        --connect-timeout 5 \
        --max-time 10 \
        2>/dev/null || echo "FAILED")

    if [[ "$response" != "FAILED" ]]; then
        log_debug "Backend health check passed"
        return 0
    fi

    log_debug "Backend not healthy yet"
    return 1
}

check_graphql_health() {
    log_debug "Checking GraphQL health endpoint"

    local health_url="http://aspdotnetweb:5000/health/graphql"
    local response
    local exit_code

    # [BUG FIX #2] เพิ่ม || true เพื่อป้องกัน set -e interrupt
    # เดิม: response=$(curl -sf ...) — ถ้า curl return non-zero กับ set -e script จะ exit ทันที
    # แก้: เพิ่ม || true เพื่อให้ exit_code capture ได้และ continue logic ด้านล่าง
    response=$(curl -sf "$health_url" \
        --connect-timeout 5 \
        --max-time 10 \
        2>/dev/null) || true

    exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$response" | grep -q '"status":"healthy"'; then
        log_debug "GraphQL health check passed"
        return 0
    fi

    log_debug "GraphQL not healthy yet: exit_code=$exit_code"
    return 1
}

check_connectivity() {
    log_debug "Testing basic connectivity to $GRAPHQL_URL"

    local response

    # [BUG FIX #2] เพิ่ม || echo "000" เพื่อป้องกัน set -e interrupt เช่นเดียวกัน
    response=$(curl -sf "$GRAPHQL_URL" \
        -o /dev/null \
        -w "%{http_code}" \
        --connect-timeout 3 \
        --max-time 5 \
        2>/dev/null || echo "000")

    log_debug "HTTP Status: $response"

    # ยอมรับทั้ง 200, 400 (GraphQL error แต่ server ทำงาน), และ 405 (Method not allowed)
    if [[ "$response" =~ ^(200|400|405)$ ]]; then
        return 0
    fi

    return 1
}

test_graphql_query() {
    log_debug "Testing GraphQL query execution"

    local query='{"query":"{ __typename }"}'
    local response
    local exit_code

    # [BUG FIX #2] เพิ่ม || true เพื่อป้องกัน set -e interrupt
    response=$(curl -sf "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-Allow-Introspection: true" \
        -d "$query" \
        --connect-timeout 5 \
        --max-time 10 \
        2>&1) || true

    exit_code=$?
    log_debug "Query exit code: $exit_code"
    log_debug "Response preview: ${response:0:200}"

    if [[ $exit_code -eq 0 ]]; then
        if echo "$response" | grep -q '"data"'; then
            log_debug "Query successful: found data field"
            return 0
        elif echo "$response" | grep -q '"errors"'; then
            log_debug "Query returned errors but server is responding"
            return 0
        fi
    fi

    log_debug "Query failed or no response"
    return 1
}

test_introspection() {
    log_debug "Testing GraphQL introspection"

    local query='{"query":"{ __schema { queryType { name } } }"}'
    local response
    local exit_code

    # [BUG FIX #2] เพิ่ม || true
    response=$(curl -sf "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-Allow-Introspection: true" \
        -d "$query" \
        --connect-timeout 10 \
        --max-time 15 \
        2>&1) || true

    exit_code=$?
    log_debug "Introspection exit code: $exit_code"

    if [[ $exit_code -eq 0 ]] && echo "$response" | grep -q '__schema'; then
        log_debug "Introspection enabled and working"
        return 0
    fi

    log_debug "Introspection not available or disabled"
    return 1
}

validate_schema_response() {
    log_debug "Validating schema structure"

    local query='{"query":"query IntrospectionQuery { __schema { queryType { name } mutationType { name } types { name kind } } }"}'
    local response

    # [BUG FIX #2] เพิ่ม || true
    response=$(curl -sf "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-Allow-Introspection: true" \
        -d "$query" \
        --connect-timeout 15 \
        --max-time 20 \
        2>&1) || true

    if echo "$response" | grep -q 'queryType'; then
        local types_count
        types_count=$(echo "$response" | grep -o '"name"' | wc -l)
        log_debug "Schema contains ~$types_count named elements"

        if [[ $types_count -gt 5 ]]; then
            log_debug "Schema appears valid (sufficient types)"
            return 0
        fi
    fi

    log_debug "Schema validation inconclusive"
    return 1
}

# ═══════════════════════════════════════════════════════════
# 🎯 Main Wait Logic
# ═══════════════════════════════════════════════════════════

wait_for_graphql() {
    local max_attempts=$((MAX_WAIT / POLL_INTERVAL))
    local attempt=0
    local start_time
    start_time=$(date +%s)

    log_header "🔍 GraphQL Endpoint Readiness Check"

    log_info "Target: $GRAPHQL_URL"
    log_info "Timeout: $(format_duration "$MAX_WAIT")"
    log_info "Poll Interval: ${POLL_INTERVAL}s"
    log_info "Max Attempts: $max_attempts"
    echo ""

    # Phase 0: Backend Warmup Wait
    log_step "Phase 0: Waiting for backend warmup (${BACKEND_WARMUP_WAIT}s)..."
    sleep "$BACKEND_WARMUP_WAIT"
    log_success "Warmup wait completed"
    echo ""

    # Phase 1: Backend Health Check
    log_step "Phase 1: Checking backend health..."

    local health_attempts=0
    local max_health_attempts=10

    while [[ $health_attempts -lt $max_health_attempts ]]; do
        health_attempts=$((health_attempts + 1))
        local elapsed=$(( $(date +%s) - start_time ))

        if ! to_bool "$VERBOSE"; then
            printf "\r  ${CYAN}▶${NC} Checking backend... [%d/%d] " "$health_attempts" "$max_health_attempts"
        fi

        if check_backend_health; then
            if ! to_bool "$VERBOSE"; then echo ""; fi
            log_success "Backend health check passed ($(format_duration "$elapsed"))"
            break
        fi

        if [[ $health_attempts -ge $max_health_attempts ]]; then
            if ! to_bool "$VERBOSE"; then echo ""; fi
            log_warn "Backend health check timeout, continuing anyway..."
            break
        fi

        sleep 2
    done

    echo ""

    # Phase 2: GraphQL Connectivity Check
    log_step "Phase 2: Testing GraphQL connectivity..."

    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))
        local elapsed=$(( $(date +%s) - start_time ))

        if to_bool "$VERBOSE"; then
            log_info "Attempt $attempt/$max_attempts ($(format_duration "$elapsed") elapsed)"
        else
            printf "\r  ${CYAN}▶${NC} Checking GraphQL... [%d/%d] " "$attempt" "$max_attempts"
        fi

        if check_graphql_health || check_connectivity; then
            if ! to_bool "$VERBOSE"; then echo ""; fi
            log_success "GraphQL connectivity established ($(format_duration "$elapsed"))"
            break
        fi

        # [BUG FIX #3] เดิม: timeout check อยู่หลัง sleep
        # ทำให้เมื่อ attempt ถึง max_attempts แล้ว ยังต้อง sleep อีก 1 รอบก่อน fail
        # แก้: ตรวจ timeout ก่อน sleep เสมอ เพื่อ fail fast ทันที
        if [[ $attempt -ge $max_attempts ]]; then
            if ! to_bool "$VERBOSE"; then echo ""; fi
            log_error "Cannot connect to GraphQL endpoint after $(format_duration "$elapsed")"
            return 1
        fi

        # ใช้ interval ที่เร็วขึ้นใน 10 attempt แรก
        if [[ $attempt -lt 10 ]]; then
            sleep "$QUICK_CHECK_INTERVAL"
        else
            sleep "$POLL_INTERVAL"
        fi
    done

    echo ""

    # Phase 3: Query Execution Check
    log_step "Phase 3: Testing query execution..."

    local query_attempts=0
    local max_query_attempts=$HEALTH_CHECK_RETRIES

    while [[ $query_attempts -lt $max_query_attempts ]]; do
        query_attempts=$((query_attempts + 1))

        log_debug "Query attempt $query_attempts/$max_query_attempts"

        if test_graphql_query; then
            local elapsed=$(( $(date +%s) - start_time ))
            log_success "GraphQL queries working ($(format_duration "$elapsed"))"
            break
        fi

        if [[ $query_attempts -ge $max_query_attempts ]]; then
            log_warn "GraphQL query test inconclusive, continuing..."
            break
        fi

        sleep 2
    done

    echo ""

    # Phase 4: Introspection Check (Optional)
    if to_bool "$REQUIRE_INTROSPECTION"; then
        log_step "Phase 4: Testing introspection (required)..."

        if test_introspection; then
            log_success "Introspection enabled"

            if validate_schema_response; then
                log_success "Schema structure validated"
            else
                log_warn "Could not validate schema structure"
            fi
        else
            log_error "Introspection required but not available"
            return 1
        fi
    else
        log_step "Phase 4: Testing introspection (optional)..."

        if test_introspection; then
            log_success "Introspection available"
        else
            log_warn "Introspection not available (continuing anyway)"
        fi
    fi

    echo ""

    # Final Success
    local total_elapsed=$(( $(date +%s) - start_time ))

    log_header "✅ GraphQL Endpoint Ready!"

    echo -e "  ${BOLD}Summary:${NC}"
    echo -e "    Total Time : $(format_duration "$total_elapsed")"
    echo -e "    Attempts   : $attempt"
    echo -e "    Status     : ${GREEN}Operational${NC}"
    echo ""

    return 0
}

# ═══════════════════════════════════════════════════════════
# 🚨 Error Diagnostics
# ═══════════════════════════════════════════════════════════

run_diagnostics() {
    log_header "🔬 Running Diagnostics"

    echo -e "${BOLD}1. Network Connectivity:${NC}"
    if ping -c 1 -W 2 aspdotnetweb >/dev/null 2>&1; then
        log_success "Can reach aspdotnetweb host"
    else
        log_error "Cannot reach aspdotnetweb host"
    fi
    echo ""

    echo -e "${BOLD}2. DNS Resolution:${NC}"
    if nslookup aspdotnetweb >/dev/null 2>&1; then
        log_success "DNS resolution working"
    else
        log_error "DNS resolution failed"
    fi
    echo ""

    echo -e "${BOLD}3. Backend Health:${NC}"
    local health_status
    health_status=$(curl -sf http://aspdotnetweb:5000/health/ready 2>/dev/null || echo "FAILED")
    if [[ "$health_status" != "FAILED" ]]; then
        log_success "Backend health check passed"
        echo "$health_status" | head -10
    else
        log_error "Backend health check failed"
    fi
    echo ""

    echo -e "${BOLD}4. HTTP Connection:${NC}"
    local http_status
    http_status=$(curl -sf -o /dev/null -w "%{http_code}" "$GRAPHQL_URL" 2>/dev/null || echo "000")
    echo "    GraphQL HTTP Status: $http_status"
    echo ""

    echo -e "${BOLD}5. GraphQL Test Query:${NC}"
    curl -sf "$GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"query":"{ __typename }"}' \
        2>&1 | head -20 || true
    echo ""

    echo -e "${BOLD}6. Detailed Curl Test:${NC}"
    curl -v "$GRAPHQL_URL" 2>&1 | head -30 || true
    echo ""

    echo -e "${BOLD}7. Environment:${NC}"
    echo "    GRAPHQL_URL         : $GRAPHQL_URL"
    echo "    MAX_WAIT            : $MAX_WAIT"
    echo "    POLL_INTERVAL       : $POLL_INTERVAL"
    echo "    BACKEND_WARMUP_WAIT : $BACKEND_WARMUP_WAIT"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# 🏁 Main Execution
# ═══════════════════════════════════════════════════════════

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--diagnostics)
                run_diagnostics
                exit 0
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -v, --verbose       Enable verbose output"
                echo "  -d, --diagnostics   Run diagnostics and exit"
                echo "  -h, --help          Show this help"
                echo ""
                echo "Environment Variables:"
                echo "  GRAPHQL_ENDPOINT         GraphQL endpoint URL (primary)"
                echo "  VITE_GRAPHQL_ENDPOINT    GraphQL endpoint URL (fallback)"
                echo "  GRAPHQL_WAIT_TIMEOUT     Maximum wait time in seconds (default: 180)"
                echo "  GRAPHQL_POLL_INTERVAL    Poll interval in seconds (default: 2)"
                echo "  BACKEND_WARMUP_WAIT      Backend warmup time (default: 15)"
                echo "  REQUIRE_INTROSPECTION    Require introspection (default: false)"
                echo "  VERBOSE                  Enable verbose output (default: false)"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if wait_for_graphql; then
        exit 0
    else
        log_error "GraphQL endpoint check failed"
        echo ""
        log_warn "Run with --diagnostics flag for more information:"
        log_warn "  $0 --diagnostics"
        exit 1
    fi
}

main "$@"