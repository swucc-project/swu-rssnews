#!/bin/bash
set -e

echo "🔧 EF Core Migration Tool"
echo "════════════════════════════════════════"

PROJECT_DIR="/app/aspnetcore"
cd "$PROJECT_DIR"

# โหลด password
if [ -z "$MSSQL_SA_PASSWORD" ]; then
  if [ -n "$MSSQL_SA_PASSWORD_FILE" ] && [ -f "$MSSQL_SA_PASSWORD_FILE" ]; then
    export MSSQL_SA_PASSWORD=$(cat "$MSSQL_SA_PASSWORD_FILE" | tr -d '\n' | tr -d '\r')
    echo "✅ Loaded password from secret file"
  else
    echo "❌ ERROR: Password file not found"
    exit 1
  fi
fi

DATABASE_HOST=${DATABASE_HOST:-mssql}
DATABASE_NAME=${DATABASE_NAME:-RSSActivityWeb}

# สร้าง connection string
CONNECTION_STRING="Server=$DATABASE_HOST;Database=$DATABASE_NAME;User ID=sa;Password=$MSSQL_SA_PASSWORD;TrustServerCertificate=True;Connect Timeout=30;Encrypt=False;"

echo "🗄️  Database: $DATABASE_NAME"
echo "🖥️  Host: $DATABASE_HOST"
echo ""

# รอให้ SQL Server พร้อม
echo "⏳ Waiting for SQL Server..."

# ✅ กำหนดค่าเริ่มต้นให้ตัวแปร (แก้ไขตรงนี้)
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
  if /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -C -b &> /dev/null; then
    break
  fi
  attempt=$(($attempt + 1))
  echo "Waiting... (attempt $attempt/$max_attempts)"
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "❌ ERROR: SQL Server not ready after $max_attempts attempts"
  exit 1
fi

echo "✅ SQL Server is ready"
echo ""

# ตรวจสอบว่า database มีอยู่หรือไม่
echo "🔍 Checking if database exists..."
DB_EXISTS=$(/opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" \
  -Q "SELECT COUNT(*) FROM sys.databases WHERE name = '$DATABASE_NAME'" -h -1 -W -C | tr -d ' \n\r')

if [ "$DB_EXISTS" = "0" ]; then
  echo "❌ ERROR: Database '$DATABASE_NAME' does not exist"
  echo "Please run database setup first!"
  exit 1
fi

echo "✅ Database '$DATABASE_NAME' exists"
echo ""

# ตรวจสอบโหมดการทำงาน
ADD_NEW_MIGRATION=${ADD_NEW_MIGRATION:-false}

if [ "$ADD_NEW_MIGRATION" = "true" ]; then
  # สร้าง migration ใหม่
  if [ -z "$MIGRATION_NAME" ]; then
    MIGRATION_NAME="AutoMigration_$(date +"%Y%m%d_%H%M%S")"
  fi
  
  echo "📦 Creating new migration: $MIGRATION_NAME"
  echo "────────────────────────────────────────"
  
  # ✅ ตรวจสอบว่ามี migration ชื่อซ้ำหรือไม่
  echo "🔍 Checking for existing migration..."
  
  if [ -d "Migrations" ]; then
    # ตรวจสอบไฟล์ที่มีชื่อ migration ซ้ำ
    EXISTING_MIGRATION=$(find Migrations -name "*_${MIGRATION_NAME}.cs" 2>/dev/null | head -n 1)
    
    if [ -n "$EXISTING_MIGRATION" ]; then
      echo "⚠️  WARNING: Migration '$MIGRATION_NAME' already exists!"
      echo "📁 Found: $EXISTING_MIGRATION"
      echo ""
      echo "Options:"
      echo "  1. Use a different name (set MIGRATION_NAME)"
      echo "  2. Remove existing migration first"
      echo "  3. Skip migration creation (set ADD_NEW_MIGRATION=false)"
      echo ""
      echo "❌ Skipping migration creation to avoid conflict"
      echo "💡 Proceeding to apply existing migrations..."
    else
      echo "✅ No existing migration with name '$MIGRATION_NAME'"
      echo ""
      
      # สร้าง migration ใหม่
      dotnet ef migrations add "$MIGRATION_NAME" \
        --project rssnews.csproj \
        --context RSSNewsDbContext \
        --output-dir Migrations \
        --verbose || {
          echo "❌ ERROR: Failed to create migration"
          exit 1
        }
      
      echo ""
      echo "✅ Migration created successfully"
      echo ""
    fi
  else
    echo "📁 Migrations directory not found, creating first migration..."
    
    dotnet ef migrations add "$MIGRATION_NAME" \
      --project rssnews.csproj \
      --context RSSNewsDbContext \
      --output-dir Migrations \
      --verbose || {
        echo "❌ ERROR: Failed to create migration"
        exit 1
      }
    
    echo ""
    echo "✅ First migration created successfully"
    echo ""
  fi
fi

# Apply migrations
echo "🚀 Applying database migrations..."
echo "────────────────────────────────────────"

dotnet ef database update \
  --connection "$CONNECTION_STRING" \
  --context RSSNewsDbContext \
  --verbose || {
    echo "❌ ERROR: Failed to apply migrations"
    exit 1
  }

echo ""
echo "✅ Database migrations applied successfully"
echo "════════════════════════════════════════"