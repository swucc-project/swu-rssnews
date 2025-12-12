#!/bin/bash
set -e

echo "🔧 Initializing Docker volumes and fixing permissions..."
echo "════════════════════════════════════════════════════════"

# กำหนดชื่อ project
PROJECT_NAME="swu-rssnews"

# ตรวจสอบว่ามี Docker daemon ทำงานอยู่หรือไม่
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker daemon is not running"
    exit 1
fi

# ✅ ฟังก์ชันสร้าง volume
create_volume_if_not_exists() {
    local vol_name=$1
    local description=$2
    
    if docker volume inspect ${PROJECT_NAME}_${vol_name} > /dev/null 2>&1; then
        echo "  ✅ ${PROJECT_NAME}_${vol_name} already exists - skipping"
        return 0
    else
        echo "  📦 Creating ${PROJECT_NAME}_${vol_name}..."
        if docker volume create ${PROJECT_NAME}_${vol_name} > /dev/null 2>&1; then
            echo "  ✅ Created ${PROJECT_NAME}_${vol_name} (${description})"
            return 0
        else
            echo "  ❌ Failed to create ${PROJECT_NAME}_${vol_name}"
            return 1
        fi
    fi
}

# ✅ Clean mode
CLEAN_VOLUMES=false
if [ "$1" = "--clean" ] || [ "$1" = "-c" ]; then
    CLEAN_VOLUMES=true
    echo "⚠️  CLEAN MODE: Will remove existing volumes"
    echo ""
    read -p "Are you sure? This will DELETE all data! (type 'yes' to confirm): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "❌ Cancelled"
        exit 0
    fi
    echo ""
fi

# ลบ volumes เก่า (ถ้าใช้ --clean)
if [ "$CLEAN_VOLUMES" = true ]; then
    echo "🗑️  Cleaning up old volumes..."
    
    echo "  Stopping all containers..."
    docker compose down -v 2>/dev/null || true
    
    for vol in rssdata rssdata-logs db-backups; do
        if docker volume ls -q | grep -q "^${PROJECT_NAME}_${vol}$"; then
            echo "  Removing ${PROJECT_NAME}_${vol}..."
            docker volume rm -f ${PROJECT_NAME}_${vol} 2>/dev/null || true
        fi
    done
    echo "✅ Old volumes cleaned"
    echo ""
fi

# สร้าง volumes
echo "📦 Creating volumes..."
create_volume_if_not_exists "rssdata" "SQL Server data files" || exit 1
create_volume_if_not_exists "rssdata-logs" "SQL Server log files" || exit 1
create_volume_if_not_exists "db-backups" "Database backups" || exit 1
echo "✅ All volumes created"
echo ""

# ✅ Set permissions สำหรับ SQL Server (สำคัญมาก!)
echo "🔐 Setting SQL Server volume permissions..."
docker run --rm \
  -v ${PROJECT_NAME}_rssdata:/data \
  -v ${PROJECT_NAME}_rssdata-logs:/logs \
  -v ${PROJECT_NAME}_db-backups:/backups \
  alpine:latest sh -c '
    set -e
    echo "  📁 Creating directory structure..."
    mkdir -p /data /logs /backups
    
    echo "  🔒 Setting ownership to 10001:0 (mssql user)..."
    chown -R 10001:0 /data /logs /backups
    
    echo "  🔓 Setting permissions to 755..."
    chmod -R 755 /data /logs /backups
    
    echo "  ✅ Verifying permissions..."
    ls -la / | grep -E "data|logs|backups"
    
    echo "✅ SQL Server permissions set successfully!"
  ' || {
    echo "❌ Failed to set SQL Server permissions!"
    echo "⚠️  Trying alternative method..."
    
    # ลองใช้ root แทน
    docker run --rm --user root \
      -v ${PROJECT_NAME}_rssdata:/data \
      -v ${PROJECT_NAME}_rssdata-logs:/logs \
      -v ${PROJECT_NAME}_db-backups:/backups \
      alpine:latest sh -c '
        mkdir -p /data /logs /backups
        chown -R 10001:0 /data /logs /backups
        chmod -R 777 /data /logs /backups
      ' || {
        echo "❌ All permission methods failed!"
        exit 1
      }
  }

echo ""

# Set permissions สำหรับ gRPC
echo "🔐 Setting gRPC volume permissions..."
docker run --rm \
  -v ${PROJECT_NAME}_grpc-batch:/grpc \
  alpine:latest sh -c '
    mkdir -p /grpc
    chmod -R 777 /grpc
    echo "✅ gRPC permissions set to 777"
  ' || echo "⚠️  Warning: Could not set gRPC permissions"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ Volume initialization completed!"
echo ""

# ตรวจสอบ volumes
echo "🔍 Verifying volumes..."
all_ok=true
for vol in rssdata rssdata-logs db-backups; do
    if docker volume inspect ${PROJECT_NAME}_${vol} > /dev/null 2>&1; then
        echo "  ✅ ${PROJECT_NAME}_${vol}"
    else
        echo "  ❌ ${PROJECT_NAME}_${vol} - MISSING"
        all_ok=false
    fi
done

echo ""
if [ "$all_ok" = false ]; then
    echo "❌ Some volumes failed verification!"
    exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "📝 Usage:"
echo "  • Normal run:  ./begin-volumes.sh"
echo "  • Clean mode:  ./begin-volumes.sh --clean"
echo ""
echo "🎯 Next steps:"
echo "  1. Run: make build"
echo "  2. Run: make install"
echo "  3. Run: make dev"
echo "════════════════════════════════════════════════════════"