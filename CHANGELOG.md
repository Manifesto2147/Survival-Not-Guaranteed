Survival Not Guaranteed v3.12.1

Release Date: July 06, 2025
Previous Version: 3.12.0

MAJOR CHANGES

- **Epic Knights Environment Fix**: Changed Epic Knights mod from client-only to universal (client + server) environment
- **RAM Allocation Enhancement**: Implemented cross-launcher 4GB RAM allocation using standards-compliant configuration files
- **Launcher Compatibility**: Added support for multiple launcher profiles (Modrinth, PrismLauncher, MultiMC)
- **Server Compatibility**: Fixed Epic Knights availability on dedicated servers

TECHNICAL IMPROVEMENTS

- **Build System**: Enhanced environment override system for problematic mods
- **Mod Override System**: Added manual download overrides for Epic Knights reliability
- **Launcher Profiles**: Added `modrinth.launcher.json` and `launcher_profiles.json` for automatic RAM configuration
- **Instance Configuration**: Added `instance.cfg` for PrismLauncher/MultiMC compatibility
- **Memory Optimization**: Implemented optimized JVM arguments (Aikar's flags) for better performance

BUG FIXES

- Fixed Epic Knights mod not being available on servers due to incorrect environment setting
- Resolved broken recipes and missing items from environment mismatches
- Fixed RAM allocation not carrying over in launcher profiles

OTHER CHANGES

- Updated modpack components
- General improvements and optimizations
- Enhanced cross-launcher compatibility

TECHNICAL DETAILS

- Total Mods: 131
- Universal Mods (Client + Server): 121
- Client-Only Mods: 10
- Server-Only Mods: 0
- Minecraft Version: 1.21.1
- NeoForge Version: 21.1.180
- External Downloads: 131 of 131 (100%)
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

