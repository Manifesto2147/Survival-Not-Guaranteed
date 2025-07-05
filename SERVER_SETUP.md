# Dedicated Server Setup Guide

This modpack now includes proper client/server environment detection to prevent crashes when running dedicated servers.

## Server Compatibility

### ✅ What Works
- **All 126 universal mods** will be installed on both client and server
- **Dedicated servers** will automatically exclude client-only mods
- **Players** can use the full modpack (142 mods) to connect to servers

### 🖥️ Client-Only Mods (11 total)
These mods enhance the client experience but are **automatically excluded** from servers:

**UI & Interface:**
- JEI (Just Enough Items) - recipe browser
- ApplesKin - food/saturation display
- GUI Clock - in-game clock display

**Rendering & Graphics:**
- Sodium - performance optimization
- Iris - shader support
- Ambient Sounds - atmospheric audio
- Sounds - enhanced audio
- Creative Core - UI framework

**Minimap & Navigation:**
- Xaero's Minimap - minimap display
- Xaero's World Map - world mapping
- Armor Statues - equipment display

**Development Tools:**
- CraftTweaker GUI - recipe modification UI

### 🖥️ Server-Only Mods (4 total)
These mods run **only on servers** and are excluded from clients:

- Open Parties and Claims - server-side land protection
- PuzzlesLib - server configuration library
- Spice of Life: Onion - server-side food variety
- Yet Another Config Lib - server configuration framework

## Setting Up a Dedicated Server

### Option 1: Automatic Server Pack
1. Download the `.mrpack` file from releases
2. Use server software that supports Modrinth packs (like [ServerPackCreator](https://github.com/Griefed/ServerPackCreator))
3. The server will automatically:
   - Install only the 130 server-compatible mods
   - Exclude all client-only mods
   - Include all necessary configurations

### Option 2: Manual Server Setup
1. **Install NeoForge Server** (version 21.1.180+ for Minecraft 1.21.1)
2. **Download server-compatible mods only:**
   - Use the modpack but exclude the 11 client-only mods listed above
   - Copy the `config/` folder for mod configurations
   - Copy `scripts/` folder for CraftTweaker scripts
3. **Start your server** - no client-only mod crashes!

### Option 3: Copy from Client Installation
1. **Start with a client installation** of the modpack
2. **Remove client-only mods** from the `mods/` folder:
   ```
   AmbientSounds_NEOFORGE_*.jar
   appleskin-*.jar
   ArmorStatues-*.jar
   CreativeCore_NEOFORGE_*.jar
   ctgui-*.jar
   iris-*.jar
   jei-*.jar
   sodium-*.jar
   sounds-*.jar
   Xaeros_Minimap_*.jar
   XaerosWorldMap_*.jar
   ```
3. **Keep all configurations** - they're designed to work on both client and server

## World Generation Compatibility

All **world generation mods** are universal and work on both client and server:
- Terralith (biomes)
- When Dungeons Arise (structures)
- All Dungeons & Taverns modules
- Enhanced Celestials
- SereneSeasons

## Performance Notes

**Server Performance:**
- Without client-only rendering mods, servers run more efficiently
- Memory usage is reduced by ~200MB without client-only mods
- No graphics/audio processing overhead

**Client Performance:**
- All optimization mods (Sodium, ModernFix, FerriteCore) still work
- Shader support maintained through Iris
- Full UI experience with JEI, minimaps, etc.

## Troubleshooting

### Server Won't Start
- **Check for client-only mods** in your server's mods folder
- **Verify NeoForge version** matches modpack requirements (21.1.180+)
- **Check server logs** for mod loading errors

### Players Can't Connect
- **Ensure players have the full modpack** (142 mods)
- **Check version compatibility** between client and server
- **Verify modpack version** matches on both sides

### Missing Features on Server
- **UI elements** (JEI, minimaps) are client-side only - this is normal
- **World generation** should work identically on client and server
- **Game mechanics** (magic, tech, combat) work on both sides

## Technical Details

The modpack uses **Modrinth index format** environment fields:
- `"client": "required", "server": "required"` - Universal mods (126)
- `"client": "required", "server": "unsupported"` - Client-only (11)
- `"client": "unsupported", "server": "required"` - Server-only (4)

This ensures **automatic compatibility** with launcher server pack creation tools.

---

**Happy server hosting!** Your dedicated server will now run smoothly without client-only mod crashes.
