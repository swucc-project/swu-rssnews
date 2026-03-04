# enable-ssl.ps1
# Setup SSL certificates for swu-rssnews project

param(
    [string]$SourcePath = "D:\docker-rss\ssl",
    [string]$DestPath = ".\ssl",
    [switch]$Validate,
    [switch]$GenerateSelfSigned
)

$ErrorActionPreference = "Stop"

# Colors
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$CYAN = "`e[36m"
$NC = "`e[0m"

Write-Host "${CYAN}🔒 SSL Certificate Setup${NC}`n"
Write-Host ("=" * 60)

# ✅ Function: Check if encryption.pem is a certificate or DH params
function Test-PemFileType {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return "notfound" }
    
    $content = Get-Content $FilePath -Raw
    
    if ($content -match "-----BEGIN CERTIFICATE-----") {
        return "certificate"
    }
    elseif ($content -match "-----BEGIN DH PARAMETERS-----") {
        return "dhparam"
    }
    elseif ($content -match "-----BEGIN .*PRIVATE KEY-----") {
        return "privatekey"
    }
    else {
        return "unknown"
    }
}

# Function: Copy SSL files
function Copy-SSLFiles {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    Write-Host "${CYAN}📋 Copying SSL files...${NC}"
    
    if (-not (Test-Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        Write-Host "  ${GREEN}✅ Created directory: $Destination${NC}"
    }
    
    try {
        Copy-Item -Path "$Source\*" -Destination $Destination -Force
        Write-Host "  ${GREEN}✅ Files copied successfully${NC}"
        
        Write-Host "`n${YELLOW}Copied files:${NC}"
        Get-ChildItem $Destination | ForEach-Object {
            Write-Host "  📄 $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)"
        }
        
        return $true
    }
    catch {
        Write-Host "  ${RED}❌ Copy failed: $_${NC}"
        return $false
    }
}

# Function: Rename to standard names
function Rename-SSLFiles {
    param([string]$Path)
    
    Write-Host "`n${CYAN}📝 Renaming files to standard names...${NC}"
    
    $renames = @{
        "private.key" = "cert.key"
        "rss.crt"     = "cert.crt"
    }
    
    foreach ($old in $renames.Keys) {
        $new = $renames[$old]
        $oldPath = Join-Path $Path $old
        $newPath = Join-Path $Path $new
        
        if (Test-Path $oldPath) {
            if (Test-Path $newPath) {
                Write-Host "  ${YELLOW}⚠️  $new already exists, skipping${NC}"
            }
            else {
                Rename-Item -Path $oldPath -NewName $new
                Write-Host "  ${GREEN}✅ Renamed: $old → $new${NC}"
            }
        }
    }
}

# ✅ Function: Handle encryption.pem intelligently
function Initialize-EncryptionPem {
    param([string]$Path)
    
    $encryptionPath = Join-Path $Path "encryption.pem"
    
    if (-not (Test-Path $encryptionPath)) {
        Write-Host "`n${YELLOW}ℹ️  encryption.pem not found${NC}"
        return $false
    }
    
    Write-Host "`n${CYAN}🔍 Analyzing encryption.pem...${NC}"
    
    $fileType = Test-PemFileType -FilePath $encryptionPath
    
    switch ($fileType) {
        "certificate" {
            Write-Host "  ${GREEN}✅ encryption.pem is an intermediate certificate${NC}"
            
            # สร้าง fullchain.crt
            $certPath = Join-Path $Path "cert.crt"
            $fullchainPath = Join-Path $Path "fullchain.crt"
            
            if (Test-Path $certPath) {
                $cert = Get-Content $certPath -Raw
                $intermediate = Get-Content $encryptionPath -Raw
                
                $fullchain = $cert.TrimEnd() + "`n" + $intermediate.TrimEnd()
                Set-Content -Path $fullchainPath -Value $fullchain -NoNewline
                
                Write-Host "  ${GREEN}✅ Created fullchain.crt${NC}"
                Write-Host "  ${CYAN}💡 Update nginx to use: ssl_certificate /etc/nginx/ssl/rssnews/fullchain.crt;${NC}"
                return $true
            }
        }
        "dhparam" {
            Write-Host "  ${YELLOW}⚠️  encryption.pem is DH Parameters (for key exchange)${NC}"
            Write-Host "  ${CYAN}💡 Use in nginx: ssl_dhparam /etc/nginx/ssl/rssnews/encryption.pem;${NC}"
            return $false
        }
        "privatekey" {
            Write-Host "  ${RED}❌ encryption.pem contains a PRIVATE KEY - should not be named 'encryption'${NC}"
            Write-Host "  ${YELLOW}💡 Rename it to cert.key if this is your certificate key${NC}"
            return $false
        }
        "unknown" {
            Write-Host "  ${YELLOW}⚠️  Cannot determine encryption.pem type${NC}"
            Write-Host "  ${CYAN}File content preview:${NC}"
            Get-Content $encryptionPath -First 5 | ForEach-Object { Write-Host "    $_" }
            return $false
        }
        default {
            Write-Host "  ${RED}❌ encryption.pem not found${NC}"
            return $false
        }
    }
}

# Main execution
try {
    if ($GenerateSelfSigned) {
        Write-Host "${CYAN}🔧 Generating self-signed certificate...${NC}"
        Write-Host "${YELLOW}⚠️  Not implemented in this script${NC}"
        Write-Host "${CYAN}Use: mkcert -install && mkcert localhost 127.0.0.1${NC}"
        exit 1
    }
    
    # Validate source
    if (-not (Test-Path $SourcePath)) {
        Write-Host "${RED}❌ Source path not found: $SourcePath${NC}"
        exit 1
    }
    
    # Copy files
    if (-not (Copy-SSLFiles -Source $SourcePath -Destination $DestPath)) {
        exit 1
    }
    
    # Rename to standard names
    Rename-SSLFiles -Path $DestPath
    
    # ✅ Handle encryption.pem
    $hasFullchain = Initialize-EncryptionPem -Path $DestPath

    if (-not $hasFullchain) {
        # Fallback: If no intermediate chain, use cert.crt as fullchain.crt
        Copy-Item -Path "$DestPath\cert.crt" -Destination "$DestPath\fullchain.crt" -Force
        Write-Host "  ${YELLOW}⚠️  No intermediate certificate found.${NC}"
        Write-Host "  ${GREEN}✅ Created fullchain.crt using cert.crt (Leaf only)${NC}"
        $hasFullchain = $true
    }
    
    # Show final file structure
    Write-Host "`n${CYAN}📂 Final SSL file structure:${NC}"
    Get-ChildItem $DestPath | ForEach-Object {
        $icon = switch -Wildcard ($_.Name) {
            "*.key" { "🔑" }
            "*.crt" { "📜" }
            "*.pem" { "📋" }
            default { "📄" }
        }
        Write-Host "  $icon $($_.Name)"
    }
    
    Write-Host "`n$('=' * 60)" -ForegroundColor Green
    Write-Host "${GREEN}✅ SSL Setup Complete!${NC}"
    Write-Host "$('=' * 60)" -ForegroundColor Green
    
    Write-Host "`n${YELLOW}Next Steps:${NC}"
    Write-Host "  1. Update web.conf with correct certificate paths"
    
    if ($hasFullchain) {
        Write-Host "     ${CYAN}ssl_certificate /etc/nginx/ssl/rssnews/fullchain.crt;${NC}"
    }
    else {
        Write-Host "     ${CYAN}ssl_certificate /etc/nginx/ssl/rssnews/cert.crt;${NC}"
    }
    
    Write-Host "     ${CYAN}ssl_certificate_key /etc/nginx/ssl/rssnews/cert.key;${NC}"
    Write-Host "  2. Restart nginx: ${CYAN}docker-compose restart web-server${NC}"
    Write-Host "  3. Test HTTPS: ${CYAN}https://localhost${NC}"
    Write-Host ""
}
catch {
    Write-Host "`n${RED}❌ Error: $_${NC}"
    exit 1
}