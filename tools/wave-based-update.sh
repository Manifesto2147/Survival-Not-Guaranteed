#!/bin/bash

# Protected Wave-Based Mod Update System
# Updates mods in safe waves while protecting dependency providers

set -euo pipefail

# Force line buffering for real-time output on macOS
export PYTHONUNBUFFERED=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
MAGENTA='\033[0;95m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_action() { echo -e "${CYAN}[ACTION]${NC} $1"; }
log_graph() { echo -e "${PURPLE}[GRAPH]${NC} $1"; }
log_wave() { echo -e "${MAGENTA}[WAVE]${NC} $1"; }

# Configuration
MINECRAFT_VERSION="1.21.1"
BASE_DIR="/Users/grimm/Desktop/Development/Survival-Not-Guaranteed"
MODS_DIR="$BASE_DIR/mods"
USER_AGENT="Survival-Not-Guaranteed-ModPack/1.0"
DRY_RUN="${DRY_RUN:-false}"

# CurseForge API Configuration
# Try to load CurseForge API key from GitHub secrets or environment
if [[ -n "${CURSEFORGE_API_KEY:-}" ]]; then
    log_info "CurseForge API key found in environment"
elif [[ -n "${GITHUB_SECRET_CURSEFORGE_API_KEY:-}" ]]; then
    CURSEFORGE_API_KEY="$GITHUB_SECRET_CURSEFORGE_API_KEY"
    log_info "CurseForge API key loaded from GitHub secrets"
elif [[ -f "$HOME/.curseforge_api_key" ]]; then
    CURSEFORGE_API_KEY=$(cat "$HOME/.curseforge_api_key" | tr -d '\n\r')
    log_info "CurseForge API key loaded from ~/.curseforge_api_key"
else
    log_warning "No CurseForge API key found - CurseForge mods will be skipped"
    log_info "To enable CurseForge support:"
    log_info "  - Set CURSEFORGE_API_KEY environment variable"
    log_info "  - Set GITHUB_SECRET_CURSEFORGE_API_KEY (for GitHub Actions)"
    log_info "  - Or place key in ~/.curseforge_api_key file"
fi

export CURSEFORGE_API_KEY

# Environment optimization variables
OPTIMAL_MINECRAFT_VERSION=""
OPTIMAL_NEOFORGE_VERSION=""
FORCE_ENV_UPDATE=false

# Data storage
DETECTED_MODS=()         # Format: "filename:project_id:current_version:latest_version:has_update"
MOD_DEPENDENCIES=()      # Format: "project_id:dep1,dep2,dep3"
MOD_DEPENDENTS=()        # Format: "project_id:dependent1,dependent2"

# Wave categories
WAVE_1_INDEPENDENT=()
WAVE_2_CONSUMERS=()
WAVE_3_PROVIDERS=()
WAVE_4_PROTECTED=()

# Helper functions
get_project_info() {
    local project_id="$1"
    local response
    response=$(curl -s \
        "https://api.modrinth.com/v2/project/$project_id" 2>/dev/null)
    
    if [[ -n "$response" ]] && echo "$response" | jq empty 2>/dev/null; then
        echo "$response"
    else
        echo "{}"
    fi
}

get_version_list() {
    local project_id="$1"
    local response
    
    # Use curl with built-in timeout
    response=$(curl -s --max-time 15 \
        "https://api.modrinth.com/v2/project/$project_id/version?game_versions=%5B%22$MINECRAFT_VERSION%22%5D&loaders=%5B%22neoforge%22%5D" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$response" ]] && echo "$response" | jq empty 2>/dev/null; then
        echo "$response"
    else
        echo "[]"
    fi
}

# Extract data from stored format
get_mod_data() {
    local mod_entry="$1"
    local field="$2"
    
    IFS=':' read -ra PARTS <<< "$mod_entry"
    case "$field" in
        "filename") echo "${PARTS[0]}" ;;
        "project_id") echo "${PARTS[1]}" ;;
        "current_version") echo "${PARTS[2]}" ;;
        "latest_version") echo "${PARTS[3]}" ;;
        "has_update") echo "${PARTS[4]}" ;;
        "external_url") echo "${PARTS[5]:-}" ;;
    esac
}

find_mod_by_project_id() {
    local target_id="$1"
    for mod_entry in "${DETECTED_MODS[@]}"; do
        local project_id=$(get_mod_data "$mod_entry" "project_id")
        if [[ "$project_id" == "$target_id" ]]; then
            echo "$mod_entry"
            return 0
        fi
    done
    return 1
}

get_dependencies() {
    local target_id="$1"
    for dep_entry in "${MOD_DEPENDENCIES[@]}"; do
        IFS=':' read -ra PARTS <<< "$dep_entry"
        if [[ "${PARTS[0]}" == "$target_id" ]]; then
            echo "${PARTS[1]:-}"
            return 0
        fi
    done
    echo ""
}

get_dependents() {
    local target_id="$1"
    for dep_entry in "${MOD_DEPENDENTS[@]}"; do
        IFS=':' read -ra PARTS <<< "$dep_entry"
        if [[ "${PARTS[0]}" == "$target_id" ]]; then
            echo "${PARTS[1]:-}"
            return 0
        fi
    done
    echo ""
}

has_update_available() {
    local target_id="$1"
    local mod_entry
    mod_entry=$(find_mod_by_project_id "$target_id")
    if [[ $? -eq 0 ]]; then
        local has_update=$(get_mod_data "$mod_entry" "has_update")
        [[ "$has_update" == "true" ]]
    else
        return 1
    fi
}

# Auto-detect mods from jar files using metadata with enhanced platform prioritization
auto_detect_mods() {
    log_info "Auto-detecting mods using enhanced JAR metadata analysis in $MODS_DIR..."
    
    # Use the enhanced detection function
    enhanced_auto_detect_mods
}

# Extract mod metadata from JAR file
extract_mod_metadata() {
    local mod_file="$1"
    local metadata_file=$(mktemp)
    
    # Special handling for known mods without standard metadata
    local filename=$(basename "$mod_file")
    case "$filename" in
        kotlinforforge-*)
            # Kotlin for Forge has embedded JARs - extract from nested structure
            local temp_dir=$(mktemp -d)
            if unzip -q "$mod_file" -d "$temp_dir" 2>/dev/null; then
                # Look for the actual mod jar inside
                local nested_jar="$temp_dir/META-INF/jarjar/thedarkcolour.kffmod-5.9.0.jar"
                if [[ -f "$nested_jar" ]] && unzip -p "$nested_jar" META-INF/neoforge.mods.toml 2>/dev/null > "$metadata_file"; then
                    # Successfully extracted TOML from nested jar
                    rm -rf "$temp_dir"
                    # Continue with normal TOML processing below
                else
                    rm -rf "$temp_dir"
                    rm -f "$metadata_file"
                    # Fallback: extract from filename
                    local version=$(echo "$filename" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                    echo "kotlinforforge|$version|Kotlin for Forge|https://github.com/thedarkcolour/KotlinForForge"
                    return 0
                fi
            else
                rm -rf "$temp_dir"
                # Fallback: extract from filename
                local version=$(echo "$filename" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
                echo "kotlinforforge|$version|Kotlin for Forge|https://github.com/thedarkcolour/KotlinForForge"
                return 0
            fi
            ;;
        *)
            # Use standard TOML extraction for other mods
            if ! unzip -p "$mod_file" META-INF/neoforge.mods.toml 2>/dev/null > "$metadata_file"; then
                rm -f "$metadata_file"
                return 1
            fi
            ;;
    esac
    
    if [[ ! -s "$metadata_file" ]]; then
        rm -f "$metadata_file"
        return 1
    fi
    
    # Extract mod information (handle both standard format and array format)
    local mod_id=""
    local version=""
    local display_name=""
    local display_url=""
    
    # Check if this is an array-based format (like Dungeons & Taverns mods)
    if grep -q "mods = \[" "$metadata_file"; then
        # Handle array-based format: { modId = 'value', version = 'value', ... }
        # Use simpler extraction methods that work with single quotes
        mod_id=$(grep "modId =" "$metadata_file" | cut -d"'" -f2 2>/dev/null)
        version=$(grep "version =" "$metadata_file" | grep -v 'Range\|loaderVersion' | cut -d"'" -f2 2>/dev/null)
        display_name=$(grep "displayName =" "$metadata_file" | cut -d"'" -f2 2>/dev/null)
        display_url=$(grep "displayURL =" "$metadata_file" | cut -d"'" -f2 2>/dev/null)
    else
        # Handle standard format: key = value
        # Extract modId - get the first modId that's not exactly "neoforge" or "minecraft"
        mod_id=$(grep -E '^\s*modId\s*=' "$metadata_file" | head -1 | cut -d'"' -f2 2>/dev/null)
        if [[ -z "$mod_id" ]]; then  # If no quotes, try unquoted
            mod_id=$(grep -E '^\s*modId\s*=' "$metadata_file" | head -1 | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
        fi
        # Skip if it's exactly neoforge or minecraft
        if [[ "$mod_id" == "neoforge" ]] || [[ "$mod_id" == "minecraft" ]]; then
            mod_id=$(grep -E '^\s*modId\s*=' "$metadata_file" | sed -n '2p' | cut -d'"' -f2 2>/dev/null)
            if [[ -z "$mod_id" ]]; then
                mod_id=$(grep -E '^\s*modId\s*=' "$metadata_file" | sed -n '2p' | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
            fi
        fi
        
        # Extract version - get the first version that's not a range or loader version
        version=$(grep -E '^\s*version\s*=' "$metadata_file" | grep -v 'Range\|loaderVersion' | head -1 | cut -d'"' -f2 2>/dev/null)
        if [[ -z "$version" ]]; then  # If no quotes, try unquoted
            version=$(grep -E '^\s*version\s*=' "$metadata_file" | grep -v 'Range\|loaderVersion' | head -1 | awk -F'=' '{print $2}' | tr -d ' ' | sed 's/#.*$//' 2>/dev/null)
        fi
        
        # Extract displayName - get the display name
        display_name=$(grep -E '^\s*displayName\s*=' "$metadata_file" | head -1 | cut -d'"' -f2 2>/dev/null)
        if [[ -z "$display_name" ]]; then  # If no quotes, try unquoted
            display_name=$(grep -E '^\s*displayName\s*=' "$metadata_file" | head -1 | awk -F'=' '{print $2}' | tr -d ' ' | sed 's/#.*$//' 2>/dev/null)
        fi
        
        # Extract displayURL - get the display URL
        display_url=$(grep -E '^\s*displayURL\s*=' "$metadata_file" | head -1 | cut -d'"' -f2 2>/dev/null)
        if [[ -z "$display_url" ]]; then  # If no quotes, try unquoted
            display_url=$(grep -E '^\s*displayURL\s*=' "$metadata_file" | head -1 | awk -F'=' '{print $2}' | tr -d ' ' | sed 's/#.*$//' 2>/dev/null)
        fi
    fi
    
    rm -f "$metadata_file"
    
    # Handle ${file.jarVersion} placeholder by extracting version from filename
    if [[ "$version" == '${file.jarVersion}' ]] || [[ -z "$version" ]]; then
        local filename_without_ext=$(basename "$mod_file" .jar)
        # Try to extract version pattern from filename (e.g., "1.8-29", "3.0.7", etc.)
        local extracted_version=$(echo "$filename_without_ext" | grep -oE '[0-9]+\.[0-9]+([.-][0-9a-zA-Z]+)*' | tail -1)
        if [[ -n "$extracted_version" ]]; then
            version="$extracted_version"
        fi
    fi
    
    if [[ -n "$mod_id" ]]; then
        echo "$mod_id|$version|$display_name|$display_url"
        return 0
    fi
    
    return 1
}

# Map mod ID to Modrinth project ID using search
find_modrinth_project() {
    local mod_id="$1"
    local display_name="$2"
    local display_url="$3"
    
    # Input validation
    if [[ -z "$mod_id" ]]; then
        return 1
    fi
    
    # Special case mappings for known problematic mods
    case "$mod_id" in
        "neoforge_armorhud")
            echo "AghHBZC5"  # armor-hud
            return 0
            ;;
        "xaerominimap")
            echo "1bokaNcj"  # xaeros-minimap
            return 0
            ;;
        "kotlinforforge")
            echo "ordsPcFz"  # kotlin-for-forge
            return 0
            ;;
        "dawnoftimebuilder")
            # This mod is only on CurseForge, not Modrinth
            return 1
            ;;
    esac
    
    # Try searching by mod ID first (most reliable) - use curl timeout
    local search_result
    search_result=$(curl -s --max-time 8 --retry 1 "https://api.modrinth.com/v2/search?query=$mod_id&facets=%5B%5B%22project_type:mod%22%5D%5D" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$search_result" ]]; then
        return 1
    fi
    
    # Check if the response is valid JSON
    if ! echo "$search_result" | jq empty 2>/dev/null; then
        return 1
    fi
    
    # Check if we got any hits at all
    local total_hits
    total_hits=$(echo "$search_result" | jq -r '.total_hits // 0' 2>/dev/null)
    if [[ "$total_hits" == "0" ]]; then
        # No results found, try with display name if available
        if [[ -n "$display_name" ]]; then
            local safe_name=$(echo "$display_name" | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/ /%20/g')
            search_result=$(curl -s --max-time 8 --retry 1 "https://api.modrinth.com/v2/search?query=$safe_name&facets=%5B%5B%22project_type:mod%22%5D%5D" 2>/dev/null)
            
            if [[ $? -ne 0 ]] || [[ -z "$search_result" ]] || ! echo "$search_result" | jq empty 2>/dev/null; then
                return 1
            fi
            
            total_hits=$(echo "$search_result" | jq -r '.total_hits // 0' 2>/dev/null)
            if [[ "$total_hits" == "0" ]]; then
                return 1  # Still no results
            fi
        else
            return 1  # No hits and no display name to try
        fi
    fi
    
    # Check if any result has a matching slug (mod_id often matches slug)
    local project_id
    project_id=$(echo "$search_result" | jq -r ".hits[]? | select(.slug? == \"$mod_id\")? | .project_id?" 2>/dev/null | head -1)
    
    if [[ -n "$project_id" ]] && [[ "$project_id" != "null" ]] && [[ "$project_id" != "" ]]; then
        echo "$project_id"
        return 0
    fi
    
    # Try common mod ID to slug mappings for known cases
    local slug_variants=()
    case "$mod_id" in
        "neoforge_armorhud"|"armorhud")
            slug_variants=("armor-hud" "armorhud" "neoforge-armorhud")
            ;;
        "xaerominimap")
            slug_variants=("xaeros-minimap" "xaerominimap" "xaero-minimap")
            ;;
        "kotlinforforge")
            slug_variants=("kotlin-for-forge" "kotlinforforge")
            ;;
        *)
            # Generate common slug variants for any mod_id
            local underscore_to_dash=$(echo "$mod_id" | sed 's/_/-/g')
            local dash_to_underscore=$(echo "$mod_id" | sed 's/-/_/g')
            slug_variants=("$underscore_to_dash" "$dash_to_underscore")
            ;;
    esac
    
    # Check slug variants
    for variant in "${slug_variants[@]}"; do
        project_id=$(echo "$search_result" | jq -r ".hits[]? | select(.slug? == \"$variant\")? | .project_id?" 2>/dev/null | head -1)
        if [[ -n "$project_id" ]] && [[ "$project_id" != "null" ]] && [[ "$project_id" != "" ]]; then
            echo "$project_id"
            return 0
        fi
    done
    
    # If no exact slug match, try to find by title similarity (safer approach)
    if [[ -n "$display_name" ]]; then
        # Simple string match without regex to avoid jq issues
        local clean_name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g')
        project_id=$(echo "$search_result" | jq -r --arg name "$clean_name" '.hits[]? | select(.title? | ascii_downcase | contains($name))? | .project_id?' 2>/dev/null | head -1)
        
        if [[ -n "$project_id" ]] && [[ "$project_id" != "null" ]] && [[ "$project_id" != "" ]]; then
            echo "$project_id"
            return 0
        fi
    fi
    
    # Final fallback: just take the first result if we have any
    project_id=$(echo "$search_result" | jq -r '.hits[0]?.project_id?' 2>/dev/null)
    
    if [[ -n "$project_id" ]] && [[ "$project_id" != "null" ]] && [[ "$project_id" != "" ]]; then
        echo "$project_id"
        return 0
    fi
    
    return 1
}

# Search whitelisted domains and CurseForge for mods not on Modrinth
search_whitelisted_domains() {
    local mod_id="$1"
    local display_name="$2"
    local display_url="$3"
    local filename="$4"
    
    log_info "    Searching external sources for: $mod_id"
    
    # 1. Try CurseForge first (most reliable for mods not on Modrinth)
    local search_terms=("$display_name" "$mod_id")
    for term in "${search_terms[@]}"; do
        if [[ -n "$term" ]]; then
            local curseforge_result
            curseforge_result=$(search_curseforge_mod "$term" "$filename" 2>/dev/null || echo "")
            if [[ -n "$curseforge_result" ]]; then
                echo "$curseforge_result"
                return 0
            fi
        fi
    done
    
    # Clean up search terms
    local clean_mod_id=$(echo "$mod_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    local clean_name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/ /-/g')
    local base_filename=$(basename "$filename" .jar)
    
    # Search terms to try
    local search_terms=("$mod_id" "$clean_mod_id" "$clean_name" "$base_filename")
    
    # 1. Check if displayURL points to a whitelisted domain
    if [[ -n "$display_url" ]]; then
        if is_whitelisted_domain "$display_url"; then
            log_info "      Display URL is on whitelisted domain: $display_url"
            local download_url=$(find_download_from_repo "$display_url" "$filename")
            if [[ -n "$download_url" ]]; then
                echo "$download_url"
                return 0
            fi
        fi
    fi
    
    # 2. Search GitHub for repositories
    for term in "${search_terms[@]}"; do
        if [[ -n "$term" ]]; then
            log_info "      Searching GitHub for: $term"
            local github_url=$(search_github_repos "$term" "$filename")
            if [[ -n "$github_url" ]]; then
                echo "$github_url"
                return 0
            fi
            sleep 0.3  # Rate limiting (reduced from 0.5s)
        fi
    done
    
    # 3. Search GitLab for repositories
    for term in "${search_terms[@]}"; do
        if [[ -n "$term" ]]; then
            log_info "      Searching GitLab for: $term"
            local gitlab_url=$(search_gitlab_repos "$term" "$filename")
            if [[ -n "$gitlab_url" ]]; then
                echo "$gitlab_url"
                return 0
            fi
            sleep 0.3  # Rate limiting (reduced from 0.5s)
        fi
    done
    
    # 4. Check common GitHub raw URLs
    log_info "      Checking common raw.githubusercontent.com patterns"
    local raw_url=$(check_common_raw_urls "$mod_id" "$display_name" "$filename")
    if [[ -n "$raw_url" ]]; then
        echo "$raw_url"
        return 0
    fi
    
    return 1
}

# Check if a URL is from a whitelisted domain
is_whitelisted_domain() {
    local url="$1"
    
    case "$url" in
        *github.com*|*gitlab.com*|*raw.githubusercontent.com*|*cdn.modrinth.com*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Search GitHub repositories
search_github_repos() {
    local search_term="$1"
    local filename="$2"
    
    # GitHub API search with timeout
    local search_result
    search_result=$(curl -s --max-time 10 \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/search/repositories?q=$search_term+minecraft+mod+language:java&sort=stars&order=desc" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$search_result" ]] || ! echo "$search_result" | jq empty 2>/dev/null; then
        return 1
    fi
    
    # Check first few results for releases
    local repos
    repos=$(echo "$search_result" | jq -r '.items[0:3][]?.full_name?' 2>/dev/null)
    
    while IFS= read -r repo; do
        if [[ -n "$repo" ]]; then
            local download_url=$(check_github_releases "$repo" "$filename")
            if [[ -n "$download_url" ]]; then
                echo "$download_url"
                return 0
            fi
        fi
    done <<< "$repos"
    
    return 1
}

# Check GitHub releases for download
check_github_releases() {
    local repo="$1"
    local filename="$2"
    
    # Get latest release
    local release_data
    release_data=$(curl -s --max-time 10 \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$release_data" ]] || ! echo "$release_data" | jq empty 2>/dev/null; then
        return 1
    fi
    
    # Look for JAR files in assets
    local jar_assets
    jar_assets=$(echo "$release_data" | jq -r '.assets[]? | select(.name | test("\\.jar$")) | .browser_download_url?' 2>/dev/null)

    # Try to find exact filename match first
    while IFS= read -r asset_url; do
        if [[ -n "$asset_url" ]]; then
            local asset_name=$(basename "$asset_url")
            if [[ "$asset_name" == "$filename" ]]; then
                echo "$asset_url"
                return 0
            fi
        fi
    done <<< "$jar_assets"
    
    # If no exact match, try pattern matching
    local base_filename=$(basename "$filename" .jar)
    local clean_base=$(echo "$base_filename" | sed 's/-[0-9].*$//')  # Remove version part
    
    while IFS= read -r asset_url; do
        if [[ -n "$asset_url" ]]; then
            local asset_name=$(basename "$asset_url" .jar)
            if [[ "$asset_name" == *"$clean_base"* ]]; then
                echo "$asset_url"
                return 0
            fi
        fi
    done <<< "$jar_assets"
    
    return 1
}

# Search GitLab repositories
search_gitlab_repos() {
    local search_term="$1"
    local filename="$2"
    
    # GitLab API search with timeout
    local search_result
    search_result=$(curl -s --max-time 10 \
        "https://gitlab.com/api/v4/projects?search=$search_term&order_by=stars&sort=desc&per_page=5" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$search_result" ]] || ! echo "$search_result" | jq empty 2>/dev/null; then
        return 1
    fi
    
    # Check first few results for releases
    local project_ids
    project_ids=$(echo "$search_result" | jq -r '.[0:3][]?.id?' 2>/dev/null)
    
    while IFS= read -r project_id; do
        if [[ -n "$project_id" ]]; then
            local download_url=$(check_gitlab_releases "$project_id" "$filename")
            if [[ -n "$download_url" ]]; then
                echo "$download_url"
                return 0
            fi
        fi
    done <<< "$project_ids"
    
    return 1
}

# Check GitLab releases for download
check_gitlab_releases() {
    local project_id="$1"
    local filename="$2"
    
    # Get latest release
    local release_data
    release_data=$(curl -s --max-time 10 \
        "https://gitlab.com/api/v4/projects/$project_id/releases" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$release_data" ]] || ! echo "$release_data" | jq empty 2>/dev/null; then
        return 1
    fi
    
    # Look for JAR files in assets
    local jar_links
    jar_links=$(echo "$release_data" | jq -r '.[0]?.assets?.links[]? | select(.name | test("\\.jar$")) | .url?' 2>/dev/null)
    
    while IFS= read -r link_url; do
        if [[ -n "$link_url" ]]; then
            local link_name=$(basename "$link_url")
            if [[ "$link_name" == "$filename" ]] || [[ "$link_name" == *"$(basename "$filename" .jar)"* ]]; then
                echo "$link_url"
                return 0
            fi
        fi
    done <<< "$jar_links"
    
    return 1
}

# Check common raw.githubusercontent.com patterns
check_common_raw_urls() {
    local mod_id="$1"
    local display_name="$2"
    local filename="$3"
    
    # Common patterns for raw GitHub URLs
    local patterns=(
        "https://raw.githubusercontent.com/${mod_id}/${mod_id}/main/releases/${filename}"
        "https://raw.githubusercontent.com/${mod_id}/${mod_id}/master/releases/${filename}"
        "https://raw.githubusercontent.com/${mod_id}/${mod_id}/main/dist/${filename}"
        "https://raw.githubusercontent.com/${mod_id}/${mod_id}/master/dist/${filename}"
    )
    
    if [[ -n "$display_name" ]]; then
        local clean_name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        patterns+=(
            "https://raw.githubusercontent.com/${clean_name}/${clean_name}/main/releases/${filename}"
            "https://raw.githubusercontent.com/${clean_name}/${clean_name}/master/releases/${filename}"
        )
    fi
    
    for pattern in "${patterns[@]}"; do
        if curl -s --max-time 5 --head "$pattern" | grep -q "200 OK"; then
            echo "$pattern"
            return 0
        fi
        sleep 0.2
    done
    
    return 1
}

# Find download URL from a repository URL
find_download_from_repo() {
    local repo_url="$1"
    local filename="$2"
    
    # Extract owner/repo from URL
    local repo_path=""
    if [[ "$repo_url" =~ github\.com/([^/]+/[^/]+) ]]; then
        repo_path="${BASH_REMATCH[1]}"
        local download_url=$(check_github_releases "$repo_path" "$filename")
        if [[ -n "$download_url" ]]; then
            echo "$download_url"
            return 0
        fi
    elif [[ "$repo_url" =~ gitlab\.com/([^/]+/[^/]+) ]]; then
        # For GitLab, we'd need to get the project ID first
        # This is more complex, so we'll skip for now
        return 1
    fi
    
    return 1
}

# Update modrinth.index.json with external downloads
update_modrinth_index_downloads() {
    local filename="$1"
    local download_url="$2"
    local modrinth_index="$BASE_DIR/modrinth.index.json"
    
    if [[ -f "$modrinth_index" ]]; then
        log_info "      Adding to modrinth.index.json downloads array"
        
        # Add to downloads array
        local temp_file=$(mktemp)
        jq --arg filename "$filename" --arg url "$download_url" '
            .files += [{
                "path": ("mods/" + $filename),
                "downloads": [$url],
                "fileSize": 0
            }]
        ' "$modrinth_index" > "$temp_file" && mv "$temp_file" "$modrinth_index"
        
        return 0
    fi
    
    return 1
}

# Enhanced mod detection using JAR metadata with whitelisted domain search
auto_detect_mods_from_metadata() {
    log_info "Auto-detecting mods from JAR metadata in $MODS_DIR..."
    
    local detected_count=0
    local failed_count=0
    local total_jars=$(find "$MODS_DIR" -name "*.jar" | wc -l)
    local current_jar=0
    
    for mod_file in "$MODS_DIR"/*.jar; do
        if [[ -f "$mod_file" ]]; then
            current_jar=$((current_jar + 1))
            local filename=$(basename "$mod_file")
            echo -ne "\r\033[K"  # Clear line
            log_info "  Processing: $filename ($current_jar/$total_jars)"
            
            # Extract metadata from JAR - simplified approach
            local metadata=""
            metadata=$(extract_mod_metadata "$mod_file" 2>/dev/null || echo "")
            
            if [[ -n "$metadata" ]]; then
                IFS='|' read -ra META_PARTS <<< "$metadata"
                local mod_id="${META_PARTS[0]:-}"
                local current_version="${META_PARTS[1]:-}"
                local display_name="${META_PARTS[2]:-}"
                local display_url="${META_PARTS[3]:-}"
                
                if [[ -n "$mod_id" ]]; then
                    log_info "    Metadata: ID=$mod_id, Name=$display_name, Version=$current_version"
                    
                    # Find corresponding Modrinth project - simplified call
                    local project_id=""
                    project_id=$(find_modrinth_project "$mod_id" "$display_name" "$display_url" 2>/dev/null || echo "")
                    
                    if [[ -n "$project_id" ]] && [[ "$project_id" != "null" ]]; then
                        log_info "    → Found on Modrinth: $project_id"
                        # Get latest version for this project
                        local versions
                        versions=$(get_version_list "$project_id" 2>/dev/null || echo "[]")
                        local latest_version=""
                        local has_update="false"
                        
                        if [[ "$versions" != "[]" ]] && [[ -n "$versions" ]]; then
                            latest_version=$(echo "$versions" | jq -r '.[0].version_number // empty' 2>/dev/null || echo "")
                            if [[ -n "$latest_version" ]]; then
                                if [[ -z "$current_version" ]] || [[ "$current_version" != "$latest_version" ]]; then
                                    has_update="true"
                                fi
                            fi
                        fi
                        
                        # Store mod data
                        DETECTED_MODS+=("$filename:$project_id:$current_version:$latest_version:$has_update")
                        if [[ "$has_update" == "true" ]]; then
                            log_info "      ✓ Update available: $current_version → $latest_version"
                        else
                            log_info "      ✓ Up to date"
                        fi
                        
                        ((detected_count++))
                    else
                        log_warning "    Could not find Modrinth project for mod ID: $mod_id (name: $display_name)"
                        
                        # Skip whitelisted domain search in dry-run for now to avoid hangs
                        if [[ "$DRY_RUN" != "true" ]]; then
                            log_info "    Searching external sources for alternative download..."
                            local external_url=""
                            external_url=$(search_external_mod_sources "$mod_id" "$display_name" "$display_url" "$filename" 2>/dev/null || echo "")
                            
                            if [[ -n "$external_url" ]]; then
                                if [[ "$external_url" == curseforge:* ]]; then
                                    log_info "    Found on CurseForge: $external_url"
                                    # Store as CurseForge mod with update info
                                    DETECTED_MODS+=("$filename:curseforge:$current_version:check_update:true:$external_url")
                                    ((detected_count++))
                                else
                                    log_info "    Found external download: $external_url"
                                    # Store as external mod (no updates available)
                                    DETECTED_MODS+=("$filename:external:$current_version:$current_version:false:$external_url")
                                    ((detected_count++))
                                fi
                            else
                                log_warning "    Not found on external sources - recommend manual addition to overrides"
                                ((failed_count++))
                            fi
                        else
                            log_info "    (Skipping external search in dry-run mode)"
                            ((failed_count++))
                        fi
                    fi
                else
                    log_warning "    No valid mod ID found in metadata"
                    ((failed_count++))
                fi
            else
                log_warning "    Could not extract metadata from JAR"
                ((failed_count++))
            fi
            
            sleep 0.05  # Minimal rate limiting
            
            # Progress report every 10 mods
            if (( current_jar % 10 == 0 )); then
                log_info "  Progress: $detected_count detected, $failed_count failed out of $current_jar processed"
            fi
        fi
    done
    
    log_info "Detected $detected_count mods, failed to identify $failed_count mods"
    log_info "Detection completed successfully"
}

# Enhanced CurseForge API search with better matching
search_curseforge_mod() {
    local mod_id="$1"
    local display_name="$2"
    local filename="$3"
    
    # Check if CurseForge API key is available
    if [[ -z "${CURSEFORGE_API_KEY:-}" ]]; then
        log_warning "    CurseForge API key not available - skipping CurseForge search"
        return 1
    fi
    
    log_info "    Searching CurseForge for: $display_name"
    
    # Clean up search term - prefer display_name over mod_id for CurseForge
    local search_term="${display_name:-$mod_id}"
    local clean_name=$(echo "$search_term" | sed 's/[^a-zA-Z0-9 ]/ /g' | sed 's/  */ /g' | tr '[:upper:]' '[:lower:]')
    local search_url="https://api.curseforge.com/v1/mods/search"
    
    # Search parameters: gameId=432 (Minecraft), categoryId=6 (Mods), sortField=2 (Popularity)
    local search_result
    search_result=$(curl -s --max-time 10 \
        -H "Accept: application/json" \
        -H "x-api-key: ${CURSEFORGE_API_KEY}" \
        "$search_url?gameId=432&categoryId=6&searchFilter=$clean_name&sortField=2&sortOrder=desc&pageSize=20" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$search_result" ]] || ! echo "$search_result" | jq empty 2>/dev/null; then
        log_warning "    Failed to search CurseForge API"
        return 1
    fi
    
    # Check if we got any results
    local mod_count
    mod_count=$(echo "$search_result" | jq -r '.data | length' 2>/dev/null)
    if [[ "$mod_count" == "0" ]]; then
        log_info "    No mods found on CurseForge for: $search_term"
        return 1
    fi
    
    # Look for best match with multiple strategies
    local mod_info=""
    
    # Strategy 1: Exact name match (case insensitive)
    mod_info=$(echo "$search_result" | jq -r --arg name "$clean_name" '.data[]? | select(.name | ascii_downcase == $name) | "\(.id)|\(.name)|\(.slug)"' 2>/dev/null | head -1)
    
    if [[ -z "$mod_info" ]]; then
        # Strategy 2: Name contains search term
        mod_info=$(echo "$search_result" | jq -r --arg name "$clean_name" '.data[]? | select(.name | ascii_downcase | contains($name)) | "\(.id)|\(.name)|\(.slug)"' 2>/dev/null | head -1)
    fi
    
    if [[ -z "$mod_info" ]]; then
        # Strategy 3: Slug matches mod_id patterns
        local mod_id_variants=()
        mod_id_variants+=("$mod_id")
        mod_id_variants+=("$(echo "$mod_id" | sed 's/_/-/g')")  # underscore to dash
        mod_id_variants+=("$(echo "$mod_id" | sed 's/-/_/g')")  # dash to underscore
        
        for variant in "${mod_id_variants[@]}"; do
            mod_info=$(echo "$search_result" | jq -r --arg slug "$variant" '.data[]? | select(.slug == $slug) | "\(.id)|\(.name)|\(.slug)"' 2>/dev/null | head -1)
            if [[ -n "$mod_info" ]]; then
                break
            fi
        done
    fi
    
    if [[ -z "$mod_info" ]]; then
        # Strategy 4: Filename-based matching (remove version numbers and compare)
        local base_filename=$(echo "$filename" | sed 's/-[0-9].*\.jar$//' | sed 's/_[0-9].*\.jar$//' | tr '[:upper:]' '[:lower:]')
        mod_info=$(echo "$search_result" | jq -r --arg base "$base_filename" '.data[]? | select(.slug | contains($base)) | "\(.id)|\(.name)|\(.slug)"' 2>/dev/null | head -1)
    fi
    
    if [[ -z "$mod_info" ]]; then
        # Strategy 5: Take first result with manual verification
        local first_result
        first_result=$(echo "$search_result" | jq -r '.data[0] | "\(.id)|\(.name)|\(.slug)"' 2>/dev/null)
        
        if [[ -n "$first_result" ]]; then
            local first_name=$(echo "$first_result" | cut -d'|' -f2)
            log_warning "    Using best guess from CurseForge: $first_name"
            log_warning "    Please verify this is correct for mod: $display_name"
            mod_info="$first_result"
        fi
    fi
    
    if [[ -n "$mod_info" ]]; then
        echo "$mod_info"
        return 0
    fi
    
    return 1
}

get_curseforge_latest_file() {
    local mod_id="$1"
    local minecraft_version="$2"
    
    if [[ -z "${CURSEFORGE_API_KEY:-}" ]]; then
        return 1
    fi
    
    # Get mod files for the specific Minecraft version
    local files_url="https://api.curseforge.com/v1/mods/$mod_id/files"
    local files_result
    files_result=$(curl -s --max-time 10 \
        -H "Accept: application/json" \
        -H "x-api-key: ${CURSEFORGE_API_KEY}" \
        "$files_url?gameVersion=$minecraft_version&modLoaderType=4" 2>/dev/null)  # modLoaderType=4 is NeoForge
    
    if [[ $? -ne 0 ]] || [[ -z "$files_result" ]] || ! echo "$files_result" | jq empty 2>/dev/null; then
        # Fallback: try without mod loader filter
        files_result=$(curl -s --max-time 10 \
            -H "Accept: application/json" \
            -H "x-api-key: ${CURSEFORGE_API_KEY}" \
            "$files_url?gameVersion=$minecraft_version" 2>/dev/null)
    fi
    
    if [[ $? -eq 0 ]] && [[ -n "$files_result" ]] && echo "$files_result" | jq empty 2>/dev/null; then
        # Get the latest file (first in list, sorted by date)
        local file_info
        file_info=$(echo "$files_result" | jq -r '.data[0] | "\(.id)|\(.fileName)|\(.downloadUrl)"' 2>/dev/null)
        
        if [[ -n "$file_info" ]] && [[ "$file_info" != "null" ]]; then
            echo "$file_info"
            return 0
        fi
    fi
    
    return 1
}

get_curseforge_download_url() {
    local mod_id="$1"
    local file_id="$2"
    
    if [[ -z "${CURSEFORGE_API_KEY:-}" ]]; then
        return 1
    fi
    
    local file_info_url="https://api.curseforge.com/v1/mods/$mod_id/files/$file_id"
    local file_info
    file_info=$(curl -s --max-time 10 \
        -H "Accept: application/json" \
        -H "x-api-key: ${CURSEFORGE_API_KEY}" \
        "$file_info_url" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$file_info" ]] && echo "$file_info" | jq empty 2>/dev/null; then
        local download_url
        download_url=$(echo "$file_info" | jq -r '.data.downloadUrl // empty' 2>/dev/null)
        if [[ -n "$download_url" ]]; then
            echo "$download_url"
            return 0
        fi
    fi
    
    return 1
}
search_external_mod_sources() {
    local mod_id="$1"
    local display_name="$2"
    local display_url="$3"
    local filename="$4"
    
    log_info "    Searching external sources for: $mod_id"
    
    # 1. Try CurseForge first for better reliability
    log_info "      Searching CurseForge..."
    local curseforge_result
    curseforge_result=$(search_curseforge_mod "$mod_id" "$display_name" "$filename" 2>/dev/null || echo "")
    
    if [[ -n "$curseforge_result" ]]; then
        IFS='|' read -ra CF_PARTS <<< "$curseforge_result"
        local cf_mod_id="${CF_PARTS[0]:-}"
        local cf_name="${CF_PARTS[1]:-}"
        local cf_slug="${CF_PARTS[2]:-}"
        
        log_info "      Found on CurseForge: $cf_name (ID: $cf_mod_id)"
        
        # Get latest file
        local file_info
        file_info=$(get_curseforge_latest_file "$cf_mod_id" "$MINECRAFT_VERSION" 2>/dev/null || echo "")
        
        if [[ -n "$file_info" ]]; then
            IFS='|' read -ra FILE_PARTS <<< "$file_info"
            local file_id="${FILE_PARTS[0]:-}"
            local file_name="${FILE_PARTS[1]:-}"
            local download_url="${FILE_PARTS[2]:-}"
            
            if [[ -n "$download_url" ]]; then
                log_info "      Latest file: $file_name"
                echo "curseforge:$cf_mod_id:$file_id:$download_url:$file_name"
                return 0
            fi
        fi
    fi
    
    # 2. Fall back to whitelisted domain search
    log_info "      Trying whitelisted domains..."
    local whitelisted_result
    whitelisted_result=$(search_whitelisted_domains "$mod_id" "$display_name" "$display_url" "$filename" 2>/dev/null || echo "")
    
    if [[ -n "$whitelisted_result" ]]; then
        echo "external:$whitelisted_result"
        return 0
    fi
    
    return 1
}

# Update a CurseForge mod
update_curseforge_mod() {
    local mod_info="$1"  # Format: curseforge:mod_id:file_id:download_url:filename
    local old_filename="$2"
    
    IFS=':' read -ra PARTS <<< "$mod_info"
    local cf_mod_id="${PARTS[1]:-}"
    local cf_file_id="${PARTS[2]:-}"
    local download_url="${PARTS[3]:-}"
    local new_filename="${PARTS[4]:-}"
    
    if [[ -z "$download_url" ]] || [[ -z "$new_filename" ]]; then
        log_error "  Invalid CurseForge mod info: $mod_info"
        return 1
    fi
    
    # Remove old file
    local old_file="$MODS_DIR/$old_filename"
    if [[ -f "$old_file" ]]; then
        log_info "  Removing old file: $old_filename"
        rm "$old_file"
    fi
    
    # Download new file
    local new_file="$MODS_DIR/$new_filename"
    log_info "  Downloading from CurseForge: $new_filename"
    
    if curl -L -o "$new_file" "$download_url"; then
        log_success "  Updated CurseForge mod successfully"
        return 0
    else
        log_error "  Failed to download from CurseForge"
        return 1
    fi
}

# Update a single mod (Modrinth or CurseForge)
update_mod() {
    local project_id="$1"
    
    local mod_entry
    mod_entry=$(find_mod_by_project_id "$project_id")
    if [[ $? -ne 0 ]]; then
        log_error "Mod not found: $project_id"
        return 1
    fi
    
    local filename=$(get_mod_data "$mod_entry" "filename")
    local latest_version=$(get_mod_data "$mod_entry" "latest_version")
    local external_url=$(get_mod_data "$mod_entry" "external_url")
    
    # Handle CurseForge mods differently
    if [[ "$project_id" == "curseforge" ]]; then
        return update_curseforge_mod "$external_url" "$filename"
    fi
    
    log_action "Updating $project_id to $latest_version..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "  [DRY RUN] Would update $project_id ($filename)"
        return 0
    fi
    
    # Get download info from Modrinth
    local versions
    versions=$(get_version_list "$project_id")
    local download_url
    download_url=$(echo "$versions" | jq -r '.[0].files[0].url // empty')
    local new_filename
    new_filename=$(echo "$versions" | jq -r '.[0].files[0].filename // empty')
    
    if [[ -z "$download_url" ]] || [[ -z "$new_filename" ]]; then
        log_error "  Could not get download info for $project_id"
        return 1
    fi
    
    # Remove old file
    local old_file="$MODS_DIR/$filename"
    if [[ -f "$old_file" ]]; then
        log_info "  Removing old file: $filename"
        rm "$old_file"
    fi
    
    # Download new file
    local new_file="$MODS_DIR/$new_filename"
    log_info "  Downloading: $new_filename"
    
    if curl -L -o "$new_file" "$download_url"; then
        log_success "  Updated $project_id successfully"
        return 0
    else
        log_error "  Failed to download $project_id"
        return 1
    fi
}

# Execute a wave of updates
execute_wave() {
    local wave_name="$1"
    shift
    local wave_mods=("$@")
    
    # Filter out external mods (they can't be updated), but allow CurseForge
    local updateable_mods=()
    for project_id in "${wave_mods[@]}"; do
        if [[ "$project_id" != "external" ]]; then
            updateable_mods+=("$project_id")
        fi
    done
    
    if [[ ${#updateable_mods[@]} -eq 0 ]]; then
        log_info "$wave_name: No mods to update"
        return 0
    fi
    
    log_wave "Executing $wave_name (${#updateable_mods[@]} mods)..."
    
    local success_count=0
    local failure_count=0
    
    for project_id in "${updateable_mods[@]}"; do
        if update_mod "$project_id"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
        sleep 0.5
    done
    
    log_success "$wave_name completed: $success_count successful, $failure_count failed"
    return $failure_count
}

# Determine optimal environment versions
determine_optimal_environment() {
    log_info "Analyzing mod compatibility for optimal environment versions..."
    
    local minecraft_versions=()
    local neoforge_versions=()
    local neoforge_requirements=()
    local mod_count=0
    
    # First, extract NeoForge requirements from actual mod JAR files
    log_info "  Extracting NeoForge requirements from mod files..."
    
    # Sample a few mod files for efficiency
    local sample_count=0
    local max_samples=20
    
    for mod_file in "$MODS_DIR"/*.jar; do
        if [[ -f "$mod_file" ]] && [[ $sample_count -lt $max_samples ]]; then
            local neoforge_req
            neoforge_req=$(unzip -p "$mod_file" META-INF/neoforge.mods.toml 2>/dev/null | \
                          grep -A 3 'modId="neoforge"' | \
                          grep 'versionRange=' | \
                          grep -o '"[^"]*"' | tr -d '"' | \
                          head -1)
            
            if [[ -n "$neoforge_req" ]]; then
                neoforge_requirements+=("$neoforge_req")
                
                # Extract minimum version from range (e.g., "[21.1.0,)" -> "21.1.0"
                local min_version
                min_version=$(echo "$neoforge_req" | sed 's/\[\([^,]*\).*/\1/')
                if [[ "$min_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9]+)?$ ]]; then
                    neoforge_versions+=("$min_version")
                fi
            fi
            
            # Also extract Minecraft version from the mod
            local mc_req
            mc_req=$(unzip -p "$mod_file" META-INF/neoforge.mods.toml 2>/dev/null | \
                    grep -A 3 'modId="minecraft"' | \
                    grep 'versionRange=' | \
                    grep -o '"[^"]*"' | tr -d '"' | \
                    head -1)
            
            if [[ -n "$mc_req" ]]; then
                # Extract version range (e.g., "[1.21, 1.21.1)" -> "1.21" and "1.21.1")
                local mc_versions_from_range
                mc_versions_from_range=$(echo "$mc_req" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -u)
                while IFS= read -r version; do
                    if [[ -n "$version" ]]; then
                        minecraft_versions+=("$version")
                    fi
                done <<< "$mc_versions_from_range"
            fi
            
            ((sample_count++))
        fi
    done
    
    mod_count=$sample_count
    log_info "  Extracted requirements from $mod_count mod files"
    
    # Also collect versions from Modrinth API for additional context
    log_info "  Cross-referencing with Modrinth API..."
    local api_check_count=0
    
    for mod_entry in "${DETECTED_MODS[@]}"; do
        local project_id=$(get_mod_data "$mod_entry" "project_id")
        
        if [[ -n "$project_id" ]] && [[ $api_check_count -lt 20 ]]; then  # Limit API calls
            local versions
            versions=$(curl -s "https://api.modrinth.com/v2/project/$project_id/version" 2>/dev/null)
            
            if [[ -n "$versions" ]] && echo "$versions" | jq empty 2>/dev/null; then
                # Get Minecraft versions supported by this mod
                local mc_versions
                mc_versions=$(echo "$versions" | jq -r '.[].game_versions[]' 2>/dev/null | sort -u)
                
                if [[ -n "$mc_versions" ]]; then
                    while IFS= read -r version; do
                        if [[ -n "$version" ]]; then
                            minecraft_versions+=("$version")
                        fi
                    done <<< "$mc_versions"
                fi
                
                ((api_check_count++))
            fi
        fi
        
        # Rate limiting
        if [[ $((api_check_count % 5)) -eq 0 ]] && [[ $api_check_count -gt 0 ]]; then
            sleep 1
        fi
    done
    
    log_info "Analyzed $mod_count mods for version compatibility"
    
    # Show some examples of the NeoForge requirements found
    if [[ ${#neoforge_requirements[@]} -gt 0 ]]; then
        log_info "  Found NeoForge requirements:"
        local unique_reqs=($(printf '%s\n' "${neoforge_requirements[@]}" | sort -u | head -5))
        for req in "${unique_reqs[@]}"; do
            log_info "    $req"
        done
        if [[ ${#neoforge_requirements[@]} -gt 5 ]]; then
            log_info "    ... and $((${#neoforge_requirements[@]} - 5)) more"
        fi
    fi
    
    # Find the most common/compatible Minecraft version
    if [[ ${#minecraft_versions[@]} -gt 0 ]]; then
        local optimal_mc_version
        optimal_mc_version=$(printf '%s\n' "${minecraft_versions[@]}" | sort | uniq -c | sort -nr | head -1 | awk '{print $2}')
        log_info "  Most compatible Minecraft version: $optimal_mc_version"
        
        # Update configuration if different
        if [[ "$optimal_mc_version" != "$MINECRAFT_VERSION" ]]; then
            log_warning "  Current: $MINECRAFT_VERSION -> Recommended: $optimal_mc_version"
            OPTIMAL_MINECRAFT_VERSION="$optimal_mc_version"
        else
            log_success "  Current Minecraft version is optimal: $MINECRAFT_VERSION"
            OPTIMAL_MINECRAFT_VERSION="$MINECRAFT_VERSION"
        fi
    else
        log_warning "  Could not determine optimal Minecraft version"
        OPTIMAL_MINECRAFT_VERSION="$MINECRAFT_VERSION"
    fi
    
    # Find the highest minimum NeoForge version required
    if [[ ${#neoforge_versions[@]} -gt 0 ]]; then
        # Sort versions and get the highest minimum requirement
        local optimal_nf_version
        optimal_nf_version=$(printf '%s\n' "${neoforge_versions[@]}" | sort -V | tail -1)
        log_info "  Highest minimum NeoForge version required: $optimal_nf_version"
        
        # Get a more recent stable version that satisfies this requirement
        local recommended_nf_version
        case "$OPTIMAL_MINECRAFT_VERSION" in
            "1.21.1") 
                # For 1.21.1, use a recent stable version that's >= the minimum
                if [[ $(printf '%s\n%s' "$optimal_nf_version" "21.1.0" | sort -V | head -1) == "$optimal_nf_version" ]]; then
                    recommended_nf_version="21.1.200"  # Recent stable version
                else
                    recommended_nf_version="$optimal_nf_version"
                fi
                ;;
            "1.21.0"|"1.21") 
                if [[ $(printf '%s\n%s' "$optimal_nf_version" "21.0.0" | sort -V | head -1) == "$optimal_nf_version" ]]; then
                    recommended_nf_version="21.0.168"
                else
                    recommended_nf_version="$optimal_nf_version"
                fi
                ;;
            *) 
                recommended_nf_version="$optimal_nf_version"
                ;;
        esac
        
        log_info "  Recommended NeoForge version: $recommended_nf_version"
        OPTIMAL_NEOFORGE_VERSION="$recommended_nf_version"
    else
        # Get latest stable NeoForge version from API if mods don't specify
        log_info "  No specific NeoForge requirements found, checking for latest stable version..."
        local latest_neoforge
        latest_neoforge=$(curl -s "https://api.modrinth.com/v2/project/neoforge/version?game_versions=%5B%22$OPTIMAL_MINECRAFT_VERSION%22%5D" 2>/dev/null | jq -r '.[0].version_number // empty' 2>/dev/null)
        
        if [[ -n "$latest_neoforge" ]]; then
            log_info "  Latest stable NeoForge for $OPTIMAL_MINECRAFT_VERSION: $latest_neoforge"
            OPTIMAL_NEOFORGE_VERSION="$latest_neoforge"
        else
            # Final fallback - use a reasonable default for the Minecraft version
            case "$OPTIMAL_MINECRAFT_VERSION" in
                "1.21.1") OPTIMAL_NEOFORGE_VERSION="21.1.200" ;;
                "1.21.0"|"1.21") OPTIMAL_NEOFORGE_VERSION="21.0.168" ;;
                "1.20.6") OPTIMAL_NEOFORGE_VERSION="20.6.119" ;;
                "1.20.4") OPTIMAL_NEOFORGE_VERSION="20.4.237" ;;
                *) OPTIMAL_NEOFORGE_VERSION="21.1.200" ;;
            esac
            log_warning "  Could not determine optimal NeoForge version, using default: $OPTIMAL_NEOFORGE_VERSION"
        fi
    fi
}

# Update environment configuration files
update_environment_config() {
    local new_mc_version="$1"
    local new_nf_version="$2"
    
    log_info "Updating environment configuration..."
    
    # Update this script's configuration
    if [[ "$new_mc_version" != "$MINECRAFT_VERSION" ]]; then
        log_action "Updating script Minecraft version: $MINECRAFT_VERSION -> $new_mc_version"
        sed -i '' "s/MINECRAFT_VERSION=\"$MINECRAFT_VERSION\"/MINECRAFT_VERSION=\"$new_mc_version\"/" "$0"
    fi
    
    # Update build.sh if it exists
    local build_script="$BASE_DIR/build.sh"
    if [[ -f "$build_script" ]]; then
        local current_build_nf=""
        
        # Get current NeoForge version from build.sh to show the change
        current_build_nf=$(grep -oE '21\.1\.[0-9]+' "$build_script" | head -1)
        if [[ -z "$current_build_nf" ]]; then
            current_build_nf=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$build_script" | grep -E '^(20|21)\.' | head -1)
        fi
        
        if [[ -n "$current_build_nf" ]] && [[ "$current_build_nf" != "$new_nf_version" ]]; then
            log_action "Updating build.sh NeoForge version: $current_build_nf -> $new_nf_version"
        else
            log_action "Setting build.sh NeoForge version to: $new_nf_version"
        fi
        
        # Update various NeoForge version patterns in build.sh
        # Look for explicit variable assignments first
        if grep -q "NEOFORGE_VERSION=" "$build_script"; then
            sed -i '' "s/NEOFORGE_VERSION=\"[^\"]*\"/NEOFORGE_VERSION=\"$new_nf_version\"/" "$build_script"
            sed -i '' "s/NEOFORGE_VERSION=[^[:space:]]*/NEOFORGE_VERSION=$new_nf_version/" "$build_script"
        elif grep -q "neoforge_version=" "$build_script"; then
            sed -i '' "s/neoforge_version=\"[^\"]*\"/neoforge_version=\"$new_nf_version\"/" "$build_script"
            sed -i '' "s/neoforge_version=[^[:space:]]*/neoforge_version=$new_nf_version/" "$build_script"
        fi
        
        # Update version patterns in comments or text
        if [[ -n "$current_build_nf" ]]; then
            # Replace the specific current version with new version
            sed -i '' "s/$current_build_nf/$new_nf_version/g" "$build_script"
        else
            # Look for and replace any NeoForge version-like patterns
            sed -i '' "s/21\.1\.[0-9]*/$(echo "$new_nf_version" | sed 's/\./\\./g')/g" "$build_script"
        fi
        
        # Update Minecraft version if different
        if [[ "$new_mc_version" != "$MINECRAFT_VERSION" ]]; then
            log_action "Updating build.sh Minecraft version: $MINECRAFT_VERSION -> $new_mc_version"
            sed -i '' "s/$MINECRAFT_VERSION/$new_mc_version/g" "$build_script"
        fi
    fi
    
    # Update modrinth.index.json if it exists
    local modrinth_index="$BASE_DIR/modrinth.index.json"
    if [[ -f "$modrinth_index" ]]; then
        log_action "Updating modrinth.index.json versions"
        
        # Update Minecraft version
        jq --arg mc_version "$new_mc_version" '.versionId = $mc_version' "$modrinth_index" > "${modrinth_index}.tmp" && mv "${modrinth_index}.tmp" "$modrinth_index"
        
        # Update NeoForge dependency
        jq --arg nf_version "$new_nf_version" '
            .dependencies.neoforge = $nf_version
        ' "$modrinth_index" > "${modrinth_index}.tmp" && mv "${modrinth_index}.tmp" "$modrinth_index"
    fi
    
    log_success "Environment configuration updated"
}

# Build dependency graph from detected mods
build_dependency_graph() {
    log_graph "Building dependency graph..."
    
    # Clear existing data
    MOD_DEPENDENCIES=()
    MOD_DEPENDENTS=()
    
    local processed_count=0
    
    # Process each detected mod to find its dependencies
    for mod_entry in "${DETECTED_MODS[@]}"; do
        local project_id=$(get_mod_data "$mod_entry" "project_id")
        
        # Skip external and CurseForge mods for dependency analysis
        if [[ "$project_id" == "external" ]] || [[ "$project_id" == "curseforge" ]]; then
            continue
        fi
        
        log_graph "  Analyzing dependencies for: $project_id"
        
        # Get project info from Modrinth
        local project_info=$(get_project_info "$project_id")
        
        if [[ -n "$project_info" ]] && echo "$project_info" | jq empty 2>/dev/null; then
            # Get version list to find dependencies
            local versions=$(get_version_list "$project_id")
            
            if [[ -n "$versions" ]] && echo "$versions" | jq empty 2>/dev/null; then
                # Extract dependencies from the latest version
                local dependencies=$(echo "$versions" | jq -r '.[0].dependencies[]? | select(.dependency_type == "required") | .project_id' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                
                if [[ -n "$dependencies" ]]; then
                    MOD_DEPENDENCIES+=("$project_id:$dependencies")
                    log_graph "    → Dependencies: $dependencies"
                    
                    # Update dependents mapping
                    IFS=',' read -ra DEPS <<< "$dependencies"
                    for dep in "${DEPS[@]}"; do
                        # Find existing dependents entry for this dependency
                        local found=false
                        for i in "${!MOD_DEPENDENTS[@]}"; do
                            local entry="${MOD_DEPENDENTS[$i]}"
                            local dep_id="${entry%%:*}"
                            if [[ "$dep_id" == "$dep" ]]; then
                                # Add this project as a dependent
                                MOD_DEPENDENTS[$i]="${entry},$project_id"
                                found=true
                                break
                            fi
                        done
                        
                        if [[ "$found" == "false" ]]; then
                            MOD_DEPENDENTS+=("$dep:$project_id")
                        fi
                    done
                else
                    MOD_DEPENDENCIES+=("$project_id:")
                    log_graph "    → No dependencies"
                fi
            else
                MOD_DEPENDENCIES+=("$project_id:")
                log_graph "    → No version data available"
            fi
        else
            MOD_DEPENDENCIES+=("$project_id:")
            log_graph "    → No project info available"
        fi
        
        processed_count=$((processed_count + 1))
    done
    
    log_graph "Dependency analysis completed for $processed_count mods"
}

# Categorize mods into update waves
categorize_waves() {
    log_wave "Categorizing mods into update waves..."
    
    # Clear wave arrays
    WAVE_1_INDEPENDENT=()
    WAVE_2_CONSUMERS=()
    WAVE_3_PROVIDERS=()
    WAVE_4_PROTECTED=()
    
    # Process each detected mod
    for mod_entry in "${DETECTED_MODS[@]}"; do
        local project_id=$(get_mod_data "$mod_entry" "project_id")
        local has_update=$(get_mod_data "$mod_entry" "has_update")
        
        # Skip mods that don't need updates
        if [[ "$has_update" != "true" ]]; then
            continue
        fi
        
        # Skip external mods (can't be updated)
        if [[ "$project_id" == "external" ]]; then
            continue
        fi
        
        # Find dependencies and dependents for this mod
        local dependencies=""
        local dependents=""
        
        for dep_entry in "${MOD_DEPENDENCIES[@]}"; do
            local dep_id="${dep_entry%%:*}"
            if [[ "$dep_id" == "$project_id" ]]; then
                dependencies="${dep_entry#*:}"
                break
            fi
        done
        
        for dependent_entry in "${MOD_DEPENDENTS[@]}"; do
            local dependent_id="${dependent_entry%%:*}"
            if [[ "$dependent_id" == "$project_id" ]]; then
                dependents="${dependent_entry#*:}"
                break
            fi
        done
        
        # Categorize based on dependency relationships
        if [[ -z "$dependencies" ]] && [[ -z "$dependents" ]]; then
            # No dependencies or dependents - safe to update first
            WAVE_1_INDEPENDENT+=("$project_id")
            log_wave "  Wave 1 (Independent): $project_id"
        elif [[ -n "$dependencies" ]] && [[ -z "$dependents" ]]; then
            # Has dependencies but no dependents - consumer mod
            WAVE_2_CONSUMERS+=("$project_id")
            log_wave "  Wave 2 (Consumer): $project_id"
        elif [[ -z "$dependencies" ]] && [[ -n "$dependents" ]]; then
            # No dependencies but has dependents - provider mod
            WAVE_3_PROVIDERS+=("$project_id")
            log_wave "  Wave 3 (Provider): $project_id"
        else
            # Has both dependencies and dependents - handle carefully
            WAVE_4_PROTECTED+=("$project_id")
            log_wave "  Wave 4 (Protected): $project_id"
        fi
    done
    
    log_wave "Wave categorization completed:"
    log_wave "  Wave 1 (Independent): ${#WAVE_1_INDEPENDENT[@]} mods"
    log_wave "  Wave 2 (Consumers): ${#WAVE_2_CONSUMERS[@]} mods"
    log_wave "  Wave 3 (Providers): ${#WAVE_3_PROVIDERS[@]} mods"
    log_wave "  Wave 4 (Protected): ${#WAVE_4_PROTECTED[@]} mods"
}

# Enhanced mod project identification with better Modrinth prioritization
identify_mod_project() {
    local mod_id="$1"
    local display_name="$2"
    local display_url="$3"
    local filename="$4"
    
    log_info "    Identifying mod project for: $mod_id (${display_name:-$filename})"
    
    # Phase 1: Try Modrinth first (preferred platform)
    log_info "      Phase 1: Searching Modrinth (preferred)..."
    local modrinth_project_id=""
    modrinth_project_id=$(find_modrinth_project "$mod_id" "$display_name" "$display_url" 2>/dev/null || echo "")
    
    if [[ -n "$modrinth_project_id" ]] && [[ "$modrinth_project_id" != "null" ]]; then
        log_success "      ✓ Found on Modrinth: $modrinth_project_id"
        echo "modrinth:$modrinth_project_id"
        return 0
    fi
    
    log_info "      ✗ Not found on Modrinth"
    
    # Phase 2: Try CurseForge as fallback
    if [[ -n "${CURSEFORGE_API_KEY:-}" ]]; then
        log_info "      Phase 2: Searching CurseForge (fallback)..."
        local curseforge_result=""
        curseforge_result=$(search_curseforge_mod "$mod_id" "$display_name" "$filename" 2>/dev/null || echo "")
        
        if [[ -n "$curseforge_result" ]]; then
            IFS='|' read -ra CF_PARTS <<< "$curseforge_result"
            local cf_mod_id="${CF_PARTS[0]:-}"
            local cf_name="${CF_PARTS[1]:-}"
            local cf_slug="${CF_PARTS[2]:-}"
            
            log_success "      ✓ Found on CurseForge: $cf_name (ID: $cf_mod_id)"
            echo "curseforge:$cf_mod_id:$cf_name:$cf_slug"
            return 0
        fi
        
        log_info "      ✗ Not found on CurseForge"
    else
        log_warning "      ! CurseForge API key not available - skipping CurseForge search"
    fi
    
    # Phase 3: Try whitelisted domains as last resort
    log_info "      Phase 3: Searching whitelisted domains (last resort)..."
    local whitelisted_result=""
    whitelisted_result=$(search_whitelisted_domains "$mod_id" "$display_name" "$display_url" "$filename" 2>/dev/null || echo "")
    
    if [[ -n "$whitelisted_result" ]]; then
        log_info "      ✓ Found external download: $whitelisted_result"
        echo "external:$whitelisted_result"
        return 0
    fi
    
    log_warning "      ✗ No project found on any platform"
    return 1
}

# Enhanced mod detection with improved platform prioritization
enhanced_auto_detect_mods() {
    log_info "Enhanced auto-detecting mods with Modrinth priority in $MODS_DIR..."
    
    local detected_count=0
    local modrinth_count=0
    local curseforge_count=0
    local external_count=0
    local failed_count=0
    local total_jars=$(find "$MODS_DIR" -name "*.jar" | wc -l)
    local current_jar=0
    
    for mod_file in "$MODS_DIR"/*.jar; do
        if [[ -f "$mod_file" ]]; then
            current_jar=$((current_jar + 1))
            local filename=$(basename "$mod_file")
            echo -ne "\r\033[K"  # Clear line
            log_info "  Processing: $filename ($current_jar/$total_jars)"
            
            # Extract metadata from JAR
            local metadata=""
            metadata=$(extract_mod_metadata "$mod_file" 2>/dev/null || echo "")
            
            if [[ -n "$metadata" ]]; then
                IFS='|' read -ra META_PARTS <<< "$metadata"
                local mod_id="${META_PARTS[0]:-}"
                local current_version="${META_PARTS[1]:-}"
                local display_name="${META_PARTS[2]:-}"
                local display_url="${META_PARTS[3]:-}"
                
                if [[ -n "$mod_id" ]]; then
                    log_info "    Metadata: ID=$mod_id, Name=$display_name, Version=$current_version"
                    
                    # Use enhanced project identification
                    local project_result=""
                    project_result=$(identify_mod_project "$mod_id" "$display_name" "$display_url" "$filename" 2>&1 | tail -1)
                    
                    if [[ -n "$project_result" ]]; then
                        IFS=':' read -ra RESULT_PARTS <<< "$project_result"
                        local platform="${RESULT_PARTS[0]:-}"
                        local project_id="${RESULT_PARTS[1]:-}"
                        local has_update="false"  # Initialize has_update variable
                        
                        case "$platform" in
                            "modrinth")
                                # Handle Modrinth mod
                                local versions=""
                                versions=$(get_version_list "$project_id" 2>/dev/null || echo "[]")
                                local latest_version=""
                                local has_update="false"
                                
                                if [[ "$versions" != "[]" ]] && [[ -n "$versions" ]]; then
                                    latest_version=$(echo "$versions" | jq -r '.[0].version_number // empty' 2>/dev/null || echo "")
                                    if [[ -n "$latest_version" ]]; then
                                        # More intelligent version comparison
                                        if [[ -z "$current_version" ]]; then
                                            has_update="true"
                                        elif [[ "$current_version" != "$latest_version" ]]; then
                                            # Check if the current file already matches the latest filename
                                            local latest_filename=$(echo "$versions" | jq -r '.[0].files[0].filename // empty' 2>/dev/null || echo "")
                                            if [[ -n "$latest_filename" ]] && [[ "$filename" == "$latest_filename" ]]; then
                                                has_update="false"  # Already have the correct file
                                            else
                                                has_update="true"
                                            fi
                                        fi
                                    fi
                                fi
                                
                                DETECTED_MODS+=("$filename:$project_id:$current_version:$latest_version:$has_update")
                                ((modrinth_count++))
                                ;;
                                
                            "curseforge")
                                # Handle CurseForge mod
                                local cf_mod_id="${RESULT_PARTS[1]:-}"
                                local cf_name="${RESULT_PARTS[2]:-}"
                                local cf_slug="${RESULT_PARTS[3]:-}"
                                
                                # Get latest file info
                                                               local file_info=""
                                file_info=$(get_curseforge_latest_file "$cf_mod_id" "$MINECRAFT_VERSION" 2>/dev/null || echo "")
                                
                                if [[ -n "$file_info" ]]; then
                                    IFS='|' read -ra FILE_PARTS <<< "$file_info"
                                    local file_id="${FILE_PARTS[0]:-}"
                                    local file_name="${FILE_PARTS[1]:-}"
                                    local download_url="${FILE_PARTS[2]:-}"
                                    
                                    # Determine if update is available by comparing filenames
                                    local has_update="false"
                                    if [[ "$filename" != "$file_name" ]]; then
                                        has_update="true"
                                    fi
                                    
                                    local external_url="curseforge:$cf_mod_id:$file_id:$download_url:$file_name"
                                    DETECTED_MODS+=("$filename:curseforge:$current_version:check_update:$has_update:$external_url")
                                    ((curseforge_count++))
                                else
                                    # CurseForge mod found but no file info
                                    DETECTED_MODS+=("$filename:curseforge:$current_version:unknown:false")
                                    ((curseforge_count++))
                                fi
                                ;;
                                
                            "external")
                                # Handle external mod
                                local external_url="${RESULT_PARTS[1]:-}"
                                DETECTED_MODS+=("$filename:external:$current_version:$current_version:false:$external_url")
                                ((external_count++))
                                ;;
                        esac
                        
                        ((detected_count++))
                        
                        if [[ "$has_update" == "true" ]]; then
                            log_success "      ✓ Update available ($platform)"
                        else
                            log_success "      ✓ Up to date ($platform)"
                        fi
                    else
                        log_warning "    Could not identify project on any platform"
                        ((failed_count++))
                    fi
                else
                    log_warning "    Invalid or missing mod metadata"
                    ((failed_count++))
                fi
            else
                log_warning "    Could not extract metadata from $filename"
                ((failed_count++))
            fi
        fi
    done
    
    echo -ne "\r\033[K"  # Clear line
    log_success "Enhanced detection completed:"
    log_success "  Total detected: $detected_count mods"
    log_success "  Modrinth: $modrinth_count mods (preferred)"
    log_success "  CurseForge: $curseforge_count mods (fallback)"
    log_success "  External: $external_count mods (manual)"
    log_success "  Failed: $failed_count mods"
    
    local modrinth_percentage=0
    if [[ $detected_count -gt 0 ]]; then
        modrinth_percentage=$((modrinth_count * 100 / detected_count))
    fi
    
    log_success "  Modrinth coverage: ${modrinth_percentage}% (target: >80%)"
}

# Report platform distribution and coverage statistics
report_platform_coverage() {
    log_info "Analyzing platform distribution and coverage..."
    
    local total_mods=${#DETECTED_MODS[@]}
    local modrinth_mods=0
    local curseforge_mods=0
    local external_mods=0
    local updateable_mods=0
    local mods_with_updates=0
    
    # Count mods by platform
    for mod_entry in "${DETECTED_MODS[@]}"; do
        local project_id=$(get_mod_data "$mod_entry" "project_id")
        local has_update=$(get_mod_data "$mod_entry" "has_update")
        
        case "$project_id" in
            "curseforge")
                ((curseforge_mods++))
                ((updateable_mods++))
                ;;
            "external")
                ((external_mods++))
                ;;
            *)
                ((modrinth_mods++))
                ((updateable_mods++))
                ;;
        esac
        
        if [[ "$has_update" == "true" ]]; then
            ((mods_with_updates++))
        fi
    done
    
    # Calculate percentages
    local modrinth_pct=0
    local curseforge_pct=0
    local external_pct=0
    local updateable_pct=0
    local updates_available_pct=0
    
    if [[ $total_mods -gt 0 ]]; then
        modrinth_pct=$((modrinth_mods * 100 / total_mods))
        curseforge_pct=$((curseforge_mods * 100 / total_mods))
        external_pct=$((external_mods * 100 / total_mods))
        updateable_pct=$((updateable_mods * 100 / total_mods))
    fi
    
    if [[ $updateable_mods -gt 0 ]]; then
        updates_available_pct=$((mods_with_updates * 100 / updateable_mods))
    fi
    
    echo
    log_success "═══ PLATFORM COVERAGE REPORT ═══"
    log_success "Total Mods Detected: $total_mods"
    log_success ""
    log_success "Platform Distribution:"
    log_success "  🟢 Modrinth (preferred):  $modrinth_mods mods (${modrinth_pct}%)"
    log_success "  🟡 CurseForge (fallback): $curseforge_mods mods (${curseforge_pct}%)"
    log_success "  🔴 External (manual):     $external_mods mods (${external_pct}%)"
    log_success ""
    log_success "Update Capabilities:"
    log_success "  Updateable Mods:     $updateable_mods / $total_mods (${updateable_pct}%)"
    log_success "  Updates Available:   $mods_with_updates / $updateable_mods (${updates_available_pct}%)"
    log_success ""
    
    # Provide recommendations
    if [[ $modrinth_pct -ge 80 ]]; then
        log_success "✅ Excellent Modrinth coverage (≥80%)"
    elif [[ $modrinth_pct -ge 60 ]]; then
        log_warning "⚠️  Good Modrinth coverage (60-79%), consider migrating some CurseForge mods"
    else
        log_warning "⚠️  Low Modrinth coverage (<60%), many mods using fallback platforms"
    fi
    
    if [[ $external_mods -gt 0 ]]; then
        log_warning "Note: $external_mods mods require manual updates (external downloads)"
    fi
    
    # List mods that might need attention
    if [[ $curseforge_mods -gt 0 ]] || [[ $external_mods -gt 0 ]]; then
        log_info ""
        log_info "Mods requiring attention:"
        
        for mod_entry in "${DETECTED_MODS[@]}"; do
            local filename=$(get_mod_data "$mod_entry" "filename")
            local project_id=$(get_mod_data "$mod_entry" "project_id")
            
            case "$project_id" in
                "curseforge")
                    log_warning "  📦 $filename (CurseForge only - consider Modrinth alternative)"
                    ;;
                "external")
                    log_warning "  🔗 $filename (External download - manual updates required)"
                    ;;
            esac
        done
    fi
    
    echo
}

# Main execution flow
main() {
    local action="${1:-detect}"
    
    case "$action" in
        "detect"|"scan")
            log_info "Starting enhanced mod detection with Modrinth priority..."
            auto_detect_mods
            report_platform_coverage
            ;;
        "analyze"|"deps")
            log_info "Starting dependency analysis..."
            auto_detect_mods
            build_dependency_graph
            categorize_waves
            ;;
        "update"|"upgrade")
            log_info "Starting wave-based mod updates..."
            auto_detect_mods
            report_platform_coverage
            build_dependency_graph
            categorize_waves
            
            # Execute waves in order
            if [[ ${#WAVE_1_INDEPENDENT[@]} -gt 0 ]]; then
                execute_wave "Wave 1 (Independent)" "${WAVE_1_INDEPENDENT[@]}"
            fi
            
            if [[ ${#WAVE_2_CONSUMERS[@]} -gt 0 ]]; then
                execute_wave "Wave 2 (Consumers)" "${WAVE_2_CONSUMERS[@]}"
            fi
            
            if [[ ${#WAVE_3_PROVIDERS[@]} -gt 0 ]]; then
                execute_wave "Wave 3 (Providers)" "${WAVE_3_PROVIDERS[@]}"
            fi
            
            if [[ ${#WAVE_4_PROTECTED[@]} -gt 0 ]]; then
                execute_wave "Wave 4 (Protected)" "${WAVE_4_PROTECTED[@]}"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Enhanced Wave-Based Mod Update System"
            echo "======================================"
            echo ""
            echo "Usage: $0 [action]"
            echo ""
            echo "Actions:"
            echo "  detect, scan     - Detect mods and show platform coverage"
            echo "  analyze, deps    - Analyze dependencies and categorize update waves"
            echo "  update, upgrade  - Perform wave-based mod updates"
            echo "  help             - Show this help message"
            echo ""
            echo "Features:"
            echo "  🟢 Prioritizes Modrinth (preferred platform)"
            echo "  🟡 Falls back to CurseForge when needed"
            echo "  🔴 Supports external downloads as last resort"
            echo "  📊 Provides detailed platform coverage reports"
            echo "  🌊 Safe wave-based updates respecting dependencies"
            echo ""
            echo "Environment Variables:"
            echo "  CURSEFORGE_API_KEY  - CurseForge API key for fallback support"
            echo "  DRY_RUN=true        - Show what would be updated without doing it"
            echo ""
            ;;
        *)
            log_error "Unknown action: $action"
            log_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
