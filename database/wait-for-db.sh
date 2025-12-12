#!/bin/bash
set -e

MAX_RETRIES=30
RETRY_INTERVAL=2

echo "⏳ Waiting for SQL Server to be ready..."

for i in $(seq 1 $MAX_RETRIES); do
    if /opt/mssql-tools18/bin/sqlcmd \
        -S mssql \
        -U sa \
        -P "$(cat /run/secrets/db_password)" \
        -Q "SELECT 1" \
        -C \
        -b > /dev/null 2>&1; then
        echo "✅ SQL Server is ready (attempt $i/$MAX_RETRIES)"
        exit 0
    fi
    
    echo "⏳ Waiting for SQL Server... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

echo "❌ SQL Server failed to become ready after $MAX_RETRIES attempts"
exit 1