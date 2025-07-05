#!/bin/bash

# Workspace Cleanup and Organization Script
# Clean up redundant files and organize our mod management tools

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC} $1"; }
print_check() { echo -e "${PURPLE}🔍${NC} $1"; }
print_action() { echo -e "${CYAN}🔧${NC} $1"; }

echo "🧹 Workspace Cleanup and Organization"
echo "====================================="
echo ""

# Create organized directories
print_action "Creating organized directory structure..."
mkdir -p tools/core
mkdir -p tools/analysis
mkdir -p tools/demo
mkdir -p tools/archive
mkdir -p docs/reports

echo ""

# Define our core tools that should be kept
print_check "Identifying core tools..."
echo ""

CORE_TOOLS=(
    "update-mods.sh"           # Main automated update system
    "validate-dependencies.sh"  # Dependency validation
    "manage-mods.sh"           # High-level mod management
)

ANALYSIS_TOOLS=(
    "analyze-curios-dependencies.sh"  # Curios analysis (historical)
    "final-curios-analysis.sh"        # Final Curios analysis
    "curios-analysis-final-report.sh" # Final report
)

DEMO_TOOLS=(
    "demo-constraint-resolution.sh"   # Constraint resolution demo
    "demo-update-system.sh"           # Update system demo
)

REDUNDANT_TOOLS=(
    "apply-mod-updates.sh"            # Replaced by update-mods.sh
    "check-mod-updates.sh"            # Integrated into update-mods.sh
    "auto-update-mods.sh"             # Replaced by update-mods.sh
    "resolve-constraints.sh"          # Integrated into update-mods.sh
    "resolve-dependency-constraints.sh" # Integrated into update-mods.sh
    "complete-workflow.sh"            # Replaced by manage-mods.sh
    "curios-cleanup-summary.sh"       # Completed task
    "remove-curios-duplicate.sh"      # Completed task
    "verify-curios-cleanup.sh"        # Completed task
)

echo "📦 Core Tools (Keep in tools/core/):"
for tool in "${CORE_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        echo "   ✅ $tool"
    else
        echo "   ❌ $tool (missing)"
    fi
done

echo ""
echo "📊 Analysis Tools (Keep in tools/analysis/):"
for tool in "${ANALYSIS_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        echo "   ✅ $tool"
    else
        echo "   ❌ $tool (missing)"
    fi
done

echo ""
echo "🎭 Demo Tools (Keep in tools/demo/):"
for tool in "${DEMO_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        echo "   ✅ $tool"
    else
        echo "   ❌ $tool (missing)"
    fi
done

echo ""
echo "🗑️  Redundant Tools (Archive in tools/archive/):"
for tool in "${REDUNDANT_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        echo "   ⚠️  $tool (will be archived)"
    else
        echo "   ✅ $tool (already removed)"
    fi
done

echo ""
print_action "Organizing files..."

# Move core tools
for tool in "${CORE_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        mv "$tool" "tools/core/"
        echo "   📦 Moved $tool to tools/core/"
    fi
done

# Move analysis tools
for tool in "${ANALYSIS_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        mv "$tool" "tools/analysis/"
        echo "   📊 Moved $tool to tools/analysis/"
    fi
done

# Move demo tools
for tool in "${DEMO_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        mv "$tool" "tools/demo/"
        echo "   🎭 Moved $tool to tools/demo/"
    fi
done

# Archive redundant tools
for tool in "${REDUNDANT_TOOLS[@]}"; do
    if [ -f "$tool" ]; then
        mv "$tool" "tools/archive/"
        echo "   🗑️  Archived $tool to tools/archive/"
    fi
done

echo ""
print_check "Checking for any remaining scripts..."
REMAINING_SCRIPTS=$(ls -1 *.sh 2>/dev/null | wc -l)
if [ "$REMAINING_SCRIPTS" -gt 0 ]; then
    echo "   📋 Remaining scripts to review:"
    ls -1 *.sh 2>/dev/null | while read -r script; do
        echo "      • $script"
    done
else
    print_success "All scripts have been organized!"
fi

echo ""
print_action "Creating convenience symlinks..."

# Create symlinks for frequently used tools
ln -sf "tools/core/update-mods.sh" "update-mods.sh"
ln -sf "tools/core/validate-dependencies.sh" "validate-dependencies.sh"
ln -sf "tools/core/manage-mods.sh" "manage-mods.sh"

echo "   🔗 Created symlinks for core tools"

echo ""
print_check "Verifying final structure..."
echo ""

echo "📁 Final Directory Structure:"
echo "   tools/"
echo "   ├── core/           # Production-ready tools"
for tool in "${CORE_TOOLS[@]}"; do
    if [ -f "tools/core/$tool" ]; then
        echo "   │   ├── $tool"
    fi
done
echo "   ├── analysis/       # Analysis and reporting tools"
for tool in "${ANALYSIS_TOOLS[@]}"; do
    if [ -f "tools/analysis/$tool" ]; then
        echo "   │   ├── $tool"
    fi
done
echo "   ├── demo/           # Demo and documentation tools"
for tool in "${DEMO_TOOLS[@]}"; do
    if [ -f "tools/demo/$tool" ]; then
        echo "   │   ├── $tool"
    fi
done
echo "   └── archive/        # Archived/redundant tools"
for tool in "${REDUNDANT_TOOLS[@]}"; do
    if [ -f "tools/archive/$tool" ]; then
        echo "       ├── $tool"
    fi
done

echo ""
echo "🔗 Root Level (Symlinks):"
echo "   ├── update-mods.sh -> tools/core/update-mods.sh"
echo "   ├── validate-dependencies.sh -> tools/core/validate-dependencies.sh"
echo "   └── manage-mods.sh -> tools/core/manage-mods.sh"

echo ""
print_success "Workspace cleanup completed!"
echo ""

print_info "Summary:"
echo "   ✅ Organized scripts into logical directories"
echo "   ✅ Created symlinks for easy access to core tools"
echo "   ✅ Archived redundant/completed tools"
echo "   ✅ Maintained clean root directory"
echo ""

echo "🚀 Next Steps:"
echo "   1. Review and test core tools"
echo "   2. Create documentation"
echo "   3. Commit changes to dev branch"
echo "   4. Deploy to production"
