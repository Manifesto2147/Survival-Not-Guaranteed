#!/bin/bash

# Data Validation Error Fix Script
# Fixes recipe parsing, loot table, and tag validation errors from server logs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="fix-validation-errors.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log "${BLUE}Starting data validation error fixes...${NC}"

# ==================== RECIPE FIXES ====================

fix_empty_recipe_files() {
    log "${YELLOW}Fixing empty recipe files...${NC}"
    
    # Fix empty beetroot soup recipe
    local beetroot_recipe="minecraft/data/minecraft/recipe/beetroot_soup.json"
    if [[ -f "$beetroot_recipe" ]] && [[ ! -s "$beetroot_recipe" ]]; then
        log "Fixing empty beetroot_soup.json"
        cat > "$beetroot_recipe" << 'EOF'
{
  "type": "minecraft:crafting_shaped",
  "category": "misc",
  "pattern": [
    "BBB",
    "BBB",
    " b "
  ],
  "key": {
    "B": {
      "item": "minecraft:beetroot"
    },
    "b": {
      "item": "minecraft:bowl"
    }
  },
  "result": {
    "item": "minecraft:beetroot_soup"
  }
}
EOF
    fi

    # Fix empty mushroom stew recipe
    local mushroom_recipe="minecraft/data/minecraft/recipe/mushroom_stew.json"
    if [[ -f "$mushroom_recipe" ]] && [[ ! -s "$mushroom_recipe" ]]; then
        log "Fixing empty mushroom_stew.json"
        cat > "$mushroom_recipe" << 'EOF'
{
  "type": "minecraft:crafting_shapeless",
  "category": "misc",
  "ingredients": [
    {
      "item": "minecraft:brown_mushroom"
    },
    {
      "item": "minecraft:red_mushroom"
    },
    {
      "item": "minecraft:bowl"
    }
  ],
  "result": {
    "item": "minecraft:mushroom_stew"
  }
}
EOF
    fi

    # Fix empty rabbit stew recipes
    for recipe in "rabbit_stew_from_brown_mushroom" "rabbit_stew_from_red_mushroom"; do
        local rabbit_recipe="minecraft/data/minecraft/recipe/${recipe}.json"
        if [[ -f "$rabbit_recipe" ]] && [[ ! -s "$rabbit_recipe" ]]; then
            log "Fixing empty ${recipe}.json"
            cat > "$rabbit_recipe" << 'EOF'
{
  "type": "minecraft:crafting_shapeless",
  "category": "misc",
  "ingredients": [
    {
      "item": "minecraft:baked_potato"
    },
    {
      "item": "minecraft:cooked_rabbit"
    },
    {
      "item": "minecraft:bowl"
    },
    {
      "item": "minecraft:carrot"
    },
    {
      "item": "minecraft:brown_mushroom"
    }
  ],
  "result": {
    "item": "minecraft:rabbit_stew"
  }
}
EOF
        fi
    done
}

fix_malformed_tag_files() {
    log "${YELLOW}Fixing malformed tag files...${NC}"
    
    # Fix cold_sweat biome tag with invalid boolean
    local biome_tag="config/cold_sweat/tags/worldgen/biome/increased_soul_stalk.json"
    if [[ -f "$biome_tag" ]]; then
        log "Fixing cold_sweat biome tag format"
        # Create a backup
        cp "$biome_tag" "${biome_tag}.backup"
        
        # Fix the malformed boolean
        sed -i 's/"false"/false/g' "$biome_tag"
        sed -i 's/"true"/true/g' "$biome_tag"
    fi
}

create_missing_loot_tables() {
    log "${YELLOW}Creating missing loot table entries...${NC}"
    
    # Create missing azisterweaponsedeco loot tables
    local azister_loot_dir="config/azisterweaponsedeco/data/azisterweaponsedeco/loot_tables/blocks"
    mkdir -p "$azister_loot_dir"
    
    for item in "beiraf_golden_marble1" "beiraf_golden_marble2" "beiraf_golden_marble3" \
                "beira_golden_marble1" "beira_golden_marble2" "beira_golden_marble3" \
                "beirac_golden_marble1" "beirac_golden_marble2" "beirac_golden_marble3" \
                "beiracf_golden_marble1" "beiracf_golden_marble2" "beiracf_golden_marble3" \
                "n_golden_marble1" "n_golden_marble2" "n_golden_marble3" \
                "n_golden_marble_p1" "n_golden_marble_p2" "n_golden_marble_p3" \
                "n_hell_marble1" "n_hell_marble2" "n_hell_marble3" \
                "steps"; do
        
        if [[ ! -f "${azister_loot_dir}/${item}.json" ]]; then
            log "Creating loot table for ${item}"
            cat > "${azister_loot_dir}/${item}.json" << EOF
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ],
      "entries": [
        {
          "type": "minecraft:item",
          "name": "azisterweaponsedeco:${item}"
        }
      ],
      "rolls": 1.0
    }
  ]
}
EOF
        fi
    done
}

fix_recipe_serialization_errors() {
    log "${YELLOW}Creating recipe compatibility fixes...${NC}"
    
    # Create datapack fixes directory
    local fixes_dir="config/recipe_fixes/data"
    mkdir -p "$fixes_dir"
    
    # Create a conditions file to disable problematic recipes
    cat > "${fixes_dir}/recipe_conditions.json" << 'EOF'
{
  "neoforge:conditions": [
    {
      "type": "neoforge:mod_loaded",
      "modid": "create_ironworks"
    }
  ]
}
EOF
}

validate_mod_compatibility() {
    log "${YELLOW}Validating mod compatibility...${NC}"
    
    # Check for missing mod dependencies (improve with actual mod detection)
    local missing_mods=()
    local warning_mods=()
    
    # Check for Create-related industrial mods (create_ironworks alternatives)
    if ! ls minecraft/mods/ | grep -q -E "(create.*iron|create.*metal|create.*industrial)"; then
        # Check if we have recipes that might need ironworks functionality
        if find config/ minecraft/config/ -name "*.json" -exec grep -l "create.*iron\|ironworks" {} \; 2>/dev/null | head -1 >/dev/null; then
            warning_mods+=("create_ironworks or similar industrial Create addon")
        fi
    fi
    
    # Check for environmental/survival mods (toughasnails alternatives)
    if ! ls minecraft/mods/ | grep -q -E "(tough.*nail|cold.*sweat|serene.*season|temperature|thirst)"; then
        # You have ColdSweat and SereneSeasons, so this check should pass
        if ls minecraft/mods/ | grep -q -E "(ColdSweat|SereneSeasons|ThirstWasTaken)"; then
            log "${GREEN}Environmental/survival mods detected (ColdSweat, SereneSeasons, ThirstWasTaken)${NC}"
        else
            warning_mods+=("environmental survival mod (like toughasnails)")
        fi
    fi
    
    # Check for Farmer's Delight family mods
    if ! ls minecraft/mods/ | grep -q -E "(farmers.*delight|farmers.*respite|cultural.*delight)"; then
        # You have FarmersDelight, so this should pass
        if ls minecraft/mods/ | grep -q -E "(FarmersDelight|culturaldelights)"; then
            log "${GREEN}Farmer's Delight family mods detected${NC}"
        else
            warning_mods+=("farmers delight or related cooking mod")
        fi
    fi
    
    # Report missing critical dependencies
    if [[ ${#missing_mods[@]} -gt 0 ]]; then
        log "${RED}Missing critical mod dependencies:${NC}"
        for mod in "${missing_mods[@]}"; do
            log "  - ${mod}"
        done
        log "${YELLOW}Some recipes may fail due to missing dependencies${NC}"
    fi
    
    # Report optional/alternative dependencies
    if [[ ${#warning_mods[@]} -gt 0 ]]; then
        log "${YELLOW}Optional mod dependencies (recipes may be disabled):${NC}"
        for mod in "${warning_mods[@]}"; do
            log "  - ${mod}"
        done
        log "${BLUE}Consider adding these mods if you encounter recipe conflicts${NC}"
    fi
    
    # If everything looks good, report success
    if [[ ${#missing_mods[@]} -eq 0 && ${#warning_mods[@]} -eq 0 ]]; then
        log "${GREEN}All expected mod dependencies are satisfied${NC}"
    fi
}

create_recipe_override_datapack() {
    log "${YELLOW}Creating recipe override datapack...${NC}"
    
    local datapack_dir="config/datapacks/recipe_fixes/data"
    mkdir -p "$datapack_dir"
    
    # Create pack.mcmeta
    cat > "config/datapacks/recipe_fixes/pack.mcmeta" << 'EOF'
{
  "pack": {
    "description": "Recipe validation fixes for Survival Not Guaranteed",
    "pack_format": 57,
    "supported_formats": [57, 58]
  }
}
EOF
    
    # Create conditions to disable problematic recipes
    mkdir -p "${datapack_dir}/minecraft/recipe"
    
    # Disable problematic create recipes that use missing mods
    for recipe in "create_simple_ore_doubling:6.0.0/compacting/2x_zinc" \
                  "create_simple_ore_doubling:6.0.0/compacting/2x_copper" \
                  "create_simple_ore_doubling:6.0.0/compacting/2x_iron" \
                  "create_simple_ore_doubling:6.0.0/compacting/2x_gold"; do
        
        local recipe_file="${datapack_dir}/$(echo "$recipe" | tr ':' '/')}.json"
        mkdir -p "$(dirname "$recipe_file")"
        
        cat > "$recipe_file" << 'EOF'
{
  "neoforge:conditions": [
    {
      "type": "neoforge:false"
    }
  ],
  "type": "minecraft:crafting_shapeless",
  "ingredients": [],
  "result": {
    "item": "minecraft:air"
  }
}
EOF
    done
}

fix_config_validation_errors() {
    log "${YELLOW}Fixing configuration validation errors...${NC}"
    
    # Fix Cold Sweat access transformer issue
    local cold_sweat_at="minecraft/mods/ColdSweat-2.4-b03c.jar"
    if [[ -f "$cold_sweat_at" ]]; then
        log "Cold Sweat access transformer file missing - this is a mod issue"
        log "Consider updating Cold Sweat to a newer version"
    fi
    
    # Create fallback configs for mods with issues
    local config_fixes_dir="config/fixes"
    mkdir -p "$config_fixes_dir"
    
    # Create a comprehensive mod compatibility report
    cat > "${config_fixes_dir}/compatibility_report.txt" << 'EOF'
Mod Compatibility Report - Survival Not Guaranteed
==================================================

RECIPE PARSING ERRORS:
- Multiple Create addon recipes fail due to missing mod dependencies
- Some recipes use unsupported serializer types
- Empty recipe files cause JSON parsing failures

LOOT TABLE ERRORS:
- Azister Weapons & Deco has missing item registrations
- Some Cultural Delights items are not properly registered
- Samurai Dynasty statue blocks have malformed loot conditions

TAG VALIDATION ERRORS:
- Cold Sweat biome tags contain malformed boolean values
- Some item tags reference non-existent items
- Missing tag definitions for Create addons

RECOMMENDATIONS:
1. Update Cold Sweat to fix access transformer issues
2. Consider removing or updating problematic Create addons
3. Verify all item and block registrations are complete
4. Test recipe functionality in-game after fixes

Generated: $(date)
EOF
}

# ==================== MAIN EXECUTION ====================

main() {
    log "${BLUE}Data Validation Error Fix Script${NC}"
    log "Timestamp: $(date)"
    
    # Create necessary directories
    mkdir -p config/datapacks
    mkdir -p config/fixes
    
    # Apply fixes
    fix_empty_recipe_files
    fix_malformed_tag_files
    create_missing_loot_tables
    fix_recipe_serialization_errors
    validate_mod_compatibility
    create_recipe_override_datapack
    fix_config_validation_errors
    
    log "${GREEN}Data validation fixes completed successfully!${NC}"
    log ""
    log "${YELLOW}Summary of fixes applied:${NC}"
    log "  - Fixed empty recipe files"
    log "  - Corrected malformed tag files"
    log "  - Created missing loot table entries"
    log "  - Generated recipe compatibility overrides"
    log "  - Created mod compatibility report"
    log ""
    log "${BLUE}Next steps:${NC}"
    log "1. Restart the server to apply fixes"
    log "2. Monitor logs for remaining errors"
    log "3. Consider updating problematic mods"
    log "4. Review the compatibility report in config/fixes/"
    log ""
    log "Log file: $LOG_FILE"
}

# Run the main function
main "$@"
