# enable-ssl.ps1
# Setup SSL certificates for swu-rssnews project

param(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "D:\docker-rss\ssl",
    
    [Parameter(Mandatory=$false)]
    [string]$DestPath = ".\ssl",
    
    [Parameter(Mandatory=$false)]
    [switch]$Validate,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateSelfSigned
)

$ErrorActionPreference = "Stop"

# Colors
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$CYAN = "`e[36m"
$NC = "`e[0m"

Write-Host "${CYAN}🔐 SSL Certificate Setup${NC}`n"
Write-Host "=" * 60

# Function: Validate certificate files
function Test-CertificateFiles {
    param([string]$Path)
    
    Write-Host "${CYAN}🔍 Validating certificate files...${NC}"
    
    $requiredFiles = @{
        "Private Key" = @("*.key", "private.key")
        "Certificate" = @("*.crt", "*.pem", "rss.crt")
        "CSR" = @("*.csr", "rss.csr")
    }
    
    $valid = $true
    
    foreach ($type in $requiredFiles.Keys) {
        $patterns = $requiredFiles[$type]
        $found = $false
        
        foreach ($pattern in $patterns) {
            if (Test-Path (Join-Path $Path $pattern)) {
                Write-Host "  ${GREEN}✅ $type found: $pattern${NC}"
                $found = $true
                break
            }
        }
        
        if (-not $found -and $type -ne "CSR") {
            Write-Host "  ${RED}❌ $type not found${NC}"
            $valid = $false
        }
    }
    
    return $valid
}

# Function: Copy SSL files
function Copy-SSLFiles {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    Write-Host "${CYAN}📋 Copying SSL files...${NC}"
    
    # Create destination directory
    if (-not (Test-Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        Write-Host "  ${GREEN}✅ Created directory: $Destination${NC}"
    }
    
    # Copy files
    try {
        Copy-Item -Path "$Source\*" -Destination $Destination -Force
        Write-Host "  ${GREEN}✅ Files copied successfully${NC}"
        
        # List copied files
        Write-Host "`n${YELLOW}Copied files:${NC}"
        Get-ChildItem $Destination | ForEach-Object {
            Write-Host "  📄 $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)"
        }
        
        return $true
    } catch {
        Write-Host "  ${RED}❌ Copy failed: $_${NC}"
        return $false
    }
}

# Function: Rename files to standard names
function Rename-SSLFiles {
    param([string]$Path)
    
    Write-Host "`n${CYAN}🔄 Renaming files to standard names...${NC}"
    
    $renames = @{
        "private.key" = "cert.key"
        "rss.crt" = "cert.crt"
        "rss.csr" = "cert.csr"
    }
    
    foreach ($old in $renames.Keys) {
        $new = $renames[$old]
        $oldPath = Join-Path $Path $old
        $newPath = Join-Path $Path $new
        
        if (Test-Path $oldPath) {
            if (Test-Path $newPath) {
                Write-Host "  ${YELLOW}⚠️  $new already exists, skipping${NC}"
            } else {
                Rename-Item -Path $oldPath -NewName $new
                Write-Host "  ${GREEN}✅ Renamed: $old → $new${NC}"
            }
        }
    }
}

# Function: Validate certificate with OpenSSL (if available)
function Test-CertificateValidity {
    param([string]$Path)
    
    Write-Host "`n${CYAN}🔬 Validating certificate integrity...${NC}"
    
    $certFile = Get-ChildItem -Path $Path -Filter "*.crt" | Select-Object -First 1
    $keyFile = Get-ChildItem -Path $Path -Filter "*.key" | Select-Object -First 1
    
    if (-not $certFile -or -not $keyFile) {
        Write-Host "  ${YELLOW}⚠️  Certificate or key file not found${NC}"
        return
    }
    
    # Check if OpenSSL is available
    if (Get-Command openssl -ErrorAction SilentlyContinue) {
        Write-Host "  ${CYAN}Using OpenSSL for validation...${NC}"
        
        # Validate certificate
        Write-Host "`n  ${YELLOW}Certificate Info:${NC}"
        openssl x509 -in $certFile.FullName -text -noout | Select-String "Subject:|Issuer:|Not Before|Not After"
        
        # Validate key
        Write-Host "`n  ${YELLOW}Key Validation:${NC}"
        $certMD5 = openssl x509 -noout -modulus -in $certFile.FullName | openssl md5
        $keyMD5 = openssl rsa -noout -modulus -in $keyFile.FullName | openssl md5
        
        if ($certMD5 -eq $keyMD5) {
            Write-Host "  ${GREEN}✅ Certificate and key match${NC}"
        } else {
            Write-Host "  ${RED}❌ Certificate and key do NOT match${NC}"
        }
    } else {
        Write-Host "  ${YELLOW}⚠️  OpenSSL not found, skipping validation${NC}"
        Write-Host "  ${CYAN}Install OpenSSL for certificate validation${NC}"
    }
}

# Function: Generate self-signed certificate
function New-SelfSignedCertificate {
    param([string]$Path)
    
    Write-Host "`n${CYAN}🔧 Generating self-signed certificate...${NC}"
    
    if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
        Write-Host "${RED}❌ OpenSSL not found. Please install OpenSSL.${NC}"
        return $false
    }
    
    # Create directory
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    
    $certPath = Join-Path $Path "cert.crt"
    $keyPath = Join-Path $Path "cert.key"
    
    # Generate self-signed certificate
    $cmd = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 " +
           "-keyout `"$keyPath`" -out `"$certPath`" " +
           "-subj `"/C=TH/ST=Bangkok/L=Bangkok/O=SWU/OU=IT/CN=news.swu.ac.th`""
    
    Invoke-Expression $cmd
    
    if (Test-Path $certPath -and Test-Path $keyPath) {
        Write-Host "  ${GREEN}✅ Self-signed certificate generated${NC}"
        Write-Host "  ${YELLOW}⚠️  This is for DEVELOPMENT only!${NC}"
        return $true
    } else {
        Write-Host "  ${RED}❌ Certificate generation failed${NC}"
        return $false
    }
}

# Function: Update nginx configuration
function Update-NginxConfig {
    param([string]$SslPath)
    
    Write-Host "`n${CYAN}📝 Checking nginx configuration...${NC}"
    
    $nginxConfig = ".\host\web.conf"
    
    if (-not (Test-Path $nginxConfig)) {
        Write-Host "  ${YELLOW}⚠️  nginx config not found at: $nginxConfig${NC}"
        return
    }
    
    $content = Get-Content $nginxConfig -Raw
    
    # Expected SSL paths in container
    $expectedCertPath = "/etc/nginx/ssl/rssnews/cert.crt"
    $expectedKeyPath = "/etc/nginx/ssl/rssnews/cert.key"
    
    Write-Host "  ${YELLOW}Expected SSL paths in nginx:${NC}"
    Write-Host "    Certificate: $expectedCertPath"
    Write-Host "    Key: $expectedKeyPath"
    
    if ($content -match "ssl_certificate\s+([^;]+);") {
        Write-Host "  ${CYAN}Current: ssl_certificate $($matches)${NC}"
    }
    if ($content -match "ssl_certificate_key\s+([^;]+);") {
        Write-Host "  ${CYAN}Current: ssl_certificate_key $($matches)${NC}"
    }
    
    Write-Host "`n  ${GREEN}✅ Manual check required${NC}"
    Write-Host "  ${YELLOW}Make sure nginx config matches your certificate filenames${NC}"
}

# Function: Test nginx configuration
function Test-NginxConfig {
    Write-Host "`n${CYAN}🧪 Testing nginx configuration...${NC}"
    
    try {
        docker-compose exec web-server nginx -t 2>&1 | ForEach-Object {
            if ($_ -match "successful") {
                Write-Host "  ${GREEN}✅ nginx config is valid${NC}"
            } elseif ($_ -match "failed|error") {
                Write-Host "  ${RED}❌ nginx config error: $_${NC}"
            } else {
                Write-Host "  $_"
            }
        }
    } catch {
        Write-Host "  ${YELLOW}⚠️  Cannot test nginx (container not running?)${NC}"
    }
}

# Main execution
try {
    if ($GenerateSelfSigned) {
        # Generate self-signed certificate
        if (New-SelfSignedCertificate -Path $DestPath) {
            Update-NginxConfig -SslPath $DestPath
        }
    } else {
        # Validate source
        if (-not (Test-Path $SourcePath)) {
            Write-Host "${RED}❌ Source path not found: $SourcePath${NC}"
            exit 1
        }
        
        # Validate files in source
        if (-not (Test-CertificateFiles -Path $SourcePath)) {
            Write-Host "${RED}❌ Required certificate files not found${NC}"
            exit 1
        }
        
        # Copy files
        if (-not (Copy-SSLFiles -Source $SourcePath -Destination $DestPath)) {
            exit 1
        }
        
        # Rename to standard names
        Rename-SSLFiles -Path $DestPath
        
        # Validate certificate
        if ($Validate) {
            Test-CertificateValidity -Path $DestPath
        }
        
        # Update nginx config
        Update-NginxConfig -SslPath $DestPath
    }
    
    # Test nginx config
    Test-NginxConfig
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Green
    Write-Host "${GREEN}✅ SSL Setup Complete!${NC}"
    Write-Host "=" * 60 -ForegroundColor Green
    
    Write-Host "`n${YELLOW}Next Steps:${NC}"
    Write-Host "  1. Review nginx config: ${CYAN}.\host\web.conf${NC}"
    Write-Host "  2. Restart nginx: ${CYAN}docker-compose restart web-server${NC}"
    Write-Host "  3. Test HTTPS: ${CYAN}https://localhost${NC}"
    Write-Host ""
    
} catch {
    Write-Host "`n${RED}❌ Error: $_${NC}"
    exit 1
}