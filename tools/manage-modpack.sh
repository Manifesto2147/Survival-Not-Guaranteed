#!/bin/bash

# Comprehensive Modpack Management Script
# Handles mod updates, data validation, and directory structure verification

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
print_section() { echo -e "${PURPLE}▶️${NC} $1"; }

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="Modpack Manager"

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION
Comprehensive modpack management for PrismLauncher instances

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    validate        Validate directory structure and configuration
    update          Update mods from modrinth.index.json
    fix-data        Fix data validation errors (recipes, loot tables, etc.)
    check-deps      Check mod dependencies
    full-check      Run all validation and maintenance tasks
    help            Show this help message

OPTIONS:
    --dry-run       Show what would be done without making changes
    --verbose       Show detailed output
    --force         Force operations even if warnings exist

EXAMPLES:
    $0 validate                 # Validate directory structure
    $0 update --dry-run         # Show what mods would be updated
    $0 fix-data                 # Fix data validation errors
    $0 full-check               # Run comprehensive check
    $0 full-check --verbose     # Run comprehensive check with detailed output

DIRECTORY STRUCTURE:
This script expects the flat directory structure:
  - mods/                     # Mod files
  - config/                   # Configuration files  
  - scripts/                  # KubeJS scripts
  - shaderpacks/              # Shader packs
  - modrinth.index.json       # Mod manifest

SCRIPTS USED:
  - validate-directory-structure.sh
  - update-mods.sh
  - fix-data-validation-errors.sh
  - validate-dependencies.sh
EOF
}

check_dependencies() {
    print_section "Checking script dependencies..."
    
    local deps=(
        "jq:JSON processing"
        "curl:HTTP downloads"
        "unzip:Archive extraction"
        "shasum:File integrity"
    )
    
    for dep_info in "${deps[@]}"; do
        local dep="${dep_info%%:*}"
        local desc="${dep_info##*:}"
        
        if command -v "$dep" >/dev/null 2>&1; then
            print_status "$dep available ($desc)"
        else
            print_error "$dep not found ($desc)"
            return 1
        fi
    done
    
    # Check if required scripts exist
    local scripts=(
        "tools/validate-directory-structure.sh"
        "tools/update-mods.sh"
        "tools/fix-data-validation-errors.sh"
        "tools/validate-dependencies.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            print_status "$script found"
        else
            print_error "$script not found"
            return 1
        fi
    done
}

validate_structure() {
    print_section "Validating directory structure..."
    
    if [[ -x "tools/validate-directory-structure.sh" ]]; then
        ./tools/validate-directory-structure.sh
    else
        print_error "tools/validate-directory-structure.sh not executable"
        return 1
    fi
}

update_mods() {
    print_section "Updating mods..."
    
    local dry_run=""
    if [[ "$1" == "--dry-run" ]]; then
        dry_run="--validate"
        print_info "Running in dry-run mode (validation only)"
    fi
    
    if [[ -x "tools/update-mods.sh" ]]; then
        ./tools/update-mods.sh $dry_run
    else
        print_error "tools/update-mods.sh not executable"
        return 1
    fi
}

fix_data_validation() {
    print_section "Fixing data validation errors..."
    
    if [[ -x "tools/fix-data-validation-errors.sh" ]]; then
        ./tools/fix-data-validation-errors.sh
    else
        print_error "tools/fix-data-validation-errors.sh not executable"
        return 1
    fi
}

check_mod_dependencies() {
    print_section "Checking mod dependencies..."
    
    if [[ -x "tools/validate-dependencies.sh" ]]; then
        ./tools/validate-dependencies.sh
    else
        print_error "tools/validate-dependencies.sh not executable"
        return 1
    fi
}

full_check() {
    print_section "Running comprehensive modpack check..."
    
    local verbose=""
    local dry_run=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                verbose="--verbose"
                shift
                ;;
            --dry-run)
                dry_run="--dry-run"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    echo "=================================="
    echo "   COMPREHENSIVE MODPACK CHECK"
    echo "=================================="
    
    # Step 1: Check dependencies
    check_dependencies
    
    # Step 2: Validate directory structure
    validate_structure
    
    # Step 3: Check mod dependencies
    check_mod_dependencies
    
    # Step 4: Validate mods (dry run)
    update_mods --dry-run
    
    # Step 5: Check for data validation issues
    fix_data_validation
    
    echo "=================================="
    print_status "Comprehensive check completed!"
    echo "=================================="
    
    # Generate summary report
    generate_summary_report
}

generate_summary_report() {
    print_section "Generating summary report..."
    
    local report_file="modpack_management_report.txt"
    
    cat > "$report_file" << EOF
# Modpack Management Report
Generated: $(date)
Script Version: $SCRIPT_VERSION

## Directory Structure
$(if [[ -f "directory_structure_report.txt" ]]; then
    echo "✅ Directory structure validated successfully"
    echo "See: directory_structure_report.txt"
else
    echo "❌ Directory structure not validated"
fi)

## Mod Files
$(if [[ -f "modrinth.index.json" ]]; then
    local mod_count=$(jq '.files | length' modrinth.index.json 2>/dev/null || echo "unknown")
    echo "✅ Manifest found with $mod_count mod entries"
else
    echo "❌ No manifest found"
fi)

## Configuration
$(if [[ -d "config" ]]; then
    local configs=$(find config -name "*.toml" -o -name "*.json" 2>/dev/null | wc -l)
    echo "✅ Configuration files: $configs"
else
    echo "❌ Configuration directory not found"
fi)

## Data Validation Fixes
$(if [[ -f "fix-validation-errors.log" ]]; then
    echo "✅ Data validation fixes applied"
    echo "See: fix-validation-errors.log"
else
    echo "ℹ️ No data validation fixes needed"
fi)

## Recommendations
1. Run 'validate-directory-structure.sh' regularly to ensure proper structure
2. Use 'update-mods.sh --validate' to check for mod updates without applying them
3. Run 'fix-data-validation-errors.sh' after adding new mods
4. Check 'validate-dependencies.sh' when experiencing mod conflicts

## Next Steps
- Deploy any generated fixes to your server
- Monitor server logs for new errors
- Consider running full-check before major updates
EOF
    
    print_status "Summary report saved to: $report_file"
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        validate)
            validate_structure
            ;;
        update)
            shift
            update_mods "$@"
            ;;
        fix-data)
            fix_data_validation
            ;;
        check-deps)
            check_mod_dependencies
            ;;
        full-check)
            shift
            full_check "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
