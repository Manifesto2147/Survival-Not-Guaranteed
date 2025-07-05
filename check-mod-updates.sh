#!/bin/bash

# Mod Update Checker with Dependency Analysis
# This script checks for mod updates while respecting dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_update() { echo -e "${CYAN}🔄${NC} $1"; }
print_dependency() { echo -e "${PURPLE}🔗${NC} $1"; }

# Configuration
MINECRAFT_VERSION="1.21.1"
NEOFORGE_VERSION="21.1.180"
MANIFEST_FILE="modrinth.index.json"
DEPENDENCY_CACHE="mod_dependencies.json"
UPDATE_REPORT="update_report.json"
TEMP_DIR="temp_update_check"

# API endpoints
MODRINTH_API="https://api.modrinth.com/v2"
CURSEFORGE_API="https://api.curseforge.com/v1"

# Check if required tools are installed
check_dependencies() {
    print_info "Checking required tools..."
    
    local missing_tools=()
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install with: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    print_status "All required tools are available"
}

# Extract mod information from manifest
extract_mod_info() {
    print_info "Extracting mod information from manifest..."
    
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Extract mod information
    jq -r '.files[] | @base64' "$MANIFEST_FILE" | while read -r mod_data; do
        mod_info=$(echo "$mod_data" | base64 -d)
        
        path=$(echo "$mod_info" | jq -r '.path')
        url=$(echo "$mod_info" | jq -r '.downloads[0] // empty')
        env=$(echo "$mod_info" | jq -r '.env // {}')
        
        # Extract mod name from path
        mod_name=$(basename "$path" .jar)
        
        # Determine source platform
        platform="unknown"
        project_id=""
        
        if [[ "$url" == *"modrinth.com"* ]]; then
            platform="modrinth"
            # Extract project ID from URL
            if [[ "$url" =~ /data/([^/]+)/ ]]; then
                project_id="${BASH_REMATCH[1]}"
            fi
        elif [[ "$url" == *"curseforge.com"* ]] || [[ "$url" == *"forgecdn.net"* ]]; then
            platform="curseforge"
            # Extract project ID from URL patterns
            if [[ "$url" =~ /files/([0-9]+)/([0-9]+)/ ]]; then
                project_id="${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
            fi
        fi
        
        # Save mod info
        echo "$mod_info" | jq --arg name "$mod_name" --arg platform "$platform" --arg project_id "$project_id" \
            '. + {name: $name, platform: $platform, project_id: $project_id}' \
            > "$TEMP_DIR/${mod_name}.json"
    done
    
    print_status "Extracted information for $(ls -1 "$TEMP_DIR"/*.json 2>/dev/null | wc -l) mods"
}

# Get mod dependencies from Modrinth
get_modrinth_dependencies() {
    local project_id="$1"
    local version_id="$2"
    
    # Get project info
    local project_info=$(curl -s "$MODRINTH_API/project/$project_id" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$project_info" ]]; then
        return 1
    fi
    
    # Get version info if version_id is provided
    local version_info=""
    if [[ -n "$version_id" ]]; then
        version_info=$(curl -s "$MODRINTH_API/version/$version_id" 2>/dev/null)
    fi
    
    # Extract dependencies
    local dependencies=""
    if [[ -n "$version_info" ]]; then
        dependencies=$(echo "$version_info" | jq -r '.dependencies[]? | select(.dependency_type == "required") | .project_id')
    fi
    
    echo "$dependencies"
}

# Check for updates on Modrinth
check_modrinth_updates() {
    local project_id="$1"
    local current_version="$2"
    
    print_info "Checking Modrinth updates for project: $project_id"
    
    # Get project versions
    local versions=$(curl -s "$MODRINTH_API/project/$project_id/version?loaders=[%22neoforge%22]&game_versions=[%22$MINECRAFT_VERSION%22]" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$versions" ]]; then
        print_warning "Failed to fetch versions for $project_id"
        return 1
    fi
    
    # Get latest version
    local latest_version=$(echo "$versions" | jq -r '.[0] // empty')
    
    if [[ -z "$latest_version" ]]; then
        print_warning "No compatible versions found for $project_id"
        return 1
    fi
    
    local latest_version_number=$(echo "$latest_version" | jq -r '.version_number')
    local latest_version_id=$(echo "$latest_version" | jq -r '.id')
    local latest_date=$(echo "$latest_version" | jq -r '.date_published')
    
    # Get dependencies for latest version
    local dependencies=$(get_modrinth_dependencies "$project_id" "$latest_version_id")
    
    # Create update info
    local update_info=$(jq -n \
        --arg project_id "$project_id" \
        --arg current_version "$current_version" \
        --arg latest_version "$latest_version_number" \
        --arg latest_version_id "$latest_version_id" \
        --arg latest_date "$latest_date" \
        --argjson dependencies "$(echo "$dependencies" | jq -R -s -c 'split("\n") | map(select(. != ""))')" \
        '{
            project_id: $project_id,
            current_version: $current_version,
            latest_version: $latest_version,
            latest_version_id: $latest_version_id,
            latest_date: $latest_date,
            dependencies: $dependencies,
            has_update: ($current_version != $latest_version),
            platform: "modrinth"
        }')
    
    echo "$update_info"
}

# Build dependency graph
build_dependency_graph() {
    print_info "Building dependency graph..."
    
    local dependency_graph="{}"
    
    # Process each mod
    for mod_file in "$TEMP_DIR"/*.json; do
        if [[ ! -f "$mod_file" ]]; then
            continue
        fi
        
        local mod_info=$(cat "$mod_file")
        local mod_name=$(echo "$mod_info" | jq -r '.name')
        local platform=$(echo "$mod_info" | jq -r '.platform')
        local project_id=$(echo "$mod_info" | jq -r '.project_id')
        
        if [[ "$platform" == "modrinth" ]] && [[ -n "$project_id" ]]; then
            print_info "Getting dependencies for $mod_name..."
            
            # Get current version ID from URL
            local url=$(echo "$mod_info" | jq -r '.downloads[0]')
            local version_id=""
            if [[ "$url" =~ /versions/([^/]+)/ ]]; then
                version_id="${BASH_REMATCH[1]}"
            fi
            
            local dependencies=$(get_modrinth_dependencies "$project_id" "$version_id")
            
            # Add to dependency graph
            dependency_graph=$(echo "$dependency_graph" | jq --arg mod "$mod_name" --argjson deps "$(echo "$dependencies" | jq -R -s -c 'split("\n") | map(select(. != ""))')" \
                '. + {($mod): $deps}')
        fi
    done
    
    echo "$dependency_graph" > "$DEPENDENCY_CACHE"
    print_status "Dependency graph saved to $DEPENDENCY_CACHE"
}

# Check for updates
check_updates() {
    print_info "Checking for mod updates..."
    
    local updates="[]"
    
    # Process each mod
    for mod_file in "$TEMP_DIR"/*.json; do
        if [[ ! -f "$mod_file" ]]; then
            continue
        fi
        
        local mod_info=$(cat "$mod_file")
        local mod_name=$(echo "$mod_info" | jq -r '.name')
        local platform=$(echo "$mod_info" | jq -r '.platform')
        local project_id=$(echo "$mod_info" | jq -r '.project_id')
        
        if [[ "$platform" == "modrinth" ]] && [[ -n "$project_id" ]]; then
            print_info "Checking updates for $mod_name..."
            
            # Extract current version from filename
            local current_version=$(echo "$mod_name" | sed -E 's/.*-([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
            
            local update_info=$(check_modrinth_updates "$project_id" "$current_version")
            
            if [[ -n "$update_info" ]]; then
                updates=$(echo "$updates" | jq --argjson update "$update_info" '. + [$update]')
                
                local has_update=$(echo "$update_info" | jq -r '.has_update')
                if [[ "$has_update" == "true" ]]; then
                    local latest_version=$(echo "$update_info" | jq -r '.latest_version')
                    print_update "Update available for $mod_name: $current_version → $latest_version"
                fi
            fi
        else
            print_warning "Skipping $mod_name (platform: $platform, project_id: $project_id)"
        fi
    done
    
    echo "$updates" > "$UPDATE_REPORT"
    print_status "Update report saved to $UPDATE_REPORT"
}

# Analyze update safety
analyze_update_safety() {
    print_info "Analyzing update safety..."
    
    if [[ ! -f "$UPDATE_REPORT" ]]; then
        print_error "Update report not found. Run check_updates first."
        return 1
    fi
    
    local updates=$(cat "$UPDATE_REPORT")
    local dependency_graph="{}"
    
    if [[ -f "$DEPENDENCY_CACHE" ]]; then
        dependency_graph=$(cat "$DEPENDENCY_CACHE")
    fi
    
    echo "🔍 Update Safety Analysis"
    echo "========================"
    
    # Check each update
    echo "$updates" | jq -r '.[] | select(.has_update == true) | @base64' | while read -r update_data; do
        local update_info=$(echo "$update_data" | base64 -d)
        local project_id=$(echo "$update_info" | jq -r '.project_id')
        local current_version=$(echo "$update_info" | jq -r '.current_version')
        local latest_version=$(echo "$update_info" | jq -r '.latest_version')
        
        echo ""
        echo "📦 Project: $project_id"
        echo "   Current: $current_version"
        echo "   Latest:  $latest_version"
        
        # Check if this mod is a dependency of others
        local dependents=$(echo "$dependency_graph" | jq -r --arg pid "$project_id" 'to_entries[] | select(.value[] == $pid) | .key')
        
        if [[ -n "$dependents" ]]; then
            echo "   ⚠️  This mod is a dependency of:"
            echo "$dependents" | while read -r dependent; do
                echo "      - $dependent"
            done
            echo "   🔍 Consider testing thoroughly before updating"
        else
            echo "   ✅ Safe to update (no known dependents)"
        fi
        
        # Check dependencies of this mod
        local dependencies=$(echo "$update_info" | jq -r '.dependencies[]?')
        if [[ -n "$dependencies" ]]; then
            echo "   📎 Dependencies:"
            echo "$dependencies" | while read -r dep; do
                echo "      - $dep"
            done
        fi
    done
}

# Generate update recommendations
generate_recommendations() {
    print_info "Generating update recommendations..."
    
    if [[ ! -f "$UPDATE_REPORT" ]]; then
        print_error "Update report not found. Run check_updates first."
        return 1
    fi
    
    local updates=$(cat "$UPDATE_REPORT")
    local safe_updates="[]"
    local risky_updates="[]"
    
    # Categorize updates
    echo "$updates" | jq -r '.[] | select(.has_update == true) | @base64' | while read -r update_data; do
        local update_info=$(echo "$update_data" | base64 -d)
        local project_id=$(echo "$update_info" | jq -r '.project_id')
        
        # Simple risk assessment (can be enhanced)
        local risk_level="low"
        
        # Check if mod has many dependencies
        local dep_count=$(echo "$update_info" | jq -r '.dependencies | length')
        if [[ "$dep_count" -gt 3 ]]; then
            risk_level="medium"
        fi
        
        # Add risk assessment
        local enhanced_update=$(echo "$update_info" | jq --arg risk "$risk_level" '. + {risk_level: $risk}')
        
        if [[ "$risk_level" == "low" ]]; then
            safe_updates=$(echo "$safe_updates" | jq --argjson update "$enhanced_update" '. + [$update]')
        else
            risky_updates=$(echo "$risky_updates" | jq --argjson update "$enhanced_update" '. + [$update]')
        fi
    done
    
    echo "🎯 Update Recommendations"
    echo "========================"
    
    local safe_count=$(echo "$safe_updates" | jq 'length')
    local risky_count=$(echo "$risky_updates" | jq 'length')
    
    if [[ "$safe_count" -gt 0 ]]; then
        echo ""
        echo "✅ Safe Updates (Low Risk) - $safe_count available:"
        echo "$safe_updates" | jq -r '.[] | "   📦 \(.project_id): \(.current_version) → \(.latest_version)"'
    fi
    
    if [[ "$risky_count" -gt 0 ]]; then
        echo ""
        echo "⚠️  Risky Updates (Medium/High Risk) - $risky_count available:"
        echo "$risky_updates" | jq -r '.[] | "   📦 \(.project_id): \(.current_version) → \(.latest_version) (Risk: \(.risk_level))"'
    fi
    
    echo ""
    echo "💡 Recommendations:"
    echo "   1. Apply safe updates first in development branch"
    echo "   2. Test risky updates individually"
    echo "   3. Always backup before updating"
    echo "   4. Run dependency analysis after updates"
}

# Cleanup temporary files
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Main execution
main() {
    echo "🔄 Mod Update Checker with Dependency Analysis"
    echo "=============================================="
    
    # Setup cleanup trap
    trap cleanup EXIT
    
    case "${1:-check}" in
        "check")
            check_dependencies
            extract_mod_info
            build_dependency_graph
            check_updates
            analyze_update_safety
            generate_recommendations
            ;;
        "dependencies")
            check_dependencies
            extract_mod_info
            build_dependency_graph
            ;;
        "updates")
            check_dependencies
            extract_mod_info
            check_updates
            ;;
        "analyze")
            analyze_update_safety
            ;;
        "recommend")
            generate_recommendations
            ;;
        "clean")
            cleanup
            rm -f "$DEPENDENCY_CACHE" "$UPDATE_REPORT"
            print_status "Cleaned up temporary files"
            ;;
        *)
            echo "Usage: $0 [check|dependencies|updates|analyze|recommend|clean]"
            echo ""
            echo "Commands:"
            echo "  check        - Full update check with dependency analysis (default)"
            echo "  dependencies - Build dependency graph only"
            echo "  updates      - Check for updates only"
            echo "  analyze      - Analyze update safety"
            echo "  recommend    - Generate update recommendations"
            echo "  clean        - Clean up temporary files"
            ;;
    esac
}

main "$@"
