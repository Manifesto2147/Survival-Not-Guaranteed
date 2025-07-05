#!/bin/bash

# Advanced Dependency Constraint Resolver
# Analyzes mod dependencies and resolves version conflicts

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
print_constraint() { echo -e "${PURPLE}🔗${NC} $1"; }
print_resolve() { echo -e "${CYAN}🎯${NC} $1"; }

# Configuration
MANIFEST_FILE="modrinth.index.json"
DEPENDENCY_CONSTRAINTS="dependency_constraints.json"
CONSTRAINT_CACHE="constraint_cache.json"
RESOLUTION_REPORT="resolution_report.json"
MINECRAFT_VERSION="1.21.1"
NEOFORGE_VERSION="21.1.180"

# API endpoints
MODRINTH_API="https://api.modrinth.com/v2"

# Initialize or load dependency constraints database
init_dependency_constraints() {
    if [[ ! -f "$DEPENDENCY_CONSTRAINTS" ]]; then
        print_info "Creating dependency constraints database..."
        
        cat > "$DEPENDENCY_CONSTRAINTS" << 'EOF'
{
  "known_dependencies": {
    "bookshelf": {
      "dependents": ["enchantment-descriptions", "searchables", "torchmaster"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "21.1.0",
          "max_version": "21.99.99",
          "compatible_versions": ["21.1.65", "21.1.66", "21.1.67"]
        }
      }
    },
    "geckolib": {
      "dependents": ["epic-knights", "cataclysm", "artifacts", "azurelib"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "4.7.0",
          "max_version": "4.99.99",
          "compatible_versions": ["4.7.6", "4.7.7", "4.7.8"]
        }
      }
    },
    "curios": {
      "dependents": ["artifacts", "relics", "rings-of-ascension", "gravestones"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "9.0.0",
          "max_version": "9.99.99",
          "compatible_versions": ["9.5.1", "9.5.2", "9.5.3"]
        }
      }
    },
    "balm": {
      "dependents": ["waystones", "cooking-for-blockheads", "farming-for-blockheads"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "21.0.0",
          "max_version": "21.99.99",
          "compatible_versions": ["21.0.46", "21.0.47", "21.0.48"]
        }
      }
    },
    "cloth-config": {
      "dependents": ["rei", "roughly-enough-items", "modmenu", "configured"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "15.0.0",
          "max_version": "15.99.99",
          "compatible_versions": ["15.0.140", "15.0.141", "15.0.142"]
        }
      }
    },
    "architectury": {
      "dependents": ["rei", "roughly-enough-items", "cloth-config"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "13.0.0",
          "max_version": "13.99.99",
          "compatible_versions": ["13.0.8", "13.0.9", "13.0.10"]
        }
      }
    },
    "collective": {
      "dependents": ["serilum-mods"],
      "version_constraints": {
        "minecraft_1.21.1": {
          "min_version": "8.0.0",
          "max_version": "8.99.99",
          "compatible_versions": ["8.3", "8.4", "8.5"]
        }
      }
    }
  },
  "dependency_mappings": {
    "epic-knights": ["geckolib"],
    "cataclysm": ["geckolib"],
    "artifacts": ["curios", "geckolib"],
    "enchantment-descriptions": ["bookshelf"],
    "searchables": ["bookshelf"],
    "waystones": ["balm"],
    "cooking-for-blockheads": ["balm"],
    "farming-for-blockheads": ["balm"],
    "rei": ["architectury", "cloth-config"],
    "roughly-enough-items": ["architectury", "cloth-config"]
  }
}
EOF
        
        print_status "Dependency constraints database created"
    fi
}

# Get current mod versions from manifest
get_current_versions() {
    print_info "Extracting current mod versions..."
    
    local current_versions="{}"
    
    # Extract mod information from manifest
    jq -r '.files[] | @base64' "$MANIFEST_FILE" | while read -r mod_data; do
        local mod_info=$(echo "$mod_data" | base64 -d)
        local mod_path=$(echo "$mod_info" | jq -r '.path')
        local mod_filename=$(basename "$mod_path" .jar)
        
        # Extract mod name and version
        local mod_name=$(echo "$mod_filename" | tr '[:upper:]' '[:lower:]' | sed -E 's/-(neoforge|fabric|forge)-.*$//' | sed -E 's/-mc[0-9]+\.[0-9]+(\.[0-9]+)?//' | sed -E 's/-[0-9]+\.[0-9]+.*$//')
        local mod_version=$(echo "$mod_filename" | sed -E 's/.*-([0-9]+\.[0-9]+(\.[0-9]+)?[^-]*).*/\1/')
        
        # Store version info
        current_versions=$(echo "$current_versions" | jq --arg name "$mod_name" --arg version "$mod_version" --arg path "$mod_path" \
            '. + {($name): {version: $version, path: $path}}')
    done
    
    echo "$current_versions" > "current_versions.json"
    print_status "Current versions extracted"
}

# Get dependency constraints for a specific mod
get_dependency_constraints() {
    local mod_name="$1"
    local project_id="$2"
    
    print_info "Getting dependency constraints for $mod_name (project: $project_id)"
    
    # Get project info from Modrinth
    local project_info=$(curl -s "$MODRINTH_API/project/$project_id" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$project_info" ]]; then
        print_warning "Failed to get project info for $project_id"
        return 1
    fi
    
    # Get all versions for this project
    local versions=$(curl -s "$MODRINTH_API/project/$project_id/version?loaders=[%22neoforge%22]&game_versions=[%22$MINECRAFT_VERSION%22]" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$versions" ]]; then
        print_warning "Failed to get versions for $project_id"
        return 1
    fi
    
    # Analyze dependencies for each version
    local version_constraints="[]"
    
    echo "$versions" | jq -r '.[0:5][] | @base64' | while read -r version_data; do
        local version_info=$(echo "$version_data" | base64 -d)
        local version_number=$(echo "$version_info" | jq -r '.version_number')
        local version_id=$(echo "$version_info" | jq -r '.id')
        local dependencies=$(echo "$version_info" | jq -r '.dependencies[]? | select(.dependency_type == "required") | .project_id')
        
        # Get dependency version constraints
        local dep_constraints="[]"
        while read -r dep_project_id; do
            if [[ -n "$dep_project_id" ]]; then
                # Get dependency project info
                local dep_project=$(curl -s "$MODRINTH_API/project/$dep_project_id" 2>/dev/null)
                if [[ -n "$dep_project" ]]; then
                    local dep_slug=$(echo "$dep_project" | jq -r '.slug')
                    local dep_constraint=$(jq -n \
                        --arg slug "$dep_slug" \
                        --arg project_id "$dep_project_id" \
                        '{dependency: $slug, project_id: $project_id}')
                    dep_constraints=$(echo "$dep_constraints" | jq --argjson constraint "$dep_constraint" '. + [$constraint]')
                fi
            fi
        done <<< "$dependencies"
        
        # Store version constraint info
        local version_constraint=$(jq -n \
            --arg version "$version_number" \
            --arg version_id "$version_id" \
            --argjson dependencies "$dep_constraints" \
            '{version: $version, version_id: $version_id, dependencies: $dependencies}')
        
        version_constraints=$(echo "$version_constraints" | jq --argjson constraint "$version_constraint" '. + [$constraint]')
    done
    
    # Store constraints in cache
    local cache_entry=$(jq -n \
        --arg mod_name "$mod_name" \
        --arg project_id "$project_id" \
        --argjson constraints "$version_constraints" \
        '{mod_name: $mod_name, project_id: $project_id, constraints: $constraints, timestamp: now}')
    
    # Update cache
    if [[ ! -f "$CONSTRAINT_CACHE" ]]; then
        echo "[]" > "$CONSTRAINT_CACHE"
    fi
    
    local updated_cache=$(cat "$CONSTRAINT_CACHE" | jq --argjson entry "$cache_entry" '. + [$entry]')
    echo "$updated_cache" > "$CONSTRAINT_CACHE"
    
    print_status "Constraints cached for $mod_name"
}

# Find compatible version for a dependency
find_compatible_version() {
    local dependency_name="$1"
    local dependent_mods="$2"
    
    print_info "Finding compatible version for $dependency_name"
    print_info "Dependent mods: $dependent_mods"
    
    # Get all available versions of the dependency
    local dependency_project_id=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].project_id // empty' "$DEPENDENCY_CONSTRAINTS")
    
    if [[ -z "$dependency_project_id" ]]; then
        print_warning "No project ID found for $dependency_name"
        return 1
    fi
    
    # Get versions from Modrinth
    local versions=$(curl -s "$MODRINTH_API/project/$dependency_project_id/version?loaders=[%22neoforge%22]&game_versions=[%22$MINECRAFT_VERSION%22]" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$versions" ]]; then
        print_warning "Failed to get versions for $dependency_name"
        return 1
    fi
    
    # Analyze each version for compatibility
    local compatible_versions="[]"
    
    echo "$versions" | jq -r '.[] | @base64' | while read -r version_data; do
        local version_info=$(echo "$version_data" | base64 -d)
        local version_number=$(echo "$version_info" | jq -r '.version_number')
        local version_date=$(echo "$version_info" | jq -r '.date_published')
        
        # Check if this version is compatible with all dependent mods
        local is_compatible=true
        
        # For now, use simple version constraints from our database
        local min_version=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].version_constraints.minecraft_1_21_1.min_version // "0.0.0"' "$DEPENDENCY_CONSTRAINTS")
        local max_version=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].version_constraints.minecraft_1_21_1.max_version // "999.999.999"' "$DEPENDENCY_CONSTRAINTS")
        
        # Simple version comparison (could be enhanced with proper semver)
        if [[ "$version_number" < "$min_version" ]] || [[ "$version_number" > "$max_version" ]]; then
            is_compatible=false
        fi
        
        if [[ "$is_compatible" == "true" ]]; then
            local compatible_version=$(jq -n \
                --arg version "$version_number" \
                --arg date "$version_date" \
                --arg compatibility "high" \
                '{version: $version, date: $date, compatibility: $compatibility}')
            
            compatible_versions=$(echo "$compatible_versions" | jq --argjson version "$compatible_version" '. + [$version]')
        fi
    done
    
    # Sort by date and return the most recent compatible version
    local best_version=$(echo "$compatible_versions" | jq -r 'sort_by(.date) | reverse | .[0].version // empty')
    
    if [[ -n "$best_version" ]]; then
        print_resolve "Best compatible version for $dependency_name: $best_version"
        echo "$best_version"
        return 0
    else
        print_warning "No compatible version found for $dependency_name"
        return 1
    fi
}

# Resolve dependency conflicts
resolve_dependency_conflicts() {
    print_info "Resolving dependency conflicts..."
    
    # Get current versions
    get_current_versions
    
    # Get installed mods that are dependencies
    local dependencies=$(jq -r '.known_dependencies | keys[]' "$DEPENDENCY_CONSTRAINTS")
    
    local resolution_results="[]"
    
    while read -r dependency; do
        print_info "Analyzing dependency: $dependency"
        
        # Get current version
        local current_version=$(jq -r --arg dep "$dependency" '.[$dep].version // "not-found"' "current_versions.json")
        
        if [[ "$current_version" == "not-found" ]]; then
            print_warning "Dependency $dependency not found in current modpack"
            continue
        fi
        
        # Get dependent mods
        local dependents=$(jq -r --arg dep "$dependency" '.known_dependencies[$dep].dependents[]' "$DEPENDENCY_CONSTRAINTS")
        
        # Check if any dependent mods are installed
        local installed_dependents="[]"
        while read -r dependent; do
            local dependent_version=$(jq -r --arg dep "$dependent" '.[$dep].version // "not-found"' "current_versions.json")
            if [[ "$dependent_version" != "not-found" ]]; then
                installed_dependents=$(echo "$installed_dependents" | jq --arg dep "$dependent" --arg version "$dependent_version" '. + [{name: $dep, version: $version}]')
            fi
        done <<< "$dependents"
        
        local installed_count=$(echo "$installed_dependents" | jq 'length')
        
        if [[ "$installed_count" -gt 0 ]]; then
            print_info "Found $installed_count installed dependents for $dependency"
            
            # Find compatible version
            local compatible_version=$(find_compatible_version "$dependency" "$installed_dependents")
            
            if [[ -n "$compatible_version" ]]; then
                # Create resolution result
                local resolution=$(jq -n \
                    --arg dependency "$dependency" \
                    --arg current_version "$current_version" \
                    --arg compatible_version "$compatible_version" \
                    --argjson dependents "$installed_dependents" \
                    '{
                        dependency: $dependency,
                        current_version: $current_version,
                        recommended_version: $compatible_version,
                        dependents: $dependents,
                        needs_update: ($current_version != $compatible_version),
                        resolution_status: "resolved"
                    }')
                
                resolution_results=$(echo "$resolution_results" | jq --argjson resolution "$resolution" '. + [$resolution]')
                
                if [[ "$current_version" != "$compatible_version" ]]; then
                    print_resolve "Update recommendation: $dependency $current_version → $compatible_version"
                else
                    print_status "Already optimal: $dependency $current_version"
                fi
            else
                print_warning "Could not resolve version for $dependency"
            fi
        else
            print_info "No installed dependents found for $dependency"
        fi
        
    done <<< "$dependencies"
    
    # Save resolution results
    local resolution_report=$(jq -n \
        --argjson results "$resolution_results" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            timestamp: $timestamp,
            minecraft_version: "1.21.1",
            neoforge_version: "21.1.180",
            resolutions: $results,
            summary: {
                total_dependencies: ($results | length),
                needs_update: ($results | map(select(.needs_update == true)) | length),
                resolved: ($results | map(select(.resolution_status == "resolved")) | length)
            }
        }')
    
    echo "$resolution_report" > "$RESOLUTION_REPORT"
    print_status "Resolution report saved to $RESOLUTION_REPORT"
}

# Generate constraint analysis report
generate_constraint_report() {
    print_info "Generating constraint analysis report..."
    
    if [[ ! -f "$RESOLUTION_REPORT" ]]; then
        print_error "Resolution report not found. Run resolve_dependency_conflicts first."
        return 1
    fi
    
    local report=$(cat "$RESOLUTION_REPORT")
    
    echo ""
    echo "🎯 Dependency Constraint Analysis Report"
    echo "========================================"
    echo ""
    
    local total_deps=$(echo "$report" | jq '.summary.total_dependencies')
    local needs_update=$(echo "$report" | jq '.summary.needs_update')
    local resolved=$(echo "$report" | jq '.summary.resolved')
    
    echo "📊 Summary:"
    echo "   Total dependencies analyzed: $total_deps"
    echo "   Need updates: $needs_update"
    echo "   Successfully resolved: $resolved"
    echo ""
    
    if [[ "$needs_update" -gt 0 ]]; then
        echo "🔄 Recommended Updates:"
        echo "======================"
        echo "$report" | jq -r '.resolutions[] | select(.needs_update == true) | 
            "📦 \(.dependency): \(.current_version) → \(.recommended_version)\n   Dependents: \(.dependents | map(.name) | join(", "))\n"'
    fi
    
    echo "✅ Already Optimal:"
    echo "=================="
    echo "$report" | jq -r '.resolutions[] | select(.needs_update == false) | 
        "📦 \(.dependency): \(.current_version) ✓\n   Dependents: \(.dependents | map(.name) | join(", "))\n"'
    
    echo ""
    echo "💡 Resolution Strategy:"
    echo "======================"
    echo "   1. Update dependencies in dependency order"
    echo "   2. Test each update individually"
    echo "   3. Verify all dependents still work"
    echo "   4. Apply updates in develop branch first"
}

# Check specific dependency update compatibility
check_dependency_update() {
    local dependency_name="$1"
    local target_version="$2"
    
    if [[ -z "$dependency_name" ]]; then
        print_error "Dependency name required"
        return 1
    fi
    
    print_info "Checking compatibility for $dependency_name update to $target_version"
    
    # Get current dependents
    local dependents=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].dependents[]?' "$DEPENDENCY_CONSTRAINTS")
    
    if [[ -z "$dependents" ]]; then
        print_warning "No known dependents for $dependency_name"
        return 1
    fi
    
    echo "🔍 Checking compatibility with dependents:"
    while read -r dependent; do
        echo "   📦 $dependent"
        
        # Check if dependent is installed
        local dependent_version=$(jq -r --arg dep "$dependent" '.[$dep].version // "not-found"' "current_versions.json")
        if [[ "$dependent_version" != "not-found" ]]; then
            echo "      Current version: $dependent_version"
            echo "      Compatibility: Checking..."
            
            # Here you would check actual compatibility
            # For now, use basic version constraints
            local min_version=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].version_constraints.minecraft_1_21_1.min_version // "0.0.0"' "$DEPENDENCY_CONSTRAINTS")
            local max_version=$(jq -r --arg dep "$dependency_name" '.known_dependencies[$dep].version_constraints.minecraft_1_21_1.max_version // "999.999.999"' "$DEPENDENCY_CONSTRAINTS")
            
            if [[ "$target_version" > "$min_version" ]] && [[ "$target_version" < "$max_version" ]]; then
                echo "      ✅ Compatible"
            else
                echo "      ❌ Potentially incompatible"
            fi
        else
            echo "      ⚠️  Not installed"
        fi
    done <<< "$dependents"
}

# Show help
show_help() {
    echo "Advanced Dependency Constraint Resolver"
    echo "======================================"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  resolve           - Resolve all dependency conflicts (default)"
    echo "  report            - Generate constraint analysis report"
    echo "  check <dep> [ver] - Check specific dependency update compatibility"
    echo "  init              - Initialize dependency constraints database"
    echo "  clean             - Clean up temporary files"
    echo ""
    echo "Examples:"
    echo "  $0 resolve                    # Resolve all conflicts"
    echo "  $0 check geckolib 4.7.7      # Check geckolib update"
    echo "  $0 report                     # Show analysis report"
    echo ""
    echo "Features:"
    echo "  ✅ Version constraint analysis"
    echo "  ✅ Multi-dependent resolution"
    echo "  ✅ Compatibility checking"
    echo "  ✅ Optimal version selection"
}

# Main execution
main() {
    case "${1:-resolve}" in
        "resolve")
            init_dependency_constraints
            resolve_dependency_conflicts
            generate_constraint_report
            ;;
        "report")
            generate_constraint_report
            ;;
        "check")
            if [[ -z "$2" ]]; then
                print_error "Dependency name required"
                show_help
                exit 1
            fi
            init_dependency_constraints
            get_current_versions
            check_dependency_update "$2" "$3"
            ;;
        "init")
            init_dependency_constraints
            ;;
        "clean")
            rm -f "$CONSTRAINT_CACHE" "$RESOLUTION_REPORT" "current_versions.json"
            print_status "Cleaned up temporary files"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
