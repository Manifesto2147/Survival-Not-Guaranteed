#!/bin/bash

# Mod Dependency Validator
# Validates mod dependencies and compatibility

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_dependency() { echo -e "${PURPLE}🔗${NC} $1"; }

# Configuration
MANIFEST_FILE="modrinth.index.json"
MINECRAFT_VERSION="1.21.1"
NEOFORGE_VERSION="21.1.180"
KNOWN_DEPENDENCIES="known_dependencies.json"

# Initialize known dependencies database
init_known_dependencies() {
    if [[ ! -f "$KNOWN_DEPENDENCIES" ]]; then
        print_info "Creating known dependencies database..."
        
        # Create a comprehensive dependency database
        cat > "$KNOWN_DEPENDENCIES" << 'EOF'
{
  "essential_libraries": [
    "bookshelf",
    "geckolib",
    "curios",
    "balm",
    "cloth-config",
    "architectury",
    "collective"
  ],
  "dependency_relationships": {
    "bookshelf": {
      "required_by": ["enchantment-descriptions", "searchables"],
      "description": "Library mod for Darkhax mods"
    },
    "geckolib": {
      "required_by": ["epic-knights", "cataclysm", "artifacts"],
      "description": "Animation library for complex models"
    },
    "curios": {
      "required_by": ["artifacts", "relics", "rings-of-ascension"],
      "description": "Equipment slot expansion API"
    },
    "balm": {
      "required_by": ["waystones", "cooking-for-blockheads", "farming-for-blockheads"],
      "description": "Multiplatform mod library"
    },
    "cloth-config": {
      "required_by": ["rei", "roughly-enough-items", "modmenu"],
      "description": "Configuration library"
    },
    "architectury": {
      "required_by": ["rei", "roughly-enough-items"],
      "description": "Multiplatform mod development framework"
    },
    "collective": {
      "required_by": ["collective-mods"],
      "description": "Shared library for Serilum mods"
    }
  },
  "environment_rules": {
    "client_only": [
      "optifine",
      "shader",
      "jei",
      "rei",
      "roughly-enough-items",
      "ambient-sounds",
      "sound-physics",
      "better-fps",
      "fps-reducer",
      "mouse-tweaks",
      "inventory-tweaks",
      "appleskin",
      "armor-hud",
      "minimap"
    ],
    "server_incompatible": [
      "optifine",
      "shader",
      "ambient-sounds",
      "sound-physics",
      "better-fps",
      "fps-reducer"
    ]
  },
  "known_conflicts": {
    "optifine": ["sodium", "iris", "rubidium"],
    "sodium": ["optifine"],
    "iris": ["optifine"],
    "rubidium": ["optifine"]
  }
}
EOF
        
        print_status "Known dependencies database created"
    fi
}

# Extract mod list from manifest
get_mod_list() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not found: $MANIFEST_FILE"
        return 1
    fi
    
    # Extract mod names from file paths
    jq -r '.files[].path' "$MANIFEST_FILE" | while read -r mod_path; do
        # Extract mod name from path and remove version/extension
        mod_name=$(basename "$mod_path" .jar | tr '[:upper:]' '[:lower:]')
        echo "$mod_name"
    done | sort -u
}

# Check for missing essential libraries
check_essential_libraries() {
    print_info "Checking for essential libraries..."
    
    local mod_list=$(get_mod_list)
    local essential_libs=$(jq -r '.essential_libraries[]' "$KNOWN_DEPENDENCIES")
    local missing_libs=()
    
    while read -r lib; do
        if ! echo "$mod_list" | grep -q "$lib"; then
            missing_libs+=("$lib")
        fi
    done <<< "$essential_libs"
    
    if [[ ${#missing_libs[@]} -eq 0 ]]; then
        print_status "All essential libraries are present"
        return 0
    else
        print_warning "Missing essential libraries:"
        for lib in "${missing_libs[@]}"; do
            print_error "  - $lib"
        done
        return 1
    fi
}

# Check dependency relationships
check_dependency_relationships() {
    print_info "Checking dependency relationships..."
    
    local mod_list=$(get_mod_list)
    local issues=()
    
    # Check each dependency relationship
    jq -r '.dependency_relationships | to_entries[] | @base64' "$KNOWN_DEPENDENCIES" | while read -r entry_data; do
        local entry=$(echo "$entry_data" | base64 -d)
        local library=$(echo "$entry" | jq -r '.key')
        local required_by=$(echo "$entry" | jq -r '.value.required_by[]?')
        local description=$(echo "$entry" | jq -r '.value.description')
        
        # Check if library is present
        if ! echo "$mod_list" | grep -q "$library"; then
            # Check if any mods that require this library are present
            local requiring_mods=()
            while read -r required_mod; do
                if echo "$mod_list" | grep -q "$required_mod"; then
                    requiring_mods+=("$required_mod")
                fi
            done <<< "$required_by"
            
            if [[ ${#requiring_mods[@]} -gt 0 ]]; then
                print_error "Missing dependency: $library"
                print_info "  Description: $description"
                print_info "  Required by: ${requiring_mods[*]}"
                issues+=("$library")
            fi
        fi
    done
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        print_status "All dependency relationships are satisfied"
        return 0
    else
        print_warning "Found ${#issues[@]} dependency issues"
        return 1
    fi
}

# Check for known conflicts
check_mod_conflicts() {
    print_info "Checking for known mod conflicts..."
    
    local mod_list=$(get_mod_list)
    local conflicts=()
    
    # Check each known conflict
    jq -r '.known_conflicts | to_entries[] | @base64' "$KNOWN_DEPENDENCIES" | while read -r conflict_data; do
        local conflict=$(echo "$conflict_data" | base64 -d)
        local mod_a=$(echo "$conflict" | jq -r '.key')
        local conflicting_mods=$(echo "$conflict" | jq -r '.value[]')
        
        # Check if mod_a is present
        if echo "$mod_list" | grep -q "$mod_a"; then
            # Check if any conflicting mods are also present
            while read -r mod_b; do
                if echo "$mod_list" | grep -q "$mod_b"; then
                    print_error "Conflict detected: $mod_a conflicts with $mod_b"
                    conflicts+=("$mod_a<->$mod_b")
                fi
            done <<< "$conflicting_mods"
        fi
    done
    
    if [[ ${#conflicts[@]} -eq 0 ]]; then
        print_status "No known conflicts detected"
        return 0
    else
        print_warning "Found ${#conflicts[@]} conflicts"
        return 1
    fi
}

# Validate environment compatibility
validate_environment() {
    print_info "Validating environment compatibility..."
    
    local client_only_count=0
    local server_only_count=0
    local universal_count=0
    local misconfigured_count=0
    
    # Analyze each mod's environment setting
    jq -r '.files[] | @base64' "$MANIFEST_FILE" | while read -r mod_data; do
        local mod_info=$(echo "$mod_data" | base64 -d)
        local mod_path=$(echo "$mod_info" | jq -r '.path')
        local mod_name=$(basename "$mod_path" .jar | sed -E 's/-[0-9]+\.[0-9]+(\.[0-9]+)?.*$//' | tr '[:upper:]' '[:lower:]')
        local env_client=$(echo "$mod_info" | jq -r '.env.client // "required"')
        local env_server=$(echo "$mod_info" | jq -r '.env.server // "required"')
        
        # Check if mod is properly categorized
        local client_only_mods=$(jq -r '.environment_rules.client_only[]' "$KNOWN_DEPENDENCIES")
        local server_incompatible_mods=$(jq -r '.environment_rules.server_incompatible[]' "$KNOWN_DEPENDENCIES")
        
        local should_be_client_only=false
        local should_be_server_incompatible=false
        
        while read -r client_mod; do
            if echo "$mod_name" | grep -q "$client_mod"; then
                should_be_client_only=true
                break
            fi
        done <<< "$client_only_mods"
        
        while read -r server_incompatible_mod; do
            if echo "$mod_name" | grep -q "$server_incompatible_mod"; then
                should_be_server_incompatible=true
                break
            fi
        done <<< "$server_incompatible_mods"
        
        # Validate configuration
        if [[ "$should_be_client_only" == true ]] && [[ "$env_server" != "unsupported" ]]; then
            print_warning "Mod $mod_name should be client-only but is configured as server-compatible"
            misconfigured_count=$((misconfigured_count + 1))
        fi
        
        if [[ "$should_be_server_incompatible" == true ]] && [[ "$env_server" == "required" ]]; then
            print_warning "Mod $mod_name should be server-incompatible but is configured as server-required"
            misconfigured_count=$((misconfigured_count + 1))
        fi
        
        # Count by environment
        if [[ "$env_client" == "required" ]] && [[ "$env_server" == "unsupported" ]]; then
            client_only_count=$((client_only_count + 1))
        elif [[ "$env_client" == "unsupported" ]] && [[ "$env_server" == "required" ]]; then
            server_only_count=$((server_only_count + 1))
        elif [[ "$env_client" == "required" ]] && [[ "$env_server" == "required" ]]; then
            universal_count=$((universal_count + 1))
        fi
    done
    
    echo ""
    echo "📊 Environment Distribution:"
    echo "   Universal mods: $universal_count"
    echo "   Client-only mods: $client_only_count"
    echo "   Server-only mods: $server_only_count"
    echo "   Misconfigured mods: $misconfigured_count"
    
    if [[ "$misconfigured_count" -eq 0 ]]; then
        print_status "Environment configuration is correct"
        return 0
    else
        print_warning "Found $misconfigured_count misconfigured mods"
        return 1
    fi
}

# Check version compatibility
check_version_compatibility() {
    print_info "Checking version compatibility..."
    
    local incompatible_count=0
    
    # Check Minecraft version compatibility
    local manifest_mc_version=$(jq -r '.dependencies.minecraft' "$MANIFEST_FILE")
    if [[ "$manifest_mc_version" != "$MINECRAFT_VERSION" ]]; then
        print_warning "Minecraft version mismatch: manifest($manifest_mc_version) vs expected($MINECRAFT_VERSION)"
        incompatible_count=$((incompatible_count + 1))
    fi
    
    # Check NeoForge version compatibility
    local manifest_neoforge_version=$(jq -r '.dependencies.neoforge // .dependencies.forge' "$MANIFEST_FILE")
    if [[ "$manifest_neoforge_version" != "$NEOFORGE_VERSION" ]]; then
        print_warning "NeoForge version mismatch: manifest($manifest_neoforge_version) vs expected($NEOFORGE_VERSION)"
        incompatible_count=$((incompatible_count + 1))
    fi
    
    if [[ "$incompatible_count" -eq 0 ]]; then
        print_status "Version compatibility is correct"
        return 0
    else
        print_warning "Found $incompatible_count version compatibility issues"
        return 1
    fi
}

# Generate dependency report
generate_dependency_report() {
    print_info "Generating dependency report..."
    
    local mod_list=$(get_mod_list)
    local report_file="dependency_report.json"
    
    # Create comprehensive report
    local report=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg minecraft_version "$MINECRAFT_VERSION" \
        --arg neoforge_version "$NEOFORGE_VERSION" \
        --argjson mod_list "$(echo "$mod_list" | jq -R -s -c 'split("\n") | map(select(. != ""))')" \
        '{
            timestamp: $timestamp,
            minecraft_version: $minecraft_version,
            neoforge_version: $neoforge_version,
            total_mods: ($mod_list | length),
            mod_list: $mod_list,
            validation_results: {
                essential_libraries: "pending",
                dependency_relationships: "pending",
                mod_conflicts: "pending",
                environment_compatibility: "pending",
                version_compatibility: "pending"
            }
        }')
    
    # Run validation checks and update report
    local results=""
    
    if check_essential_libraries; then
        results=$(echo "$results" | jq '.essential_libraries = "pass"')
    else
        results=$(echo "$results" | jq '.essential_libraries = "fail"')
    fi
    
    if check_dependency_relationships; then
        results=$(echo "$results" | jq '.dependency_relationships = "pass"')
    else
        results=$(echo "$results" | jq '.dependency_relationships = "fail"')
    fi
    
    if check_mod_conflicts; then
        results=$(echo "$results" | jq '.mod_conflicts = "pass"')
    else
        results=$(echo "$results" | jq '.mod_conflicts = "fail"')
    fi
    
    if validate_environment; then
        results=$(echo "$results" | jq '.environment_compatibility = "pass"')
    else
        results=$(echo "$results" | jq '.environment_compatibility = "fail"')
    fi
    
    if check_version_compatibility; then
        results=$(echo "$results" | jq '.version_compatibility = "pass"')
    else
        results=$(echo "$results" | jq '.version_compatibility = "fail"')
    fi
    
    # Update report with results
    echo "$report" | jq --argjson results "$results" '.validation_results = $results' > "$report_file"
    
    print_status "Dependency report saved to $report_file"
}

# Main validation function
run_full_validation() {
    echo "🔍 Mod Dependency Validation"
    echo "============================"
    
    init_known_dependencies
    
    local issues=0
    
    if ! check_essential_libraries; then
        issues=$((issues + 1))
    fi
    
    echo ""
    if ! check_dependency_relationships; then
        issues=$((issues + 1))
    fi
    
    echo ""
    if ! check_mod_conflicts; then
        issues=$((issues + 1))
    fi
    
    echo ""
    if ! validate_environment; then
        issues=$((issues + 1))
    fi
    
    echo ""
    if ! check_version_compatibility; then
        issues=$((issues + 1))
    fi
    
    echo ""
    echo "📋 Validation Summary:"
    
    if [[ "$issues" -eq 0 ]]; then
        print_status "All dependency validations passed! ✨"
        echo "   🎯 Ready for production"
        return 0
    else
        print_warning "Found $issues validation issues"
        echo "   🔧 Review and fix issues before proceeding"
        return 1
    fi
}

# Show help
show_help() {
    echo "Mod Dependency Validator"
    echo "======================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  validate    - Run full dependency validation (default)"
    echo "  libraries   - Check essential libraries only"
    echo "  deps        - Check dependency relationships only"
    echo "  conflicts   - Check for mod conflicts only"
    echo "  env         - Validate environment compatibility only"
    echo "  version     - Check version compatibility only"
    echo "  report      - Generate comprehensive dependency report"
    echo "  init        - Initialize known dependencies database"
    echo ""
    echo "Examples:"
    echo "  $0 validate    # Full validation"
    echo "  $0 libraries   # Check essential libraries"
    echo "  $0 conflicts   # Check for conflicts"
}

# Main execution
main() {
    case "${1:-validate}" in
        "validate")
            run_full_validation
            ;;
        "libraries")
            init_known_dependencies
            check_essential_libraries
            ;;
        "deps")
            init_known_dependencies
            check_dependency_relationships
            ;;
        "conflicts")
            init_known_dependencies
            check_mod_conflicts
            ;;
        "env")
            init_known_dependencies
            validate_environment
            ;;
        "version")
            check_version_compatibility
            ;;
        "report")
            init_known_dependencies
            generate_dependency_report
            ;;
        "init")
            init_known_dependencies
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
