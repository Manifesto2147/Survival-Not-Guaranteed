# Survival Not Guaranteed

A gritty and challenging survival modpack featuring magic, technology, and culinary adventures.

## 🚀 Quick Start

```bash
# Build the modpack
./build.sh

# Debug a specific mod (if needed)
./debug.sh
```

## 📦 What's Generated

- **`Survival Not Guaranteed-3.5.5.mrpack`** - The final modpack file
- **`modrinth.index.json`** - Manifest with mod download URLs
- **99% external downloads** - Minimal pack size, maximum compatibility

## Features

- **Magic Systems**: Ars Nouveau and related mods for spellcasting
- **Technology**: Create mod and expansions for engineering
- **Culinary Adventures**: Farmer's Delight and various food mods
- **Enhanced Combat**: Expanded combat mechanics
- **Quality of Life**: Various improvements to the vanilla experience

## Installation

### 🚀 **Quick Downloads**

| Platform | Link | Description |
|----------|------|-------------|
| **Modrinth** | [Download](https://modrinth.com/modpack/survival-not-guaranteed) | ⭐ Recommended - Auto-updates, easy management |
| **GitHub Latest** | [Download](https://github.com/Manifesto2147/Survival-Not-Guaranteed/releases/latest) | 📦 Direct `.mrpack` download |
| **All Versions** | [Browse](https://github.com/Manifesto2147/Survival-Not-Guaranteed/releases) | 📚 Full version history |

### 📱 **Installation Methods**

#### Option 1: Modrinth App (Recommended)
1. Open [Modrinth App](https://modrinth.com/app)
2. Search for "Survival Not Guaranteed"
3. Click "Install" and select the latest version

#### Option 2: Manual Import (.mrpack)
1. Download the latest `.mrpack` file from the links above
2. Open your launcher (Prism Launcher, MultiMC, etc.)
3. Import the downloaded `.mrpack` file
4. Launch and enjoy!

## 🔧 Configuration

- **`mod_overrides.conf`** - Manual download URLs for problematic mods
- **`config/`** - Mod configurations
- **`scripts/`** - Custom scripts
- **`shaderpacks/`** - Shader packs
- **`resourcepacks/`** - Resource packs

## 📊 Build System Features

- **Comprehensive mod lookup**: Modrinth hash → Modrinth search → CurseForge → Manual overrides
- **99% external downloads**: Only 1 mod out of 143 needs to be included in pack
- **Automatic mirror URLs**: No more "no mirrors" errors
- **Full launcher compatibility**: Works with PrismLauncher, MultiMC, and other launchers

## 🎯 Results

- **Total mods**: 143
- **External downloads**: 142 (99%)
- **Pack size**: ~750KB (vs ~400MB with included mods)
- **Build time**: ~30 seconds

## 💡 Maintenance

- **Adding mods**: Drop .jar files in `minecraft/mods/` and rebuild
- **Removing mods**: Delete .jar files and rebuild
- **Troubleshooting**: Use `./debug.sh` to test specific mod lookups
- **Manual overrides**: Add entries to `mod_overrides.conf`

## Automated Releases

This modpack uses an **enhanced multi-platform building system** with **GitHub Actions** for automated releases. The system:

- 🔍 **Smart Version Detection**: Cross-platform comparison with GitHub as source of truth
- 📦 **Mirror-Based Distribution**: Modrinth (primary) + CurseForge (fallback) + Local (guarantee)
- 🌐 **Multi-Platform Compatibility**: Works with all major launchers
- ✅ **Automated GitHub Releases** with downloadable `.mrpack` files
- ✅ **Automated Modrinth Uploads** with intelligent sync
- ✅ **Smart Version Bumping** based on change types (mods = minor, config = patch)
- ✅ **Historical Synchronization**: Missing versions auto-synced between platforms
- ✅ **Rich Release Notes** with change summaries and technical details
- 🛡️ **Zero Version Conflicts**: Robust fallback chain prevents duplicates
- 💾 **Optimized Pack Size**: 2-5MB downloads vs 400-500MB traditional packs (99% reduction)

## Enhanced System Features

### 🔧 **For Developers**
- **Single Command Build**: `./build.sh`
- **Comprehensive Testing**: `./test.sh`
- **Easy Setup**: `./setup.sh`
- **Full Documentation**: See `docs/implementation.md`

### 🎯 **For Users**
- **Lightning Fast Downloads**: 99% smaller pack files
- **Reliable Installation**: Multiple download mirrors
- **Automatic Updates**: Launcher-managed mod updates
- **Universal Compatibility**: Works with all major launchers

### 🔧 **Enhanced Mod Discovery**

The system now supports dual-platform mod lookup:

1. **🌐 Modrinth (Primary)**: SHA1 hash-based lookup for most mods
2. **🔥 CurseForge (Fallback)**: Fingerprint-based lookup for mods not on Modrinth
3. **📁 Local Include**: Only mods not found on either platform are included in the pack

This approach minimizes pack size while maximizing compatibility. See [CURSEFORGE_INTEGRATION.md](CURSEFORGE_INTEGRATION.md) for detailed setup instructions.

## Requirements

- Minecraft 1.20.1
- Forge 47.2.0+

## Contributing

Feel free to suggest improvements or report issues!
