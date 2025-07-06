# Troubleshooting Guide

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
