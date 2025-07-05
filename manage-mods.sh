#!/bin/bash

# Mod Management Master Script
# Comprehensive mod update workflow with dependency safety

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_header() { echo -e "${CYAN}🚀${NC} $1"; }

# Show banner
show_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                        🔧 Mod Management Suite                            ║"
    echo "║                   Safe Updates with Dependency Analysis                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if we're on develop branch
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [[ "$current_branch" != "develop" ]]; then
        print_warning "Not on develop branch (current: $current_branch)"
        echo "   🔄 Switch to develop branch for safe testing"
        echo "   💡 Run: git checkout develop"
        return 1
    fi
    
    # Check if required scripts exist
    local required_scripts=("check-mod-updates.sh" "apply-mod-updates.sh" "validate-dependencies.sh" "test-develop.sh")
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            print_error "Required script missing: $script"
            return 1
        fi
    done
    
    # Check if required tools are installed
    local required_tools=("jq" "curl" "git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool missing: $tool"
            return 1
        fi
    done
    
    print_status "All prerequisites satisfied"
    return 0
}

# Run full workflow
run_full_workflow() {
    print_header "Running Full Mod Update Workflow"
    
    echo "Step 1: Validate current dependencies"
    if ! ./validate-dependencies.sh; then
        print_error "Dependency validation failed"
        print_info "Fix dependency issues before proceeding"
        return 1
    fi
    
    echo ""
    echo "Step 2: Check for mod updates"
    if ! ./check-mod-updates.sh; then
        print_error "Update check failed"
        return 1
    fi
    
    echo ""
    echo "Step 3: Review available updates"
    ./apply-mod-updates.sh list
    
    echo ""
    echo "Step 4: Apply safe updates"
    read -p "Apply safe updates? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ./apply-mod-updates.sh safe; then
            print_status "Safe updates applied successfully"
        else
            print_error "Failed to apply safe updates"
            return 1
        fi
    else
        print_info "Skipping safe updates"
    fi
    
    echo ""
    echo "Step 5: Validate after updates"
    if ! ./validate-dependencies.sh; then
        print_error "Post-update validation failed"
        print_warning "Consider restoring from backup"
        return 1
    fi
    
    echo ""
    echo "Step 6: Test pack integrity"
    if ! ./test-develop.sh; then
        print_error "Pack integrity test failed"
        print_warning "Consider restoring from backup"
        return 1
    fi
    
    print_status "Full workflow completed successfully! 🎉"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Test the pack in PrismLauncher"
    echo "   2. Verify all mods work correctly"
    echo "   3. Commit changes if everything works"
    echo "   4. Create PR to merge into main"
}

# Quick update check
quick_check() {
    print_header "Quick Update Check"
    
    echo "Checking for mod updates..."
    ./check-mod-updates.sh updates
    
    echo ""
    echo "Available updates:"
    ./apply-mod-updates.sh list
}

# Interactive mode
interactive_mode() {
    print_header "Interactive Mod Management"
    
    while true; do
        echo ""
        echo "🔧 Mod Management Options:"
        echo "   1. Check for updates"
        echo "   2. Validate dependencies"
        echo "   3. Apply safe updates"
        echo "   4. Apply specific update"
        echo "   5. List available updates"
        echo "   6. Run full workflow"
        echo "   7. Test pack integrity"
        echo "   8. Clean up temporary files"
        echo "   9. Exit"
        echo ""
        
        read -p "Choose option (1-9): " -n 1 -r
        echo ""
        
        case $REPLY in
            1)
                echo ""
                print_info "Checking for updates..."
                ./check-mod-updates.sh
                ;;
            2)
                echo ""
                print_info "Validating dependencies..."
                ./validate-dependencies.sh
                ;;
            3)
                echo ""
                print_info "Applying safe updates..."
                ./apply-mod-updates.sh safe
                ;;
            4)
                echo ""
                read -p "Enter project ID: " project_id
                if [[ -n "$project_id" ]]; then
                    ./apply-mod-updates.sh update "$project_id"
                fi
                ;;
            5)
                echo ""
                ./apply-mod-updates.sh list
                ;;
            6)
                echo ""
                run_full_workflow
                ;;
            7)
                echo ""
                print_info "Testing pack integrity..."
                ./test-develop.sh
                ;;
            8)
                echo ""
                print_info "Cleaning up..."
                ./check-mod-updates.sh clean
                ./apply-mod-updates.sh clean
                ;;
            9)
                print_info "Goodbye! 👋"
                exit 0
                ;;
            *)
                print_warning "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Show help
show_help() {
    echo "Mod Management Master Script"
    echo "============================"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  workflow     - Run full update workflow (default)"
    echo "  check        - Quick update check"
    echo "  interactive  - Interactive mode"
    echo "  validate     - Validate dependencies only"
    echo "  prerequisites - Check prerequisites"
    echo ""
    echo "Full Workflow Steps:"
    echo "  1. Validate current dependencies"
    echo "  2. Check for mod updates"
    echo "  3. Review available updates"
    echo "  4. Apply safe updates (optional)"
    echo "  5. Validate after updates"
    echo "  6. Test pack integrity"
    echo ""
    echo "Safety Features:"
    echo "  ✅ Automatic backups before updates"
    echo "  ✅ Dependency validation"
    echo "  ✅ Environment compatibility checks"
    echo "  ✅ Conflict detection"
    echo "  ✅ Rollback capability"
    echo ""
    echo "Prerequisites:"
    echo "  - Must be on develop branch"
    echo "  - Required tools: jq, curl, git"
    echo "  - All management scripts present"
}

# Main execution
main() {
    show_banner
    
    case "${1:-workflow}" in
        "workflow")
            if check_prerequisites; then
                run_full_workflow
            fi
            ;;
        "check")
            if check_prerequisites; then
                quick_check
            fi
            ;;
        "interactive")
            if check_prerequisites; then
                interactive_mode
            fi
            ;;
        "validate")
            ./validate-dependencies.sh
            ;;
        "prerequisites")
            check_prerequisites
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
