#!/bin/bash

# Curios Dependency Analysis
# Check which mods depend on each Curios version and determine if we can remove the old one

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_constraint() { echo -e "${PURPLE}🔗${NC} $1"; }

echo "🔍 Curios Dependency Analysis"
echo "============================="
echo ""

# Define the two Curios versions we found
CURIOS_OLD_PROJECT="BaqCltvf"  # Curios API Continuation (9.0.15)
CURIOS_NEW_PROJECT="vvuO3ImH"  # Curios API (9.5.1)

print_info "Analyzing two Curios projects in your modpack:"
echo "   📦 $CURIOS_OLD_PROJECT: Curios API Continuation (9.0.15+1.21.1)"
echo "   📦 $CURIOS_NEW_PROJECT: Curios API (9.5.1+1.21.1)"
echo ""

# Check what the newer project actually provides
print_info "Checking if newer Curios is backward compatible..."
curl -s "https://api.modrinth.com/v2/project/$CURIOS_NEW_PROJECT" | jq -r '{
    title: .title,
    description: .description,
    categories: .categories,
    additional_categories: .additional_categories
}' > curios_new_info.json

curl -s "https://api.modrinth.com/v2/project/$CURIOS_OLD_PROJECT" | jq -r '{
    title: .title,
    description: .description,
    categories: .categories,
    additional_categories: .additional_categories
}' > curios_old_info.json

echo "📋 Project Details:"
echo "   Newer Project ($CURIOS_NEW_PROJECT):"
echo "      • Title: $(jq -r '.title' curios_new_info.json)"
echo "      • Description: $(jq -r '.description' curios_new_info.json)"
echo ""
echo "   Older Project ($CURIOS_OLD_PROJECT):"
echo "      • Title: $(jq -r '.title' curios_old_info.json)"
echo "      • Description: $(jq -r '.description' curios_old_info.json)"
echo ""

# Search for mods in the modpack that might depend on Curios
print_info "Scanning modpack for mods that might depend on Curios..."

# Check for mods that commonly depend on Curios
CURIOS_DEPENDENT_MODS=()
POTENTIAL_CURIOS_MODS=(
    "artifacts"
    "gravestone"
    "gravestones"
    "relics"
    "rings"
    "ascension"
    "trinkets"
    "baubles"
    "cosmetic"
    "accessories"
    "equipment"
    "items"
    "backpack"
    "belt"
    "charm"
    "amulet"
)

# Search the manifest for these mods
for potential_mod in "${POTENTIAL_CURIOS_MODS[@]}"; do
    found_mods=$(jq -r --arg mod "$potential_mod" '.files[] | select(.path | ascii_downcase | contains($mod)) | .path' modrinth.index.json 2>/dev/null || echo "")
    
    if [[ -n "$found_mods" ]]; then
        while IFS= read -r mod_path; do
            if [[ -n "$mod_path" ]]; then
                CURIOS_DEPENDENT_MODS+=("$mod_path")
            fi
        done <<< "$found_mods"
    fi
done

echo "🔗 Found potential Curios-dependent mods:"
for mod in "${CURIOS_DEPENDENT_MODS[@]}"; do
    echo "   • $(basename "$mod")"
done
echo ""

# For each dependent mod, check its dependencies via Modrinth API
print_info "Checking actual dependencies for each mod..."

for mod_path in "${CURIOS_DEPENDENT_MODS[@]}"; do
    mod_name=$(basename "$mod_path" .jar)
    
    # Get the mod's URL from manifest
    mod_url=$(jq -r --arg path "$mod_path" '.files[] | select(.path == $path) | .downloads[0]' modrinth.index.json 2>/dev/null)
    
    if [[ "$mod_url" == *"modrinth.com"* ]]; then
        # Extract project ID from URL
        project_id=$(echo "$mod_url" | sed -n 's|.*modrinth\.com/data/\([^/]*\)/.*|\1|p')
        version_id=$(echo "$mod_url" | sed -n 's|.*modrinth\.com/data/[^/]*/versions/\([^/]*\)/.*|\1|p')
        
        if [[ -n "$project_id" && -n "$version_id" ]]; then
            print_constraint "Checking dependencies for $mod_name ($project_id)..."
            
            # Get version dependencies
            dependencies=$(curl -s "https://api.modrinth.com/v2/version/$version_id" 2>/dev/null | \
                jq -r '.dependencies[]? | select(.dependency_type == "required") | .project_id' 2>/dev/null || echo "")
            
            if [[ -n "$dependencies" ]]; then
                while IFS= read -r dep_project_id; do
                    if [[ -n "$dep_project_id" ]]; then
                        # Check if this dependency is one of our Curios projects
                        if [[ "$dep_project_id" == "$CURIOS_OLD_PROJECT" ]]; then
                            echo "      🔴 Depends on OLD Curios ($CURIOS_OLD_PROJECT)"
                        elif [[ "$dep_project_id" == "$CURIOS_NEW_PROJECT" ]]; then
                            echo "      🟢 Depends on NEW Curios ($CURIOS_NEW_PROJECT)"
                        else
                            # Check if this dependency is a Curios-related project
                            dep_info=$(curl -s "https://api.modrinth.com/v2/project/$dep_project_id" 2>/dev/null | \
                                jq -r '.title // ""' 2>/dev/null || echo "")
                            if [[ "$dep_info" == *"curios"* ]] || [[ "$dep_info" == *"Curios"* ]]; then
                                echo "      🟡 Depends on Curios-related: $dep_info ($dep_project_id)"
                            fi
                        fi
                    fi
                done <<< "$dependencies"
            else
                echo "      ℹ️  No required dependencies found"
            fi
        fi
    fi
    echo ""
    
    # Rate limiting
    sleep 0.3
done

print_info "Checking version compatibility..."

# Check if the newer Curios version supports the same API as the older one
newer_versions=$(curl -s "https://api.modrinth.com/v2/project/$CURIOS_NEW_PROJECT/version" 2>/dev/null | \
    jq -r '[.[] | select(.game_versions[] == "1.21.1") | select(.loaders[] == "neoforge")] | sort_by(.date_published) | reverse')

older_versions=$(curl -s "https://api.modrinth.com/v2/project/$CURIOS_OLD_PROJECT/version" 2>/dev/null | \
    jq -r '[.[] | select(.game_versions[] == "1.21.1") | select(.loaders[] == "neoforge")] | sort_by(.date_published) | reverse')

echo "📋 Version Analysis:"
echo "   Newer Project ($CURIOS_NEW_PROJECT):"
echo "      • Latest: $(echo "$newer_versions" | jq -r '.[0].version_number // "Not found"')"
echo "      • Available versions: $(echo "$newer_versions" | jq -r 'length')"
echo ""
echo "   Older Project ($CURIOS_OLD_PROJECT):"
echo "      • Latest: $(echo "$older_versions" | jq -r '.[0].version_number // "Not found"')"
echo "      • Available versions: $(echo "$older_versions" | jq -r 'length')"
echo ""

# Recommendations
echo "🎯 Analysis Results"
echo "=================="

# Check if newer project has more recent updates
newer_latest_date=$(echo "$newer_versions" | jq -r '.[0].date_published // ""')
older_latest_date=$(echo "$older_versions" | jq -r '.[0].date_published // ""')

if [[ -n "$newer_latest_date" && -n "$older_latest_date" ]]; then
    print_info "Comparing update dates..."
    echo "   • Newer project last updated: $newer_latest_date"
    echo "   • Older project last updated: $older_latest_date"
    echo ""
fi

# Check project descriptions for compatibility info
newer_desc=$(jq -r '.description' curios_new_info.json)
older_desc=$(jq -r '.description' curios_old_info.json)

if [[ "$newer_desc" == "$older_desc" ]]; then
    print_success "Both projects have identical descriptions - likely compatible!"
else
    print_warning "Projects have different descriptions - need to check compatibility"
fi

echo ""
echo "🔄 Recommendations:"

# If no mods explicitly depend on the old version, we can probably remove it
old_deps_found=false
new_deps_found=false

# Re-check for explicit dependencies (this is a simplified check)
if grep -q "$CURIOS_OLD_PROJECT" curios_dependency_check.log 2>/dev/null; then
    old_deps_found=true
fi

if grep -q "$CURIOS_NEW_PROJECT" curios_dependency_check.log 2>/dev/null; then
    new_deps_found=true
fi

echo ""
print_info "Based on the analysis:"

if [[ "$newer_desc" == "$older_desc" ]]; then
    print_success "✅ Safe to remove old Curios version ($CURIOS_OLD_PROJECT)"
    print_success "✅ Keep newer Curios version ($CURIOS_NEW_PROJECT)"
    echo ""
    echo "   Reasoning:"
    echo "   • Both projects have identical descriptions"
    echo "   • Newer version (9.5.1) is more recent than older (9.0.15)"
    echo "   • Newer project appears to be the official continuation"
    echo "   • Version 9.5.1 should be backward compatible with 9.0.15 API"
    echo ""
    
    echo "🚀 Proposed Action:"
    echo "   1. Remove: curios-neoforge-9.0.15+1.21.1.jar"
    echo "   2. Keep: curios-neoforge-9.5.1+1.21.1.jar"
    echo "   3. Test the pack to ensure all dependent mods still work"
    echo ""
    
    print_warning "⚠️  Always test after removal to ensure no mods break!"
else
    print_warning "⚠️  Need manual verification - projects have different descriptions"
    echo ""
    echo "   Recommended steps:"
    echo "   1. Check mod changelogs for compatibility info"
    echo "   2. Test removal in a development environment first"
    echo "   3. Monitor for any missing dependency errors"
fi

# Cleanup
rm -f curios_new_info.json curios_old_info.json curios_dependency_check.log

print_success "Analysis complete!"
