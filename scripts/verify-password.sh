#!/bin/bash

# verify-password.sh
# ตรวจสอบความถูกต้องของ SQL Server password

set -e

PASSWORD_FILE="${1:-./secrets/db_password.txt}"

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "❌ Password file not found: $PASSWORD_FILE"
    exit 1
fi

# อ่าน password และลบ whitespace
PASSWORD=$(cat "$PASSWORD_FILE" | tr -d '[:space:]')

# ตรวจสอบความยาว
LEN=${#PASSWORD}
echo "Password length: $LEN characters"

if [ $LEN -lt 8 ]; then
    echo "❌ FAIL: Password must be at least 8 characters"
    exit 1
fi

if [ $LEN -gt 128 ]; then
    echo "❌ FAIL: Password must not exceed 128 characters"
    exit 1
fi

# ตรวจสอบความซับซ้อน (SQL Server requirements)
COMPLEXITY=0

if echo "$PASSWORD" | grep -q '[A-Z]'; then
    echo "✅ Contains uppercase letters"
    COMPLEXITY=$((COMPLEXITY + 1))
fi

if echo "$PASSWORD" | grep -q '[a-z]'; then
    echo "✅ Contains lowercase letters"
    COMPLEXITY=$((COMPLEXITY + 1))
fi

if echo "$PASSWORD" | grep -q '[0-9]'; then
    echo "✅ Contains numbers"
    COMPLEXITY=$((COMPLEXITY + 1))
fi

if echo "$PASSWORD" | grep -q '[^A-Za-z0-9]'; then
    echo "✅ Contains special characters"
    COMPLEXITY=$((COMPLEXITY + 1))
fi

if [ $COMPLEXITY -lt 3 ]; then
    echo "❌ FAIL: Password must contain at least 3 of the following:"
    echo "   - Uppercase letters (A-Z)"
    echo "   - Lowercase letters (a-z)"
    echo "   - Numbers (0-9)"
    echo "   - Special characters (!@#$%^&*)"
    exit 1
fi

# ตรวจสอบ characters ที่ไม่อนุญาต
if echo "$PASSWORD" | grep -q "[\"\'\`]"; then
    echo "⚠️  WARNING: Password contains quotes that may cause issues"
fi

echo ""
echo "✅ Password validation passed"
echo "   Length: $LEN"
echo "   Complexity: $COMPLEXITY/4"

# เขียน password ที่ clean แล้วกลับไปที่ไฟล์
echo -n "$PASSWORD" > "$PASSWORD_FILE"
echo "✅ Password file cleaned (removed whitespace)"