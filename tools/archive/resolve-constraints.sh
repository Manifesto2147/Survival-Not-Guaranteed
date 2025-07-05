#!/bin/bash

# Smart Constraint Resolution System
# Handles complex dependency version constraints automatically

set -e

# Colors
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
print_constraint() { echo -e "${PURPLE}🔗${NC} $1"; }
print_resolve() { echo -e "${CYAN}🎯${NC} $1"; }

# Configuration
MODRINTH_API="https://api.modrinth.com/v2"
MINECRAFT_VERSION="1.21.1"
CONSTRAINT_DB="constraint_database.json"
RESOLUTION_LOG="resolution_log.json"

# Known constraint patterns for common mods
initialize_constraint_database() {
    if [[ ! -f "$CONSTRAINT_DB" ]]; then
        print_info "Creating constraint database..."
        
        cat > "$CONSTRAINT_DB" << 'EOF'
{
  "constraint_patterns": {
    "geckolib": {
      "dependents": ["epic-knights", "cataclysm", "artifacts", "ars-nouveau"],
      "version_pattern": "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*",
      "compatibility_rules": {
        "major_version_breaks": true,
        "minor_version_safe": true,
        "patch_version_safe": true
      }
    },
    "curios": {
      "dependents": ["artifacts", "gravestones", "rings-of-ascension"],
      "version_pattern": "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*",
      "compatibility_rules": {
        "major_version_breaks": true,
        "minor_version_safe": true,
        "patch_version_safe": true
      }
    },
    "bookshelf": {
      "dependents": ["enchantment-descriptions", "searchables"],
      "version_pattern": "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*",
      "compatibility_rules": {
        "major_version_breaks": true,
        "minor_version_safe": true,
        "patch_version_safe": true
      }
    },
    "architectury": {
      "dependents": ["rei", "roughly-enough-items"],
      "version_pattern": "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*",
      "compatibility_rules": {
        "major_version_breaks": true,
        "minor_version_safe": true,
        "patch_version_safe": true
      }
    }
  },
  "known_dependencies": {
    "epic-knights": ["geckolib"],
    "cataclysm": ["geckolib"],
    "artifacts": ["curios", "geckolib"],
    "gravestones": ["curios"],
    "enchantment-descriptions": ["bookshelf"],
    "searchables": ["bookshelf"],
    "rei": ["architectury"],
    "roughly-enough-items": ["architectury"]
  }
}
EOF
        
        print_status "Constraint database created"
    fi
}

# Parse semantic version
parse_semver() {
    local version="$1"
    local clean_version=$(echo "$version" | sed 's/+.*$//' | sed 's/-.*$//')
    
    if [[ "$clean_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        local patch="${BASH_REMATCH[3]}"
        echo "$major.$minor.$patch"
    else
        echo "$clean_version"
    fi
}

# Compare semantic versions
semver_compare() {
    local v1="$1"
    local v2="$2"
    
    v1=$(parse_semver "$v1")
    v2=$(parse_semver "$v2")
    
    # Convert to comparable format
    local v1_num=$(echo "$v1" | awk -F. '{printf("%d%03d%03d", $1, $2, $3)}')
    local v2_num=$(echo "$v2" | awk -F. '{printf("%d%03d%03d", $1, $2, $3)}')
    
    if [[ "$v1_num" -gt "$v2_num" ]]; then
        return 0  # v1 > v2
    elif [[ "$v1_num" -eq "$v2_num" ]]; then
        return 1  # v1 == v2
    else
        return 2  # v1 < v2
    fi
}

# Check if version change is safe based on semantic versioning rules
is_version_change_safe() {
    local old_version="$1"
    local new_version="$2"
    local dependency_name="$3"
    
    local old_semver=$(parse_semver "$old_version")
    local new_semver=$(parse_semver "$new_version")
    
    # Parse version components
    local old_major=$(echo "$old_semver" | cut -d. -f1)
    local old_minor=$(echo "$old_semver" | cut -d. -f2)
    local old_patch=$(echo "$old_semver" | cut -d. -f3)
    
    local new_major=$(echo "$new_semver" | cut -d. -f1)
    local new_minor=$(echo "$new_semver" | cut -d. -f2)
    local new_patch=$(echo "$new_semver" | cut -d. -f3)
    
    # Get compatibility rules from database
    local rules=$(jq -r --arg dep "$dependency_name" '.constraint_patterns[$dep].compatibility_rules // {}' "$CONSTRAINT_DB")
    local major_breaks=$(echo "$rules" | jq -r '.major_version_breaks // true')
    local minor_safe=$(echo "$rules" | jq -r '.minor_version_safe // true')
    local patch_safe=$(echo "$rules" | jq -r '.patch_version_safe // true')
    
    # Check version compatibility
    if [[ "$new_major" != "$old_major" ]]; then
        if [[ "$major_breaks" == "true" ]]; then
            print_warning "Major version change detected: $old_version → $new_version (potentially breaking)"
            return 1
        fi
    fi
    
    if [[ "$new_minor" != "$old_minor" ]]; then
        if [[ "$minor_safe" == "false" ]]; then
            print_warning "Minor version change detected: $old_version → $new_version (potentially breaking)"
            return 1
        fi
    fi
    
    # Patch version changes are generally safe
    print_info "Version change appears safe: $old_version → $new_version"
    return 0
}

# Get all dependents of a mod
get_dependents() {
    local mod_name="$1"
    local manifest_file="$2"
    
    # Get known dependents from constraint database
    local known_dependents=$(jq -r --arg mod "$mod_name" '.constraint_patterns[$mod].dependents[]? // empty' "$CONSTRAINT_DB")
    
    # Also check for mods in manifest that might depend on this mod
    local manifest_mods=$(jq -r '.files[].path' "$manifest_file" | sed 's|mods/||' | sed 's|\.jar$||' | tr '[:upper:]' '[:lower:]')
    
    local all_dependents=()
    
    # Add known dependents that are in the manifest
    while read -r dependent; do
        if echo "$manifest_mods" | grep -q "$dependent"; then
            all_dependents+=("$dependent")
        fi
    done <<< "$known_dependents"
    
    # Return unique dependents
    printf '%s\n' "${all_dependents[@]}" | sort -u
}

# Check if a dependency update is safe for all dependents
check_dependency_update_safety() {
    local dependency_name="$1"
    local old_version="$2"
    local new_version="$3"
    local manifest_file="$4"
    
    print_info "Checking dependency update safety for $dependency_name..."
    print_info "Version change: $old_version → $new_version"
    
    # Get all dependents
    local dependents=$(get_dependents "$dependency_name" "$manifest_file")
    
    if [[ -z "$dependents" ]]; then
        print_status "No dependents found - safe to update"
        return 0
    fi
    
    print_info "Found dependents: $(echo "$dependents" | tr '\n' ' ')"
    
    # Check semantic version compatibility
    if ! is_version_change_safe "$old_version" "$new_version" "$dependency_name"; then
        print_error "Version change is not safe based on semantic versioning rules"
        return 1
    fi
    
    # Check each dependent
    local unsafe_count=0
    
    while read -r dependent; do
        if [[ -n "$dependent" ]]; then
            print_info "Checking compatibility with $dependent..."
            
            # For now, if semantic version rules pass, we assume compatibility
            # In a more advanced implementation, you could:
            # 1. Check the dependent's mod page for version requirements
            # 2. Look at the dependent's mod metadata
            # 3. Check community compatibility reports
            
            print_status "$dependent appears compatible"
        fi
    done <<< "$dependents"
    
    if [[ "$unsafe_count" -eq 0 ]]; then
        print_status "All dependents appear compatible with $dependency_name $new_version"
        return 0
    else
        print_error "$unsafe_count dependents may not be compatible"
        return 1
    fi
}

# Resolve optimal version for a dependency with multiple constraints
resolve_optimal_version() {
    local dependency_name="$1"
    local manifest_file="$2"
    
    print_resolve "Resolving optimal version for $dependency_name..."
    
    # Get current version from manifest
    local current_entry=$(jq -r --arg dep "$dependency_name" '.files[] | select(.path | test($dep; "i"))' "$manifest_file")
    
    if [[ -z "$current_entry" ]]; then
        print_error "Dependency $dependency_name not found in manifest"
        return 1
    fi
    
    local current_path=$(echo "$current_entry" | jq -r '.path')
    local current_version=$(echo "$current_path" | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    
    print_info "Current version: $current_version"
    
    # Get project ID from URL
    local current_url=$(echo "$current_entry" | jq -r '.downloads[0]')
    local project_id=""
    
    if [[ "$current_url" =~ /data/([^/]+)/ ]]; then
        project_id="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$project_id" ]]; then
        print_error "Could not extract project ID for $dependency_name"
        return 1
    fi
    
    # Get available versions
    local versions=$(curl -s "$MODRINTH_API/project/$project_id/version?loaders=[%22neoforge%22]&game_versions=[%22$MINECRAFT_VERSION%22]")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to fetch versions for $dependency_name"
        return 1
    fi
    
    # Find the best version (latest that's compatible)
    local best_version=""
    local best_version_data=""
    
    echo "$versions" | jq -r '.[] | @base64' | while read -r version_data; do
        if [[ -z "$version_data" ]]; then continue; fi
        
        local version_info=$(echo "$version_data" | base64 -d)
        local version_number=$(echo "$version_info" | jq -r '.version_number')
        
        # Check if this version is safe to update to
        if check_dependency_update_safety "$dependency_name" "$current_version" "$version_number" "$manifest_file"; then
            if [[ -z "$best_version" ]]; then
                best_version="$version_number"
                best_version_data="$version_info"
            else
                # Compare versions and keep the newer one
                if semver_compare "$version_number" "$best_version"; then
                    best_version="$version_number"
                    best_version_data="$version_info"
                fi
            fi
        fi
    done
    
    if [[ -n "$best_version" ]]; then
        print_resolve "Optimal version for $dependency_name: $best_version"
        echo "$best_version_data"
        return 0
    else
        print_warning "No safe update found for $dependency_name"
        return 1
    fi
}

# Main constraint resolution function
resolve_constraints() {
    local manifest_file="${1:-modrinth.index.json}"
    
    print_info "Starting constraint resolution for $manifest_file..."
    
    initialize_constraint_database
    
    # Get all mods that are dependencies
    local dependencies=$(jq -r '.constraint_patterns | keys[]' "$CONSTRAINT_DB")
    
    local resolution_results="[]"
    
    while read -r dependency; do
        if [[ -n "$dependency" ]]; then
            print_info "Processing dependency: $dependency"
            
            # Check if this dependency is in the manifest
            if jq -r '.files[].path' "$manifest_file" | grep -qi "$dependency"; then
                local optimal_version=$(resolve_optimal_version "$dependency" "$manifest_file")
                
                if [[ $? -eq 0 ]]; then
                    # Add to resolution results
                    local result=$(echo "$optimal_version" | jq -c --arg dep "$dependency" '{
                        dependency: $dep,
                        recommended_version: .version_number,
                        version_id: .id,
                        download_url: .files[0].url,
                        filename: .files[0].filename,
                        resolution_status: "success"
                    }')
                    
                    resolution_results=$(echo "$resolution_results" | jq --argjson result "$result" '. + [$result]')
                else
                    # Add failure result
                    local result=$(jq -n --arg dep "$dependency" '{
                        dependency: $dep,
                        resolution_status: "failed",
                        reason: "no_safe_update"
                    }')
                    
                    resolution_results=$(echo "$resolution_results" | jq --argjson result "$result" '. + [$result]')
                fi
            fi
        fi
    done <<< "$dependencies"
    
    # Save resolution results
    echo "$resolution_results" > "$RESOLUTION_LOG"
    
    print_status "Constraint resolution completed"
    
    # Summary
    local successful=$(echo "$resolution_results" | jq '[.[] | select(.resolution_status == "success")] | length')
    local failed=$(echo "$resolution_results" | jq '[.[] | select(.resolution_status == "failed")] | length')
    
    echo ""
    echo "📊 Resolution Summary:"
    echo "   Successful resolutions: $successful"
    echo "   Failed resolutions: $failed"
    echo "   Results saved to: $RESOLUTION_LOG"
    
    return 0
}

# Show help
show_help() {
    echo "Smart Constraint Resolution System"
    echo "================================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  resolve [manifest]  - Resolve constraints for manifest (default: modrinth.index.json)"
    echo "  check <mod> <old> <new> - Check if version change is safe"
    echo "  dependents <mod>    - Show dependents of a mod"
    echo "  init                - Initialize constraint database"
    echo ""
    echo "Examples:"
    echo "  $0 resolve                    # Resolve all constraints"
    echo "  $0 check curios 9.5.1 9.5.3  # Check version safety"
    echo "  $0 dependents geckolib        # Show geckolib dependents"
}

# Main execution
main() {
    case "${1:-resolve}" in
        "resolve")
            resolve_constraints "${2:-modrinth.index.json}"
            ;;
        "check")
            if [[ -z "$2" || -z "$3" || -z "$4" ]]; then
                echo "Usage: $0 check <mod> <old_version> <new_version>"
                exit 1
            fi
            initialize_constraint_database
            check_dependency_update_safety "$2" "$3" "$4" "${5:-modrinth.index.json}"
            ;;
        "dependents")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 dependents <mod>"
                exit 1
            fi
            initialize_constraint_database
            get_dependents "$2" "${3:-modrinth.index.json}"
            ;;
        "init")
            initialize_constraint_database
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
