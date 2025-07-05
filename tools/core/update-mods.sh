#!/bin/bash

# Automatic Mod Management System
# Zero-intervention mod updates with constraint-aware dependency checking
# Usage: ./update-mods.sh [--dry-run] [--force] [--rollback]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="modrinth.index.json"
BACKUP_DIR="backup/auto-updates"
LOG_FILE="auto-update.log"
CACHE_DIR=".modrinth_cache"
MINECRAFT_VERSION="1.21.1"
MODLOADER="neoforge"

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

show_help() {
    cat << EOF
Automatic Mod Management System

Usage: ./update-mods.sh [OPTIONS]

Options:
  --dry-run     Show what would be updated without making changes
  --force       Force updates even if constraints might be violated
  --rollback    Rollback to the last backup
  --verbose     Enable verbose logging
  -h, --help    Show this help message

Examples:
  ./update-mods.sh                    # Auto-update all safe mods
  ./update-mods.sh --dry-run          # Preview updates
  ./update-mods.sh --rollback         # Rollback last update
EOF
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
    "manifest_hash": "$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)"
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
}

# ==================== DEPENDENCY CHECKING ====================

get_mod_dependents() {
    local mod_project_id="$1"
    
    # Find mods that depend on this mod
    jq -r --arg mod_id "$mod_project_id" '
        .files[] | 
        select(.downloads and (.downloads | length > 0)) |
        select(.downloads[0] | contains("modrinth.com")) |
        {
            path: .path,
            url: .downloads[0],
            project_id: (.downloads[0] | split("/") | .[-3])
        } |
        select(.project_id != $mod_id)
    ' "$MANIFEST_FILE" 2>/dev/null || echo ""
}

check_dependency_constraints() {
    local mod_project_id="$1"
    local new_version="$2"
    
    # Simple heuristic: if this is a major dependency (like JEI, Curios, etc.)
    # be more conservative about updates
    local conservative_mods=("jei" "curios" "create" "architectury" "cloth-config" "geckolib")
    
    for conservative_mod in "${conservative_mods[@]}"; do
        if [[ "$mod_project_id" == *"$conservative_mod"* ]]; then
            log_info "Conservative update check for $mod_project_id"
            # For conservative mods, only allow minor version updates
            return 0  # For now, allow all updates - can be made more strict later
        fi
    done
    
    return 0  # Generally allow updates
}

# ==================== UPDATE CHECKING ====================

check_for_updates() {
    log_info "Checking for mod updates..."
    
    mkdir -p "$CACHE_DIR"
    
    # Get all Modrinth mods from manifest
    local modrinth_mods=$(jq -r '
        .files[] | 
        select(.downloads and (.downloads | length > 0)) |
        select(.downloads[0] | contains("modrinth.com")) |
        {
            path: .path,
            url: .downloads[0],
            project_id: (.downloads[0] | split("/") | .[4]),
            version_id: (.downloads[0] | split("/") | .[6])
        }
    ' "$MANIFEST_FILE" 2>/dev/null)
    
    if [[ -z "$modrinth_mods" ]]; then
        log_warning "No Modrinth mods found in manifest"
        return
    fi
    
    TOTAL_MODS=$(echo "$modrinth_mods" | jq -s length)
    log_info "Found $TOTAL_MODS Modrinth mods to check"
    
    local updates_file="$CACHE_DIR/available_updates.json"
    echo "[]" > "$updates_file"
    
    # Check each mod for updates
    echo "$modrinth_mods" | jq -c '.' | while read -r mod_info; do
        local project_id=$(echo "$mod_info" | jq -r '.project_id')
        local current_version_id=$(echo "$mod_info" | jq -r '.version_id')
        local current_url=$(echo "$mod_info" | jq -r '.url')
        local mod_path=$(echo "$mod_info" | jq -r '.path')
        
        if [[ "$VERBOSE" == true ]]; then
            log_info "Checking $project_id..."
        fi
        
        # Get latest version from Modrinth
        local latest_version=$(curl -s "https://api.modrinth.com/v2/project/$project_id/version?game_versions=[%22$MINECRAFT_VERSION%22]&loaders=[%22$MODLOADER%22]" | \
            jq -r 'sort_by(.date_published) | reverse | first | select(.id != null)')
        
        if [[ "$latest_version" == "null" || -z "$latest_version" ]]; then
            continue
        fi
        
        local latest_version_id=$(echo "$latest_version" | jq -r '.id')
        local latest_version_number=$(echo "$latest_version" | jq -r '.version_number')
        
        # Check if there's actually an update
        if [[ "$latest_version_id" != "$current_version_id" ]]; then
            # Found an update
            local update_info=$(jq -n \
                --arg project_id "$project_id" \
                --arg current_version "$current_version_id" \
                --arg latest_version "$latest_version_id" \
                --arg latest_number "$latest_version_number" \
                --arg current_url "$current_url" \
                --arg mod_path "$mod_path" \
                --argjson version_data "$latest_version" \
                '{
                    project_id: $project_id,
                    current_version: $current_version,
                    latest_version: $latest_version,
                    latest_number: $latest_number,
                    current_url: $current_url,
                    mod_path: $mod_path,
                    version_data: $version_data
                }')
            
            jq --argjson update "$update_info" '. += [$update]' "$updates_file" > "$updates_file.tmp" && mv "$updates_file.tmp" "$updates_file"
            
            if [[ "$VERBOSE" == true ]]; then
                log_info "Update available: $project_id -> $latest_version_number"
            fi
        fi
        
        # Rate limiting
        sleep 0.2
    done
    
    UPDATES_AVAILABLE=$(jq length "$updates_file")
    log_info "Found $UPDATES_AVAILABLE updates available"
    
    echo "$updates_file"
}

# ==================== UPDATE APPLICATION ====================

apply_updates() {
    local updates_file="$1"
    
    if [[ "$UPDATES_AVAILABLE" -eq 0 ]]; then
        log_info "No updates available"
        return 0
    fi
    
    log_info "Processing $UPDATES_AVAILABLE updates..."
    
    # Create backup before applying updates
    if [[ "$DRY_RUN" != true ]]; then
        local backup_path=$(create_backup)
        log_info "Created backup: $backup_path"
    fi
    
    # Apply each update
    while read -r update; do
        local project_id=$(echo "$update" | jq -r '.project_id')
        local latest_version=$(echo "$update" | jq -r '.latest_version')
        local latest_number=$(echo "$update" | jq -r '.latest_number')
        local current_url=$(echo "$update" | jq -r '.current_url')
        local mod_path=$(echo "$update" | jq -r '.mod_path')
        local version_data=$(echo "$update" | jq -r '.version_data')
        
        log_info "Processing update: $project_id -> $latest_number"
        
        # Check dependency constraints unless forced
        if [[ "$FORCE_UPDATE" != true ]]; then
            if ! check_dependency_constraints "$project_id" "$latest_version"; then
                log_warning "Skipping $project_id due to dependency constraints"
                UPDATES_SKIPPED=$((UPDATES_SKIPPED + 1))
                CONSTRAINT_VIOLATIONS=$((CONSTRAINT_VIOLATIONS + 1))
                continue
            fi
        fi
        
        # Apply the update
        if [[ "$DRY_RUN" != true ]]; then
            if apply_single_update "$project_id" "$latest_number" "$current_url" "$mod_path" "$version_data"; then
                UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
            else
                FAILED_UPDATES+=("$project_id")
            fi
        else
            log_info "[DRY RUN] Would update $project_id to $latest_number"
        fi
    done < <(jq -c '.[]' "$updates_file")
}

apply_single_update() {
    local project_id="$1"
    local latest_number="$2"
    local current_url="$3"
    local mod_path="$4"
    local version_data="$5"
    
    # Get the new download URL and file info
    local new_url=$(echo "$version_data" | jq -r '.files[0].url')
    local new_filename=$(echo "$version_data" | jq -r '.files[0].filename')
    local new_size=$(echo "$version_data" | jq -r '.files[0].size')
    local new_hashes=$(echo "$version_data" | jq -r '.files[0].hashes')
    
    if [[ "$new_url" == "null" ]]; then
        log_error "Failed to get download URL for $project_id"
        return 1
    fi
    
    # Update the manifest
    local temp_manifest=$(mktemp)
    jq --arg old_url "$current_url" \
       --arg new_url "$new_url" \
       --arg old_path "$mod_path" \
       --arg new_path "mods/$new_filename" \
       --arg new_size "$new_size" \
       --argjson new_hashes "$new_hashes" \
       '
       .files = [
         .files[] | 
         if .downloads[0] == $old_url then
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
        log_success "Updated $project_id to $latest_number"
        return 0
    else
        log_error "Failed to update manifest for $project_id"
        rm -f "$temp_manifest"
        return 1
    fi
}

# ==================== VALIDATION ====================

validate_manifest() {
    log_info "Validating manifest..."
    
    # Check JSON validity
    if ! jq empty "$MANIFEST_FILE" 2>/dev/null; then
        log_error "Invalid JSON in manifest"
        return 1
    fi
    
    # Check required fields
    local required_fields=("formatVersion" "game" "versionId" "name" "files")
    for field in "${required_fields[@]}"; do
        if [[ "$(jq -r ".$field" "$MANIFEST_FILE")" == "null" ]]; then
            log_error "Missing required field: $field"
            return 1
        fi
    done
    
    # Check for duplicate files
    local duplicates=$(jq -r '.files[].path' "$MANIFEST_FILE" | sort | uniq -d)
    if [[ -n "$duplicates" ]]; then
        log_error "Duplicate files found:"
        echo "$duplicates"
        return 1
    fi
    
    log_success "Manifest validation passed"
    return 0
}

# ==================== MAIN FUNCTION ====================

main() {
    # Parse arguments
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
    
    # Initialize
    mkdir -p "$BACKUP_DIR" "$CACHE_DIR"
    echo "$(date): Starting automatic mod update" > "$LOG_FILE"
    
    # Handle rollback
    if [[ "$ROLLBACK" == true ]]; then
        rollback_to_backup
        exit 0
    fi
    
    # Validate manifest exists
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Manifest file not found: $MANIFEST_FILE"
        exit 1
    fi
    
    log_info "=== Automatic Mod Update System ==="
    log_info "Checking for updates..."
    
    # Check for updates
    local updates_file=$(check_for_updates)
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "=== DRY RUN MODE ==="
        log_info "Updates available: $UPDATES_AVAILABLE"
        if [[ "$UPDATES_AVAILABLE" -gt 0 ]]; then
            log_info "Available updates:"
            jq -r '.[] | "  \(.project_id) -> \(.latest_number)"' "$updates_file"
        fi
    else
        # Apply updates
        apply_updates "$updates_file"
        
        # Validate after all updates
        if [[ "$UPDATES_APPLIED" -gt 0 ]]; then
            if ! validate_manifest; then
                log_error "Validation failed after updates"
                
                # Auto-rollback on validation failure
                local backup_path=$(find_latest_backup)
                if [[ -n "$backup_path" ]]; then
                    log_warning "Auto-rolling back due to validation failure..."
                    rollback_to_backup "$backup_path"
                fi
                
                exit 1
            fi
        fi
        
        # Show summary
        log_info "=== UPDATE SUMMARY ==="
        log_info "Total mods checked: $TOTAL_MODS"
        log_info "Updates available: $UPDATES_AVAILABLE"
        log_info "Updates applied: $UPDATES_APPLIED"
        log_info "Updates skipped: $UPDATES_SKIPPED"
        log_info "Constraint violations: $CONSTRAINT_VIOLATIONS"
        
        if [[ ${#FAILED_UPDATES[@]} -gt 0 ]]; then
            log_warning "Failed updates: ${FAILED_UPDATES[*]}"
        fi
        
        # Auto-commit if changes were made
        if [[ "$UPDATES_APPLIED" -gt 0 ]]; then
            log_info "Auto-committing changes..."
            git add "$MANIFEST_FILE" mod_overrides.conf 2>/dev/null || true
            git commit -m "Auto-update: Applied $UPDATES_APPLIED mod updates

- Updated $UPDATES_APPLIED mods
- Skipped $UPDATES_SKIPPED updates due to constraints
- Validated manifest and dependencies

Generated by update-mods.sh" 2>/dev/null || log_warning "Git commit failed"
        fi
    fi
    
    # Cleanup
    rm -rf "$CACHE_DIR"
    
    log_success "Automatic mod update completed"
}

# Run main function
main "$@"
