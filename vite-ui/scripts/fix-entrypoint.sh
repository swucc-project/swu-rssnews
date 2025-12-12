#!/bin/bash
set -e

echo "🔧 Fixing Docker entrypoint script..."

SCRIPT_PATH="./vite-ui/scripts/docker-entrypoint.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ File not found: $SCRIPT_PATH"
    exit 1
fi

# 1. Convert line endings
echo "1. Converting line endings..."
if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$SCRIPT_PATH"
    echo "   ✅ Using dos2unix"
elif command -v sed >/dev/null 2>&1; then
    sed -i 's/\r$//' "$SCRIPT_PATH"
    echo "   ✅ Using sed"
else
    echo "   ⚠️  No conversion tool, checking current format..."
    if grep -q $'\r' "$SCRIPT_PATH"; then
        echo "   ❌ Has CRLF but no conversion tool available!"
        echo "   💡 Install dos2unix: sudo apt-get install dos2unix"
        exit 1
    fi
fi

# 2. Set permissions
echo "2. Setting executable permission..."
chmod +x "$SCRIPT_PATH"

# 3. Test syntax
echo "3. Testing syntax..."
if bash -n "$SCRIPT_PATH"; then
    echo "   ✅ Syntax OK"
else
    echo "   ❌ Syntax error!"
    exit 1
fi

# 4. Check shebang
echo "4. Checking shebang..."
if head -1 "$SCRIPT_PATH" | grep -q "^#!/bin/bash"; then
    echo "   ✅ Shebang correct"
else
    echo "   ⚠️  Shebang might be wrong"
    echo "   First line: $(head -1 "$SCRIPT_PATH")"
fi

echo "✅ Entrypoint script fixed!"