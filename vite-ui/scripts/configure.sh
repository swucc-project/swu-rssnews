#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Shared Configuration Library
# Usage: source /vite-ui/scripts/configure.sh
# ═══════════════════════════════════════════════════════════

# Prevent multiple sourcing
[[ -n "${__CONFIG_LIB_LOADED__:-}" ]] && return 0
__CONFIG_LIB_LOADED__=1

# Load logging if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/logging.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
else
    log_error() { echo "ERROR: $1" >&2; }
    log_warn() { echo "WARN: $1" >&2; }
    log_info() { echo "INFO: $1"; }
fi

# ═══════════════════════════════════════════════════════════
# Default Configuration Values
# ═══════════════════════════════════════════════════════════

# Backend configuration
export BACKEND_URL="${VITE_API_URL:-http://aspdotnetweb:5000}"
export GRAPHQL_URL="${VITE_GRAPHQL_ENDPOINT:-http://aspdotnetweb:5000/graphql}"

# Timeout configuration
export BACKEND_WAIT_TIMEOUT="${BACKEND_WAIT_TIMEOUT:-180}"
export GRAPHQL_WAIT_TIMEOUT="${GRAPHQL_WAIT_TIMEOUT:-120}"
export GRAPHQL_POLL_INTERVAL="${GRAPHQL_POLL_INTERVAL:-5}"
export ROVER_TIMEOUT="${ROVER_TIMEOUT:-45}"

# Feature flags
export WAIT_FOR_BACKEND="${WAIT_FOR_BACKEND:-true}"
export USE_PLACEHOLDER_ON_FAIL="${USE_PLACEHOLDER_ON_FAIL:-true}"
export CONTINUE_ON_FAIL="${CONTINUE_ON_GRAPHQL_FAIL:-true}"
export SKIP_CODEGEN="${SKIP_GRAPHQL_CODEGEN:-false}"

# Environment
export NODE_ENV="${NODE_ENV:-development}"
export VITE_DEV_SERVER_PORT="${VITE_DEV_SERVER_PORT:-5173}"

# Logging
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export LOG_FILE="${LOG_FILE:-}"
export LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"

# ═══════════════════════════════════════════════════════════
# Configuration Validation
# ═══════════════════════════════════════════════════════════

validate_url() {
    local url="$1"
    local name="$2"
    
    # Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "$name must start with http:// or https://"
        return 1
    fi
    
    return 0
}

validate_timeout() {
    local value="$1"
    local name="$2"
    
    # Check if numeric
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name must be a positive integer (got: $value)"
        return 1
    fi
    
    # Check reasonable range
    if [[ $value -lt 1 ]] || [[ $value -gt 3600 ]]; then
        log_error "$name must be between 1 and 3600 seconds (got: $value)"
        return 1
    fi
    
    return 0
}

validate_boolean() {
    local value="$1"
    local name="$2"
    
    case "${value,,}" in  # Convert to lowercase
        true|false|1|0|yes|no)
            return 0
            ;;
        *)
            log_error "$name must be true/false/yes/no/1/0 (got: $value)"
            return 1
            ;;
    esac
}

validate_log_level() {
    local level="${1^^}"  # Convert to uppercase
    
    case "$level" in
        DEBUG|INFO|WARN|ERROR)
            return 0
            ;;
        *)
            log_error "LOG_LEVEL must be DEBUG/INFO/WARN/ERROR (got: $level)"
            return 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════
# Main Configuration Validation
# ═══════════════════════════════════════════════════════════

validate_config() {
    local errors=0
    
    log_info "Validating configuration..."
    
    # Validate URLs
    validate_url "$BACKEND_URL" "BACKEND_URL" || ((errors++))
    validate_url "$GRAPHQL_URL" "GRAPHQL_URL" || ((errors++))
    
    # Validate timeouts
    validate_timeout "$BACKEND_WAIT_TIMEOUT" "BACKEND_WAIT_TIMEOUT" || ((errors++))
    validate_timeout "$GRAPHQL_WAIT_TIMEOUT" "GRAPHQL_WAIT_TIMEOUT" || ((errors++))
    validate_timeout "$GRAPHQL_POLL_INTERVAL" "GRAPHQL_POLL_INTERVAL" || ((errors++))
    validate_timeout "$ROVER_TIMEOUT" "ROVER_TIMEOUT" || ((errors++))
    
    # Validate booleans
    validate_boolean "$WAIT_FOR_BACKEND" "WAIT_FOR_BACKEND" || ((errors++))
    validate_boolean "$USE_PLACEHOLDER_ON_FAIL" "USE_PLACEHOLDER_ON_FAIL" || ((errors++))
    validate_boolean "$CONTINUE_ON_FAIL" "CONTINUE_ON_FAIL" || ((errors++))
    validate_boolean "$SKIP_CODEGEN" "SKIP_CODEGEN" || ((errors++))
    
    # Validate log level
    validate_log_level "$LOG_LEVEL" || ((errors++))
    
    # Validate environment
    case "$NODE_ENV" in
        development|production|test)
            ;;
        *)
            log_warn "NODE_ENV should be development/production/test (got: $NODE_ENV)"
            ;;
    esac
    
    # Validate port
    if [[ ! "$VITE_DEV_SERVER_PORT" =~ ^[0-9]+$ ]] || \
       [[ $VITE_DEV_SERVER_PORT -lt 1 ]] || \
       [[ $VITE_DEV_SERVER_PORT -gt 65535 ]]; then
        log_error "VITE_DEV_SERVER_PORT must be between 1 and 65535"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "Configuration validation passed"
        return 0
    else
        log_error "Configuration validation failed with $errors error(s)"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Configuration Display
# ═══════════════════════════════════════════════════════════

display_configuration() {
    echo ""
    log_info "Current Configuration:"
    echo "─────────────────────────────────────────────────────────"
    echo "  Environment:"
    echo "    NODE_ENV: $NODE_ENV"
    echo "    VITE_DEV_SERVER_PORT: $VITE_DEV_SERVER_PORT"
    echo ""
    echo "  Backend:"
    echo "    BACKEND_URL: $BACKEND_URL"
    echo "    GRAPHQL_URL: $GRAPHQL_URL"
    echo ""
    echo "  Timeouts:"
    echo "    BACKEND_WAIT_TIMEOUT: ${BACKEND_WAIT_TIMEOUT}s"
    echo "    GRAPHQL_WAIT_TIMEOUT: ${GRAPHQL_WAIT_TIMEOUT}s"
    echo "    GRAPHQL_POLL_INTERVAL: ${GRAPHQL_POLL_INTERVAL}s"
    echo "    ROVER_TIMEOUT: ${ROVER_TIMEOUT}s"
    echo ""
    echo "  Feature Flags:"
    echo "    WAIT_FOR_BACKEND: $WAIT_FOR_BACKEND"
    echo "    USE_PLACEHOLDER_ON_FAIL: $USE_PLACEHOLDER_ON_FAIL"
    echo "    CONTINUE_ON_FAIL: $CONTINUE_ON_FAIL"
    echo "    SKIP_CODEGEN: $SKIP_CODEGEN"
    echo ""
    echo "  Logging:"
    echo "    LOG_LEVEL: $LOG_LEVEL"
    echo "    LOG_FILE: ${LOG_FILE:-<none>}"
    echo "    LOG_TIMESTAMP: $LOG_TIMESTAMP"
    echo "─────────────────────────────────────────────────────────"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# Configuration Helpers
# ═══════════════════════════════════════════════════════════

# Convert boolean strings to actual boolean
to_bool() {
    case "${1,,}" in
        true|yes|1) return 0 ;;
        *) return 1 ;;
    esac
}

# Get configuration value with fallback
get_config() {
    local var_name="$1"
    local default="${2:-}"
    
    echo "${!var_name:-$default}"
}

# Set configuration value (for runtime changes)
set_config() {
    local var_name="$1"
    local value="$2"
    
    export "$var_name=$value"
    log_debug "Set $var_name=$value"
}

# ═══════════════════════════════════════════════════════════
# Environment-specific Configuration
# ═══════════════════════════════════════════════════════════

load_env_overrides() {
    local env="${1:-$NODE_ENV}"
    local env_file=".env.${env}"
    
    if [[ -f "$env_file" ]]; then
        log_info "Loading environment overrides from $env_file"
        
        # Source the env file in a subshell and export variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
            
            # Remove quotes from value
            value="${value%\"}"
            value="${value#\"}"
            
            export "$key=$value"
            log_debug "Loaded: $key=$value"
        done < "$env_file"
    else
        log_debug "No environment file found: $env_file"
    fi
}

# ═══════════════════════════════════════════════════════════
# Configuration Export
# ═══════════════════════════════════════════════════════════

export_config_to_json() {
    local output_file="${1:-/tmp/config.json}"
    
    cat > "$output_file" <<EOF
{
  "environment": {
    "NODE_ENV": "$NODE_ENV",
    "VITE_DEV_SERVER_PORT": $VITE_DEV_SERVER_PORT
  },
  "backend": {
    "BACKEND_URL": "$BACKEND_URL",
    "GRAPHQL_URL": "$GRAPHQL_URL"
  },
  "timeouts": {
    "BACKEND_WAIT_TIMEOUT": $BACKEND_WAIT_TIMEOUT,
    "GRAPHQL_WAIT_TIMEOUT": $GRAPHQL_WAIT_TIMEOUT,
    "GRAPHQL_POLL_INTERVAL": $GRAPHQL_POLL_INTERVAL,
    "ROVER_TIMEOUT": $ROVER_TIMEOUT
  },
  "features": {
    "WAIT_FOR_BACKEND": $(to_bool "$WAIT_FOR_BACKEND" && echo "true" || echo "false"),
    "USE_PLACEHOLDER_ON_FAIL": $(to_bool "$USE_PLACEHOLDER_ON_FAIL" && echo "true" || echo "false"),
    "CONTINUE_ON_FAIL": $(to_bool "$CONTINUE_ON_FAIL" && echo "true" || echo "false"),
    "SKIP_CODEGEN": $(to_bool "$SKIP_CODEGEN" && echo "true" || echo "false")
  },
  "logging": {
    "LOG_LEVEL": "$LOG_LEVEL",
    "LOG_FILE": "${LOG_FILE:-null}",
    "LOG_TIMESTAMP": $(to_bool "$LOG_TIMESTAMP" && echo "true" || echo "false")
  }
}
EOF
    
    log_info "Configuration exported to $output_file"
}

# ═══════════════════════════════════════════════════════════
# Auto-initialization
# ═══════════════════════════════════════════════════════════

# Load environment-specific overrides if available
load_env_overrides

# ═══════════════════════════════════════════════════════════
# Example Usage (commented out)
# ═══════════════════════════════════════════════════════════

: <<'EXAMPLE_USAGE'

#!/bin/bash
source ./lib/logging.sh
source ./lib/configure.sh

# Validate configuration
if ! validate_config; then
    log_error "Invalid configuration, exiting"
    exit 1
fi

# Display current configuration
display_configuration

# Use configuration values
log_info "Connecting to backend at $BACKEND_URL"

# Check boolean flags
if to_bool "$WAIT_FOR_BACKEND"; then
    log_info "Will wait for backend..."
fi

# Get config with fallback
retry_count=$(get_config "RETRY_COUNT" "3")

# Export to JSON for debugging
export_config_to_json "/tmp/current-config.json"

EXAMPLE_USAGE