# Survival Not Guaranteed

**A challenging fantasy RPG modpack where danger doesn't wait for you to gear up.**

Welcome to a world that blends unforgiving survival mechanics with epic magic, deadly monsters, and vast dungeon-filled landscapes. This modpack transforms Minecraft into a harsh fantasy realm where every step tests your preparation, skill, and courage.

---

## 📖 Documentation

For comprehensive technical documentation, build processes, and development guidelines, see:
**[Complete System Documentation](docs/SYSTEM_DOCUMENTATION.md)**

---

## 📋 Recent Changes

### v3.12.12 (Latest) - Cold Sweat Temperature Sync Fix
**🔥 Critical Bug Fix**: Resolved temperature desynchronization between Cold Sweat and Serene Seasons

- **Updated**: Cold Sweat from v2.4-b03c to v2.4-b04a (July 2025 release)
- **Updated**: NeoForge from 21.1.180 to 21.1.194 (latest stable)
- **Fixed**: Fire warmth and heat sources not registering until player relog
- **Improved**: Temperature sync reliability with optimized Modifier Tick Rate documentation
- **Verified**: Complete modpack rebuild and testing with 140 mods
- **Impact**: Players no longer need to relog to restore fire warmth functionality

**Player Impact**: This fixes the frustrating issue where campfires, furnaces, and other heat sources would stop warming players during winter/cold weather until they logged out and back in.

### Previous Updates
- **v3.12.11**: Fixed Dungeons & Taverns mod environment detection for client installations
- **v3.12.1**: Enhanced launcher configuration with cross-platform RAM allocation and JVM optimization
- **v3.12.0+**: Implemented pure external download CI/CD system with manifest-based builds

---

## 🛠️ Pure External Download CI/CD System

This modpack employs a revolutionary pure external download architecture that has solved all launcher compatibility issues:

- **📋 Manifest Authority**: `modrinth.index.json` is the immutable source of truth for all mod information
- **� Pure External Downloads**: .mrpack files contain zero embedded mods - everything downloaded fresh by launchers
- **⚡ CI Mode**: Lightning-fast CI that preserves manifests without mod scanning or downloading
- **✅ Perfect Compatibility**: Zero "missing download link" errors across all launcher platforms
- **🎯 Server-Only Support**: Dungeons & Taverns mods properly distributed for server environments
- **📦 Size Optimization**: 99%+ size reduction (~2MB vs 2GB+) with superior functionality
- **🔄 Version Intelligence**: Automatic version collision detection with smart auto-increment
- **🛡️ Legal Perfection**: 100% official Modrinth sources with zero cached or unofficial content

### Developer Workflow (Pure External, Zero-Artifact)

```bash
# Update the manifest with new/changed mods and environment settings
vim modrinth.index.json

# Test the manifest locally (optional - CI preserves it as-is)
./build.sh

# Commit only source files (never .mrpack artifacts)
git add modrinth.index.json CHANGELOG.md config/ scripts/
git commit -m "Add new mods with proper environment settings"
git push origin main  # Triggers pure external CI/CD

# CI automatically:
# 1. Preserves existing manifest without modification
# 2. Updates only version field for release synchronization
# 3. Creates pure external .mrpack (configs + manifest only)
# 4. Distributes to GitHub and Modrinth with perfect launcher compatibility
# 5. Auto-increments version until unused version found
```

**Benefits Achieved:**
- 🚫 **No more launcher errors** - Pure external architecture eliminates all download link issues
- ⚡ **Lightning CI speed** - No mod downloading needed, pure manifest operations  
- 📦 **Massive size reduction** - 99%+ smaller .mrpack files with better functionality
- 🔄 **Automatic updates** - Mod updates flow through without pack rebuilds
- 🌍 **Universal compatibility** - Single .mrpack works perfectly everywhere
- 🛡️ **Legal compliance** - Only official sources, zero legal concerns

**For comprehensive technical documentation, see [Complete System Documentation](docs/SYSTEM_DOCUMENTATION.md)**

---

## What Awaits You

### Unforgiving Survival
- **Temperature Management**: Face searing heat and bitter cold that demand proper preparation
- **Thirst System**: Manage hydration with purifiable water sources and weather effects  
- **Enhanced Combat**: Precision and caution are required - button mashing won't save you
- **Environmental Hazards**: The world itself becomes your adversary

### Epic Magic & Progression
- **Ars Nouveau**: Master magical arts with glyphs, automation, and mystical creatures
- **Iron's Spells & Spellbooks**: Discover powerful spells and enchantments
- **Magical Automation**: Combine technology and magic for advanced contraptions
- **Progressive Difficulty**: Start weak, grow powerful through dedication

### Vast World to Explore
- **Overhauled Dungeons**: Massive structures with unique loot and deadly challenges
- **New Biomes**: Discover landscapes crafted by Terralith
- **Boss Encounters**: Face formidable foes that require strategy and preparation
- **Hidden Treasures**: Rewards for the brave and thoroughly prepared

### Technology & Automation  
- **Create Mod**: Build complex contraptions, factories, and mechanical marvels
- **Advanced Storage**: Sophisticated systems for organizing your expanding empire
- **Quality of Life**: Enhanced inventory management, mapping, and information display
- **Modular Progression**: Choose your path between magic, technology, or both

## Getting Started

### Installation & Setup

#### Recommended: Modrinth App
1. Download the latest `.mrpack` file from [Releases](https://github.com/Manifesto2147/Survival-Not-Guaranteed/releases)
2. Open Modrinth App
3. Click "Add Instance" → "From File"
4. Select the downloaded `.mrpack` file
5. **Automatic Configuration**: Modrinth App will automatically configure 4GB RAM allocation and optimal settings

#### Alternative Launchers

**PrismLauncher / MultiMC**
- Add Instance → Import → Browse for `.mrpack` file
- The modpack includes `instance.cfg` for automatic 4GB RAM configuration
- JVM arguments are pre-configured for optimal performance

**Other Launchers**
- Import the `.mrpack` file using your launcher's modpack import feature
- **Manual RAM Setup**: If automatic configuration doesn't work, manually allocate 4GB RAM
- Use the included `launcher_profiles.json` as a reference for optimal JVM arguments

### System Requirements
- **Minecraft**: 1.21.1
- **Modloader**: NeoForge 21.1.180+
- **RAM**: 4GB minimum (8GB recommended for optimal performance)
- **Java**: Java 21+ required
- **Storage**: 2GB free space for mod downloads
- **Cross-Platform**: Windows, macOS, Linux supported

### Pre-Configured Features
The modpack includes automatic configuration for:
- **Memory**: 4GB RAM allocation via launcher profiles
- **Performance**: Optimized JVM arguments (Aikar's flags)
- **Shaders**: MakeUp-UltraFast enabled by default
- **GUI Scale**: 3x for better visibility
- **Community Server**: Pre-loaded server list

### First Steps
1. **Prepare for the elements** - Craft temperature-resistant gear early
2. **Secure water sources** - Not all water is safe to drink
3. **Light up your base** - Darkness breeds more than just zombies
4. **Progress carefully** - Rush into danger at your own peril
5. **Read mod guides** - JEI and Patchouli provide in-game documentation

## Community & Support

### Multiplayer Server
The modpack automatically includes our community server in your multiplayer list:
- **Server**: survival-not-guaranteed.modrinth.gg
- **No manual setup required** - appears automatically after installation

### Getting Help
- Check in-game guides via JEI (Just Enough Items)
- Consult Patchouli books for detailed mod information
- Join discussions in [GitHub Issues](https://github.com/Manifesto2147/Survival-Not-Guaranteed/issues)

### Featured Mods (140+ Total)
- **Magic**: Ars Nouveau, Iron's Spells & Spellbooks, Relics
- **Technology**: Create, Sophisticated Storage, Advanced Automation
- **Exploration**: When Dungeons Arise, Terralith, Ice & Fire, Dungeons & Taverns
- **Survival**: Cold Sweat, Thirst Was Taken, Serene Seasons
- **Combat**: Better Combat, Epic Knights, Expanded Combat
- **Quality of Life**: JEI, Xaero's Map, Waystones

## Technical Details

### Version Information & Architecture
- **Current Version**: Automatically managed via pure external CI/CD with collision avoidance
- **Minecraft**: 1.21.1
- **Modloader**: NeoForge 21.1.180
- **Mod Count**: 140+ carefully curated mods (including server-only mods)
- **Distribution**: Pure external download architecture with zero mod embedding
- **Build System**: CI mode with manifest preservation for perfect compatibility
- **Legal Compliance**: 100% official Modrinth sources with zero cached content
- **Size Efficiency**: ~2MB .mrpack files vs 2GB+ traditional approach (99%+ reduction)

### Compatibility & Distribution
- **Client & Server**: Full multiplayer support with intelligent environment detection
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Launcher Support**: Universal compatibility (Modrinth App, PrismLauncher, MultiMC, etc.)
- **Download Method**: Pure external downloads - all mods downloaded fresh by launcher
- **Error Prevention**: Zero "missing download link" errors through pure external architecture
- **Update Efficiency**: Mod updates automatically available without pack rebuilds

---

**Ready for the challenge?** Download the latest release and discover if you have what it takes when survival is not guaranteed.
