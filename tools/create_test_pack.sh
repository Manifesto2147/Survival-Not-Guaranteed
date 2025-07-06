#!/bin/bash

# Simple test .mrpack builder to diagnose options.txt/servers.dat issues
# This creates a minimal .mrpack with just the essential files

echo "Creating minimal test .mrpack..."

# Store original directory
original_dir=$(pwd)

# Create temporary directory
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

cd "$temp_dir"

# Create minimal modrinth.index.json
cat > modrinth.index.json << 'EOF'
{
  "formatVersion": 1,
  "game": "minecraft",
  "versionId": "test-1.0.0",
  "name": "Test Pack",
  "summary": "Minimal test pack for troubleshooting",
  "files": [],
  "dependencies": {
    "minecraft": "1.21.1",
    "neoforge": "21.1.180"
  }
}
EOF

# Create overrides directory
mkdir -p overrides

# Copy the problematic files
if [ -f "$original_dir/options.txt" ]; then
  cp "$original_dir/options.txt" overrides/
  echo "✅ Copied options.txt to overrides/"
else
  echo "❌ options.txt not found in current directory"
fi

if [ -f "$original_dir/servers.dat" ]; then
  cp "$original_dir/servers.dat" overrides/
  echo "✅ Copied servers.dat to overrides/"
else
  echo "❌ servers.dat not found in current directory"
fi

# Create the .mrpack
pack_name="Test-Pack-Minimal.mrpack"
zip -r "$original_dir/$pack_name" . -x "*.DS_Store" >/dev/null 2>&1
cd "$original_dir"

# Verify contents
echo ""
echo "📋 Verifying test .mrpack contents:"
unzip -l "$pack_name" | grep -E "(options\.txt|servers\.dat|modrinth\.index\.json)" | while read -r line; do
  echo "  $line"
done

echo ""
echo "✅ Created: $pack_name"
echo "🔍 Test this minimal pack in Modrinth launcher to isolate the issue"
