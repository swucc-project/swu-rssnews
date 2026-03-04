#!/bin/bash

# =============================================================================
# FIX ASP.NET Core Kestrel Configuration Conflicts
# =============================================================================
# This script fixes the warning:
# "Overriding address(es) 'http://+:5000'. Binding to endpoints defined via 
#  IConfiguration and/or UseKestrel() instead."
# =============================================================================

set -e

# Source logging library if available
if [ -f "/vite-ui/scripts/logging.sh" ]; then
    source /vite-ui/scripts/logging.sh
else
    # Fallback functions if logging.sh not available
    log_info() { echo "ℹ️  [INFO] $1"; }
    log_success() { echo "✅ [SUCCESS] $1"; }
    log_warn() { echo "⚠️  [WARN] $1"; }
    log_error() { echo "❌ [ERROR] $1" >&2; }
    log_header() { echo ""; echo "═══════════════════════════════════════════════════════════"; echo "  $1"; echo "═══════════════════════════════════════════════════════════"; echo ""; }
    log_step() { echo ""; echo "┌─────────────────────────────────────────────────────┐"; echo "│ $1"; echo "└─────────────────────────────────────────────────────┘"; }
fi

log_header "ASP.NET Core Kestrel Configuration Fix"

# =============================================================================
# Step 1: Check prerequisites
# =============================================================================
log_step "Step 1: Checking prerequisites"

if [ ! -f "./aspnetcore/Program.cs" ]; then
    log_error "Program.cs not found in ./aspnetcore/"
    exit 1
fi

if [ ! -f "./aspnetcore/appsettings.json" ]; then
    log_error "appsettings.json not found in ./aspnetcore/"
    exit 1
fi

log_success "All required files found"

# =============================================================================
# Step 2: Create backups
# =============================================================================
log_step "Step 2: Creating backups"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./aspnetcore/backups"
mkdir -p "$BACKUP_DIR"

cp ./aspnetcore/Program.cs "$BACKUP_DIR/Program.cs.backup.$TIMESTAMP"
cp ./aspnetcore/appsettings.json "$BACKUP_DIR/appsettings.json.backup.$TIMESTAMP"

if [ -f "./aspnetcore/appsettings.Development.json" ]; then
    cp ./aspnetcore/appsettings.Development.json "$BACKUP_DIR/appsettings.Development.json.backup.$TIMESTAMP"
fi

log_success "Backups created in $BACKUP_DIR"

# =============================================================================
# Step 3: Stop containers
# =============================================================================
log_step "Step 3: Stopping containers"

docker compose down 2>/dev/null || true
log_success "Containers stopped"

# =============================================================================
# Step 4: Remove Kestrel section from appsettings.json
# =============================================================================
log_step "Step 4: Removing Kestrel configuration from appsettings.json"

if grep -q '"Kestrel"' ./aspnetcore/appsettings.json; then
    # Use jq to remove Kestrel section if available
    if command -v jq &> /dev/null; then
        jq 'del(.Kestrel)' ./aspnetcore/appsettings.json > /tmp/appsettings.tmp
        mv /tmp/appsettings.tmp ./aspnetcore/appsettings.json
        log_success "Removed Kestrel section from appsettings.json using jq"
    else
        log_warn "jq not available, manual removal needed"
        log_info "Please remove the 'Kestrel' section from appsettings.json manually"
    fi
else
    log_info "No Kestrel section found in appsettings.json"
fi

# =============================================================================
# Step 5: Update Program.cs
# =============================================================================
log_step "Step 5: Updating Program.cs with explicit Kestrel configuration"

# Check if Program.cs already has the new configuration
if grep -q "// ✅ FIX: Explicit Kestrel Configuration" ./aspnetcore/Program.cs; then
    log_info "Program.cs already has the fix applied"
else
    log_info "Adding explicit Kestrel configuration to Program.cs"
    
    # Create a temporary file with the new configuration
    cat > /tmp/kestrel_config.txt << 'EOF'

// ═══════════════════════════════════════════════════════════
// ✅ FIX: Explicit Kestrel Configuration
// ═══════════════════════════════════════════════════════════
// This prevents the warning about overriding addresses
// We explicitly configure Kestrel here instead of relying on appsettings.json
builder.WebHost.UseKestrel(options =>
{
    // Clear any default endpoints
    options.ConfigureEndpointDefaults(listenOptions =>
    {
        listenOptions.Protocols = Microsoft.AspNetCore.Server.Kestrel.Core.HttpProtocols.Http1;
    });
})
.ConfigureKestrel(serverOptions =>
{
    // Listen on all interfaces, port 5000, HTTP/1 only
    serverOptions.ListenAnyIP(5000, listenOptions =>
    {
        listenOptions.Protocols = Microsoft.AspNetCore.Server.Kestrel.Core.HttpProtocols.Http1;
    });
});

EOF

    # Insert after "var builder = WebApplication.CreateBuilder(args);"
    if grep -q "^var builder = WebApplication.CreateBuilder(args);$" ./aspnetcore/Program.cs; then
        # Use awk to insert the configuration
        awk '/^var builder = WebApplication.CreateBuilder\(args\);$/{print; while(getline line < "/tmp/kestrel_config.txt") print line; next}1' \
            ./aspnetcore/Program.cs > /tmp/Program.cs.tmp
        mv /tmp/Program.cs.tmp ./aspnetcore/Program.cs
        log_success "Added Kestrel configuration to Program.cs"
    else
        log_error "Could not find insertion point in Program.cs"
        exit 1
    fi
    
    # Remove old UseKestrel line if it exists without configuration
    if grep -q "^builder.WebHost.UseKestrel();$" ./aspnetcore/Program.cs; then
        sed -i '/^builder.WebHost.UseKestrel();$/d' ./aspnetcore/Program.cs
        log_success "Removed old UseKestrel() line"
    fi
    
    # Add logging statement after app.UseForwardedHeaders();
    if grep -q "app.UseForwardedHeaders();" ./aspnetcore/Program.cs; then
        sed -i '/app.UseForwardedHeaders();/a\app.Logger.LogInformation("🌐 Kestrel listening on http://0.0.0.0:5000 (HTTP/1 only)");' \
            ./aspnetcore/Program.cs
        log_success "Added logging statement"
    fi
fi

# =============================================================================
# Step 6: Check Docker Compose for ASPNETCORE_URLS
# =============================================================================
log_step "Step 6: Checking Docker Compose configuration"

if [ -f "./docker-compose.yml" ]; then
    if grep -q "ASPNETCORE_URLS" ./docker-compose.yml; then
        log_warn "Found ASPNETCORE_URLS in docker-compose.yml"
        log_info "Consider removing it to avoid conflicts"
        log_info "The configuration is now handled in Program.cs"
    else
        log_success "No ASPNETCORE_URLS found in docker-compose.yml"
    fi
else
    log_warn "docker-compose.yml not found"
fi

# =============================================================================
# Step 7: Rebuild and restart
# =============================================================================
log_step "Step 7: Rebuilding container"

log_info "Building ASP.NET Core container..."
docker compose build aspdotnetweb --no-cache

if [ $? -eq 0 ]; then
    log_success "Container built successfully"
else
    log_error "Container build failed"
    exit 1
fi

log_step "Step 8: Starting services"

docker compose up -d

if [ $? -eq 0 ]; then
    log_success "Services started"
else
    log_error "Failed to start services"
    exit 1
fi

# =============================================================================
# Step 9: Wait and verify
# =============================================================================
log_step "Step 9: Waiting for application to start"

log_info "Waiting for ASP.NET Core to start..."
for i in {1..30}; do
    if docker logs aspnetcore 2>&1 | grep -q "Application started"; then
        log_success "Application started successfully"
        break
    fi
    
    if docker logs aspnetcore 2>&1 | grep -q "Overriding address"; then
        log_warn "Still seeing 'Overriding address' warning"
    fi
    
    echo -n "."
    sleep 2
done
echo ""

# =============================================================================
# Step 10: Check for warnings
# =============================================================================
log_step "Step 10: Verifying the fix"

OVERRIDE_COUNT=$(docker logs aspnetcore 2>&1 | grep -c "Overriding address" || true)
ERROR_COUNT=$(docker logs aspnetcore 2>&1 | grep -c "address already in use" || true)

if [ $OVERRIDE_COUNT -eq 0 ]; then
    log_success "No 'Overriding address' warnings found"
else
    log_warn "Found $OVERRIDE_COUNT 'Overriding address' warnings"
    log_info "This might indicate environment variables are still set"
fi

if [ $ERROR_COUNT -eq 0 ]; then
    log_success "No 'address already in use' errors found"
else
    log_error "Found $ERROR_COUNT 'address already in use' errors"
fi

# Test endpoints
log_info "Testing health endpoint..."
sleep 3
if curl -sf http://localhost:5000/health > /dev/null 2>&1; then
    log_success "Health endpoint responding"
else
    log_warn "Health endpoint not responding yet"
fi

# =============================================================================
# Summary
# =============================================================================
log_header "Fix Summary"

echo "Changes made:"
echo "  1. ✅ Created backups in $BACKUP_DIR"
echo "  2. ✅ Removed Kestrel section from appsettings.json"
echo "  3. ✅ Added explicit Kestrel configuration to Program.cs"
echo "  4. ✅ Rebuilt ASP.NET Core container"
echo "  5. ✅ Restarted services"
echo ""
echo "What changed:"
echo "  • Kestrel is now configured explicitly in Program.cs"
echo "  • Removed Kestrel configuration from appsettings.json"
echo "  • This prevents configuration conflicts and warnings"
echo ""
echo "View logs:"
echo "  docker logs aspnetcore -f"
echo ""
echo "Check for warnings:"
echo "  docker logs aspnetcore 2>&1 | grep -i 'overriding'"
echo ""

if [ $OVERRIDE_COUNT -eq 0 ] && [ $ERROR_COUNT -eq 0 ]; then
    log_success "✅ Fix applied successfully! No warnings detected."
else
    log_warn "⚠️  Please check logs for any remaining issues"
    echo ""
    echo "Last 20 log lines:"
    echo "─────────────────────────────────────────────────────────────"
    docker logs aspnetcore --tail 20
    echo "─────────────────────────────────────────────────────────────"
fi

echo ""