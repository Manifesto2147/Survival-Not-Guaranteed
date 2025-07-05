#!/bin/bash

# Safe Mod Update Applicator
# Applies mod updates while maintaining dependency integrity

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
print_update() { echo -e "${CYAN}🔄${NC} $1"; }

# Configuration
MANIFEST_FILE="modrinth.index.json"
UPDATE_REPORT="update_report.json"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
APPLIED_UPDATES="applied_updates.json"

# Create backup
create_backup() {
    print_info "Creating backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup manifest
    cp "$MANIFEST_FILE" "$BACKUP_DIR/"
    
    # Backup mod_overrides if it exists
    if [[ -f "mod_overrides.conf" ]]; then
        cp "mod_overrides.conf" "$BACKUP_DIR/"
    fi
    
    # Backup any custom config files
    if [[ -d "config" ]]; then
        cp -r "config" "$BACKUP_DIR/"
    fi
    
    print_status "Backup created at $BACKUP_DIR"
}

# Restore from backup
restore_backup() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    print_warning "Restoring from backup: $backup_path"
    
    # Restore manifest
    if [[ -f "$backup_path/$MANIFEST_FILE" ]]; then
        cp "$backup_path/$MANIFEST_FILE" .
        print_status "Restored $MANIFEST_FILE"
    fi
    
    # Restore mod_overrides if it exists
    if [[ -f "$backup_path/mod_overrides.conf" ]]; then
        cp "$backup_path/mod_overrides.conf" .
        print_status "Restored mod_overrides.conf"
    fi
    
    # Restore config
    if [[ -d "$backup_path/config" ]]; then
        rm -rf "config"
        cp -r "$backup_path/config" .
        print_status "Restored config directory"
    fi
}

# Validate update report
validate_update_report() {
    if [[ ! -f "$UPDATE_REPORT" ]]; then
        print_error "Update report not found: $UPDATE_REPORT"
        print_info "Run './check-mod-updates.sh' first to generate update report"
        return 1
    fi
    
    local report_content=$(cat "$UPDATE_REPORT")
    if [[ -z "$report_content" ]] || [[ "$report_content" == "[]" ]]; then
        print_warning "No updates found in report"
        return 1
    fi
    
    print_status "Update report validated"
    return 0
}

# Apply single mod update
apply_mod_update() {
    local project_id="$1"
    local current_version="$2"
    local latest_version="$3"
    local latest_version_id="$4"
    
    print_info "Applying update for $project_id: $current_version → $latest_version"
    
    # Get new version details from Modrinth
    local version_info=$(curl -s "https://api.modrinth.com/v2/version/$latest_version_id" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$version_info" ]]; then
        print_error "Failed to fetch version info for $latest_version_id"
        return 1
    fi
    
    # Extract file information
    local file_info=$(echo "$version_info" | jq -r '.files[0]')
    local filename=$(echo "$file_info" | jq -r '.filename')
    local download_url=$(echo "$file_info" | jq -r '.url')
    local file_size=$(echo "$file_info" | jq -r '.size')
    local hashes=$(echo "$file_info" | jq -r '.hashes')
    
    # Get environment info from version
    local game_versions=$(echo "$version_info" | jq -r '.game_versions[]')
    local loaders=$(echo "$version_info" | jq -r '.loaders[]')
    
    # Determine environment compatibility
    local env_client="required"
    local env_server="required"
    
    # Check if it's a client-only mod (basic heuristic)
    local mod_name_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    if [[ "$mod_name_lower" == *"client"* ]] || [[ "$mod_name_lower" == *"optifine"* ]] || [[ "$mod_name_lower" == *"shader"* ]]; then
        env_server="unsupported"
    fi
    
    # Update manifest
    local temp_manifest=$(mktemp)
    
    # Find and update the mod entry
    jq --arg old_project_id "$project_id" \
       --arg new_path "mods/$filename" \
       --arg new_url "$download_url" \
       --arg new_size "$file_size" \
       --argjson new_hashes "$hashes" \
       --arg env_client "$env_client" \
       --arg env_server "$env_server" \
       '
       .files = [
         .files[] | 
         if (.downloads[0] | contains($old_project_id)) then
           {
             path: $new_path,
             hashes: $new_hashes,
             env: {
               client: $env_client,
               server: $env_server
             },
             fileSize: ($new_size | tonumber),
             downloads: [$new_url]
           }
         else
           .
         end
       ]
       ' "$MANIFEST_FILE" > "$temp_manifest"
    
    # Validate the updated manifest
    if jq empty "$temp_manifest" 2>/dev/null; then
        mv "$temp_manifest" "$MANIFEST_FILE"
        print_status "Updated manifest for $project_id"
        return 0
    else
        print_error "Failed to update manifest for $project_id (invalid JSON)"
        rm -f "$temp_manifest"
        return 1
    fi
}

# Apply safe updates
apply_safe_updates() {
    print_info "Applying safe updates..."
    
    if ! validate_update_report; then
        return 1
    fi
    
    create_backup
    
    local applied_updates="[]"
    local failed_updates="[]"
    
    # Get safe updates from report
    local safe_updates=$(cat "$UPDATE_REPORT" | jq -r '.[] | select(.has_update == true and (.risk_level == "low" or .risk_level == null)) | @base64')
    
    if [[ -z "$safe_updates" ]]; then
        print_warning "No safe updates available"
        return 0
    fi
    
    local total_updates=$(echo "$safe_updates" | wc -l)
    local current_update=0
    
    echo "$safe_updates" | while read -r update_data; do
        if [[ -z "$update_data" ]]; then
            continue
        fi
        
        current_update=$((current_update + 1))
        
        local update_info=$(echo "$update_data" | base64 -d)
        local project_id=$(echo "$update_info" | jq -r '.project_id')
        local current_version=$(echo "$update_info" | jq -r '.current_version')
        local latest_version=$(echo "$update_info" | jq -r '.latest_version')
        local latest_version_id=$(echo "$update_info" | jq -r '.latest_version_id')
        
        print_info "[$current_update/$total_updates] Processing $project_id..."
        
        if apply_mod_update "$project_id" "$current_version" "$latest_version" "$latest_version_id"; then
            applied_updates=$(echo "$applied_updates" | jq --argjson update "$update_info" '. + [$update]')
            print_status "Successfully updated $project_id"
        else
            failed_updates=$(echo "$failed_updates" | jq --argjson update "$update_info" '. + [$update]')
            print_error "Failed to update $project_id"
        fi
    done
    
    # Save applied updates log
    local update_log=$(jq -n \
        --argjson applied "$applied_updates" \
        --argjson failed "$failed_updates" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg backup_dir "$BACKUP_DIR" \
        '{
            timestamp: $timestamp,
            backup_directory: $backup_dir,
            applied_updates: $applied,
            failed_updates: $failed,
            summary: {
                applied_count: ($applied | length),
                failed_count: ($failed | length)
            }
        }')
    
    echo "$update_log" > "$APPLIED_UPDATES"
    
    local applied_count=$(echo "$applied_updates" | jq 'length')
    local failed_count=$(echo "$failed_updates" | jq 'length')
    
    echo ""
    echo "📊 Update Summary:"
    echo "   ✅ Applied: $applied_count"
    echo "   ❌ Failed: $failed_count"
    echo "   💾 Backup: $BACKUP_DIR"
    echo "   📋 Log: $APPLIED_UPDATES"
    
    if [[ "$applied_count" -gt 0 ]]; then
        print_status "Updates applied successfully!"
        print_info "Next steps:"
        echo "   1. Run './test-develop.sh' to validate changes"
        echo "   2. Test the pack in PrismLauncher"
        echo "   3. Commit changes if everything works"
        echo "   4. Use 'restore $BACKUP_DIR' if issues occur"
    fi
}

# Apply specific update
apply_specific_update() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        print_error "Project ID required"
        return 1
    fi
    
    if ! validate_update_report; then
        return 1
    fi
    
    # Find the specific update
    local update_info=$(cat "$UPDATE_REPORT" | jq -r --arg pid "$project_id" '.[] | select(.project_id == $pid)')
    
    if [[ -z "$update_info" ]]; then
        print_error "No update found for project: $project_id"
        return 1
    fi
    
    local has_update=$(echo "$update_info" | jq -r '.has_update')
    if [[ "$has_update" != "true" ]]; then
        print_info "No update available for $project_id"
        return 0
    fi
    
    create_backup
    
    local current_version=$(echo "$update_info" | jq -r '.current_version')
    local latest_version=$(echo "$update_info" | jq -r '.latest_version')
    local latest_version_id=$(echo "$update_info" | jq -r '.latest_version_id')
    local risk_level=$(echo "$update_info" | jq -r '.risk_level // "unknown"')
    
    print_warning "Applying update for $project_id (Risk: $risk_level)"
    print_info "Version: $current_version → $latest_version"
    
    if apply_mod_update "$project_id" "$current_version" "$latest_version" "$latest_version_id"; then
        print_status "Successfully updated $project_id"
        
        # Create update log
        local update_log=$(jq -n \
            --argjson update "$update_info" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg backup_dir "$BACKUP_DIR" \
            '{
                timestamp: $timestamp,
                backup_directory: $backup_dir,
                applied_updates: [$update],
                failed_updates: [],
                summary: {
                    applied_count: 1,
                    failed_count: 0
                }
            }')
        
        echo "$update_log" > "$APPLIED_UPDATES"
        
        print_info "Next steps:"
        echo "   1. Run './test-develop.sh' to validate changes"
        echo "   2. Test the pack thoroughly"
        echo "   3. Use 'restore $BACKUP_DIR' if issues occur"
    else
        print_error "Failed to update $project_id"
        return 1
    fi
}

# List available updates
list_updates() {
    if ! validate_update_report; then
        return 1
    fi
    
    local updates=$(cat "$UPDATE_REPORT")
    local available_updates=$(echo "$updates" | jq -r '.[] | select(.has_update == true)')
    
    if [[ -z "$available_updates" ]]; then
        print_info "No updates available"
        return 0
    fi
    
    echo "📋 Available Updates:"
    echo "===================="
    
    echo "$available_updates" | jq -r '
        "Project: \(.project_id)",
        "  Current: \(.current_version)",
        "  Latest:  \(.latest_version)",
        "  Risk:    \(.risk_level // "unknown")",
        "  Date:    \(.latest_date // "unknown")",
        ""
    '
}

# Show help
show_help() {
    echo "Safe Mod Update Applicator"
    echo "========================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  safe              - Apply all safe (low-risk) updates"
    echo "  update <project>  - Apply specific update by project ID"
    echo "  list              - List available updates"
    echo "  restore <backup>  - Restore from backup directory"
    echo "  clean             - Clean up temporary files"
    echo ""
    echo "Examples:"
    echo "  $0 safe                    # Apply all safe updates"
    echo "  $0 update sodium           # Update specific mod"
    echo "  $0 restore backup_20250705 # Restore from backup"
    echo ""
    echo "Prerequisites:"
    echo "  - Run './check-mod-updates.sh' first to generate update report"
    echo "  - Ensure you're on the develop branch"
    echo "  - Backup will be created automatically"
}

# Main execution
main() {
    case "${1:-help}" in
        "safe")
            apply_safe_updates
            ;;
        "update")
            if [[ -z "$2" ]]; then
                print_error "Project ID required"
                show_help
                exit 1
            fi
            apply_specific_update "$2"
            ;;
        "list")
            list_updates
            ;;
        "restore")
            if [[ -z "$2" ]]; then
                print_error "Backup directory required"
                show_help
                exit 1
            fi
            restore_backup "$2"
            ;;
        "clean")
            rm -f "$UPDATE_REPORT" "$APPLIED_UPDATES"
            rm -rf backup_*
            print_status "Cleaned up temporary files and backups"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
