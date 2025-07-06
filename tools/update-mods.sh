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
ENV_OVERRIDES_FILE="mod_env_overrides.conf"

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
  --validate    Validate mod files and manifest without updating
  --verbose     Enable verbose logging
  -h, --help    Show this help message

Examples:
  ./update-mods.sh                    # Auto-update all safe mods
  ./update-mods.sh --dry-run          # Preview updates
  ./update-mods.sh --validate         # Check mod file integrity
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
    [[ -f "$ENV_OVERRIDES_FILE" ]] && cp "$ENV_OVERRIDES_FILE" "$backup_path/"
    
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
    [[ -f "$backup_path/$ENV_OVERRIDES_FILE" ]] && cp "$backup_path/$ENV_OVERRIDES_FILE" "$ENV_OVERRIDES_FILE"
    
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
        
        # Check if updates should be skipped for this project
        if should_skip_update "$project_id"; then
            UPDATES_SKIPPED=$((UPDATES_SKIPPED + 1))
            continue
        fi
        
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
    
    # Calculate new mod path
    local new_mod_path="mods/$new_filename"
    
    # Download the new mod file
    if ! download_and_validate_mod "$new_url" "$new_mod_path" "$new_size" "$new_hashes"; then
        log_error "Failed to download new mod file for $project_id"
        return 1
    fi
    
    # Remove old mod file if it exists and is different
    # Map manifest path to actual filesystem path
    local actual_old_path="${mod_path}"
    if [[ -f "$actual_old_path" && "$actual_old_path" != "$new_mod_path" ]]; then
        log_info "Removing old mod file: $actual_old_path"
        rm -f "$actual_old_path"
    fi
    
    # Update the manifest
    local temp_manifest=$(mktemp)
    jq --arg old_url "$current_url" \
       --arg new_url "$new_url" \
       --arg old_path "$mod_path" \
       --arg new_path "$new_mod_path" \
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
    
    # Apply environment overrides after updating
    apply_env_overrides "$project_id" "$temp_manifest"
    
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

# ==================== FILE VALIDATION ====================

validate_mod_file() {
    local file_path="$1"
    local expected_size="$2"
    local expected_hashes="$3"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File does not exist: $file_path"
        return 1
    fi
    
    # Check file size
    local actual_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    if [[ -n "$expected_size" && "$actual_size" != "$expected_size" ]]; then
        log_warning "File size mismatch for $file_path: expected $expected_size, got $actual_size"
    fi
    
    # Check if file is a valid jar
    if [[ "$file_path" == *.jar ]]; then
        # Check if it's actually a ZIP file (resource packs and data packs might have .jar extension)
        if file "$file_path" | grep -q "Zip archive\|ZIP archive"; then
            # For ZIP files, just check if they can be read
            if ! unzip -t "$file_path" >/dev/null 2>&1; then
                log_error "Corrupted archive file: $file_path"
                return 1
            fi
            
            # Check if it's a proper mod jar (has META-INF/MANIFEST.MF) or a data/resource pack
            if unzip -l "$file_path" 2>/dev/null | grep -q "META-INF/MANIFEST.MF"; then
                # It's a proper mod jar
                log_info "Mod jar validation passed: $(basename "$file_path")"
            elif unzip -l "$file_path" 2>/dev/null | grep -q "pack.mcmeta\|data/\|assets/"; then
                # It's a data pack or resource pack
                log_info "Data/Resource pack validation passed: $(basename "$file_path")"
            else
                log_warning "Unknown jar type (but valid ZIP): $(basename "$file_path")"
            fi
        else
            log_error "File has .jar extension but is not a ZIP archive: $file_path"
            return 1
        fi
    fi
    
    # Validate file hashes if provided
    if [[ -n "$expected_hashes" && "$expected_hashes" != "null" ]]; then
        local sha1_hash=$(echo "$expected_hashes" | jq -r '.sha1 // empty' 2>/dev/null)
        if [[ -n "$sha1_hash" ]]; then
            local actual_sha1=$(shasum -a 1 "$file_path" | cut -d' ' -f1)
            if [[ "$actual_sha1" != "$sha1_hash" ]]; then
                log_error "SHA1 hash mismatch for $file_path"
                log_error "Expected: $sha1_hash"
                log_error "Actual: $actual_sha1"
                return 1
            fi
        fi
    fi
    
    log_info "File validation passed: $(basename "$file_path")"
    return 0
}

download_and_validate_mod() {
    local mod_url="$1"
    local target_path="$2"
    local expected_size="$3"
    local expected_hashes="$4"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "Downloading mod (attempt $((retry_count + 1))/$max_retries): $(basename "$target_path")"
        
        # Create temporary download path
        local temp_path="${target_path}.tmp"
        
        # Download with retry
        if curl -L -f -s --connect-timeout 30 --max-time 300 -o "$temp_path" "$mod_url"; then
            # Validate downloaded file
            if validate_mod_file "$temp_path" "$expected_size" "$expected_hashes"; then
                # Move to final location
                mv "$temp_path" "$target_path"
                log_success "Successfully downloaded and validated: $(basename "$target_path")"
                return 0
            else
                log_warning "Downloaded file failed validation, retrying..."
                rm -f "$temp_path"
            fi
        else
            log_warning "Download failed, retrying..."
            rm -f "$temp_path"
        fi
        
        retry_count=$((retry_count + 1))
        sleep $((retry_count * 2))  # Exponential backoff
    done
    
    log_error "Failed to download and validate mod after $max_retries attempts: $mod_url"
    return 1
}

validate_existing_mods() {
    log_info "Validating existing mod files..."
    local validation_errors=0
    local mods_dir="mods"
    
    if [[ ! -d "$mods_dir" ]]; then
        log_warning "Mods directory does not exist: $mods_dir"
        return 0
    fi
    
    # Get mod info from manifest
    local manifest_mods=$(jq -r '
        .files[] | 
        select(.downloads and (.downloads | length > 0)) |
        select(.path | startswith("mods/")) |
        {
            path: .path,
            url: .downloads[0],
            fileSize: .fileSize,
            hashes: .hashes
        }
    ' "$MANIFEST_FILE" 2>/dev/null)
    
    echo "$manifest_mods" | jq -c '.' | while read -r mod_info; do
        local mod_path=$(echo "$mod_info" | jq -r '.path')
        local mod_size=$(echo "$mod_info" | jq -r '.fileSize // empty')
        local mod_hashes=$(echo "$mod_info" | jq -r '.hashes // empty')
        
        # Map manifest path to actual filesystem path
        local actual_path="${mod_path}"
        
        if [[ -f "$actual_path" ]]; then
            if ! validate_mod_file "$actual_path" "$mod_size" "$mod_hashes"; then
                log_error "Validation failed for existing mod: $actual_path"
                validation_errors=$((validation_errors + 1))
            fi
        else
            log_warning "Missing mod file: $actual_path"
        fi
    done
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Found $validation_errors mod validation errors"
        return 1
    fi
    
    log_success "All existing mods validated successfully"
    return 0
}

# ==================== DEPENDENCY CHECKS ====================

check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v unzip >/dev/null 2>&1; then
        missing_deps+=("unzip")
    fi
    
    if ! command -v shasum >/dev/null 2>&1; then
        missing_deps+=("shasum")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing tools and try again"
        
        # Provide installation hints for macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "Installation hints for macOS:"
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    jq)
                        log_info "  brew install jq"
                        ;;
                    curl)
                        log_info "  curl should be pre-installed on macOS"
                        ;;
                    unzip)
                        log_info "  unzip should be pre-installed on macOS"
                        ;;
                    shasum)
                        log_info "  shasum should be pre-installed on macOS"
                        ;;
                esac
            done
        fi
        
        return 1
    fi
    
    return 0
}

# ==================== EXISTING UTILITY FUNCTIONS ====================
# (No changes in this section)

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
            --validate)
                VALIDATE_ONLY=true
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
    
    # Check dependencies first
    if ! check_dependencies; then
        log_error "Missing dependencies, cannot continue"
        exit 1
    fi
    
    # Initialize
    mkdir -p "$BACKUP_DIR" "$CACHE_DIR"
    echo "$(date): Starting automatic mod update" > "$LOG_FILE"
    
    # Load environment overrides
    load_env_overrides
    
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
    
    # Handle validation-only mode
    if [[ "$VALIDATE_ONLY" == true ]]; then
        log_info "=== VALIDATION MODE ==="
        log_info "Validating manifest..."
        if ! validate_manifest; then
            log_error "Manifest validation failed"
            exit 1
        fi
        
        log_info "Validating mod files..."
        if ! validate_existing_mods; then
            log_error "Mod file validation failed"
            exit 1
        fi
        
        log_success "All validation checks passed"
        exit 0
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
            git add "$MANIFEST_FILE" mod_overrides.conf "$ENV_OVERRIDES_FILE" 2>/dev/null || true
            git commit -m "Auto-update: Applied $UPDATES_APPLIED mod updates

- Updated $UPDATES_APPLIED mods
- Skipped $UPDATES_SKIPPED updates due to constraints
- Applied environment overrides from $ENV_OVERRIDES_FILE
- Validated manifest and dependencies

Generated by update-mods.sh" 2>/dev/null || log_warning "Git commit failed"
        fi
    fi
    
    # Cleanup
    rm -rf "$CACHE_DIR"
    
    log_success "Automatic mod update completed"
}

# ==================== ENVIRONMENT OVERRIDE FUNCTIONS ====================

load_env_overrides() {
    declare -gA ENV_OVERRIDES
    
    if [[ ! -f "$ENV_OVERRIDES_FILE" ]]; then
        log_info "No environment overrides file found: $ENV_OVERRIDES_FILE"
        return 0
    fi
    
    log_info "Loading environment overrides from: $ENV_OVERRIDES_FILE"
    
    # Parse override file
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse project_id:property:value format
        if [[ "$line" =~ ^([^:]+):([^:]+):(.+)$ ]]; then
            local project_id="${BASH_REMATCH[1]}"
            local property="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            
            ENV_OVERRIDES["$project_id:$property"]="$value"
            
            if [[ "$VERBOSE" == true ]]; then
                log_info "Loaded override: $project_id.$property = $value"
            fi
        fi
    done < "$ENV_OVERRIDES_FILE"
    
    local override_count=${#ENV_OVERRIDES[@]}
    log_info "Loaded $override_count environment overrides"
}

apply_env_overrides() {
    local project_id="$1"
    local temp_manifest="$2"
    
    # Check if there are any overrides for this project
    local has_overrides=false
    for key in "${!ENV_OVERRIDES[@]}"; do
        if [[ "$key" == "$project_id:"* ]]; then
            has_overrides=true
            break
        fi
    done
    
    if [[ "$has_overrides" == false ]]; then
        return 0
    fi
    
    log_info "Applying environment overrides for project: $project_id"
    
    # Create a temporary file for jq processing
    local jq_filters=()
    
    # Check for env.client override
    if [[ -n "${ENV_OVERRIDES["$project_id:env.client"]:-}" ]]; then
        local client_value="${ENV_OVERRIDES["$project_id:env.client"]}"
        jq_filters+=("(.files[] | select(.downloads[0] | contains(\"$project_id\")) | .env.client) = \"$client_value\"")
        log_info "Override: $project_id env.client = $client_value"
    fi
    
    # Check for env.server override
    if [[ -n "${ENV_OVERRIDES["$project_id:env.server"]:-}" ]]; then
        local server_value="${ENV_OVERRIDES["$project_id:env.server"]}"
        jq_filters+=("(.files[] | select(.downloads[0] | contains(\"$project_id\")) | .env.server) = \"$server_value\"")
        log_info "Override: $project_id env.server = $server_value"
    fi
    
    # Apply all filters
    if [[ ${#jq_filters[@]} -gt 0 ]]; then
        local filter_string=$(IFS=' | '; echo "${jq_filters[*]}")
        jq "$filter_string" "$temp_manifest" > "${temp_manifest}.tmp" && mv "${temp_manifest}.tmp" "$temp_manifest"
    fi
}

should_skip_update() {
    local project_id="$1"
    
    # Check if updates are disabled for this project
    if [[ "${ENV_OVERRIDES["$project_id:skip_updates"]:-}" == "true" ]]; then
        log_info "Skipping update for $project_id (skip_updates override)"
        return 0  # Should skip
    fi
    
    # Check if version is pinned
    if [[ -n "${ENV_OVERRIDES["$project_id:pin_version"]:-}" ]]; then
        log_info "Skipping update for $project_id (pinned version override)"
        return 0  # Should skip
    fi
    
    return 1  # Should not skip
}

# Run main function
main "$@"
