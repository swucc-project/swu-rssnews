#!/bin/bash
set -e

echo "🚀 Starting ASP.NET Core Application..."
echo "════════════════════════════════════════"

# ตั้งค่า Locale และ Timezone
export LANG=th_TH.UTF-8
export LC_ALL=th_TH.UTF-8
export TZ=Asia/Bangkok

echo "🌐 Locale: $LANG"
echo "🕐 Timezone: $TZ"

# ตรวจสอบและโหลด database password
echo ""
echo "🔐 Loading database credentials..."

if [ -z "$MSSQL_SA_PASSWORD" ]; then
  if [ -n "$MSSQL_SA_PASSWORD_FILE" ] && [ -f "$MSSQL_SA_PASSWORD_FILE" ]; then
    export MSSQL_SA_PASSWORD=$(cat "$MSSQL_SA_PASSWORD_FILE" | tr -d '\n' | tr -d '\r')
    echo "✅ Loaded password from secret file: $MSSQL_SA_PASSWORD_FILE"
  else
    echo "❌ ERROR: Password file not found at $MSSQL_SA_PASSWORD_FILE"
    exit 1
  fi
else
  echo "✅ Using password from environment variable"
fi

if [ -z "$MSSQL_SA_PASSWORD" ]; then
  echo "❌ ERROR: MSSQL_SA_PASSWORD is empty"
  exit 1
fi

echo "✅ Password loaded successfully (length: ${#MSSQL_SA_PASSWORD})"

# ตรวจสอบค่า environment variables
DATABASE_HOST=${DATABASE_HOST:-mssql}
DATABASE_NAME=${DATABASE_NAME:-RSSActivityWeb}

echo ""
echo "🗄️  Database Configuration:"
echo "   Host: $DATABASE_HOST"
echo "   Database: $DATABASE_NAME"
echo "   User: sa"

# รอให้ SQL Server พร้อม
echo ""
echo "⏳ Waiting for SQL Server to be ready..."
echo "────────────────────────────────────────"

max_attempts=60
attempt=0
connected=false

while [ $attempt -lt $max_attempts ]; do
  if /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -b -C &> /dev/null; then
    connected=true
    break
  fi
  
  attempt=$(($attempt + 1))
  echo "⏱️  Waiting for SQL Server... (attempt $attempt/$max_attempts)"
  sleep 2
done

if [ "$connected" = false ]; then
  echo ""
  echo "❌ ERROR: SQL Server not ready after $max_attempts attempts"
  echo "────────────────────────────────────────"
  echo "Troubleshooting steps:"
  echo "1. Check if SQL Server container is running: docker ps"
  echo "2. Check SQL Server logs: docker logs sqlserver"
  echo "3. Verify password in secrets/db_password.txt"
  echo "4. Try manual connection: docker exec -it sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa"
  echo ""
  echo "Testing connection manually..."
  /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -C 2>&1 || true
  exit 1
fi

echo ""
echo "✅ SQL Server is up and running"
echo "════════════════════════════════════════"

# ตรวจสอบว่า database มีอยู่หรือไม่
echo ""
echo "🔍 Checking database existence..."

DB_EXISTS=$(/opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT COUNT(*) FROM sys.databases WHERE name = '$DATABASE_NAME'" -h -1 -W -C 2>/dev/null | tr -d ' ' | tr -d '\n' | tr -d '\r')

echo "Database check result: '$DB_EXISTS'"

if [ -z "$DB_EXISTS" ] || [ "$DB_EXISTS" = "0" ]; then
  echo "⚠️  Database '$DATABASE_NAME' does not exist or cannot be verified"
  echo ""
  echo "Available databases:"
  /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT name FROM sys.databases" -C
  echo ""
  echo "Attempting to proceed anyway (EF Core will handle it)..."
else
  echo "✅ Database '$DATABASE_NAME' exists"
fi

echo ""
echo "════════════════════════════════════════"
echo "▶️  Starting ASP.NET Core application..."
echo "════════════════════════════════════════"
echo ""
echo "Environment: $ASPNETCORE_ENVIRONMENT"
echo "Listening on: $ASPNETCORE_URLS"
echo ""

# เริ่มต้น application
exec dotnet rssnews.dll