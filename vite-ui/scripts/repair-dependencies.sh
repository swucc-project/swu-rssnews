#!/bin/bash

set -e

echo "๐Ÿ"ง Fixing dependency conflicts..."

# 1. ลบ node_modules และ lock files
echo "๐Ÿงน Cleaning old dependencies..."
rm -rf node_modules package-lock.json

# 2. ติดตั้ง dependencies ใหม่พร้อม --legacy-peer-deps
echo "๐Ÿ"ฆ Installing dependencies..."
npm install --legacy-peer-deps

# 3. ตรวจสอบ zod version
echo "๐Ÿ" Verifying zod version..."
ZOD_VERSION=$(npm list zod --depth=0 2>/dev/null | grep zod@ | sed 's/.*zod@//' | sed 's/ .*//')

if [[ $ZOD_VERSION == 3.* ]]; then
    echo "โœ… Zod version $ZOD_VERSION is correct"
else
    echo "โš ๏ธ Zod version $ZOD_VERSION might cause issues, expected 3.x"
fi

# 4. ติดตั้ง @asteasolutions/zod-to-openapi ถ้ายังไม่มี
echo "๐Ÿ"ง Installing zod-to-openapi..."
npm install --save @asteasolutions/zod-to-openapi --legacy-peer-deps

# 5. แก้ไข rollup conflicts
echo "๐Ÿ"ฉ Fixing rollup version..."
npm install rollup@^3.29.5 --save-dev --legacy-peer-deps

# 6. ลบ incompatible plugins
echo "๐Ÿ—'๏ธ Removing incompatible rollup plugins..."
npm uninstall rollup-plugin-css-modules rollup-plugin-import-css --legacy-peer-deps || true

echo ""
echo "โœ… Dependency fixes completed!"
echo ""
echo "๐Ÿ"Š Installed versions:"
npm list zod openapi-zod-client @asteasolutions/zod-to-openapi rollup --depth=0 2>/dev/null || true