Survival Not Guaranteed v3.9.0

Release Date: July 04, 2025
Previous Version: 3.9.0

MAJOR IMPROVEMENTS

- **Enhanced Mod Environment Detection System**: Implemented intelligent detection for client-only, server-only, and universal mods
- **Improved Stability**: Better client-server compatibility through proper mod environment classification
- **Fixed Critical Dependencies**: Resolved missing bookshelf library and Cold Sweat mod configuration issues
- **Automated Build Process**: Enhanced build.sh with sophisticated environment detection and manual override capabilities

TECHNICAL IMPROVEMENTS

- **Smart Environment Detection**: Automatically categorizes mods based on their intended environment (client/server/both)
- **Manual Override System**: Added capability to override automatic detection for special cases (essential libraries, etc.)
- **Dependency Resolution**: Fixed missing dependencies that were causing launch failures
- **Download URL Validation**: Ensured all mods have valid download URLs and proper metadata
- **Build Script Enhancements**: Improved error handling and mod classification logic

BUG FIXES

- Fixed bookshelf library being incorrectly classified as client-unsupported
- Restored Cold Sweat mod download URL that was missing due to manual override
- Resolved environment detection issues that could cause client-server connection problems
- Fixed YDM's Weapon Master compatibility (verified working as client-only)

TECHNICAL DETAILS

- Total Mods: 142
- Universal Mods (Client + Server): 118
- Client-Only Mods: 13
- Server-Only Mods: 11
- Minecraft Version: 1.21.1
- NeoForge Version: 21.1.180
- External Downloads: 142 of 142 (100%)
- Pack Size: Optimized with external downloads
- Server Compatibility: Dedicated servers will automatically exclude client-only mods

INSTALLATION

Recommended: Modrinth App (Optimized)
1. Download the .mrpack file from this release
2. In Modrinth App: File → Add Instance → From File
3. Select the downloaded .mrpack file
4. Modrinth App will automatically configure optimal settings

Alternative Launchers:
- PrismLauncher: Add Instance → Import → Modrinth Pack
- MultiMC: Add Instance → Import → Browse for .mrpack

SYSTEM REQUIREMENTS

- Minimum RAM: 2GB allocated (4GB recommended for optimal performance)
- With Shaders: 4GB+ recommended for smooth shader performance
- Java Version: Java 21+ required
- Client/Server: Compatible with both single-player and multiplayer
- Modrinth App: Automatic memory allocation based on system specs

FEATURES

- Pre-configured Shaders: MakeUp-UltraFast enabled by default
- Optimized Settings: 3x GUI scale and performance tweaks
- Community Servers: Pre-loaded server list
- External Downloads: 100% mod downloads, minimal pack size

