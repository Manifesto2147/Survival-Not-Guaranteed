#!/bin/bash

# Local Development Testing Script
# Run this before pushing to the develop branch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }

echo "🧪 Running local development tests..."

# Test 1: Check required files
print_info "Test 1: Checking required files..."
if [[ ! -f "modrinth.index.json" ]]; then
    print_error "modrinth.index.json not found"
    exit 1
fi

if [[ ! -f "build.sh" ]]; then
    print_error "build.sh not found"
    exit 1
fi
print_status "Required files present"

# Test 2: Validate JSON
print_info "Test 2: Validating JSON syntax..."
if ! jq empty modrinth.index.json 2>/dev/null; then
    print_error "Invalid JSON in modrinth.index.json"
    exit 1
fi
print_status "JSON syntax valid"

# Test 3: Check manifest structure
print_info "Test 3: Checking manifest structure..."
required_fields=("formatVersion" "game" "versionId" "name" "files")
for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" modrinth.index.json > /dev/null 2>&1; then
        print_error "Missing required field: $field"
        exit 1
    fi
done
print_status "Manifest structure valid"

# Test 4: Check for missing URLs
print_info "Test 4: Checking for missing download URLs..."
missing_urls=$(jq '.files[] | select(.downloads == null or .downloads == [] or (.downloads | length) == 0) | .path' modrinth.index.json | wc -l)
if [[ $missing_urls -gt 0 ]]; then
    print_error "$missing_urls mods missing download URLs"
    jq '.files[] | select(.downloads == null or .downloads == [] or (.downloads | length) == 0) | .path' modrinth.index.json
    exit 1
fi
print_status "All mods have download URLs"

# Test 5: Test build script
print_info "Test 5: Testing build script syntax..."
chmod +x build.sh
if ! bash -n build.sh; then
    print_error "Build script has syntax errors"
    exit 1
fi
print_status "Build script syntax valid"

# Test 6: Check essential dependencies
print_info "Test 6: Checking essential dependencies..."
essential_mods=("bookshelf" "geckolib" "curios")
for mod in "${essential_mods[@]}"; do
    if jq -e --arg mod "$mod" '.files[] | select(.path | contains($mod))' modrinth.index.json > /dev/null 2>&1; then
        client_env=$(jq -r --arg mod "$mod" '.files[] | select(.path | contains($mod)) | .env.client' modrinth.index.json | head -1)
        server_env=$(jq -r --arg mod "$mod" '.files[] | select(.path | contains($mod)) | .env.server' modrinth.index.json | head -1)
        
        if [[ "$client_env" == "required" && "$server_env" == "required" ]]; then
            print_status "$mod: properly configured"
        else
            print_warning "$mod: client=$client_env, server=$server_env"
        fi
    else
        print_info "$mod: not found in pack"
    fi
done

# Test 7: Pack statistics
print_info "Test 7: Pack statistics..."
total_mods=$(jq '.files | length' modrinth.index.json)
universal_mods=$(jq '.files[] | select(.env.client == "required" and .env.server == "required") | .path' modrinth.index.json | wc -l)
client_only=$(jq '.files[] | select(.env.client == "required" and .env.server == "unsupported") | .path' modrinth.index.json | wc -l)

echo "📊 Pack Statistics:"
echo "  Total mods: $total_mods"
echo "  Universal: $universal_mods"
echo "  Client-only: $client_only"

print_status "All local development tests passed!"
echo ""
echo "🚀 Next steps:"
echo "1. Run './build.sh' to create .mrpack"
echo "2. Test .mrpack in PrismLauncher/Modrinth"
echo "3. Commit and push to develop branch"
echo "4. GitHub Actions will run comprehensive tests"
