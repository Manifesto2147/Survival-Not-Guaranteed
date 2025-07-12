# Survival Not Guaranteed

**A challenging fantasy RPG modpack where danger doesn't wait for you to gear up.**

Welcome to a world that blends unforgiving survival mechanics with epic magic, deadly monsters, and vast dungeon-filled landscapes. This modpack transforms Minecraft into a harsh fantasy realm where every step tests your preparation, skill, and courage.

---

## 📖 Documentation

For comprehensive technical documentation, build processes, and development guidelines, see:
**[Complete System Documentation](docs/SYSTEM_DOCUMENTATION.md)**

---

## 🛠️ Manifest-Driven Development System

This modpack employs a cutting-edge manifest-driven CI/CD system for reliable, automated distribution:

- **📋 Manifest Authority**: `modrinth.index.json` is the single source of truth for all mod information
- **🔄 Fresh CI Builds**: Every release downloads all 140+ mods fresh and rebuilds the .mrpack from scratch
- **✅ Zero Drift**: Eliminates version mismatches between development and distribution
- **🛡️ Legal Compliance**: All mods downloaded from official Modrinth sources only
- **🎯 Dungeons & Taverns**: Server-only mods properly handled and distributed
- **⚡ Instant Updates**: Push manifest changes, get automatic releases with complete mod validation

### Developer Workflow (Manifest-First)

```bash
# Update the manifest with new/changed mods
vim modrinth.index.json

# Test the manifest builds correctly
./build.sh

# Commit and push changes (no .mrpack files needed)
git add modrinth.index.json CHANGELOG.md
git commit -m "Add new mods and update manifest"
git push origin main  # Triggers automated CI/CD

# CI automatically:
# 1. Downloads all 140+ mods from manifest
# 2. Builds fresh .mrpack with exact version sync
# 3. Distributes to GitHub and Modrinth
```

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
- **Current Version**: Automatically managed via manifest-driven CI/CD
- **Minecraft**: 1.21.1
- **Modloader**: NeoForge 21.1.180
- **Mod Count**: 140+ carefully curated mods (including server-only mods)
- **Distribution**: Manifest-driven .mrpack with fresh mod downloads
- **Build System**: Zero-artifact repository with CI rebuilding
- **Legal Compliance**: Official Modrinth sources only

### Compatibility & Distribution
- **Client & Server**: Full multiplayer support with proper environment detection
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Launcher Support**: Universal .mrpack format (Modrinth App, PrismLauncher, MultiMC)
- **Download Size**: ~2MB (.mrpack with external mod downloads)
- **Installation**: Automatic mod acquisition from verified sources

---

**Ready for the challenge?** Download the latest release and discover if you have what it takes when survival is not guaranteed.
