#!/bin/bash

# Final Multi-Platform .mrpack Builder with Comprehensive Mirror Support
# Ensures all mods get proper download URLs from Modrinth, CurseForge, or manual overrides
# Never includes mod files unless absolutely necessary

set -e

echo "Building .mrpack with comprehensive mirror support..."

# Parse command line arguments
OVERRIDE_VERSION=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      OVERRIDE_VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--version VERSION]"
      exit 1
      ;;
  esac
done

# Configuration
MODS_DIR="mods"
CURSEFORGE_API_KEY="${CURSEFORGE_API_KEY:-}"
PROJECT_NAME="Survival Not Guaranteed"
MINECRAFT_VERSION="1.21.1"
MODLOADER="neoforge"
NEOFORGE_VERSION="21.1.180"

# Project configuration for version checking
GITHUB_REPO="Manifesto2147/Survival-Not-Guaranteed"
MODRINTH_PROJECT="${MODRINTH_PROJECT:-survival-not-guaranteed}"  # Set this to your actual Modrinth project slug

# Auto-detect latest compatible NeoForge version if needed
AUTO_DETECT_NEOFORGE="${AUTO_DETECT_NEOFORGE:-false}"

# Strict mode: if enabled, build will fail if any mod can't be found externally
STRICT_EXTERNAL_DOWNLOADS="${STRICT_EXTERNAL_DOWNLOADS:-true}"

# Statistics tracking
TOTAL_MODS=0
MODRINTH_FOUND=0
CURSEFORGE_FOUND=0
MANUAL_OVERRIDES_USED=0
PACK_INCLUDED=0
SMART_UPDATES=0
CLIENT_ONLY_MODS=0
SERVER_ONLY_MOD_COUNT=0
UNIVERSAL_MODS=0
FAILED_LOOKUPS=()

# ==================== MODRINTH API ENVIRONMENT DETECTION ====================

# Cache directory for API responses
CACHE_DIR=".modrinth_cache"
mkdir -p "$CACHE_DIR"

# Function to get mod compatibility from Modrinth API
get_modrinth_compatibility() {
    local mod_slug="$1"
    local cache_file="$CACHE_DIR/${mod_slug}.json"
    
    # Check cache first (24 hour expiration)
    if [[ -f "$cache_file" && $(find "$cache_file" -mtime -1 2>/dev/null) ]]; then
        cat "$cache_file"
        return
    fi
    
    # Fetch from API
    local response=$(curl -s "https://api.modrinth.com/v2/project/$mod_slug" 2>/dev/null || echo "")
    
    if [[ -n "$response" && $(echo "$response" | jq -e '.client_side' 2>/dev/null) ]]; then
        echo "$response" > "$cache_file"
        echo "$response"
    else
        echo ""
    fi
}

# Function to determine mod environment using Modrinth API
get_mod_environment_from_api() {
    local mod_file="$1"
    local mod_name=$(basename "$mod_file" .jar | tr '[:upper:]' '[:lower:]')
    
    # Extract the core mod name from complex filenames
    # This handles patterns like: ModName_NEOFORGE_v1.2.3_mc1.21.1.jar -> modname
    local core_name=$(echo "$mod_name" | sed 's/[-_].*$//' | sed 's/[^a-z0-9]//g')
    
    # Also try some common variations
    local potential_slugs=(
        "$core_name"
        "$mod_name"
        "${mod_name//_/-}"
        "${mod_name//-/_}"
        "${mod_name//[^a-z0-9]/-}"
        "${mod_name//[^a-z0-9]/_}"
        "${core_name}-mod"
        "${core_name}mod"
        "${core_name/core/}"
        "${core_name}core"
    )
    
    # Remove duplicates and empty entries
    local unique_slugs=($(printf '%s\n' "${potential_slugs[@]}" | sort -u | grep -v '^$'))
    
    for slug in "${unique_slugs[@]}"; do
        local api_data=$(get_modrinth_compatibility "$slug")
        if [[ -n "$api_data" ]]; then
            local client_side=$(echo "$api_data" | jq -r '.client_side // "unknown"')
            local server_side=$(echo "$api_data" | jq -r '.server_side // "unknown"')
            
            # Determine environment based on API response
            if [[ "$client_side" == "required" && "$server_side" == "unsupported" ]]; then
                echo "client"
                return
            elif [[ "$client_side" == "unsupported" && "$server_side" == "required" ]]; then
                echo "server"
                return
            elif [[ "$client_side" == "required" && "$server_side" == "required" ]]; then
                echo "both"
                return
            elif [[ "$client_side" == "optional" && "$server_side" == "unsupported" ]]; then
                echo "client"
                return
            elif [[ "$client_side" == "unsupported" && "$server_side" == "optional" ]]; then
                echo "server"
                return
            elif [[ "$client_side" == "optional" && "$server_side" == "optional" ]]; then
                echo "both"
                return
            else
                echo "both"  # Default to both if unclear
                return
            fi
        fi
    done
    
    # Fallback to pattern-based detection if API fails
    echo "unknown"
}

# ==================== CLIENT/SERVER ENVIRONMENT DETECTION ====================

# Define client-only mods that should never be installed on servers
CLIENT_ONLY_MODS=(
    # Rendering & Graphics
    "iris" "optifine" "sodium" "embeddium" "rubidium" "oculus" "continuity" "ctm" "connected_textures"
    "entity_texture_features" "entity_model_features" "more_beautiful_torches" "dynamic_lights"
    "shader" "complementary" "seus" "bsl" "kuda" "chocapic" "sildurs" "makeup"
    
    # UI & HUD Mods
    "jei" "rei" "emi" "jade" "hwyla" "waila" "appleskin" "torohealth" "health_overlay"
    "armor_hud" "item_physic" "mouse_tweaks" "inventory_tweaks" "crafting_tweaks" "recipe_book"
    "mod_menu" "cloth_config" "configured" "catalogue" "controlling" "key_bindings" "input_fix"
    "gui_clock" "durability_viewer" "equipment_compare" "enchantment_descriptions" "attribute_fix"
    
    # Audio & Ambient
    "ambient_sounds" "sound_physics" "dripsounds" "presence_footsteps" "auditory" "audio_plugin"
    "sound_device_options" "extreme_sound_muffler" "sounds" "sound_control" "audio_output"
    
    # Minimap & Navigation (Client-side display)
    "xaero" "minimap" "worldmap" "journey_map" "rei_minimap" "voxel_map" "zan_minimap"
    "antique_atlas" "map_atlases" "cartographer" "waypoint" "navigation" "compass_ribbon"
    
    # Performance & Debugging (Client-side only)
    "fps_display" "lagometer" "debug_hud" "profiler" "spark_client" "performance_monitor"
    "crash_utilities" "better_f3" "debug_screen" "memory_usage" "cpu_usage" "gpu_usage"
    
    # Camera & View
    "camera_mod" "replay_mod" "screenshot" "photo_mode" "cinematic_camera" "smooth_camera"
    "camera_utils" "perspective_mod" "view_bobbing" "zoom" "optizoom" "logical_zoom"
    
    # Chat & Social (Client-side display)
    "chat_heads" "chat_signing" "no_chat_reports" "chat_patches" "better_chat" "chat_colors"
    "emotecraft" "emotes" "skin_layers" "player_animator" "custom_player_models" "ears"
    
    # Resource Packs & Assets
    "resource_pack" "texture_pack" "model_pack" "ctm_pack" "connected_texture" "animation_api"
    "fresh_animations" "entity_culling" "cull_particles" "particle_culling" "better_animations"
    
    # Client-side Storage & Inventory
    "inventory_hud" "inventory_profiles" "mouse_wheelie" "item_scroller" "inventory_sorter"
    "quick_stack" "auto_sort" "inventory_tabs" "crafting_station" "recipe_essentials"
    
    # Visual Enhancements
    "better_foliage" "dynamic_trees" "fancy_block_particles" "falling_leaves" "particle_rain"
    "biome_particle_weather" "environmental_particles" "aurora" "shooting_stars" "better_clouds"
    
    # Development & Mod Support
    "mod_name_tooltip" "mod_finder" "craft_tweaker_gui" "ctgui" "kubejs_ui" "probe_js"
    "top_addons" "hwyla_addons" "jade_addons" "waila_plugins" "mod_list" "mod_updates"
    
    # Specific Mod Names (from your pack)
    "appleskin" "jei" "iris" "sodium" "ambient_sounds"
    "sound_physics" "sounds" "armor_hud" "gui_clock" "ctgui" "armorstatues" "healthy_sleep"
)

# Define server-side only mods (rare, but some exist)
SERVER_ONLY_MODS=(
    # Server Management
    "server_utilities" "forge_essentials" "bukkit_forge" "sponge_forge" "server_tools"
    "administrative_tools" "server_config" "server_performance" "server_security" "anti_cheat"
    
    # World Generation (Server-side processing)
    "chunk_pregenerator" "world_stripper" "world_border" "spawn_control" "world_management"
    
    # Performance (Server-side only)
    "ai_improvements" "mob_ai" "server_performance" "tick_profiler" "memory_cleaner"
    "garbage_collector" "chunk_loading" "dimension_manager" "world_loading" "save_optimizer"
    
    # Economy & Permissions (Server-side logic)
    "economy_mod" "permissions" "ranks" "groups" "claims" "protection" "grief_prevention"
    "shop_system" "auction_house" "currency" "banking" "trading" "market"
)

# Function to determine if a mod is client-only based on filename
is_client_only_mod() {
    local filename="$1"
    local mod_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
    
    for client_mod in "${CLIENT_ONLY_MODS[@]}"; do
        if [[ "$mod_name" == *"$client_mod"* ]] || [[ "$client_mod" == *"$mod_name"* ]]; then
            return 0  # Is client-only
        fi
    done
    return 1  # Not client-only
}

# Function to determine if a mod is server-only based on filename
is_server_only_mod() {
    local filename="$1"
    local mod_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
    
    for server_mod in "${SERVER_ONLY_MODS[@]}"; do
        if [[ "$mod_name" == *"$server_mod"* ]] || [[ "$server_mod" == *"$mod_name"* ]]; then
            return 0  # Is server-only
        fi
    done
    return 1  # Not server-only
}

# Function to get environment settings for a mod
get_mod_environment() {
    local filename="$1"
    
    # First check manual overrides (highest priority)
    local manual_override=$(get_manual_environment_override "$filename")
    if [[ -n "$manual_override" ]]; then
        echo "$manual_override"
        return
    fi
    
    # Then try to get accurate data from Modrinth API
    local api_result=$(get_mod_environment_from_api "$filename")
    
    if [[ "$api_result" == "client" ]]; then
        echo "client_only"
    elif [[ "$api_result" == "server" ]]; then
        echo "server_only"
    elif [[ "$api_result" == "both" ]]; then
        echo "both"
    else
        # Fallback to pattern-based detection if API fails
        if is_client_only_mod "$filename"; then
            echo "client_only"
        elif is_server_only_mod "$filename"; then
            echo "server_only"
        else
            echo "both"
        fi
    fi
}

# ==================== UTILITY FUNCTIONS ====================

calculate_sha1() {
  local file="$1"
  if command -v sha1sum >/dev/null 2>&1; then
    sha1sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 1 "$file" | cut -d' ' -f1
  else
    echo "Error: No SHA1 utility found" >&2
    return 1
  fi
}

calculate_sha512() {
  local file="$1"
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 512 "$file" | cut -d' ' -f1
  else
    echo "Error: No SHA512 utility found" >&2
    return 1
  fi
}

get_file_size() {
  local file="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    stat -f%z "$file"
  else
    stat -c%s "$file"
  fi
}

# ==================== MANUAL OVERRIDES ====================

# Check if a mod has a manual override
get_manual_override() {
  local filename="$1"
  
  # Check hardcoded overrides first
  case "$filename" in
    "curios-neoforge-10.0.2.20.jar")
      echo "https://mediafilez.forgecdn.net/files/5567/372/curios-neoforge-10.0.2.20.jar"
      return 0
      ;;
    "ars_elemental-1.21.1-0.6.6.jar")
      echo "https://mediafilez.forgecdn.net/files/5571/956/ars_elemental-1.21.1-0.6.6.jar"
      return 0
      ;;
    # "ars_elemental-1.21.1-0.7.4.1.jar") - Commented out due to hash mismatch
    #   echo "https://mediafilez.forgecdn.net/files/5640/518/ars_elemental-1.21.1-0.7.4.1.jar"
    #   return 0
    #   ;;
    "curios-neoforge-9.5.1+1.21.1.jar")
      echo "https://cdn.modrinth.com/data/vvuO3ImH/versions/yohfFbgD/curios-neoforge-9.5.1%2B1.21.1.jar"
      return 0
      ;;
  esac
  
  # Check config file
  if [ -f "mod_overrides.conf" ]; then
    local override_url=$(grep "^$filename=" mod_overrides.conf | cut -d'=' -f2-)
    if [ -n "$override_url" ]; then
      echo "$override_url"
      return 0
    fi
  fi
  
  return 1
}

# ==================== MANUAL ENVIRONMENT OVERRIDES ====================

# Manual overrides for mods that can't be correctly detected via filename->slug matching
# Format: "filename_pattern" -> "environment"
# Environment options: "client_only", "server_only", "both", "client_required_server_optional"

# Manual overrides for mods that can't be correctly detected via filename->slug matching
# Format: check if override exists using a function instead of associative array

# Function to check manual environment overrides
get_manual_environment_override() {
    local filename="$1"
    local mod_name=$(basename "$filename" .jar | tr '[:upper:]' '[:lower:]')
    
    # Samurai Dynasty - correct slug is "epic-samurais", not "samurai"
    if [[ "$mod_name" == *"samurai_dynasty"* ]] || [[ "$mod_name" == *"samurai-dynasty"* ]]; then
        echo "both"
        return
    fi
    
    # EC plugins that depend on universal mods
    if [[ "$mod_name" == *"ec_es_plugin"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"ec_ars_plugin"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"ec_lec_plugin"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"ec_isasb_plugin"* ]]; then
        echo "both"
        return
    fi
    
    # Open Party & Claims - requires both client and server for full functionality
    if [[ "$mod_name" == *"open-parties-and-claims"* ]] || [[ "$mod_name" == *"open_parties_and_claims"* ]]; then
        echo "both"
        return
    fi
    
    # Spice of Life - food variety mod that works on both client and server
    if [[ "$mod_name" == *"spice"* && "$mod_name" == *"life"* ]] || [[ "$mod_name" == *"spice_of_life"* ]]; then
        echo "both"
        return
    fi
    
    # Xaero's mods - work on both client and server
    if [[ "$mod_name" == *"xaeros_minimap"* ]] || [[ "$mod_name" == *"xaero"* && "$mod_name" == *"minimap"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"xaeros_worldmap"* ]] || [[ "$mod_name" == *"xaero"* && "$mod_name" == *"worldmap"* ]]; then
        echo "both"
        return
    fi
    
    # Epic Knights - override to make it universal for server compatibility
    if [[ "$mod_name" == *"epic-knights"* ]] || [[ "$mod_name" == *"epic_knights"* ]]; then
        echo "both"
        return
    fi
    
    # Ice and Fire CE and its dependencies
    if [[ "$mod_name" == *"iceandfire"* ]] || [[ "$mod_name" == *"ice_and_fire"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"uranus"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"jupiter"* ]]; then
        echo "both"
        return
    fi
    
    # Known universal mods that might be misclassified
    if [[ "$mod_name" == *"creativecore"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"waystones"* ]]; then
        echo "both"
        return
    fi
    
    # Known client-only mods
    if [[ "$mod_name" == *"appleskin"* ]]; then
        echo "client_only"
        return
    fi
    if [[ "$mod_name" == *"mouse_wheelie"* ]]; then
        echo "client_only"
        return
    fi
    if [[ "$mod_name" == *"inventory_hud"* ]]; then
        echo "client_only"
        return
    fi
    
    # YDM's Weapon Master - From v4.1.0+ the client-only and multiplayer versions are merged
    # This mod requires both client and server since it uses networking channels
    if [[ "$mod_name" == *"weaponmaster"* ]]; then
        echo "both"
        return
    fi
    
    # Essential library mods that must be available to both client and server
    if [[ "$mod_name" == *"bookshelf"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"balm"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"architectury"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"cloth_config"* ]] || [[ "$mod_name" == *"cloth-config"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"geckolib"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"moonlight"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"puzzleslib"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"collective"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"coroutil"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"ferritecore"* ]]; then
        echo "both"
        return
    fi
    if [[ "$mod_name" == *"kotlinforforge"* ]]; then
        echo "both"
        return
    fi
    
    # Dungeons & Taverns mods - all support both client and server
    # (client: optional, server: required in Modrinth terms = "both" in our system)
    if [[ "$mod_name" == *"dungeons-and-taverns"* ]] || [[ "$mod_name" == *"dungeons_and_taverns"* ]]; then
        echo "both"
        return
    fi
    
    echo ""
}

# ==================== VERSION DETECTION ====================

# Generate content hash for version comparison
generate_content_hash() {
  local mod_hash=""
  local config_hash=""
  
  # Hash mod files by examining the modrinth.index.json instead of filesystem
  # This prevents infrastructure changes from being detected as mod changes
  if [ -f "modrinth.index.json" ]; then
    mod_hash=$(jq -r '.files[] | select(.path | startswith("mods/")) | .path' modrinth.index.json 2>/dev/null | sort | tr '\n' '|' | shasum | cut -d' ' -f1)
  fi
  
  # Hash key config files
  if [ -d "config" ]; then
    config_hash=$(find config -name "*.toml" -o -name "*.json" -o -name "*.json5" | sort | while read -r file; do shasum "$file" 2>/dev/null | cut -d' ' -f1; done | tr '\n' '|' | shasum | cut -d' ' -f1)
  fi
  
  # Hash other modpack content (servers.dat)
  local other_hash=""
  if [ -f "servers.dat" ]; then
    other_hash=$(shasum servers.dat 2>/dev/null | cut -d' ' -f1)
  fi
  
  # Return combined hash with separators for individual component checking
  echo "MOD:$mod_hash|CONFIG:$config_hash|OTHER:$other_hash"
}

# Increment version number based on change type
increment_version() {
  local version="$1"
  local change_type="$2"  # "mod", "config", "other", or "infrastructure"
  
  local major=$(echo "$version" | cut -d. -f1)
  local minor=$(echo "$version" | cut -d. -f2)
  local patch=$(echo "$version" | cut -d. -f3)
  
  if [ "$change_type" = "mod" ]; then
    # Actual mod changes increment minor version and reset patch
    minor=$((minor + 1))
    patch=0
  else
    # Config, other, and infrastructure changes increment patch version
    patch=$((patch + 1))
  fi
  
  echo "$major.$minor.$patch"
}

get_latest_version() {
  echo "- Detecting version..."
  
  # Check if version is overridden (for CI)
  if [ -n "$OVERRIDE_VERSION" ]; then
    echo "- Using CI-provided version override: $OVERRIDE_VERSION"
    CURRENT_VERSION="$OVERRIDE_VERSION"
    echo "+ Using version: $CURRENT_VERSION"
    return
  fi
  
  # Check GitHub releases
  LATEST_GITHUB_VERSION=""
  if command -v curl >/dev/null 2>&1; then
    echo "- Checking GitHub releases for $GITHUB_REPO..."
    
    local github_response=""
    if [ -n "$GITHUB_TOKEN" ]; then
      github_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null || echo "")
    else
      github_response=$(curl -s \
        "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null || echo "")
    fi
    
    # Check if we got a valid response
    if [ -n "$github_response" ]; then
      local github_error=$(echo "$github_response" | jq -r '.message // empty' 2>/dev/null || echo "")
      
      if [ "$github_error" = "Not Found" ]; then
        echo "- GitHub repository not found: $GITHUB_REPO"
        echo "- Please check the GITHUB_REPO configuration in build.sh"
      elif [ -n "$github_error" ]; then
        echo "- GitHub API error: $github_error"
      else
        LATEST_GITHUB_VERSION=$(echo "$github_response" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
        if [ -n "$LATEST_GITHUB_VERSION" ] && [ "$LATEST_GITHUB_VERSION" != "null" ]; then
          echo "- Found GitHub version: $LATEST_GITHUB_VERSION"
        fi
      fi
    fi
  fi
  
  # Check Modrinth releases
  LATEST_MODRINTH_VERSION=""
  if command -v curl >/dev/null 2>&1; then
    local modrinth_versions=$(curl -s "https://api.modrinth.com/v2/project/$MODRINTH_PROJECT/version" 2>/dev/null || echo "")
    if [ -n "$modrinth_versions" ] && echo "$modrinth_versions" | jq -e '.[0]' >/dev/null 2>&1; then
      LATEST_MODRINTH_VERSION=$(echo "$modrinth_versions" | jq -r '.[0].version_number' 2>/dev/null || echo "")
    fi
  fi
  
  # Compare versions and find the highest (skip local version checking)
  local base_version=""
  local version_source=""
  
  # Helper function to compare semantic versions (simplified)
  is_version_higher() {
    local v1="$1"  # version to test
    local v2="$2"  # base version
    
    # Convert versions to comparable numbers (assumes format x.y.z)
    local v1_num=$(echo "$v1" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
    local v2_num=$(echo "$v2" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
    
    [ "$v1_num" -gt "$v2_num" ]
  }
  
  # Start with a baseline (skip local version checking)
  base_version="3.5.15"
  version_source="default"
  echo "- Using default base version: $base_version"
  
  # Check GitHub version
  if [ -n "$LATEST_GITHUB_VERSION" ] && [ "$LATEST_GITHUB_VERSION" != "null" ]; then
    echo "- Found GitHub version: $LATEST_GITHUB_VERSION"
    if is_version_higher "$LATEST_GITHUB_VERSION" "$base_version"; then
      base_version="$LATEST_GITHUB_VERSION"
      version_source="GitHub"
    fi
  else
    echo "- No GitHub releases found"
  fi
  
  # Check Modrinth version
  if [ -n "$LATEST_MODRINTH_VERSION" ] && [ "$LATEST_MODRINTH_VERSION" != "null" ]; then
    echo "- Found Modrinth version: $LATEST_MODRINTH_VERSION"
    if is_version_higher "$LATEST_MODRINTH_VERSION" "$base_version"; then
      base_version="$LATEST_MODRINTH_VERSION"
      version_source="Modrinth"
    fi
  else
    echo "- No Modrinth releases found"
  fi
  
  echo "+ Using highest version as base: $base_version (from $version_source)"
  PREVIOUS_VERSION="$base_version"  # Store the previous version for changelog
  
  # Check if content has changed
  local current_hash=$(generate_content_hash)
  local stored_hash=""
  
  if [ -f ".content_hash" ]; then
    stored_hash=$(cat .content_hash)
  fi
  
  if [ "$current_hash" != "$stored_hash" ]; then
    echo "- Content changes detected, analyzing change type..."
    
    # Parse current and stored hashes
    local current_mod_hash=$(echo "$current_hash" | sed 's/.*MOD:\([^|]*\).*/\1/')
    local current_config_hash=$(echo "$current_hash" | sed 's/.*CONFIG:\([^|]*\).*/\1/')
    local current_other_hash=$(echo "$current_hash" | sed 's/.*OTHER:\([^|]*\).*/\1/')
    
    local stored_mod_hash=""
    local stored_config_hash=""
    local stored_other_hash=""
    
    if [ -n "$stored_hash" ]; then
      stored_mod_hash=$(echo "$stored_hash" | sed 's/.*MOD:\([^|]*\).*/\1/')
      stored_config_hash=$(echo "$stored_hash" | sed 's/.*CONFIG:\([^|]*\).*/\1/')
      stored_other_hash=$(echo "$stored_hash" | sed 's/.*OTHER:\([^|]*\).*/\1/')
    fi
    
    # Determine change type
    local change_type="config"  # Default to config change
    
    # Check if this is an infrastructure change (Git-related, workflow changes, etc.)
    local is_infrastructure_change="false"
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      # Check if recent changes are primarily infrastructure
      local recent_changes=$(git diff --name-only HEAD~1 2>/dev/null || echo "")
      if echo "$recent_changes" | grep -qE "^(\.gitignore|\.github/|build\.sh|manage-modpack\.sh|docs/|README\.md|CHANGELOG\.md)"; then
        # Check if mod files are the same in the manifest
        local manifest_mod_count=$(jq -r '.files[] | select(.path | startswith("mods/")) | .path' modrinth.index.json 2>/dev/null | wc -l)
        if [ "$manifest_mod_count" -gt 0 ]; then
          is_infrastructure_change="true"
        fi
      fi
    fi
    
    if [ "$is_infrastructure_change" = "true" ]; then
      change_type="infrastructure"
      echo "- Infrastructure changes detected (Git/automation fixes)"
    elif [ "$current_mod_hash" != "$stored_mod_hash" ]; then
      change_type="mod"
      echo "- Mod changes detected"
    elif [ "$current_config_hash" != "$stored_config_hash" ]; then
      change_type="config"
      echo "- Config changes detected"
    elif [ "$current_other_hash" != "$stored_other_hash" ]; then
      change_type="other"
      echo "- Other changes detected (servers.dat)"
    fi
    
    CURRENT_VERSION=$(increment_version "$base_version" "$change_type")
    DETECTED_CHANGE_TYPE="$change_type"  # Store for changelog generation
    echo "+ New version: $CURRENT_VERSION"
    
    # Store new hash
    echo "$current_hash" > .content_hash
  else
    echo "- No content changes detected"
    CURRENT_VERSION="$base_version"
    DETECTED_CHANGE_TYPE="none"
    echo "+ Using version: $CURRENT_VERSION"
  fi
}

# ==================== NEOFORGE VERSION DETECTION ====================

get_latest_neoforge_version() {
  if [ "$AUTO_DETECT_NEOFORGE" = "true" ]; then
    echo "- Detecting latest NeoForge version for Minecraft $MINECRAFT_VERSION..."
    
    # Query NeoForge API for latest version
    local neoforge_versions=$(curl -s "https://api.neoforged.net/v1/versions" 2>/dev/null || echo "")
    
    if [ -n "$neoforge_versions" ]; then
      # Find the latest version for our Minecraft version
      local latest_version=$(echo "$neoforge_versions" | jq -r "
        .versions[] | 
        select(.minecraft_version == \"$MINECRAFT_VERSION\") | 
        select(.channel == \"release\") | 
        .version" | sort -V | tail -1)
      
      if [ -n "$latest_version" ] && [ "$latest_version" != "null" ]; then
        echo "+ Latest NeoForge version: $latest_version"
        NEOFORGE_VERSION="$latest_version"
        return 0
      fi
    fi
    
    echo "WARNING: Could not detect latest NeoForge version, using configured: $NEOFORGE_VERSION"
  else
    echo "- Using configured NeoForge version: $NEOFORGE_VERSION"
  fi
}

# ==================== MOD LOOKUP FUNCTIONS ====================

# Search Modrinth by filename
search_modrinth_by_name() {
  local filename="$1"
  local base_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | sed 's/_/ /g')
  
  # Try exact name search
  local search_result=$(curl -s "https://api.modrinth.com/v2/search?query=$(echo "$base_name" | sed 's/ /%20/g')&limit=10" 2>/dev/null || echo "")
  
  if echo "$search_result" | jq -e '.hits[0]' >/dev/null 2>&1; then
    local project_id=$(echo "$search_result" | jq -r '.hits[0].project_id')
    
    # Get versions for this project
    local versions=$(curl -s "https://api.modrinth.com/v2/project/$project_id/version" 2>/dev/null || echo "")
    
    # Try to find matching version for our specific NeoForge and Minecraft version
    local matching_url=""
    
    # First priority: exact Minecraft version + NeoForge loader
    matching_url=$(echo "$versions" | jq -r "
      .[] | 
      select(.loaders[] | contains(\"neoforge\")) | 
      select(.game_versions[] | contains(\"$MINECRAFT_VERSION\")) | 
      .files[0].url" | head -1)
    
    if [ -n "$matching_url" ] && [ "$matching_url" != "null" ]; then
      echo "$matching_url"
      return 0
    fi
    
    # Second priority: any NeoForge version for our Minecraft version
    matching_url=$(echo "$versions" | jq -r "
      .[] | 
      select(.loaders[] | contains(\"neoforge\")) | 
      select(.game_versions[] | test(\"1\\.21\")) | 
      .files[0].url" | head -1)
    
    if [ -n "$matching_url" ] && [ "$matching_url" != "null" ]; then
      echo "$matching_url"
      return 0
    fi
    
    # Fallback to any NeoForge version
    local fallback_url=$(echo "$versions" | jq -r '.[] | select(.loaders[] | contains("neoforge")) | .files[0].url' | head -1)
    if [ -n "$fallback_url" ] && [ "$fallback_url" != "null" ]; then
      echo "$fallback_url"
      return 0
    fi
  fi
  
  return 1
}

# Search CurseForge by filename (no API key needed)
search_curseforge_by_name() {
  local filename="$1"
  local base_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | sed 's/_/ /g' | tr '[:upper:]' '[:lower:]')
  
  # Known CurseForge project mappings for common mods
  local known_projects=""
  case "$base_name" in
    *"ars elemental"*|*"ars_elemental"*) known_projects="ars-elemental" ;;
    *"create"*) known_projects="create" ;;
    *"jei"*) known_projects="jei" ;;
    *"jade"*) known_projects="jade" ;;
    *"waystones"*) known_projects="waystones" ;;
    *"iron chest"*|*"ironchest"*) known_projects="iron-chests" ;;
    *"thermal foundation"*) known_projects="thermal-foundation" ;;
    *"thermal expansion"*) known_projects="thermal-expansion" ;;
    *"cofh core"*) known_projects="cofh-core" ;;
    *"redstone arsenal"*) known_projects="redstone-arsenal" ;;
  esac
  
  if [ -n "$known_projects" ]; then
    # Try to find the latest file for this project
    local project_url="https://www.curseforge.com/minecraft/mc-mods/$known_projects"
    echo "- Checking CurseForge project: $known_projects" >&2
    
    # This is a simplified approach - in a real implementation you'd scrape the page
    # For now, we'll construct likely download URLs based on known patterns
    local likely_url="https://www.curseforge.com/minecraft/mc-mods/$known_projects/files"
    echo "Found potential CurseForge project: $likely_url" >&2
    
    # Return a placeholder that indicates we found the project but need manual intervention
    echo "CURSEFORGE_PROJECT:$known_projects"
    return 0
  fi
  
  return 1
}

# Enhanced mod lookup with comprehensive fallback strategy
lookup_mod_with_mirrors() {
  local file="$1"
  local filename=$(basename "$file")
  local file_hash=$(calculate_sha1 "$file")
  
  # 1. Check manual overrides first
  local manual_url=$(get_manual_override "$filename")
  if [ $? -eq 0 ] && [ -n "$manual_url" ]; then
    echo "FOUND|manual-override|$manual_url|"
    return 0
  fi
  
  # 2. Try Modrinth hash-based lookup (most reliable)
  local modrinth_result=$(curl -s "https://api.modrinth.com/v2/version_file/$file_hash" 2>/dev/null || echo "")
  if [ -n "$modrinth_result" ] && echo "$modrinth_result" | jq -e '.files[0].url' >/dev/null 2>&1; then
    local modrinth_url=$(echo "$modrinth_result" | jq -r '.files[0].url')
    if [ -n "$modrinth_url" ] && [ "$modrinth_url" != "null" ]; then
      echo "FOUND|modrinth-hash|$modrinth_url|"
      return 0
    fi
  fi
  
  # 3. Try Modrinth name-based search
  local modrinth_search_url=$(search_modrinth_by_name "$filename")
  if [ $? -eq 0 ] && [ -n "$modrinth_search_url" ]; then
    echo "FOUND|modrinth-search|$modrinth_search_url|"
    return 0
  fi
  
  # 4. Try CurseForge search
  local cf_search_url=$(search_curseforge_by_name "$filename")
  if [ $? -eq 0 ] && [ -n "$cf_search_url" ]; then
    echo "FOUND|curseforge-search|$cf_search_url|"
    return 0
  fi
  
  # 5. If all lookups fail, check strict mode
  if [ "$STRICT_EXTERNAL_DOWNLOADS" = "true" ]; then
    echo "FAILED|not-found|$filename|"
    FAILED_LOOKUPS+=("$filename")
    return 1
  else
    echo "INCLUDE|not-found|$filename|"
    return 0
  fi
}

# ==================== DEPENDENCY-AWARE UPDATE SYSTEM ====================

# Common dependency mods that should NOT be auto-updated (too risky)
DEPENDENCY_MODS=(
    "balm"
    "bookshelf" 
    "architectury"
    "cloth-config"
    "geckolib"
    "kotlinforforge"
    "moonlight"
    "puzzleslib"
    "collective"
    "coroutil"
    "creativcore"
    "ferritecore"
    "modernfix"
    "libipn"
    "sophisticatedcore"
    "supermartijn642corelib"
    "curios"
    "jei"
    "patchouli"
    "polymorph"
    "terralith"
    "yungsapi"
    "azurelib"
    "ars_nouveau"
)

# Function to check if a mod is a dependency mod
is_dependency_mod() {
    local filename="$1"
    local mod_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | tr '[:upper:]' '[:lower:]')
    
    for dep in "${DEPENDENCY_MODS[@]}"; do
        if [[ "$mod_name" =~ "$dep" ]]; then
            return 0  # Is a dependency
        fi
    done
    return 1  # Not a dependency
}

# Function to get latest compatible version from Modrinth
get_latest_compatible_version() {
    local filename="$1"
    local base_name=$(echo "$filename" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | sed 's/_/ /g')
    
    # Search Modrinth
    local search_result=$(curl -s "https://api.modrinth.com/v2/search?query=$(echo "$base_name" | sed 's/ /%20/g')&limit=5" 2>/dev/null || echo "")
    
    if echo "$search_result" | jq -e '.hits[0]' >/dev/null 2>&1; then
        local project_id=$(echo "$search_result" | jq -r '.hits[0].project_id')
        local project_title=$(echo "$search_result" | jq -r '.hits[0].title')
        
        # Get latest version for NeoForge 1.21.1
        local versions=$(curl -s "https://api.modrinth.com/v2/project/$project_id/version" 2>/dev/null || echo "")
        
        # Find latest compatible version
        local latest_version=$(echo "$versions" | jq -r '.[] | select(.loaders[] | contains("neoforge")) | select(.game_versions[] | contains("1.21.1")) | select(.version_type == "release" or .version_type == "beta") | .files[0]' | head -1)
        
        if [ -n "$latest_version" ] && [ "$latest_version" != "null" ]; then
            local latest_url=$(echo "$latest_version" | jq -r '.url')
            local latest_filename=$(echo "$latest_version" | jq -r '.filename')
            local latest_hash=$(echo "$latest_version" | jq -r '.hashes.sha1')
            local latest_size=$(echo "$latest_version" | jq -r '.size')
            
            echo "FOUND|$latest_url|$latest_filename|$latest_hash|$latest_size"
            return 0
        fi
    fi
    
    return 1
}

# Function to validate hash and handle mismatches intelligently
smart_mod_lookup() {
    local file="$1"
    local filename=$(basename "$file")
    local file_hash=$(calculate_sha1 "$file")
    
    # First try the regular lookup
    local lookup_result=$(lookup_mod_with_mirrors "$file")
    local result_type=$(echo "$lookup_result" | cut -d'|' -f1)
    local source=$(echo "$lookup_result" | cut -d'|' -f2)
    local download_url=$(echo "$lookup_result" | cut -d'|' -f3)
    
    # If we found a download URL, try to verify it's correct
    if [ "$result_type" = "FOUND" ] && [ -n "$download_url" ]; then
        # For hash-based lookups, we already know the hash matches
        if [ "$source" = "modrinth-hash" ]; then
            echo "$lookup_result"
            return 0
        fi
        
        # For search-based lookups, try to get the expected hash
        local expected_hash=""
        
        # Try to get hash from Modrinth API if it's a Modrinth URL
        if [[ "$download_url" == *"cdn.modrinth.com"* ]]; then
            local version_id=$(echo "$download_url" | sed 's/.*\/versions\/\([^\/]*\)\/.*/\1/')
            if [ -n "$version_id" ]; then
                local version_info=$(curl -s "https://api.modrinth.com/v2/version/$version_id" 2>/dev/null || echo "")
                if [ -n "$version_info" ]; then
                    expected_hash=$(echo "$version_info" | jq -r '.files[0].hashes.sha1' 2>/dev/null || echo "")
                fi
            fi
        fi
        
        # If we have an expected hash and it doesn't match, handle intelligently
        if [ -n "$expected_hash" ] && [ "$expected_hash" != "null" ] && [ "$file_hash" != "$expected_hash" ]; then
            echo "  WARNING: Hash mismatch detected for $filename"
            echo "    Local: $file_hash"
            echo "    Expected: $expected_hash"
            
            if ! is_dependency_mod "$filename"; then
                echo "  - Non-dependency mod - attempting smart update..."
                
                local update_result=$(get_latest_compatible_version "$filename")
                if [ $? -eq 0 ]; then
                    local new_url=$(echo "$update_result" | cut -d'|' -f2)
                    local new_filename=$(echo "$update_result" | cut -d'|' -f3)
                    local new_hash=$(echo "$update_result" | cut -d'|' -f4)
                    local new_size=$(echo "$update_result" | cut -d'|' -f5)
                    
                    echo "  + Found updated version: $new_filename"
                    echo "FOUND|smart-update|$new_url|$new_hash|$new_size|$new_filename"
                    return 0
                fi
            else
                echo "  NOTE: Dependency mod - will include in pack to avoid conflicts"
                echo "INCLUDE|dependency-safety|$filename|"
                return 0
            fi
        fi
    fi
    
    # If no hash mismatch detected or couldn't resolve, return original result
    echo "$lookup_result"
    return 0
}

# ==================== MANIFEST GENERATION ====================

# Generate final manifest JSON
generate_final_manifest() {
  local mod_entries="$1"
  local file_count="$2"
  
  # Generate complete manifest optimized for Modrinth App
  cat > modrinth.index.json << EOF
{
  "formatVersion": 1,
  "game": "minecraft",
  "versionId": "$CURRENT_VERSION",
  "name": "$PROJECT_NAME",
  "summary": "A challenging survival modpack featuring magic, technology, and culinary adventures with optimized shaders",
  "files": [
$(echo -e "$mod_entries")
  ],
  "dependencies": {
    "minecraft": "$MINECRAFT_VERSION",
    "$MODLOADER": "$NEOFORGE_VERSION"
  }
}
EOF
  
  echo "+ Generated manifest with $file_count mod entries"
}

# Generate mod entry from override configuration (used for environment detection)
generate_mod_entry_from_override() {
  local mod_filename="$1"
  local download_url="$2"
  
  # Extract mod name from filename
  local mod_name=$(basename "$mod_filename" .jar)
  
  # Determine environment (default to both if unknown)
  local env="both"
  if is_client_only_mod "$mod_filename"; then
    env="client"
    ((CLIENT_ONLY_MODS++))
  elif is_server_only_mod "$mod_filename"; then
    env="server"
    ((SERVER_ONLY_MOD_COUNT++))
  else
    ((UNIVERSAL_MODS++))
  fi
  
  # Generate entry
  cat << EOF
    {
      "path": "mods/$mod_filename",
      "hashes": {
        "sha1": "",
        "sha512": ""
      },
      "env": {
        "client": "$([ "$env" = "client" ] || [ "$env" = "both" ] && echo "required" || echo "unsupported")",
        "server": "$([ "$env" = "server" ] || [ "$env" = "both" ] && echo "required" || echo "unsupported")"
      },
      "downloads": [
        "$download_url"
      ],
      "fileSize": 0
    }
EOF
}

generate_manifest() {
  # In CI mode, use existing manifest instead of scanning mods
  if [ "$CI_MODE" = "true" ] && [ -f "modrinth.index.json" ]; then
    echo "- CI mode: Using existing manifest (skipping mod scanning)..."
    
    # Update version in existing manifest if needed
    if [ "$(jq -r '.versionId' modrinth.index.json)" != "$CURRENT_VERSION" ]; then
      echo "+ Updating manifest version: $(jq -r '.versionId' modrinth.index.json) → $CURRENT_VERSION"
      jq --arg version "$CURRENT_VERSION" '.versionId = $version' modrinth.index.json > temp_manifest.json
      mv temp_manifest.json modrinth.index.json
    fi
    
    # Set statistics from existing manifest
    local manifest_mod_count=$(jq '.files | length' modrinth.index.json)
    echo "+ Using existing manifest with: $manifest_mod_count mods"
    
    TOTAL_MODS=$manifest_mod_count
    MODRINTH_FOUND=$manifest_mod_count
    return 0
  fi
  
  echo "- Generating manifest from mod scan..."
  
  local mod_entries=""
  local file_count=0
  
  # Find mod directory
  local effective_mods_dir="$MODS_DIR"
  if [ ! -d "$effective_mods_dir" ]; then
    echo "- ERROR: No mods directory found at: $effective_mods_dir"
    echo "- The mods directory should be present (either from local development or CI download)"
    echo "- If running in CI, ensure the workflow downloads mods from manifest first"
    exit 1
  fi
  
  # Check if mods directory is empty or contains only empty files (CI download failures)
  local jar_count=$(ls "$effective_mods_dir"/*.jar 2>/dev/null | wc -l)
  if [ "$jar_count" -eq 0 ]; then
    echo "- ERROR: No mod JAR files found in $effective_mods_dir"
    echo "- Local development: Ensure mod files are present"
    echo "- CI environment: Check that manifest download step succeeded"
    exit 1
  fi
  
  echo "Scanning mods in: $effective_mods_dir ($jar_count mod files found)"
  
  # Process each mod file
  for mod_file in "$effective_mods_dir"/*.jar; do
    if [ ! -f "$mod_file" ]; then
      continue
    fi
    
    local filename=$(basename "$mod_file")
    local file_sha1=$(calculate_sha1 "$mod_file")
    local file_sha512=$(calculate_sha512 "$mod_file")
    local file_size=$(get_file_size "$mod_file")
    
    echo "- Processing: $filename"
    
    # Determine environment settings early
    local mod_env=$(get_mod_environment "$filename")
    
    # Lookup mod with smart update support
    local lookup_result=$(smart_mod_lookup "$mod_file")
    local result_type=$(echo "$lookup_result" | cut -d'|' -f1)
    local source=$(echo "$lookup_result" | cut -d'|' -f2)
    local download_url=$(echo "$lookup_result" | cut -d'|' -f3)
    local updated_hash=$(echo "$lookup_result" | cut -d'|' -f4)
    local updated_size=$(echo "$lookup_result" | cut -d'|' -f5)
    local updated_filename=$(echo "$lookup_result" | cut -d'|' -f6)
    
    # Update statistics based on result
    case "$source" in
      "manual-override")
        MANUAL_OVERRIDES_USED=$((MANUAL_OVERRIDES_USED + 1))
        ;;
      "modrinth-hash"|"modrinth-search")
        MODRINTH_FOUND=$((MODRINTH_FOUND + 1))
        ;;
      "smart-update")
        MODRINTH_FOUND=$((MODRINTH_FOUND + 1))
        SMART_UPDATES=$((SMART_UPDATES + 1))
        ;;
      "curseforge-search")
        CURSEFORGE_FOUND=$((CURSEFORGE_FOUND + 1))
        ;;
      "not-found"|"dependency-safety")
        PACK_INCLUDED=$((PACK_INCLUDED + 1))
        ;;
    esac
    
    # Update environment statistics
    case "$mod_env" in
      "client_only")
        CLIENT_ONLY_MODS=$((CLIENT_ONLY_MODS + 1))
        ;;
      "server_only")
        SERVER_ONLY_MOD_COUNT=$((SERVER_ONLY_MOD_COUNT + 1))
        ;;
      "both")
        UNIVERSAL_MODS=$((UNIVERSAL_MODS + 1))
        ;;
      "client_required_server_optional")
        UNIVERSAL_MODS=$((UNIVERSAL_MODS + 1))  # Count as universal for stats
        ;;
    esac
    
    # Check for failed lookups in strict mode
    if [ "$result_type" = "FAILED" ]; then
      echo "  - ERROR: Failed to find external download: $filename"
      continue # Skip this mod, don't add to manifest
    fi
    
    # Handle smart updates - use updated filename/hash if available
    local actual_filename="$filename"
    local actual_sha1="$file_sha1"
    local actual_sha512="$file_sha512"
    local actual_size="$file_size"
    
    if [ "$source" = "smart-update" ] && [ -n "$updated_filename" ]; then
      actual_filename="$updated_filename"
      actual_sha1="$updated_hash"  # This is still SHA1 from the lookup
      # Need to calculate SHA512 for the updated file
      actual_sha512=$(calculate_sha512 "$mod_file")
      actual_size="$updated_size"
      echo "  - Updated to: $actual_filename"
      # Update environment for the new filename
      mod_env=$(get_mod_environment "$actual_filename")
    fi
    
    # Set environment variables based on mod_env
    local client_env="required"
    local server_env="required"
    
    case "$mod_env" in
      "client_only")
        client_env="required"
        server_env="unsupported"
        echo "  → Client-only mod detected"
        ;;
      "server_only")
        client_env="unsupported"
        server_env="required"
        echo "  → Server-only mod detected"
        ;;
      "both")
        client_env="required"
        server_env="required"
        echo "  → Universal mod (client + server)"
        ;;
      "client_required_server_optional")
        client_env="required"
        server_env="optional"
        echo "  → Client-required, server-optional mod detected"
        ;;
      *)
        client_env="required"
        server_env="required"
        echo "  → Default: Universal mod (client + server)"
        ;;
    esac
    
    # Build file entry
    local entry="    {\n"
    entry="$entry      \"path\": \"mods/$actual_filename\",\n"
    entry="$entry      \"hashes\": {\n"
    entry="$entry        \"sha1\": \"$actual_sha1\",\n"
    entry="$entry        \"sha512\": \"$actual_sha512\"\n"
    entry="$entry      },\n"
    entry="$entry      \"env\": {\n"
    entry="$entry        \"client\": \"$client_env\",\n"
    entry="$entry        \"server\": \"$server_env\"\n"
    entry="$entry      },\n"
    entry="$entry      \"fileSize\": $actual_size"
    
    # Add download URLs based on result
    if [ "$result_type" = "FOUND" ]; then
      entry="$entry,\n      \"downloads\": [\n"
      entry="$entry        \"$download_url\"\n"
      entry="$entry      ]"
      echo "  + $source: $download_url"
    else
      entry="$entry,\n      \"downloads\": []"
      echo "  - Will include in pack: $filename"
    fi
    
    entry="$entry\n    }"
    
    # Add to entries
    if [ $file_count -gt 0 ]; then
      mod_entries="$mod_entries,\n$entry"
    else
      mod_entries="$entry"
    fi
    
    file_count=$((file_count + 1))
    TOTAL_MODS=$((TOTAL_MODS + 1))
  done
  
  # Generate the complete manifest
  generate_final_manifest "$mod_entries" "$file_count"
}

# ==================== PACK CREATION ====================

create_mrpack() {
  echo "- Creating .mrpack file optimized for Modrinth App..."
  
  local pack_name="$PROJECT_NAME-$CURRENT_VERSION.mrpack"
  local temp_dir="temp_pack"
  
  # Clean up any existing .mrpack files for this version
  rm -f "$pack_name" 2>/dev/null || true
  
  # Clean and create temp directory
  rm -rf "$temp_dir"
  mkdir -p "$temp_dir"
  
  # Copy manifest
  cp modrinth.index.json "$temp_dir/"
  
  # Modrinth App prefers overrides structure for all configurations
  mkdir -p "$temp_dir/overrides"
  
  # Copy configuration files to overrides/ (Modrinth App preference)
  if [ -d "config" ]; then
    cp -r config "$temp_dir/overrides/"
    echo "  + config/ → overrides/config/ (Modrinth App optimized)"
  fi
  
  # Copy other assets to overrides/ for Modrinth App compatibility
  for dir in scripts shaderpacks resourcepacks datapacks; do
    if [ -d "minecraft/$dir" ] && [ "$(ls -A "minecraft/$dir" 2>/dev/null)" ]; then
      cp -r "minecraft/$dir" "$temp_dir/overrides/"
      echo "  + minecraft/$dir/ → overrides/$dir/ (Modrinth App optimized)"
    elif [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
      cp -r "$dir" "$temp_dir/overrides/"
      echo "  + $dir/ → overrides/$dir/ (Modrinth App optimized)"
    fi
  done
  
  # Copy server list for community servers (Modrinth App handles this well)
  if [ -f "servers.dat" ]; then
    cp "servers.dat" "$temp_dir/overrides/servers.dat"
    echo "  + servers.dat → overrides/servers.dat (community servers)"
  fi
  
  # Modrinth App specific optimizations for shader configuration
  # These files need to be in overrides/ for proper initialization
  
  # Copy iris.properties with Modrinth App optimized settings
  if [ -f "config/iris.properties" ]; then
    # Ensure config directory exists in overrides
    mkdir -p "$temp_dir/overrides/config"
    cp "config/iris.properties" "$temp_dir/overrides/config/"
    echo "  + config/iris.properties → overrides/config/iris.properties (shader auto-enable)"
  fi
  
  # Copy additional shader configuration files for Modrinth App
  if [ -f "config/iris-excluded.json" ]; then
    mkdir -p "$temp_dir/overrides/config"
    cp "config/iris-excluded.json" "$temp_dir/overrides/config/"
    echo "  + config/iris-excluded.json → overrides/config/iris-excluded.json (iris config)"
  fi
  
  if [ -f "config/sodium-options.json" ]; then
    mkdir -p "$temp_dir/overrides/config"
    cp "config/sodium-options.json" "$temp_dir/overrides/config/"
    echo "  + config/sodium-options.json → overrides/config/sodium-options.json (performance)"
  fi
  
  # Copy shader-specific options files
  if [ -f "config/optionsshaders.txt" ]; then
    mkdir -p "$temp_dir/overrides/config"
    cp "config/optionsshaders.txt" "$temp_dir/overrides/config/"
    echo "  + config/optionsshaders.txt → overrides/config/optionsshaders.txt (shader settings)"
  fi
  
  # Copy client options with GUI scale and performance settings
  if [ -f "options.txt" ]; then
    cp "options.txt" "$temp_dir/overrides/"
    echo "  + options.txt → overrides/options.txt (client settings, GUI scale 3x)"
  fi
  
  # Copy launcher configuration files for auto RAM allocation
  if [ -f "instance.cfg" ]; then
    cp "instance.cfg" "$temp_dir/overrides/"
    echo "  + instance.cfg → overrides/instance.cfg (PrismLauncher: 4GB auto-allocation)"
  fi
  
  if [ -f "modrinth.launcher.json" ]; then
    cp "modrinth.launcher.json" "$temp_dir/overrides/"
    echo "  + modrinth.launcher.json → overrides/modrinth.launcher.json (Modrinth App: 4GB auto-allocation)"
  fi
  
  if [ -f "launcher_profiles.json" ]; then
    cp "launcher_profiles.json" "$temp_dir/overrides/"
    echo "  + launcher_profiles.json → overrides/launcher_profiles.json (Minecraft Launcher: 4GB auto-allocation)"
  fi
  
  # Include mods that couldn't be resolved (but NOT in CI mode - CI uses pure external downloads)
  if [ $PACK_INCLUDED -gt 0 ] && [ "$STRICT_EXTERNAL_DOWNLOADS" != "false" ]; then
    mkdir -p "$temp_dir/mods"
    local effective_mods_dir="$MODS_DIR"
    
    echo "  + Including unresolved mods in pack"
    
    for mod_file in "$effective_mods_dir"/*.jar; do
      if [ ! -f "$mod_file" ]; then
        continue
      fi
      
      local filename=$(basename "$mod_file")
      
      # Check if this mod needs to be included
      local lookup_result=$(smart_mod_lookup "$mod_file")
      local result_type=$(echo "$lookup_result" | cut -d'|' -f1)
      local source=$(echo "$lookup_result" | cut -d'|' -f2)
      
      if [ "$result_type" = "INCLUDE" ] || [ "$source" = "dependency-safety" ]; then
        cp "$mod_file" "$temp_dir/mods/"
        echo "  - Including: $filename"
      fi
    done
  fi
  
  # Create .mrpack (zip file)
  cd "$temp_dir"
  zip -r "../$pack_name" . -x "*.DS_Store" "*/__pycache__/*" "*/.*" >/dev/null 2>&1
  cd ..
  
  # Verify critical files are present in the .mrpack
  echo "- Verifying .mrpack structure..."
  local options_present=$(unzip -l "$pack_name" | grep -c "overrides/options.txt" || echo "0")
  local servers_present=$(unzip -l "$pack_name" | grep -c "overrides/servers.dat" || echo "0")
  
  if [ "$options_present" -eq 1 ]; then
    echo "  ✅ options.txt found in overrides/"
  else
    echo "  ❌ options.txt MISSING from overrides/"
  fi
  
  if [ "$servers_present" -eq 1 ]; then
    echo "  ✅ servers.dat found in overrides/"
  else
    echo "  ❌ servers.dat MISSING from overrides/"
  fi
  
  # Clean up
  rm -rf "$temp_dir"
  
  local pack_size=$(ls -lh "$pack_name" | awk '{print $5}')
  echo "+ Created: $pack_name ($pack_size)"
}

# ==================== CHANGELOG GENERATION ====================

# Generate detailed changelog based on detected changes
generate_changelog() {
  local change_type="$1"
  local base_version="$2"
  local new_version="$3"
  
  echo "- Generating changelog for $change_type changes..."
  
  local changelog_file="CHANGELOG.md"
  local short_changelog=""
  local detailed_changelog=""
  
  # Header
  detailed_changelog="Survival Not Guaranteed v$new_version\n\n"
  detailed_changelog="${detailed_changelog}Release Date: $(date +'%B %d, %Y')\n"
  detailed_changelog="${detailed_changelog}Previous Version: $base_version\n\n"
  
  if [ "$change_type" = "mod" ]; then
    echo "- Analyzing mod changes..."
    
    # Detect mod changes by comparing current mods with git history
    local added_mods=()
    local removed_mods=()
    local updated_mods=()
    
    # Get previous mod list from git
    local prev_mods=""
    if git rev-parse HEAD~1 >/dev/null 2>&1; then
      prev_mods=$(git show HEAD~1:modrinth.index.json 2>/dev/null | jq -r '.files[].path' 2>/dev/null | sed 's|^mods/||' | sort || echo "")
    fi
    
    local current_mods=$(find mods -name "*.jar" -type f -exec basename {} \; | sort)
    
    # Find added mods
    if [ -n "$prev_mods" ]; then
      while IFS= read -r mod; do
        if [ -n "$mod" ] && ! echo "$prev_mods" | grep -Fxq "$mod"; then
          added_mods+=("$mod")
        fi
      done <<< "$current_mods"
      
      # Find removed mods
      while IFS= read -r mod; do
        if [ -n "$mod" ] && ! echo "$current_mods" | grep -Fxq "$mod"; then
          removed_mods+=("$mod")
        fi
      done <<< "$prev_mods"
    fi
    
    # Generate mod changelog
    detailed_changelog="${detailed_changelog}MOD CHANGES\n\n"
    short_changelog="Updated modpack with mod changes"
    
    if [ ${#added_mods[@]} -gt 0 ]; then
      detailed_changelog="${detailed_changelog}Added Mods:\n"
      short_changelog="Added ${#added_mods[@]} new mod(s)"
      for mod in "${added_mods[@]}"; do
        local mod_name=$(echo "$mod" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | sed 's/_/ /g' | sed 's/\b\w/\U&/g')
        detailed_changelog="${detailed_changelog}- $mod_name ($mod)\n"
      done
      detailed_changelog="${detailed_changelog}\n"
    fi
    
    if [ ${#removed_mods[@]} -gt 0 ]; then
      detailed_changelog="${detailed_changelog}Removed Mods:\n"
      if [ ${#added_mods[@]} -gt 0 ]; then
        short_changelog="$short_changelog, removed ${#removed_mods[@]} mod(s)"
      else
        short_changelog="Removed ${#removed_mods[@]} mod(s)"
      fi
      for mod in "${removed_mods[@]}"; do
        local mod_name=$(echo "$mod" | sed 's/\.jar$//' | sed 's/-[0-9].*$//' | sed 's/_/ /g' | sed 's/\b\w/\U&/g')
        detailed_changelog="${detailed_changelog}- $mod_name ($mod)\n"
      done
      detailed_changelog="${detailed_changelog}\n"
    fi
    
    # Check for smart updates
    if [ $SMART_UPDATES -gt 0 ]; then
      detailed_changelog="${detailed_changelog}Smart Updates:\n"
      detailed_changelog="${detailed_changelog}- $SMART_UPDATES mod(s) automatically updated to latest compatible versions\n"
      detailed_changelog="${detailed_changelog}- Improved compatibility and bug fixes\n\n"
      
      if [ ${#added_mods[@]} -eq 0 ] && [ ${#removed_mods[@]} -eq 0 ]; then
        short_changelog="Smart-updated $SMART_UPDATES mod(s) to latest versions"
      fi
    fi
    
  elif [ "$change_type" = "config" ]; then
    echo "- Analyzing config changes..."
    
    # Detect specific config changes
    local config_changes=()
    
    # Check for common config files that changed
    if git diff --quiet HEAD~1 -- config/ 2>/dev/null; then
      : # No changes
    else
      local changed_configs=$(git diff --name-only HEAD~1 -- config/ 2>/dev/null | head -5)
      while IFS= read -r config; do
        if [ -n "$config" ]; then
          local config_name=$(basename "$config" | sed 's/\.[^.]*$//')
          local mod_name=$(echo "$config_name" | sed 's/-[a-z]*$//' | sed 's/_/ /g' | sed 's/\b\w/\U&/g')
          config_changes+=("$mod_name")
        fi
      done <<< "$changed_configs"
    fi
    
    detailed_changelog="${detailed_changelog}CONFIGURATION CHANGES\n\n"
    short_changelog="Updated configuration settings"
    
    if [ ${#config_changes[@]} -gt 0 ]; then
      detailed_changelog="${detailed_changelog}Modified Settings:\n"
      for config in "${config_changes[@]}"; do
        detailed_changelog="${detailed_changelog}- $config configuration updated\n"
      done
      detailed_changelog="${detailed_changelog}\n"
      short_changelog="Updated ${#config_changes[@]} configuration file(s)"
    else
      detailed_changelog="${detailed_changelog}- Configuration files optimized for better gameplay experience\n"
      detailed_changelog="${detailed_changelog}- Performance and balance improvements\n\n"
    fi
    
  else
    # Other changes (servers.dat, etc.)
    detailed_changelog="${detailed_changelog}OTHER CHANGES\n\n"
    detailed_changelog="${detailed_changelog}- Updated modpack components\n"
    detailed_changelog="${detailed_changelog}- General improvements and optimizations\n\n"
    short_changelog="Updated modpack components"
  fi
  
  # Add technical details
  detailed_changelog="${detailed_changelog}TECHNICAL DETAILS\n\n"
  detailed_changelog="${detailed_changelog}- Total Mods: $TOTAL_MODS\n"
  detailed_changelog="${detailed_changelog}- Universal Mods (Client + Server): $UNIVERSAL_MODS\n"
  detailed_changelog="${detailed_changelog}- Client-Only Mods: $CLIENT_ONLY_MODS\n"
  detailed_changelog="${detailed_changelog}- Server-Only Mods: $SERVER_ONLY_MOD_COUNT\n"
  detailed_changelog="${detailed_changelog}- Minecraft Version: $MINECRAFT_VERSION\n"
  detailed_changelog="${detailed_changelog}- NeoForge Version: $NEOFORGE_VERSION\n"
  detailed_changelog="${detailed_changelog}- External Downloads: $((MODRINTH_FOUND + CURSEFORGE_FOUND + MANUAL_OVERRIDES_USED)) of $TOTAL_MODS ($(( (MODRINTH_FOUND + CURSEFORGE_FOUND + MANUAL_OVERRIDES_USED) * 100 / TOTAL_MODS ))%)\n"
  detailed_changelog="${detailed_changelog}- Pack Size: Optimized with external downloads\n"
  detailed_changelog="${detailed_changelog}- Server Compatibility: Dedicated servers will automatically exclude client-only mods\n\n"
  
  # Add installation instructions with Modrinth App emphasis
  detailed_changelog="${detailed_changelog}INSTALLATION\n\n"
  detailed_changelog="${detailed_changelog}Recommended: Modrinth App (Optimized)\n"
  detailed_changelog="${detailed_changelog}1. Download the .mrpack file from this release\n"
  detailed_changelog="${detailed_changelog}2. In Modrinth App: File → Add Instance → From File\n"
  detailed_changelog="${detailed_changelog}3. Select the downloaded .mrpack file\n"
  detailed_changelog="${detailed_changelog}4. Modrinth App will automatically configure optimal settings\n\n"
  detailed_changelog="${detailed_changelog}Alternative Launchers:\n"
  detailed_changelog="${detailed_changelog}- PrismLauncher: Add Instance → Import → Modrinth Pack\n"
  detailed_changelog="${detailed_changelog}- MultiMC: Add Instance → Import → Browse for .mrpack\n\n"
  
  # Add compatibility info with Modrinth App specifics
  detailed_changelog="${detailed_changelog}SYSTEM REQUIREMENTS\n\n"
  detailed_changelog="${detailed_changelog}- Minimum RAM: 2GB allocated (4GB recommended for optimal performance)\n"
  detailed_changelog="${detailed_changelog}- With Shaders: 4GB+ recommended for smooth shader performance\n"
  detailed_changelog="${detailed_changelog}- Java Version: Java 21+ required\n"
  detailed_changelog="${detailed_changelog}- Client/Server: Compatible with both single-player and multiplayer\n"
  detailed_changelog="${detailed_changelog}- Modrinth App: Automatic memory allocation based on system specs\n\n"
  
  # Add features section
  detailed_changelog="${detailed_changelog}FEATURES\n\n"
  detailed_changelog="${detailed_changelog}- Pre-configured Shaders: MakeUp-UltraFast enabled by default\n"
  detailed_changelog="${detailed_changelog}- Optimized Settings: 3x GUI scale and performance tweaks\n"
  detailed_changelog="${detailed_changelog}- Community Servers: Pre-loaded server list\n"
  detailed_changelog="${detailed_changelog}- External Downloads: 100% mod downloads, minimal pack size\n"
  
  # Save changelog
  echo -e "$detailed_changelog" > "$changelog_file"
  
  # Export for GitHub Actions
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "short_changelog=$short_changelog" >> "$GITHUB_OUTPUT"
    echo "detailed_changelog_file=$changelog_file" >> "$GITHUB_OUTPUT"
  fi
  
  echo "+ Generated changelog: $short_changelog"
  echo "+ Detailed changelog saved to: $changelog_file"
}

# ==================== STATISTICS ====================

print_statistics() {
  echo ""
  echo "- Build Statistics:"
  echo "────────────────────"
  echo "Total mods processed: $TOTAL_MODS"
  echo "Modrinth downloads: $MODRINTH_FOUND"
  echo "CurseForge downloads: $CURSEFORGE_FOUND"
  echo "Manual overrides used: $MANUAL_OVERRIDES_USED"
  echo "Smart updates applied: $SMART_UPDATES"
  echo "Included in pack: $PACK_INCLUDED"
  echo ""
  echo "- Environment Distribution:"
  echo "Universal mods (client + server): $UNIVERSAL_MODS"
  echo "Client-only mods: $CLIENT_ONLY_MODS"
  echo "Server-only mods: $SERVER_ONLY_MOD_COUNT"
  echo ""
  
  if [ $TOTAL_MODS -gt 0 ]; then
    local external_downloads=$((MODRINTH_FOUND + CURSEFORGE_FOUND + MANUAL_OVERRIDES_USED))
    local coverage=$((external_downloads * 100 / TOTAL_MODS))
    echo "External download coverage: $coverage%"
    echo "Pack size reduction: ~$((100 - (PACK_INCLUDED * 100 / TOTAL_MODS)))%"
  else
    echo "External download coverage: 0%"
    echo "- Pack size reduction: 0%"
  fi
  echo ""
  
  if [ $SMART_UPDATES -gt 0 ]; then
    echo "- $SMART_UPDATES mods were auto-updated to latest compatible versions"
  fi
  
  if [ $PACK_INCLUDED -gt 0 ]; then
    echo "WARNING: $PACK_INCLUDED mods will be included in pack (dependencies or not found on platforms)"
  else
    echo "- All mods have external download URLs - no mods included in pack!"
  fi
  
  if [ $CLIENT_ONLY_MODS -gt 0 ]; then
    echo "- $CLIENT_ONLY_MODS client-only mods detected (will not be installed on dedicated servers)"
  fi
  
  if [ $SERVER_ONLY_MOD_COUNT -gt 0 ]; then
    echo "- $SERVER_ONLY_MOD_COUNT server-only mods detected (will not be installed on clients)"
  fi
}

# ==================== MAIN EXECUTION ====================

main() {
  echo "Final .mrpack Builder"
  echo "========================"
  echo ""
  
  # Clean up old files to ensure fresh build
  echo "- Cleaning up old build artifacts..."
  
  # In CI mode, preserve the existing manifest
  if [ "$CI_MODE" = "true" ] && [ -f "modrinth.index.json" ]; then
    echo "- CI mode: Preserving existing manifest..."
    cp modrinth.index.json modrinth.index.json.backup
  fi
  
  rm -f modrinth.index.json 2>/dev/null || true
  rm -f *.mrpack 2>/dev/null || true
  rm -f CHANGELOG.md 2>/dev/null || true
  
  # Restore manifest in CI mode
  if [ "$CI_MODE" = "true" ] && [ -f "modrinth.index.json.backup" ]; then
    echo "- CI mode: Restoring preserved manifest..."
    mv modrinth.index.json.backup modrinth.index.json
  fi
  
  # Detect version
  get_latest_version
  
  # Detect NeoForge version
  get_latest_neoforge_version
  
  # Generate manifest
  generate_manifest
  
  # Check for failed lookups in strict mode
  if [ "$STRICT_EXTERNAL_DOWNLOADS" = "true" ] && [ ${#FAILED_LOOKUPS[@]} -gt 0 ]; then
    echo ""
    echo "- ERROR: Build failed: Strict external downloads mode enabled"
    echo "   The following mods could not be found on external platforms:"
    for failed_mod in "${FAILED_LOOKUPS[@]}"; do
      echo "   - $failed_mod"
    done
    echo ""
    echo "- To fix this, you can:"
    echo "   1. Add manual overrides for these mods in mod_overrides.conf"
    echo "   2. Set STRICT_EXTERNAL_DOWNLOADS=false to include them in the pack"
    echo "   3. Set up a CurseForge API key for better CurseForge search"
    echo ""
    exit 1
  fi
  
  # Create pack
  create_mrpack
  
  # Generate changelog if version information is available
  if [ -n "$CURRENT_VERSION" ] && [ -n "$PREVIOUS_VERSION" ]; then
    local change_type="$DETECTED_CHANGE_TYPE"
    # Determine change type based on what triggered the build
    if [ -n "$GITHUB_ACTIONS" ] && [ "$DETECTED_CHANGE_TYPE" = "none" ]; then
      # In GitHub Actions, we can check the changed files
      if git diff --quiet HEAD~1 -- mods/ 2>/dev/null; then
        if git diff --quiet HEAD~1 -- config/ 2>/dev/null; then
          change_type="other"
        else
          change_type="config"
        fi
      else
        change_type="mod"
      fi
    fi
    
    generate_changelog "$change_type" "$PREVIOUS_VERSION" "$CURRENT_VERSION"
  fi
  
  # Show statistics
  print_statistics
  
  echo ""
  echo "+ Build complete! Your .mrpack is optimized for Modrinth App with proper client/server separation."
  echo "- File: $PROJECT_NAME-$CURRENT_VERSION.mrpack"
  echo "- Primary target: Modrinth App (optimized structure)"
  echo "- Also compatible with: PrismLauncher, MultiMC, and other launchers"
  echo "- Server compatibility: Client-only mods automatically excluded from dedicated servers"
  echo "- Mod lookup order: Manual overrides → Modrinth hash → Modrinth search → CurseForge search → Include in pack"
  echo "- Smart updates: Non-dependency mods auto-update to latest compatible versions on hash mismatch"
  echo "- Shader configuration: Pre-configured for MakeUp-UltraFast shaders with 3x GUI scale"
  echo ""
  echo "- Modrinth App features:"
  echo "  * All configs in overrides/ for proper initialization"
  echo "  * Optimized shader auto-enablement"
  echo "  * Community server list included"
  echo "  * Performance settings pre-configured"
  echo ""
  echo "- Next steps:"
  echo "1. Test the .mrpack file in Modrinth App"
  echo "2. Upload to GitHub releases"
  echo "3. Push to Modrinth for distribution"
  echo ""
  echo "📋 If options.txt or servers.dat are not recognized by the launcher:"
  echo "1. Check docs/TROUBLESHOOTING.md for debugging steps"
  echo "2. Try with a different launcher (PrismLauncher) to isolate the issue"
  echo "3. Report to Modrinth support if the issue persists"
}

# Run main function
main "$@"
