# Survival Not Guaranteed - Complete System Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Branch Architecture](#branch-architecture)
3. [Core Components](#core-components)
4. [Automation System](#automation-system)
5. [Management Tools](#management-tools)
6. [Build System](#build-system)
7. [Version Management](#version-management)
8. [Deployment Pipeline](#deployment-pipeline)
9. [File Structure](#file-structure)
10. [Configuration Management](#configuration-management)
11. [Troubleshooting and Maintenance](#troubleshooting-and-maintenance)

## System Overview

Survival Not Guaranteed is a Minecraft modpack built on NeoForge 1.21.1 featuring 131 carefully curated mods. The project employs a sophisticated automated management system designed for zero-intervention operations, comprehensive dependency management, and reliable deployment.

### Key Characteristics
- **Target Audience**: Players seeking challenging survival gameplay with fantasy RPG elements
- **Mod Count**: 131 mods (121 universal, 10 client-only)
- **Distribution**: .mrpack format with 100% external downloads
- **Architecture**: Multi-platform with automated CI/CD pipeline
- **Management**: Fully automated mod updates and dependency resolution
- **Repository Strategy**: Lightweight repository with no binary mod files tracked

### Recent Infrastructure Improvements (v3.12.1)
- **Launcher Configuration**: Added cross-launcher RAM allocation and JVM optimization
- **Epic Knights Environment Fix**: Resolved server compatibility issues with environment overrides
- **Memory Management**: Implemented standards-compliant 4GB RAM allocation
- **Profile Support**: Added support for Modrinth App, PrismLauncher, and MultiMC profiles
- **JVM Optimization**: Integrated Aikar's flags for improved performance

### Recent Infrastructure Improvements (v3.12.0+)
- **Git Optimization**: Removed mod files from repository tracking (131 files excluded)
- **CI/CD Enhancement**: Implemented manifest-based CI builds with temporary mod download
- **Build System**: Dual-mode operation for local development and CI automation
- **Workflow Optimization**: Automated mod acquisition from manifest URLs in CI
- **Documentation**: Updated to reflect manifest-driven development workflow
- **Legal Compliance**: Enhanced mod licensing compliance with official-source-only downloads
- **Build Verification**: Added automatic verification of critical files in .mrpack
- **Troubleshooting**: Enhanced diagnostics and troubleshooting tools
- **Client Configuration**: Improved handling of options.txt and servers.dat files
- **Maintainability**: Enhanced troubleshooting and maintenance procedures

## Branch Architecture

The repository follows a structured branching model designed for stability and continuous development:

### Main Branch
- **Purpose**: Production-ready releases
- **Trigger**: Manual merges from develop branch after thorough testing
- **Automation**: Triggers GitHub Actions for release creation and deployment
- **Stability**: Highest - only stable, tested code
- **Access**: Public releases are built from this branch

### Develop Branch  
- **Purpose**: Active development and testing
- **Trigger**: Direct pushes for feature development and bug fixes
- **Automation**: Triggers development builds and validation
- **Stability**: Moderate - features may be experimental
- **Access**: Internal testing and validation

### Branch Synchronization
Both branches maintain identical core functionality but may differ in:
- Version numbers (develop may have pre-release versions)
- Experimental features (develop-only until proven stable)
- Configuration tweaks (tested in develop before main)

## Core Components

### 1. Modpack Definition ([modrinth.index.json](../modrinth.index.json))
The central manifest file defining the complete modpack structure:

```json
{
  "formatVersion": 1,
  "game": "minecraft",
  "versionId": "3.12.1",
  "name": "Survival Not Guaranteed",
  "files": [...]
}
```

**Key Features:**
- External download URLs for all mods (100% external)
- Environment specifications (client/server compatibility)
- File integrity verification (SHA1/SHA512 hashes)
- Version tracking and dependency mapping

### 2. Build System ([build.sh](../build.sh))
A comprehensive 1600+ line build script that handles:

**Core Functions:**
- Automatic mod discovery and URL resolution
- Modrinth/CurseForge API integration
- Environment detection (client-only, server-only, universal)
- Version management and smart updates
- .mrpack generation with external downloads

**API Integration:**
- **Modrinth API**: Primary source for mod metadata and downloads
- **CurseForge API**: Fallback for mods not available on Modrinth
- **GitHub API**: Version checking and release management
- **Manual Overrides**: Hardcoded URLs for problematic mods

**Environment Detection Logic:**
```bash
# Automatic detection with manual overrides
get_manual_environment_override() {
    local filename="$1"
    local mod_name=$(basename "$filename" .jar | tr '[:upper:]' '[:lower:]')
    
    # Xaero's mods - work on both client and server
    if [[ "$mod_name" == *"xaeros_minimap"* ]] || [[ "$mod_name" == *"xaero"* && "$mod_name" == *"minimap"* ]]; then
        echo "both"
        return
    fi
    # Additional overrides...
}
```

### 3. Management Tools

#### [manage-modpack.sh](../manage-modpack.sh)
Unified interface for all modpack operations:
- **validate**: Directory structure and configuration validation
- **update**: Mod updates from modrinth.index.json
- **fix-data**: Data validation error correction
- **check-deps**: Dependency validation
- **full-check**: Comprehensive system validation

#### [fix-data-validation-errors.sh](../fix-data-validation-errors.sh)
Automated data integrity maintenance:
- Recipe file validation and repair
- Loot table verification
- Tag system validation
- Dependency conflict resolution

#### [validate-directory-structure.sh](../validate-directory-structure.sh)
PrismLauncher compatibility validator:
- Directory structure verification
- Path reference validation in scripts
- Configuration file integrity checking
- Manifest path validation

### 4. Update System ([tools/update-mods.sh](../tools/update-mods.sh))
Advanced automatic update system with:

**Features:**
- Zero-intervention automated updates
- Dependency constraint solving
- Backup and rollback capabilities
- File integrity verification
- Environment override support

**Safety Mechanisms:**
- Pre-update backups with metadata
- Validation before and after updates
- Automatic rollback on failure
- Conservative update policies for critical mods

## Automation System

### GitHub Actions Workflow

#### Streamlined Release Pipeline ([.github/workflows/release.yml](../.github/workflows/release.yml))
**New Architecture (v3.12.5+)**: Validation-based CI instead of rebuilding

**Workflow Philosophy:**
- **Local Build Authority**: Developers build locally with full mod access (including dependencies like uranus/jupiter)
- **CI Validation**: GitHub Actions validates existing artifacts and handles distribution
- **Smart Versioning**: Automatic version detection based on file changes
- **Fast Deployment**: ~2 minutes instead of 5-10 minutes

**Workflow Steps:**

1. **Pre-built Artifact Validation**
   - Validates existing `.mrpack` file in repository
   - Confirms `modrinth.index.json` manifest exists
   - Extracts current version from manifest

2. **Smart Version Detection**
   - Analyzes changed files since last release tag
   - Determines appropriate version bump type:
     - **PATCH**: Configuration changes (`config/`, `scripts/`, `shaderpacks/`)
     - **MINOR**: Mod count changes (detected in `modrinth.index.json`)
     - **MAJOR**: Breaking changes (manual specification)

3. **Version Update & Artifact Preparation**
   - Updates `modrinth.index.json` with new version
   - Renames `.mrpack` file to match new version
   - Prepares artifacts for distribution

4. **Release Creation & Distribution**
   - Creates GitHub release with version-appropriate changelog
   - Uploads `.mrpack` to GitHub release assets
   - Distributes to Modrinth platform
   - Commits version updates back to repository

**Trigger Conditions:**
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'config/**'          # Mod configurations (PATCH)
      - 'scripts/**'         # CraftTweaker scripts (PATCH)
      - 'shaderpacks/**'     # Shader packs (PATCH)
      - 'modrinth.index.json' # Mod manifest (MINOR for mod changes)
      - 'mod_overrides.conf' # URL overrides (PATCH)
      - 'options.txt'        # Client settings (PATCH)
      - 'servers.dat'        # Server list (PATCH)
  workflow_dispatch:        # Manual trigger
```

**Key Benefits:**
- ✅ **Eliminates dependency download issues** (uranus, jupiter, etc.)
- ✅ **Much faster CI execution** (2 minutes vs 5-10 minutes)
- ✅ **Local builds are authoritative** - what you test locally is what gets released
- ✅ **No mod download failures** in CI environment
- ✅ **Simplified workflow** - focus on validation rather than recreation

**Developer Workflow:**
1. **Build Locally**: Run `./build.sh` to generate `.mrpack` and update manifest
2. **Test Locally**: Verify modpack works with all dependencies
3. **Commit & Push**: Include both `.mrpack` file and `modrinth.index.json` 
4. **Automatic Release**: CI validates, versions, and distributes

#### Legacy Build-in-CI Approach (Deprecated)
Previously, the CI would download mods from the manifest and rebuild the modpack, but this caused issues with:
- Missing dependencies not in the manifest (uranus, jupiter for Ice and Fire CE)
- Unreliable mod downloads from external sources
- Complex dependency resolution in CI environment
- Longer build times and potential network failures

#### Development Pipeline ([.github/workflows/develop.yml](../.github/workflows/develop.yml))
Triggered on develop branch changes:

1. **Validation Testing**: Runs all validation scripts
2. **Build Testing**: Ensures [build.sh](../build.sh) executes successfully
3. **Compatibility Testing**: Validates mod compatibility
4. **Integration Testing**: Tests management tools

### Environment Variables and Secrets
- **MODRINTH_TOKEN**: API access for mod data and uploads
- **CURSEFORGE_API_KEY**: Fallback mod source access
- **GITHUB_TOKEN**: Repository access for releases
- **PROJECT_ID**: Modrinth project identifier

## Management Tools

### Command Reference

```bash
# Unified Management
[../manage-modpack.sh](../manage-modpack.sh) validate        # Validate all systems
[../manage-modpack.sh](../manage-modpack.sh) update          # Update mods
[../manage-modpack.sh](../manage-modpack.sh) fix-data        # Fix data errors
[../manage-modpack.sh](../manage-modpack.sh) check-deps      # Validate dependencies
[../manage-modpack.sh](../manage-modpack.sh) full-check      # Run all checks

# Direct Tools
[../build.sh](../build.sh)                          # Build .mrpack
[../tools/update-mods.sh](../tools/update-mods.sh)         # Update mods with constraints
[../validate-directory-structure.sh](../validate-directory-structure.sh)   # Validate directory structure
[../fix-data-validation-errors.sh](../fix-data-validation-errors.sh)     # Fix data validation issues

# Update System Options
[../tools/update-mods.sh](../tools/update-mods.sh) --dry-run     # Preview updates
[../tools/update-mods.sh](../tools/update-mods.sh) --validate    # Validate files only
[../tools/update-mods.sh](../tools/update-mods.sh) --rollback    # Rollback last update
[../tools/update-mods.sh](../tools/update-mods.sh) --force       # Force risky updates
```

### Safety Features

**Backup System:**
- Automatic backups before any modification
- Timestamped backup directories
- Metadata tracking for backup identification
- Easy rollback capabilities

**Validation System:**
- Pre-operation validation
- Post-operation verification
- File integrity checking
- Dependency constraint validation

**Error Recovery:**
- Automatic rollback on validation failure
- Detailed error logging
- Recovery suggestions
- Safe failure modes

## Build System

## Build System

### New Streamlined Architecture (v3.12.5+)

The build system has been redesigned for maximum efficiency and reliability:

#### **Local Development (Primary Build Environment)**
**Purpose**: Authoritative modpack builds with full dependency access

1. **Environment Setup**
   - Full mod collection available in `mods/` directory
   - All dependencies including uranus, jupiter for Ice and Fire CE
   - Complete configuration and resource files

2. **Build Process** (`./build.sh`)
   - Scan existing mod JARs for metadata extraction
   - Query Modrinth/CurseForge APIs for official download URLs
   - Apply manual overrides from `mod_overrides.conf`
   - Detect environment compatibility (client/server/both)
   - Generate `modrinth.index.json` manifest with external URLs
   - Create `.mrpack` file with configurations only (no mod JARs)

3. **Quality Assurance**
   - Test generated `.mrpack` in local launcher
   - Verify all dependencies are properly included
   - Validate server compatibility if needed

4. **Commit Artifacts**
   - Commit updated `modrinth.index.json` manifest
   - Commit generated `.mrpack` file (now tracked in Git)
   - Commit any configuration changes

#### **CI/CD Pipeline (Validation & Distribution)**
**Purpose**: Validate existing artifacts and handle automated distribution

1. **Artifact Validation**
   - Verify `.mrpack` file exists in repository
   - Confirm `modrinth.index.json` manifest is present
   - Extract current version information

2. **Smart Version Management**
   - Analyze changed files since last release
   - Auto-determine version bump type (PATCH/MINOR/MAJOR)
   - Update manifest version and rename `.mrpack` accordingly

3. **Distribution**
   - Create GitHub release with updated artifacts
   - Upload to Modrinth platform
   - Commit version updates back to repository

#### **Key Architectural Benefits**

✅ **Eliminates Dependency Issues**: No more missing uranus/jupiter problems  
✅ **Faster CI**: 2-minute validation vs 5-10 minute rebuilds  
✅ **Local Authority**: What you build locally is exactly what gets released  
✅ **Network Reliability**: No mod downloads in CI that can fail  
✅ **Developer Experience**: Build and test locally with full mod access  

### Git Tracking Changes

#### **Now Tracked in Git:**
- `.mrpack` files (small, contains only configs/scripts/resources)
- `modrinth.index.json` manifest
- Configuration files, scripts, shaderpacks

#### **Still Excluded from Git:**
- `mods/` directory with JAR files (too large, licensing)
- Cache and temporary files
- Build artifacts except final `.mrpack`

### Developer Workflow

```bash
# 1. Local Development
./build.sh                    # Build locally with full mod access
# Test the generated .mrpack in your launcher

# 2. Commit Changes  
git add modrinth.index.json *.mrpack config/ scripts/
git commit -m "Add new mod: Example Mod v1.2.3"

# 3. Push and Automate
git push origin main          # Triggers CI validation and release
```

### Backward Compatibility

The build script still supports both modes:
- **Local Mode**: Full featured building with mod JARs present
- **CI Mode**: Can download mods from manifest if needed (legacy fallback)

The CI workflow prioritizes validation over rebuilding, but maintains capability for full builds if required.

### Legacy CI Build Mode (Deprecated)

Previously the CI would:
1. Download all mods from manifest URLs  
2. Rebuild the entire modpack from scratch
3. Generate new manifest and `.mrpack`

**Issues with Legacy Approach:**
- Missing dependencies not in manifest (uranus, jupiter)
- Network reliability issues with mod downloads
- Longer build times and complex dependency resolution
- CI environment differences from local development
   - Generate .mrpack file with overrides only
   - Exclude mod files (100% external downloads)
   - Include configuration and resource files
   - Validate final package

### Override Systems

#### URL Overrides ([mod_overrides.conf](../mod_overrides.conf))
For mods requiring specific download URLs:
```
filename.jar=https://specific-download-url.com/file.jar
```

#### Environment Overrides ([build.sh](../build.sh))
Hardcoded overrides for environment detection:
```bash
# Xaero's mods - work on both client and server
if [[ "$mod_name" == *"xaeros_minimap"* ]]; then
    echo "both"
    return
fi
```

#### Manual Overrides (get_manual_override function)
For mods requiring specific handling:
```bash
case "$filename" in
    "specific-mod.jar")
        echo "https://custom-url.com/download.jar"
        return 0
        ;;
esac
```

## Recommended Development Workflow

### Local Development Process
1. **Mod Testing**: Add/remove/update mod JARs in local `mods/` directory
2. **Configuration**: Modify configs, scripts, shaders as needed
3. **Local Build**: Run `./build.sh` to generate updated manifest and test .mrpack
4. **Testing**: Import generated .mrpack into launcher to verify functionality
5. **Commit Changes**: Commit updated `modrinth.index.json` and any config changes
6. **Push**: Push to repository to trigger automated CI build and release

### CI Automation Flow
1. **Trigger**: Push to main branch or manual workflow dispatch
2. **Download**: CI downloads mod JARs from committed manifest URLs
3. **Build**: Runs full build process with temporary mod files
4. **Release**: Creates GitHub release and uploads to distribution platforms
5. **Cleanup**: Removes temporary mod files, leaving only artifacts

### Key Benefits
- **Local Testing**: Full mod testing capability during development
- **Repository Efficiency**: No large binary files tracked in Git
- **Legal Compliance**: Mods downloaded from official sources only
- **Automation**: Zero-intervention CI builds from committed manifests
- **Reproducibility**: Exact mod versions specified in manifest

## Deployment Pipeline

### Version Management
- **Semantic Versioning**: MAJOR.MINOR.PATCH format focused on modpack content
- **Content-Driven**: Version increments only for changes affecting the modpack itself
- **Smart Detection**: Distinguishes between mod content and configuration changes
- **Cross-platform**: Consistent versioning across branches

### Release Process
1. **Development**: Changes committed to develop branch
2. **Validation**: Automated testing and validation
3. **Merge**: Manual merge to main branch after approval
4. **Build**: Automated build process triggered
5. **Release**: GitHub release created with .mrpack artifact
6. **Distribution**: Uploaded to Modrinth and other platforms

### Quality Assurance
- **Pre-release Testing**: All tools validated before merge
- **Dependency Checking**: Automated dependency validation
- **Compatibility Testing**: Client/server compatibility verification
- **Performance Testing**: Load testing with full mod set

## File Structure

```
Survival Not Guaranteed/
├── .github/
│   └── workflows/           # GitHub Actions CI/CD
├── docs/                    # Documentation
│   ├── SYSTEM_DOCUMENTATION.md
│   └── TROUBLESHOOTING.md
├── config/                  # PrismLauncher instance config
├── mods/                    # Mod JAR files (excluded from Git)
├── scripts/                 # CraftTweaker scripts
├── shaderpacks/             # Shader files
├── tools/
│   ├── core/
│   │   ├── [update-mods.sh](../tools/update-mods.sh)  # Advanced update system
│   │   └── [validate-dependencies.sh](../tools/validate-dependencies.sh)
│   └── [create_test_pack.sh](../tools/create_test_pack.sh)  # Diagnostic tool
├── [build.sh](../build.sh)                # Main build script
├── [manage-modpack.sh](../manage-modpack.sh)       # Unified management interface
├── [fix-data-validation-errors.sh](../fix-data-validation-errors.sh)
├── [validate-directory-structure.sh](../validate-directory-structure.sh)
├── modrinth.index.json     # Modpack manifest
├── mod_overrides.conf      # URL overrides
├── options.txt             # Minecraft client settings (GUI scale, performance)
├── servers.dat             # Pre-configured community servers
├── README.md               # User documentation
└── CHANGELOG.md            # Version history
```

### Directory Purposes

**/.github/workflows/**: Automation and CI/CD pipeline definitions
**/docs/**: Comprehensive system documentation and troubleshooting guides
**/config/**: PrismLauncher-specific configuration files
**/mods/**: Mod JAR files (excluded from Git tracking, populated by build system)
**/scripts/**: CraftTweaker scripts
**/shaderpacks/**: Shader files
**/tools/**: Advanced management utilities and diagnostic tools
**Root Level**: Primary scripts and configuration files

### Git Tracking Strategy

The repository follows a hybrid approach:
- **Configuration files**: Tracked in Git for version control (config/, scripts/, shaderpacks/)
- **Client settings**: Tracked in Git (options.txt, servers.dat) for consistent user experience
- **Mod files**: Excluded from Git but monitored by build system
- **Scripts and overrides**: Fully tracked for reproducibility
- **Generated files**: Excluded (.mrpack, .content_hash, build artifacts)

This approach ensures:
- Repository remains lightweight (no large binary files)
- Full reproducibility through external download URLs
- Consistent client settings and server listings for all users
- Efficient CI/CD with minimal transfer overhead
- Complete audit trail of configuration changes

## Configuration Management

### Environment Configuration
Mods are classified into three categories:

1. **Universal (both)**: Required on both client and server
2. **Client-only**: User interface, visual enhancements, client-side optimizations
3. **Server-only**: Server management, administrative tools

### Override Priority
1. **Manual Environment Overrides** ([build.sh](../build.sh) function)
2. **API Detection** (Modrinth/CurseForge metadata)
3. **Filename Pattern Matching** (fallback classification)
4. **Default Classification** (conservative approach)

### Configuration Files
- **[modrinth.index.json](../modrinth.index.json)**: Primary modpack manifest
- **[mod_overrides.conf](../mod_overrides.conf)**: URL override configuration
- **[config/](../config/)**: Individual mod configurations
- **[scripts/](../scripts/)**: CraftTweaker script configurations

## Troubleshooting and Maintenance

### Common Issues and Solutions

#### Build Failures
**Symptom**: [build.sh](../build.sh) fails with mod lookup errors
**Solution**: 
1. Check network connectivity
2. Verify API keys are valid
3. Add manual overrides for problematic mods
4. Check mod availability on Modrinth/CurseForge

#### Update Failures
**Symptom**: [update-mods.sh](../tools/update-mods.sh) fails during mod updates
**Solution**:
1. Run `../tools/update-mods.sh --rollback`
2. Check dependency constraints
3. Use `--force` flag for critical updates
4. Manually resolve conflicts in [mod_overrides.conf](../mod_overrides.conf)

#### Validation Errors
**Symptom**: Scripts report directory structure issues
**Solution**:
1. Run `../validate-directory-structure.sh`
2. Ensure PrismLauncher directory structure is intact
3. Verify all scripts reference correct paths
4. Check file permissions on scripts

#### Dependency Conflicts
**Symptom**: Mods fail to load due to missing dependencies
**Solution**:
1. Run `[../manage-modpack.sh](../manage-modpack.sh) check-deps`
2. Update [modrinth.index.json](../modrinth.index.json) with missing dependencies
3. Verify mod versions are compatible
4. Check for functional equivalents (e.g., ColdSweat for ToughAsNails)

#### Git Tracking Issues
**Symptom**: Mods directory appears in Git status or repository size is too large
**Solution**:
1. Verify `.gitignore` includes `mods/` entry
2. Remove mods from tracking: `git rm -r --cached mods/`
3. Check ignored files: `git status --ignored`
4. Ensure `mods/` appears in ignored files list

#### GitHub Actions Not Triggering
**Symptom**: Workflows don't run when mods are changed
**Solution**:
1. Check workflow paths in `.github/workflows/`
2. Ensure paths match actual directory structure
3. Verify `mods/**` is included in workflow triggers
4. Check if workflow files have correct permissions

#### Version Detection Issues
**Symptom**: Build system assigns incorrect version numbers
**Solution**:
1. Check if manual version is set in `modrinth.index.json`
2. Verify content hash file `.content_hash` exists
3. Review change detection logic for edge cases
4. Use manual version override if automatic detection fails

#### Infrastructure vs Content Changes
**Symptom**: Infrastructure changes trigger minor version bumps
**Solution**:
1. Distinguish between actual mod changes and Git/CI changes
2. Use manual version control for infrastructure fixes
3. Update content hash to reflect actual state
4. Document infrastructure changes separately from content changes

#### Launcher Compatibility Issues
**Symptom**: options.txt or servers.dat not recognized by Modrinth launcher
**Solution**:
1. Verify files are present in .mrpack: `unzip -l "pack.mrpack" | grep -E "(options|servers)"`
2. Check `docs/TROUBLESHOOTING.md` for detailed diagnostic steps
3. Use `./tools/create_test_pack.sh` to create minimal test pack
4. Test with alternative launcher (PrismLauncher) to isolate the issue
5. Verify launcher version is up-to-date
6. Check if files exist in Minecraft instance directory after import
7. Report to launcher maintainers if issue persists

### Maintenance Tasks

#### Regular Maintenance (Weekly)
```bash
[../manage-modpack.sh](../manage-modpack.sh) full-check      # Complete system validation
[../tools/update-mods.sh](../tools/update-mods.sh) --dry-run  # Check for available updates
```

#### Monthly Maintenance
```bash
# Update to latest mod versions
[../tools/update-mods.sh](../tools/update-mods.sh)

# Rebuild package with latest URLs
[../build.sh](../build.sh)

# Validate all systems
[../manage-modpack.sh](../manage-modpack.sh) validate
```

#### Emergency Recovery
```bash
# Rollback last update
[../tools/update-mods.sh](../tools/update-mods.sh) --rollback

# Restore from backup (manual)
cp backup/auto-updates/TIMESTAMP/modrinth.index.json ../

# Force rebuild
[../build.sh](../build.sh) --force-external
```

#### Build Verification Testing
```bash
# Test build with verification
[../build.sh](../build.sh)    # Includes automatic verification

# Create diagnostic test pack
[../tools/create_test_pack.sh](../tools/create_test_pack.sh)

# Manual verification of .mrpack contents
unzip -l "Survival Not Guaranteed-X.X.X.mrpack" | grep -E "(options|servers)"
```

### Monitoring and Logging

#### Log Files
- **auto-update.log**: Update system activity log
- **fix-validation-errors.log**: Data validation repair log
- **build.log**: Build process detailed log (if enabled)

#### Validation Reports
- **directory_structure_report.txt**: Structure validation results
- **dependency_analysis.json**: Dependency relationship mapping

### Development Guidelines

#### Adding New Mods
1. Add mod JAR to `../minecraft/mods/`
2. Run `[../build.sh](../build.sh)` to auto-detect and add to manifest
3. Test with `[../manage-modpack.sh](../manage-modpack.sh) validate`
4. Commit changes to develop branch

#### Modifying Environment Classification
1. Edit `get_manual_environment_override()` in [build.sh](../build.sh)
2. Rebuild manifest with `[../build.sh](../build.sh)`
3. Validate changes with management tools
4. Test on both client and server

#### Creating New Management Tools
1. Follow established patterns (logging, error handling, validation)
2. Add to unified management interface ([manage-modpack.sh](../manage-modpack.sh))
3. Include comprehensive help documentation
4. Test on both main and develop branches

### Diagnostic Tools

#### Build Verification
The build system now includes automatic verification of critical files:
- **options.txt verification**: Confirms client settings are included in .mrpack
- **servers.dat verification**: Confirms server list is included in .mrpack  
- **Override structure validation**: Ensures proper directory structure in generated packages

#### Troubleshooting Resources
- **docs/TROUBLESHOOTING.md**: Comprehensive troubleshooting guide for common issues
- **tools/create_test_pack.sh**: Creates minimal test .mrpack for diagnosing launcher issues
- **Build output verification**: Real-time validation feedback during build process

#### Launcher Compatibility Testing
Tools for testing .mrpack compatibility across different launchers:
- **Modrinth App**: Primary target with optimization for overrides structure
- **PrismLauncher**: Alternative launcher for isolation testing
- **Structure validation**: Ensures compliance with modpack format specifications

## Quick Reference

### Essential Commands
| Command | Purpose | Script |
|---------|---------|--------|
| `../build.sh` | Build .mrpack package | [build.sh](../build.sh) |
| `../manage-modpack.sh full-check` | Complete validation | [manage-modpack.sh](../manage-modpack.sh) |
| `../tools/update-mods.sh` | Update mods | [update-mods.sh](../tools/update-mods.sh) |
| `../validate-directory-structure.sh` | Validate structure | [validate-directory-structure.sh](../validate-directory-structure.sh) |
| `../tools/create_test_pack.sh` | Create minimal test .mrpack | [create_test_pack.sh](../tools/create_test_pack.sh) |

### Key Files
| File | Purpose | Link |
|------|---------|------|
| Modpack Manifest | Main configuration | [modrinth.index.json](../modrinth.index.json) |
| URL Overrides | Custom download URLs | [mod_overrides.conf](../mod_overrides.conf) |
| Change Log | Version history | [CHANGELOG.md](../CHANGELOG.md) |
| User Guide | End-user documentation | [README.md](../README.md) |
| Troubleshooting | Diagnostic and troubleshooting guide | [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

This documentation provides a complete reference for understanding, maintaining, and extending the Survival Not Guaranteed modpack management system. The architecture is designed for reliability, automation, and ease of maintenance while supporting both development and production workflows.

## Version Management

### Semantic Versioning Strategy

The project follows semantic versioning (MAJOR.MINOR.PATCH) with specific rules focused on modpack content:

**MAJOR (X.0.0)**: Breaking changes that affect compatibility
- Minecraft version updates (e.g., 1.20.x → 1.21.x)
- NeoForge major version changes
- Breaking configuration changes that require world resets

**MINOR (X.Y.0)**: Modpack content changes
- New mods added to the pack
- Mods removed from the pack
- Mod version updates that add/remove significant features
- Changes that affect gameplay mechanics

**PATCH (X.Y.Z)**: Configuration and maintenance (no modpack content changes)
- Configuration file updates (mod configs, scripts)
- Bug fixes and optimizations
- Infrastructure improvements (Git, CI/CD, documentation)
- Dependency updates without functional changes
- Performance tuning and stability improvements

**Key Principle**: Version increments only when the modpack itself changes. Infrastructure, documentation, or configuration tweaks are patch releases.

### Version Detection Logic

The build system automatically determines version increments based on actual modpack changes:

1. **Remote Version Sources**: Uses GitHub releases and Modrinth versions as base (no local version checking)
2. **Content Change Detection**: Analyzes if actual mods were added, removed, or significantly updated  
3. **Configuration vs Content**: Distinguishes between config changes and mod content changes
4. **Infrastructure Filtering**: Excludes Git, CI/CD, and documentation changes from version bumps

**Version Trigger Examples:**
- **MINOR bump**: Adding/removing a mod JAR file to/from the pack
- **PATCH bump**: Updating mod configurations, CraftTweaker scripts, or shader settings
- **No bump**: Documentation updates, Git tracking fixes, CI/CD improvements

**Key Principle**: Only changes that affect what players download and install trigger version increments. Version detection relies on remote sources (GitHub/Modrinth) for consistency.

### Practical Versioning Examples

**MINOR Version Increments (3.X.0):**
```bash
# These changes trigger minor version bumps
- Adding JEI mod to the pack                    → 3.13.0 → 3.14.0
- Removing Sodium for performance testing       → 3.14.0 → 3.15.0  
- Updating Create mod from 1.5 to 1.6          → 3.15.0 → 3.16.0
```

**PATCH Version Increments (3.0.X):**
```bash
# These changes trigger patch version bumps  
- Updating JEI configuration settings          → 3.13.0 → 3.13.1
- Adding new CraftTweaker recipes              → 3.13.1 → 3.13.2
- Changing shader pack settings                → 3.13.2 → 3.13.3
- Fixing mod configuration conflicts           → 3.13.3 → 3.13.4
```

**No Version Change:**
```bash
# These changes do NOT trigger version bumps
- Updating documentation                       → 3.13.0 (no change)
- Fixing GitHub Actions workflows             → 3.13.0 (no change)
- Improving build scripts                     → 3.13.0 (no change)
- Updating .gitignore file                    → 3.13.0 (no change)
```

**MAJOR Version Increments (X.0.0):**
```bash  
# Reserved for breaking changes
- Updating from Minecraft 1.21.1 to 1.22.0   → 3.13.0 → 4.0.0
- Major NeoForge version change               → 4.0.0 → 5.0.0
- Complete modpack overhaul                   → 5.0.0 → 6.0.0
```
