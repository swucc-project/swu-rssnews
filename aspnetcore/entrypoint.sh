#!/bin/bash
# /aspnetcore/entrypoint.sh
set -e

echo "🚀 Starting ASP.NET Core Application..."
echo "════════════════════════════════════════"

# Locale และ Timezone
export LANG=${LANG:-th_TH.UTF-8}
export LC_ALL=${LC_ALL:-th_TH.UTF-8}
export TZ=${TZ:-Asia/Bangkok}

echo "🌐 Locale: $LANG"
echo "🕐 Timezone: $TZ"

# ═══════════════════════════════════════════════════════════
# ⚠️  IMPORTANT: Migration Notice
# ═══════════════════════════════════════════════════════════
echo ""
echo "📢 MIGRATION NOTICE:"
echo "   This container does NOT have EF Core tools installed."
echo "   To run migrations, use the migration scripts:"
echo "   • ./aspnetcore/add-first-migration.sh  (create migrations)"
echo "   • ./aspnetcore/quick-fix.sh            (apply migrations)"
echo ""
echo "   Migrations must be run from the HOST machine,"
echo "   NOT from inside this container."
echo "════════════════════════════════════════"
echo ""

# Load password from secret
if [ -z "$MSSQL_SA_PASSWORD" ]; then
  if [ -n "$MSSQL_SA_PASSWORD_FILE" ] && [ -f "$MSSQL_SA_PASSWORD_FILE" ]; then
    export MSSQL_SA_PASSWORD=$(cat "$MSSQL_SA_PASSWORD_FILE" | tr -d '[:space:]')
    echo "✅ Loaded password from secret file"
  else
    echo "❌ ERROR: Password not found"
    exit 1
  fi
fi

DATABASE_HOST=${DATABASE_HOST:-mssql}
DATABASE_NAME=${DATABASE_NAME:-RSSActivityWeb}

echo "🗄️  Database: $DATABASE_NAME @ $DATABASE_HOST"

# Wait for SQL Server
echo "⏳ Waiting for SQL Server..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
  if /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -C -b &>/dev/null; then
    echo "✅ SQL Server is ready"
    break
  fi
  attempt=$((attempt + 1))
  [ $((attempt % 10)) -eq 0 ] && echo "⏱️  Waiting... ($attempt/$max_attempts)"
  sleep 2
done

if [ $attempt -ge $max_attempts ]; then
  echo "❌ SQL Server not ready after $max_attempts attempts"
  exit 1
fi

# Check/Create database
echo "🔍 Checking database..."
DB_EXISTS=$(/opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" \
  -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$DATABASE_NAME'" -h -1 -W -C 2>/dev/null | tr -d '[:space:]')

if [ "$DB_EXISTS" != "1" ]; then
  echo "🛠️  Creating database '$DATABASE_NAME'..."
  /opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" \
    -Q "CREATE DATABASE [$DATABASE_NAME]" -C
  echo "✅ Database created"
else
  echo "✅ Database exists"
fi

# Check if migrations need to be applied
echo ""
echo "🔍 Checking migration status..."
PENDING_MIGRATIONS=$(/opt/mssql-tools18/bin/sqlcmd -S "$DATABASE_HOST" -U sa -P "$MSSQL_SA_PASSWORD" -d "$DATABASE_NAME" \
  -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '__EFMigrationsHistory'" -h -1 -W -C 2>/dev/null | tr -d '[:space:]')

if [ "$PENDING_MIGRATIONS" = "0" ]; then
  echo ""
  echo "⚠️  ════════════════════════════════════════════════════════"
  echo "⚠️  WARNING: No migrations have been applied!"
  echo "⚠️  ════════════════════════════════════════════════════════"
  echo "⚠️  "
  echo "⚠️  The database exists but has no schema."
  echo "⚠️  You need to run migrations before the app will work."
  echo "⚠️  "
  echo "⚠️  Run from your HOST machine (NOT from inside container):"
  echo "⚠️  "
  echo "⚠️    ./aspnetcore/quick-fix.sh"
  echo "⚠️  "
  echo "⚠️  ════════════════════════════════════════════════════════"
  echo ""
  echo "⏸️  Application will start but may fail without migrations..."
  echo ""
else
  echo "✅ Migrations have been applied"
fi

echo ""
echo "════════════════════════════════════════"
echo "▶️  Starting application..."
echo "════════════════════════════════════════"
echo "Environment: $ASPNETCORE_ENVIRONMENT"
echo ""

cd /var/www/rssnews
exec dotnet rssnews.dll