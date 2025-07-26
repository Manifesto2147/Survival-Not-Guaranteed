# Troubleshooting Guide

## Issue: Cold Sweat Temperature Desync (Fixed in v3.12.12)

### Problem Description
Players experiencing issues where fire warmth and heat sources (campfires, furnaces, lava, etc.) stop registering during winter or cold weather periods, requiring a relog to restore functionality.

### Root Cause Analysis
This was a critical bug in Cold Sweat v2.4-b03c where temperature modifiers would desynchronize with Serene Seasons, particularly during seasonal transitions or when ambient temperature changed rapidly.

### Solution Applied
**Fixed in v3.12.12**: Updated Cold Sweat from v2.4-b03c to v2.4-b04a and NeoForge to 21.1.194

**Technical Details**:
- Updated `modrinth.index.json` with Cold Sweat v2.4-b04a URLs and hashes
- Updated NeoForge dependency from 21.1.180 to 21.1.194 (latest stable)
- Replaced physical mod file in `mods/` directory
- Enhanced `config/coldsweat/main.toml` with sync reliability documentation
- Full modpack rebuild and verification with all 140 mods

### Verification Steps
```bash
# Verify Cold Sweat version
jq '.files[] | select(.path | contains("ColdSweat"))' modrinth.index.json

# Check physical mod file
ls -la mods/ColdSweat-*.jar
file mods/ColdSweat-2.4-b04a.jar

# Verify config version
grep "Version" config/coldsweat/main.toml
```

### Player Impact
- **Before Fix**: Players had to relog during winter to restore fire warmth
- **After Fix**: Temperature sync remains stable throughout seasonal changes
- **Gameplay**: Significantly improved survival experience during cold weather

---

## Issue: `options.txt` and `servers.dat` not being recognized by Modrinth launcher

### Problem Description
When importing the `.mrpack` file into Modrinth launcher, the `options.txt` and `servers.dat` files are present in the archive but are not being applied to the Minecraft instance.

### Investigation Results

✅ **Files are present in `.mrpack`**: Both files are correctly placed in `overrides/` directory
✅ **File formats are correct**: `options.txt` is ASCII text, `servers.dat` is NBT format
✅ **Archive structure is correct**: Follows Modrinth format specification
✅ **Build process is working**: Files are being copied correctly during build

### Current Status
The `.mrpack` file is properly structured and contains the required files in the correct locations. The issue appears to be with the Modrinth launcher not applying these files during the import process.

### Debugging Steps

1. **Verify .mrpack contents**:
   ```bash
   unzip -l "Survival Not Guaranteed-3.12.1.mrpack" | grep -E "(options\.txt|servers\.dat)"
   ```

2. **Extract and inspect**:
   ```bash
   mkdir test_extract && cd test_extract
   unzip "../Survival Not Guaranteed-3.12.1.mrpack"
   ls -la overrides/
   ```

3. **Check file contents**:
   ```bash
   head -10 overrides/options.txt
   file overrides/servers.dat
   ```

### Possible Causes

1. **Modrinth App Bug**: The launcher might have a bug in the override processing
2. **Import Order**: Files might not be copied at the right time during import
3. **Minecraft Version Compatibility**: Settings in `options.txt` might not be compatible with the current Minecraft version
4. **Permissions**: Files might not have correct permissions after extraction

### Recommended Actions

1. **Test with minimal .mrpack**: Use `./tools/create_test_pack.sh` to create a minimal test pack with just the essential files
2. **Test with different launcher**: Try importing the `.mrpack` in a different launcher (like PrismLauncher) to confirm the issue is specific to Modrinth
3. **Check Modrinth App logs**: Look for any error messages during import
4. **Check launcher version**: Ensure you're using the latest version of the Modrinth App
5. **Verify file permissions**: After import, check if the files exist in the Minecraft instance directory
6. **Test with fresh instance**: Create a new Minecraft instance to rule out conflicts with existing settings
7. **Report to Modrinth**: If the issue persists, report it to Modrinth support with the `.mrpack` file

### File Structure Verification
```
.mrpack
├── modrinth.index.json
└── overrides/
    ├── options.txt          ✅ Present
    ├── servers.dat          ✅ Present
    ├── config/              ✅ Present
    ├── scripts/             ✅ Present
    └── shaderpacks/         ✅ Present
```

All files are correctly placed according to the Modrinth format specification.

### Build Script Verification

The latest build script now includes verification steps that confirm both files are present:
- ✅ options.txt found in overrides/
- ✅ servers.dat found in overrides/

### Additional Diagnostic Tools

1. **Create minimal test pack**: `./tools/create_test_pack.sh` - creates a minimal .mrpack with just the essential files
2. **Manual verification**: `unzip -l "pack.mrpack" | grep -E "(options|servers)"` - verify files are in the archive
3. **Extract and inspect**: Create a test directory, extract the .mrpack, and manually verify file contents

### Known Working Solutions

The `.mrpack` file structure is confirmed to be correct according to the Modrinth specification. The issue appears to be with the launcher's import process, not the pack structure itself.

## New Workflow Issues (v3.12.5+)

### Issue: CI fails with "No .mrpack file found"

**Problem**: The streamlined CI workflow expects pre-built `.mrpack` files but can't find them.

**Cause**: `.mrpack` files weren't committed to the repository or `.gitignore` is still excluding them.

**Solution**:
1. Build locally: `./build.sh`
2. Commit the generated `.mrpack`: `git add *.mrpack && git commit -m "Add built modpack"`
3. Verify `.gitignore` doesn't exclude `*.mrpack` files

### Issue: CI version bump not working correctly

**Problem**: CI creates releases with incorrect version numbers.

**Debugging**:
1. Check the last release tag: `git describe --tags --abbrev=0`
2. Verify manifest version: `jq -r '.versionId' modrinth.index.json`
3. Look at changed files: `git diff --name-only HEAD~1 HEAD`

**Common fixes**:
- Ensure `modrinth.index.json` contains a valid version
- Check that git tags follow `v1.2.3` format
- Verify file changes trigger appropriate version bump logic

### Issue: Dependencies missing in released modpack

**Problem**: Mods like uranus or jupiter are missing from the final release.

**Root Cause**: This was the main issue with the old CI approach. The new workflow eliminates this.

**Solution with new workflow**:
1. **Build locally** where all dependencies are available
2. Test the generated `.mrpack` locally to ensure dependencies work
3. Commit the working `.mrpack` file
4. CI will validate and distribute the exact same file you tested

### Issue: Local build vs CI build differences

**Problem**: Local builds work but CI releases don't.

**New workflow advantage**: This issue is eliminated because CI no longer rebuilds - it validates and distributes your local build.

**If still experiencing issues**:
1. Verify you're committing the `.mrpack` file: `git ls-files | grep mrpack`
2. Check the workflow uses validation mode: Look for "Validating pre-built modpack" in CI logs
3. Ensure no legacy CI build steps are running

## Legacy Workflow Issues (Deprecated v3.12.4 and earlier)

### Issue: Missing mod dependencies in CI builds

**Problem**: CI-generated modpacks missing critical dependencies like uranus/jupiter for Ice and Fire CE.

**Legacy cause**: CI downloaded mods from manifest, but some dependencies weren't in the manifest.

**Resolution**: **Upgrade to v3.12.5+ streamlined workflow** - this issue is completely eliminated.

### Issue: CI mod download failures

**Problem**: CI fails when downloading mods from external URLs.

**Legacy causes**:
- Network timeouts or rate limiting
- Changed download URLs
- Unavailable mod files

**Resolution**: **Upgrade to v3.12.5+ streamlined workflow** - no more mod downloads in CI.
