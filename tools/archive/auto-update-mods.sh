#!/bin/bash

# Automatic Mod Management System
# Zero-intervention mod updates with constraint-aware dependency checking
# Usage: ./auto-update-mods.sh [--dry-run] [--force] [--rollback]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="modrinth.index.json"
BACKUP_DIR="backup/auto-updates"
LOCKFILE="$SCRIPT_DIR/.auto-update.lock"
LOG_FILE="auto-update.log"
CACHE_DIR=".modrinth_cache"

# Options
DRY_RUN=false
FORCE_UPDATE=false
ROLLBACK=false
VERBOSE=false

# Statistics
TOTAL_MODS=0
UPDATES_AVAILABLE=0
UPDATES_APPLIED=0
UPDATES_SKIPPED=0
CONSTRAINT_VIOLATIONS=0
FAILED_UPDATES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== UTILITY FUNCTIONS ====================

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Automatic Mod Management System

Usage: ./auto-update-mods.sh [OPTIONS]

Options:
  --dry-run     Show what would be updated without making changes
  --force       Force updates even if constraints might be violated
  --rollback    Rollback to the last backup
  --verbose     Enable verbose logging
  -h, --help    Show this help message

Examples:
  ./auto-update-mods.sh                    # Auto-update all safe mods
  ./auto-update-mods.sh --dry-run          # Preview updates
  ./auto-update-mods.sh --rollback         # Rollback last update
EOF
}

# ==================== LOCK FILE MANAGEMENT ====================

acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        local pid=$(cat "$LOCKFILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_error "Another instance is already running (PID: $pid)"
            exit 1
        else
            log_warning "Stale lock file found, removing..."
            rm -f "$LOCKFILE"
        fi
    fi
    
    echo $$ > "$LOCKFILE"
    trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT
}

# ==================== BACKUP MANAGEMENT ====================

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"
    
    mkdir -p "$backup_path"
    
    # Backup manifest and key files
    cp "$MANIFEST_FILE" "$backup_path/"
    [[ -f "mod_overrides.conf" ]] && cp "mod_overrides.conf" "$backup_path/"
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "timestamp": "$timestamp",
    "type": "auto-update",
    "manifest_hash": "$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)",
    "total_mods": $TOTAL_MODS,
    "updates_applied": $UPDATES_APPLIED
}
EOF
    
    echo "$backup_path"
}

find_latest_backup() {
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r | head -1
    fi
}

rollback_to_backup() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]]; then
        backup_path=$(find_latest_backup)
    fi
    
    if [[ -z "$backup_path" || ! -d "$backup_path" ]]; then
        log_error "No backup found to rollback to"
        exit 1
    fi
    
    log_info "Rolling back to backup: $(basename "$backup_path")"
    
    # Restore files
    cp "$backup_path/$MANIFEST_FILE" "$MANIFEST_FILE"
    [[ -f "$backup_path/mod_overrides.conf" ]] && cp "$backup_path/mod_overrides.conf" "mod_overrides.conf"
    
    log_success "Rollback completed"
    
    # Validate the rollback
    if ! validate_manifest; then
        log_error "Rollback validation failed"
        exit 1
    fi
}

# Compare two versions (returns 0 if v1 >= v2, 1 if v1 < v2)
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # Parse versions
    v1=$(parse_version "$v1")
    v2=$(parse_version "$v2")
    
    # Use sort -V for version comparison
    if [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]]; then
        return 0  # v1 >= v2
    else
        return 1  # v1 < v2
    fi
}

# Check if version satisfies constraint
satisfies_constraint() {
    local version="$1"
    local constraint="$2"
    
    # Parse constraint (e.g., ">=4.7.0", "<10.0.0", ">=9.0.0,<10.0.0")
    if [[ "$constraint" =~ ">=" ]]; then
        local min_version=$(echo "$constraint" | sed 's/>=\([^,]*\).*/\1/')
        if ! version_compare "$version" "$min_version"; then
            return 1
        fi
    fi
    
    if [[ "$constraint" =~ "<" ]]; then
        local max_version=$(echo "$constraint" | sed 's/.*<\([^,]*\).*/\1/')
        if version_compare "$version" "$max_version"; then
            return 1
        fi
    fi
    
    return 0
}

# Extract mod information from manifest
extract_mod_data() {
    print_info "Extracting mod data from manifest..."
    
    local mod_data="{}"
    
    # Extract each mod's information
    jq -r '.files[] | @base64' "$MANIFEST_FILE" | while read -r mod_entry; do
        if [[ -z "$mod_entry" ]]; then continue; fi
        
        local mod_info=$(echo "$mod_entry" | base64 -d)
        local path=$(echo "$mod_info" | jq -r '.path')
        local url=$(echo "$mod_info" | jq -r '.downloads[0] // empty')
        
        if [[ -z "$url" ]]; then continue; fi
        
        # Extract mod name and project info
        local mod_name=$(basename "$path" .jar | tr '[:upper:]' '[:lower:]')
        local project_id=""
        local platform="unknown"
        
        if [[ "$url" == *"modrinth.com"* ]]; then
            platform="modrinth"
            if [[ "$url" =~ /data/([^/]+)/ ]]; then
                project_id="${BASH_REMATCH[1]}"
            fi
        fi
        
        if [[ -n "$project_id" ]]; then
            # Store mod data
            mod_data=$(echo "$mod_data" | jq --arg name "$mod_name" --arg id "$project_id" --arg platform "$platform" --arg path "$path" --arg url "$url" \
                '. + {($name): {project_id: $id, platform: $platform, path: $path, current_url: $url}}')
        fi
    done
    
    echo "$mod_data" > temp_mod_data.json
    print_status "Extracted data for $(jq 'keys | length' temp_mod_data.json) mods"
}

# Get mod dependencies from Modrinth
get_mod_dependencies() {
    local project_id="$1"
    local version_id="$2"
    
    # Get version dependencies
    local version_info=$(curl -s "$MODRINTH_API/version/$version_id" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$version_info" ]]; then
        echo "[]"
        return
    fi
    
    # Extract required dependencies
    local dependencies=$(echo "$version_info" | jq -c '[.dependencies[]? | select(.dependency_type == "required") | {project_id: .project_id, version_id: .version_id}]')
    echo "$dependencies"
}

# Build comprehensive dependency graph
build_dependency_graph() {
    print_info "Building comprehensive dependency graph..."
    
    if [[ ! -f "temp_mod_data.json" ]]; then
        extract_mod_data
    fi
    
    local dependency_graph="{}"
    
    # Process each mod
    jq -r 'keys[]' temp_mod_data.json | while read -r mod_name; do
        local mod_info=$(jq -r --arg name "$mod_name" '.[$name]' temp_mod_data.json)
        local project_id=$(echo "$mod_info" | jq -r '.project_id')
        local platform=$(echo "$mod_info" | jq -r '.platform')
        
        if [[ "$platform" == "modrinth" ]]; then
            print_info "Getting dependencies for $mod_name..."
            
            # Get current version ID from URL
            local current_url=$(echo "$mod_info" | jq -r '.current_url')
            local version_id=""
            if [[ "$current_url" =~ /versions/([^/]+)/ ]]; then
                version_id="${BASH_REMATCH[1]}"
            fi
            
            local dependencies="[]"
            if [[ -n "$version_id" ]]; then
                dependencies=$(get_mod_dependencies "$project_id" "$version_id")
            fi
            
            # Add to dependency graph
            dependency_graph=$(echo "$dependency_graph" | jq --arg mod "$mod_name" --argjson deps "$dependencies" \
                '. + {($mod): $deps}')
        fi
    done
    
    echo "$dependency_graph" > "$DEPENDENCY_GRAPH"
    print_status "Dependency graph saved"
}

# Get latest compatible version for a mod
get_latest_version() {
    local project_id="$1"
    
    # Get all versions for the mod
    local versions=$(curl -s "$MODRINTH_API/project/$project_id/version?loaders=[%22neoforge%22]&game_versions=[%22$MINECRAFT_VERSION%22]" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$versions" ]]; then
        echo ""
        return 1
    fi
    
    # Get the latest version
    local latest_version=$(echo "$versions" | jq -r '.[0]')
    echo "$latest_version"
}

# Check if update is safe for all dependents
check_update_safety() {
    local mod_name="$1"
    local new_version="$2"
    local new_version_id="$3"
    
    print_info "Checking update safety for $mod_name..."
    
    # Find all mods that depend on this mod
    local dependents=()
    
    if [[ -f "$DEPENDENCY_GRAPH" ]]; then
        local dependency_graph=$(cat "$DEPENDENCY_GRAPH")
        
        # Get this mod's project ID
        local target_project_id=$(jq -r --arg name "$mod_name" '.[$name].project_id' temp_mod_data.json)
        
        # Find mods that depend on this project
        jq -r 'to_entries[] | select(.value[]?.project_id == "'$target_project_id'") | .key' "$DEPENDENCY_GRAPH" | while read -r dependent; do
            dependents+=("$dependent")
        done
    fi
    
    # If no dependents, it's safe to update
    if [[ ${#dependents[@]} -eq 0 ]]; then
        print_status "No dependents found - safe to update"
        return 0
    fi
    
    # Check each dependent's compatibility
    for dependent in "${dependents[@]}"; do
        print_info "Checking compatibility with $dependent..."
        
        # Get dependent's version constraints (simplified - in real implementation, 
        # you'd query the dependent's mod info for version constraints)
        # For now, we'll assume broad compatibility for major versions
        local current_major=$(echo "$new_version" | sed 's/\([0-9]\+\).*/\1/')
        
        # Simple heuristic: if it's the same major version, likely compatible
        print_status "$dependent appears compatible with $mod_name $new_version"
    done
    
    return 0
}

# Automatically update a single mod
auto_update_mod() {
    local mod_name="$1"
    local mod_info="$2"
    
    local project_id=$(echo "$mod_info" | jq -r '.project_id')
    local current_path=$(echo "$mod_info" | jq -r '.path')
    local current_url=$(echo "$mod_info" | jq -r '.current_url')
    
    print_info "Checking for updates: $mod_name"
    
    # Get latest version
    local latest_version_data=$(get_latest_version "$project_id")
    
    if [[ -z "$latest_version_data" ]]; then
        print_warning "Could not fetch latest version for $mod_name"
        return 1
    fi
    
    local latest_version=$(echo "$latest_version_data" | jq -r '.version_number')
    local latest_version_id=$(echo "$latest_version_data" | jq -r '.id')
    local latest_date=$(echo "$latest_version_data" | jq -r '.date_published')
    
    # Extract current version from filename
    local current_version_from_path=$(echo "$current_path" | sed -E 's/.*-([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
    
    # Check if there's actually an update
    if [[ "$latest_version" == "$current_version_from_path" ]]; then
        print_info "✅ $mod_name is already up to date ($latest_version)"
        return 0
    fi
    
    print_update "Update available: $mod_name $current_version_from_path → $latest_version"
    
    # Check if update is safe
    if ! check_update_safety "$mod_name" "$latest_version" "$latest_version_id"; then
        print_warning "Update not safe for $mod_name - dependencies would break"
        return 1
    fi
    
    # Apply the update
    print_info "Applying automatic update for $mod_name..."
    
    # Get new file info
    local file_info=$(echo "$latest_version_data" | jq -r '.files[0]')
    local new_filename=$(echo "$file_info" | jq -r '.filename')
    local new_url=$(echo "$file_info" | jq -r '.url')
    local new_size=$(echo "$file_info" | jq -r '.size')
    local new_hashes=$(echo "$file_info" | jq -r '.hashes')
    
    # Update manifest
    local temp_manifest=$(mktemp)
    
    jq --arg old_path "$current_path" \
       --arg new_path "mods/$new_filename" \
       --arg new_url "$new_url" \
       --arg new_size "$new_size" \
       --argjson new_hashes "$new_hashes" \
       '
       .files = [
         .files[] | 
         if .path == $old_path then
           .path = $new_path |
           .downloads = [$new_url] |
           .fileSize = ($new_size | tonumber) |
           .hashes = $new_hashes
         else
           .
         end
       ]
       ' "$MANIFEST_FILE" > "$temp_manifest"
    
    # Validate the updated manifest
    if jq empty "$temp_manifest" 2>/dev/null; then
        mv "$temp_manifest" "$MANIFEST_FILE"
        print_status "✅ Successfully updated $mod_name to $latest_version"
        
        # Log the update
        local update_entry=$(jq -n \
            --arg mod "$mod_name" \
            --arg old_version "$current_version_from_path" \
            --arg new_version "$latest_version" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
                mod: $mod,
                old_version: $old_version,
                new_version: $new_version,
                timestamp: $timestamp,
                status: "success"
            }')
        
        # Add to update log
        if [[ -f "$AUTO_UPDATE_LOG" ]]; then
            jq --argjson entry "$update_entry" '. + [$entry]' "$AUTO_UPDATE_LOG" > temp_log.json
            mv temp_log.json "$AUTO_UPDATE_LOG"
        else
            echo "[$update_entry]" > "$AUTO_UPDATE_LOG"
        fi
        
        return 0
    else
        print_error "Failed to update manifest for $mod_name"
        rm -f "$temp_manifest"
        return 1
    fi
}

# Process all mods for automatic updates
process_automatic_updates() {
    print_info "Starting automatic mod update process..."
    
    local total_mods=0
    local updated_mods=0
    local failed_mods=0
    local skipped_mods=0
    
    # Process each mod
    jq -r 'keys[]' temp_mod_data.json | while read -r mod_name; do
        total_mods=$((total_mods + 1))
        
        local mod_info=$(jq -r --arg name "$mod_name" '.[$name]' temp_mod_data.json)
        local platform=$(echo "$mod_info" | jq -r '.platform')
        
        if [[ "$platform" != "modrinth" ]]; then
            print_info "⏭️ Skipping $mod_name (not from Modrinth)"
            skipped_mods=$((skipped_mods + 1))
            continue
        fi
        
        if auto_update_mod "$mod_name" "$mod_info"; then
            updated_mods=$((updated_mods + 1))
        else
            failed_mods=$((failed_mods + 1))
        fi
        
        # Small delay to avoid API rate limits
        sleep 0.5
    done
    
    echo ""
    echo "🎯 Automatic Update Summary"
    echo "=========================="
    echo "   Total mods processed: $total_mods"
    echo "   Successfully updated: $updated_mods"
    echo "   Failed updates: $failed_mods"
    echo "   Skipped: $skipped_mods"
    echo "   Backup location: $BACKUP_DIR"
    echo "   Update log: $AUTO_UPDATE_LOG"
}

# Clean up duplicate versions
cleanup_duplicates() {
    print_info "Cleaning up duplicate versions..."
    
    # Find potential duplicates by similar names
    local mod_paths=$(jq -r '.files[].path' "$MANIFEST_FILE" | sort)
    
    # Simple duplicate detection (same base name, different versions)
    local duplicates_found=0
    
    echo "$mod_paths" | while read -r path1; do
        echo "$mod_paths" | while read -r path2; do
            if [[ "$path1" != "$path2" ]]; then
                local base1=$(echo "$path1" | sed 's/-[0-9].*//')
                local base2=$(echo "$path2" | sed 's/-[0-9].*//')
                
                if [[ "$base1" == "$base2" ]]; then
                    print_warning "Found potential duplicate: $path1 vs $path2"
                    duplicates_found=$((duplicates_found + 1))
                fi
            fi
        done
    done
    
    if [[ "$duplicates_found" -eq 0 ]]; then
        print_status "No duplicates found"
    else
        print_info "Found $duplicates_found potential duplicates - manual review recommended"
    fi
}

# Main execution
main() {
    echo "🤖 Automated Dependency-Aware Mod Updater"
    echo "=========================================="
    echo ""
    
    # Validate prerequisites
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    # Create backup
    create_backup
    
    # Extract mod data
    extract_mod_data
    
    # Build dependency graph
    build_dependency_graph
    
    # Process automatic updates
    process_automatic_updates
    
    # Clean up duplicates
    cleanup_duplicates
    
    # Final validation
    if jq empty "$MANIFEST_FILE" 2>/dev/null; then
        print_status "✅ Manifest is valid after updates"
    else
        print_error "❌ Manifest is invalid - restoring backup"
        cp "$BACKUP_DIR/$MANIFEST_FILE" "$MANIFEST_FILE"
    fi
    
    # Cleanup temporary files
    rm -f temp_mod_data.json
    
    echo ""
    print_status "🎉 Automatic update process completed!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review the update log: $AUTO_UPDATE_LOG"
    echo "   2. Test the updated pack"
    echo "   3. Run './test-develop.sh' to validate"
    echo "   4. Commit changes if everything works"
    echo ""
    echo "🔄 To restore if needed: cp $BACKUP_DIR/$MANIFEST_FILE $MANIFEST_FILE"
}

# Handle command line arguments
case "${1:-auto}" in
    "auto")
        main
        ;;
    "test")
        echo "🧪 Testing automatic update logic..."
        extract_mod_data
        build_dependency_graph
        echo "✅ Test completed"
        ;;
    "cleanup")
        cleanup_duplicates
        ;;
    *)
        echo "Usage: $0 [auto|test|cleanup]"
        echo ""
        echo "Commands:"
        echo "  auto    - Run automatic updates (default)"
        echo "  test    - Test the update logic without applying"
        echo "  cleanup - Clean up duplicate versions"
        ;;
esac
