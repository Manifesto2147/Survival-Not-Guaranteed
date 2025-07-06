#!/bin/bash

# Directory Structure Validator for PrismLauncher Instance
# Validates that all scripts and processes use correct directory paths

# Don't exit on non-zero returns from validation functions
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }

# Define expected directory structure for PrismLauncher
EXPECTED_DIRS=(
    "mods"
    "config"
    "scripts"
    "shaderpacks"
    "saves"
    "resourcepacks"
    "datapacks"
    "tools"
)

# Critical files and their expected locations
CRITICAL_FILES=(
    "modrinth.index.json"
    "build.sh"
    "tools/update-mods.sh"
    "tools/fix-data-validation-errors.sh"
    "tools/validate-dependencies.sh"
    "servers.dat"
    "options.txt"
)

validate_directory_structure() {
    print_info "Validating PrismLauncher directory structure..."
    
    local errors=0
    
    # Check expected directories
    for dir in "${EXPECTED_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            print_status "Directory exists: $dir"
        else
            print_error "Missing directory: $dir"
            ((errors++))
        fi
    done
    
    # Check critical files
    for file in "${CRITICAL_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            print_status "File exists: $file"
        else
            print_error "Missing file: $file"
            ((errors++))
        fi
    done
    
    return $errors
}

validate_script_paths() {
    print_info "Validating script directory references..."
    
    local errors=0
    local scripts=(
        "tools/update-mods.sh"
        "tools/fix-data-validation-errors.sh"
        "tools/validate-dependencies.sh"
        "build.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            print_info "Checking $script..."
            
            # Check for incorrect mod directory references
            if grep -q "minecraft/mods/" "$script" 2>/dev/null; then
                print_error "$script contains references to 'minecraft/mods/' instead of 'mods/'"
                ((errors++))
            fi
            
            # Check for correct mods references
            if grep -q "\"mods/" "$script" 2>/dev/null || grep -q "mods_dir.*mods" "$script" 2>/dev/null; then
                print_status "$script correctly references mods/"
            fi
            
            # Check for config directory references
            if grep -q "config/" "$script" 2>/dev/null; then
                # Check if it's using the old minecraft/config path
                if grep -q "minecraft/config/" "$script" 2>/dev/null; then
                    print_error "$script references minecraft/config/ - should use config/ instead"
                    ((errors++))
                else
                    print_status "$script correctly references config/"
                fi
            fi
        else
            print_warning "Script not found: $script"
        fi
    done
    
    return $errors
}

validate_manifest_paths() {
    print_info "Validating manifest file paths..."
    
    local errors=0
    
    if [[ -f "modrinth.index.json" ]]; then
        # Check if manifest contains correct paths
        if command -v jq >/dev/null 2>&1; then
            local mod_paths=$(jq -r '.files[] | select(.path | startswith("mods/")) | .path' modrinth.index.json 2>/dev/null)
            if [[ -n "$mod_paths" ]]; then
                print_status "Manifest contains mod paths (mods/...)"
                
                # Verify actual files exist in mods/
                while IFS= read -r mod_path; do
                    local actual_path="${mod_path}"
                    if [[ -f "$actual_path" ]]; then
                        print_status "Mod file exists: $actual_path"
                    else
                        print_error "Missing mod file: $actual_path"
                        ((errors++))
                    fi
                done <<< "$mod_paths"
            else
                print_warning "No mod paths found in manifest"
            fi
        else
            print_warning "jq not available - cannot validate manifest paths"
        fi
    else
        print_error "modrinth.index.json not found"
        ((errors++))
    fi
    
    return $errors
}

validate_config_structure() {
    print_info "Validating configuration structure..."
    
    local errors=0
    
    # Check if we have dual config directories (PrismLauncher style)
    if [[ -d "config" && -d "minecraft/config" ]]; then
        print_status "Both config directories exist (PrismLauncher style)"
        
        # Check if they have different purposes
        local root_configs=$(find config -name "*.toml" -o -name "*.json" 2>/dev/null | wc -l)
        local mc_configs=$(find minecraft/config -name "*.toml" -o -name "*.json" 2>/dev/null | wc -l)
        
        print_info "Root config files: $root_configs"
        print_info "Minecraft config files: $mc_configs"
        
        if [[ $root_configs -eq 0 && $mc_configs -eq 0 ]]; then
            print_warning "No configuration files found in either location"
        fi
    elif [[ -d "config" ]]; then
        print_status "Root config directory exists"
    elif [[ -d "minecraft/config" ]]; then
        print_status "Minecraft config directory exists"
    else
        print_error "No config directory found"
        ((errors++))
    fi
    
    return $errors
}

generate_fix_report() {
    print_info "Generating directory structure fix report..."
    
    local report_file="directory_structure_report.txt"
    
    cat > "$report_file" << EOF
# Directory Structure Validation Report
Generated: $(date)

## PrismLauncher Instance Structure
This instance follows the PrismLauncher directory structure:

- Root directory: Contains instance metadata and scripts
- minecraft/: Contains the actual Minecraft files
  - minecraft/mods/: Mod files
  - minecraft/config/: Minecraft configuration files
  - minecraft/saves/: World saves
  - minecraft/scripts/: CraftTweaker scripts
  - minecraft/shaderpacks/: Shader packs
- config/: Instance-specific configuration
- overrides/: Files to override in the pack

## Script Path Requirements
All scripts should reference:
- minecraft/mods/ for mod files
- minecraft/config/ for Minecraft configurations
- config/ for instance-specific configurations

## Manifest Path Mapping
The modrinth.index.json uses relative paths:
- "mods/filename.jar" maps to "minecraft/mods/filename.jar"
- "config/filename.toml" maps to "minecraft/config/filename.toml"

EOF
    
    print_status "Report saved to: $report_file"
}

main() {
    echo "=================================="
    echo "PrismLauncher Directory Validator"
    echo "=================================="
    
    local total_errors=0
    
    # Run all validations
    validate_directory_structure
    total_errors=$((total_errors + $?))
    
    validate_script_paths
    total_errors=$((total_errors + $?))
    
    validate_manifest_paths
    total_errors=$((total_errors + $?))
    
    validate_config_structure
    total_errors=$((total_errors + $?))
    
    generate_fix_report
    
    echo "=================================="
    if [[ $total_errors -eq 0 ]]; then
        print_status "All validations passed! Directory structure is correct."
    else
        print_error "Found $total_errors issues. Please review and fix."
        exit 1
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
