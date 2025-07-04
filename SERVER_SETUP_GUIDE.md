# Server Setup Guide

## Community Server Integration

Your **Survival Not Guaranteed** modpack now includes automatic server integration! When players install the modpack, they'll automatically see your community server in their multiplayer server list.

### How It Works

The modpack includes a `servers.dat` file in the `overrides/` directory that contains:
- **Server Name**: Survival Not Guaranteed
- **Server IP**: survival-not-guaranteed.modrinth.gg
- **Server Icon**: Custom server icon (embedded in the data)

### For Players

When you install this modpack:

1. **Install the .mrpack** in your launcher (Modrinth, PrismLauncher, MultiMC, etc.)
2. **Launch Minecraft** with the modpack
3. **Go to Multiplayer** - you'll see "Survival Not Guaranteed" server already in your list
4. **Click and Connect** - no need to manually add the server!

### For Server Administrators

If you need to update the server information:

1. **Edit the server** in your Minecraft client's multiplayer server list
2. **Export the servers.dat** file from your `.minecraft/` directory
3. **Replace `minecraft/servers.dat`** in the modpack source
4. **Rebuild the .mrpack** using `./build.sh`

### Technical Details

- The `servers.dat` file is a binary NBT format used by Minecraft
- It's placed in `overrides/servers.dat` in the .mrpack so it gets copied to the root of the Minecraft instance
- The file contains server name, IP, icon, and other metadata
- Players can still add/remove/modify servers normally - this just provides a convenient starting point

### Current Server Info

- **Name**: Survival Not Guaranteed
- **IP**: survival-not-guaranteed.modrinth.gg
- **Status**: Active (as of build time)
- **Icon**: Custom server icon included

---

*This server integration was added to enhance the multiplayer experience and connect our community automatically!*
