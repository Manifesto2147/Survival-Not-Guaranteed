#!/bin/bash

# Verify Curios Cleanup Status
# Comprehensive check of both manifest and physical files

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_check() { echo -e "${PURPLE}🔍${NC} $1"; }

echo "🔍 Curios Cleanup Verification Report"
echo "===================================="
echo ""

# Check manifest status
print_check "Analyzing modrinth.index.json..."
echo ""

# Count Curios entries in manifest
CURIOS_COUNT=$(jq -r '.files[] | select(.path | contains("curios")) | .path' modrinth.index.json | wc -l)
echo "📄 Manifest Analysis:"
echo "   • Curios entries found: $CURIOS_COUNT"

if [ "$CURIOS_COUNT" -eq 1 ]; then
    print_success "Only one Curios entry in manifest (expected)"
    CURIOS_VERSION=$(jq -r '.files[] | select(.path | contains("curios")) | .path' modrinth.index.json)
    echo "   • Version: $CURIOS_VERSION"
else
    print_warning "Multiple Curios entries still in manifest!"
    jq -r '.files[] | select(.path | contains("curios")) | .path' modrinth.index.json | while read -r path; do
        echo "   • $path"
    done
fi

echo ""

# Check physical JAR files
print_check "Checking physical JAR files..."
echo ""

JAR_FILES=$(find minecraft/mods -name "*curios*.jar" 2>/dev/null || true)
JAR_COUNT=$(echo "$JAR_FILES" | grep -c "curios" || echo "0")

echo "📦 Physical Files Analysis:"
echo "   • Curios JAR files found: $JAR_COUNT"

if [ "$JAR_COUNT" -gt 0 ]; then
    echo "$JAR_FILES" | while read -r jar; do
        if [ -n "$jar" ]; then
            SIZE=$(du -h "$jar" | cut -f1)
            echo "   • $jar ($SIZE)"
        fi
    done
fi

echo ""

# Check if cleanup is needed
if [ "$CURIOS_COUNT" -eq 1 ] && [ "$JAR_COUNT" -gt 1 ]; then
    print_warning "CLEANUP NEEDED: Multiple JAR files but only one in manifest"
    echo ""
    echo "🔧 Recommended Actions:"
    echo "   1. Remove old JAR files not referenced in manifest"
    echo "   2. Keep only the JAR file specified in modrinth.index.json"
    echo ""
    
    # Show which JAR should be kept
    MANIFEST_JAR=$(jq -r '.files[] | select(.path | contains("curios")) | .path' modrinth.index.json)
    echo "   📋 Keep this file: $MANIFEST_JAR"
    echo ""
    
    # Show which JARs should be removed
    echo "   🗑️  Remove these files:"
    echo "$JAR_FILES" | while read -r jar; do
        if [ -n "$jar" ]; then
            JAR_NAME=$(basename "$jar")
            MANIFEST_NAME=$(basename "$MANIFEST_JAR")
            if [ "$JAR_NAME" != "$MANIFEST_NAME" ]; then
                echo "      • $jar"
            fi
        fi
    done
    
elif [ "$CURIOS_COUNT" -eq 1 ] && [ "$JAR_COUNT" -eq 1 ]; then
    print_success "OPTIMAL STATE: One manifest entry, one JAR file"
    
elif [ "$CURIOS_COUNT" -gt 1 ]; then
    print_error "MANIFEST ISSUE: Multiple Curios entries in manifest"
    echo "   🔧 Need to run: ./remove-curios-duplicate.sh"
    
else
    print_info "No Curios files found"
fi

echo ""

# Check dependent mods
print_check "Verifying dependent mods..."
echo ""

# Find mods that might depend on Curios
CURIOS_DEPENDENTS=$(jq -r '.files[] | select(.path | contains("curios") and (contains("compat") or contains("addon"))) | .path' modrinth.index.json)

if [ -n "$CURIOS_DEPENDENTS" ]; then
    echo "🔗 Found Curios-dependent mods:"
    echo "$CURIOS_DEPENDENTS" | while read -r mod; do
        if [ -n "$mod" ]; then
            echo "   • $mod"
        fi
    done
else
    echo "🔗 No obvious Curios-dependent mods found in manifest"
fi

echo ""

# Check for relics and other known dependents
KNOWN_DEPENDENTS=("relics" "gravestone" "artifacts")
echo "🔍 Checking for known Curios dependents:"

for dep in "${KNOWN_DEPENDENTS[@]}"; do
    COUNT=$(jq -r ".files[] | select(.path | contains(\"$dep\")) | .path" modrinth.index.json | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        print_success "$dep found ($COUNT entries)"
        jq -r ".files[] | select(.path | contains(\"$dep\")) | .path" modrinth.index.json | while read -r path; do
            if [ -n "$path" ]; then
                echo "   • $path"
            fi
        done
    else
        print_info "$dep not found"
    fi
done

echo ""

# Summary and recommendations
print_info "Summary and Recommendations:"
echo ""

if [ "$CURIOS_COUNT" -eq 1 ] && [ "$JAR_COUNT" -eq 1 ]; then
    print_success "✨ EXCELLENT: Curios cleanup is complete and optimal!"
    echo "   • Manifest has exactly one Curios entry"
    echo "   • Physical files match manifest"
    echo "   • No action needed"
    
elif [ "$CURIOS_COUNT" -eq 1 ] && [ "$JAR_COUNT" -gt 1 ]; then
    print_warning "🧹 CLEANUP NEEDED: Remove unused JAR files"
    echo "   • Run the cleanup commands shown above"
    echo "   • This will complete the optimization"
    
    # Generate cleanup commands
    echo ""
    echo "💡 Quick cleanup commands:"
    MANIFEST_JAR=$(jq -r '.files[] | select(.path | contains("curios")) | .path' modrinth.index.json)
    echo "$JAR_FILES" | while read -r jar; do
        if [ -n "$jar" ]; then
            JAR_NAME=$(basename "$jar")
            MANIFEST_NAME=$(basename "$MANIFEST_JAR")
            if [ "$JAR_NAME" != "$MANIFEST_NAME" ]; then
                echo "   rm \"$jar\""
            fi
        fi
    done
    
else
    print_error "🔧 ADDITIONAL WORK NEEDED: Manifest cleanup required"
    echo "   • Run: ./remove-curios-duplicate.sh"
    echo "   • Then run this script again"
fi

echo ""
echo "🎯 For reference, the optimal state is:"
echo "   • 1 Curios entry in modrinth.index.json"
echo "   • 1 matching JAR file in minecraft/mods/"
echo "   • Version 9.5.1 or higher"
echo "   • All dependent mods working correctly"
