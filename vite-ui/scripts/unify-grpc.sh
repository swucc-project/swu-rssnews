#!/bin/bash
set -e

echo "🔄 Syncing gRPC files..."

# สร้าง directory ถ้ายังไม่มี
mkdir -p ./grpc-generated

# Copy gRPC generated files
if [ -d "./grpc" ] && [ "$(ls -A ./grpc 2>/dev/null)" ]; then
    echo "✅ Copying gRPC files from ./grpc..."
    cp -R ./grpc/* ./grpc-generated/ || {
        echo "⚠️ Copy failed, trying with sudo..."
        sudo cp -R ./grpc/* ./grpc-generated/ 2>/dev/null || true
    }
    echo "📦 Files copied:"
    ls -la ./grpc-generated/
else
    echo "⚠️ No gRPC files found in ./grpc"
    echo "   Creating placeholder structure..."
    touch ./grpc-generated/.gitkeep
fi

# Set permissions
chmod -R 777 ./grpc-generated 2>/dev/null || {
    echo "⚠️ Could not set permissions (non-critical)"
}

# ✅ Verify files
if [ "$(ls -A ./grpc-generated 2>/dev/null)" ]; then
    echo "✅ gRPC files synced successfully!"
    echo "📋 Available files:"
    find ./grpc-generated -type f | head -10
else
    echo "⚠️ No files in grpc-generated directory"
fi

echo "✅ Sync completed!"