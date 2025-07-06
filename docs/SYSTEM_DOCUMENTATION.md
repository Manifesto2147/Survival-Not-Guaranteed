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

### Recent Infrastructure Improvements (v3.13.0+)
- **Git Optimization**: Removed mod files from repository tracking (131 files excluded)
- **CI/CD Enhancement**: Implemented manifest-based CI builds with temporary mod download
- **Build System**: Dual-mode operation for local development and CI automation
- **Workflow Optimization**: Automated mod acquisition from manifest URLs in CI
- **Documentation**: Updated to reflect manifest-driven development workflow
- **Legal Compliance**: Enhanced mod licensing compliance with official-source-only downloads
- **CI/CD Enhancement**: Fixed GitHub Actions workflow path references
- **Build System**: Improved version detection and change analysis
- **Documentation**: Updated to reflect actual system architecture
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
  "versionId": "3.10.1",
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

#### Release Pipeline ([.github/workflows/release.yml](../.github/workflows/release.yml))
Triggered on main branch changes:

### GitHub Actions Workflow

#### Release Pipeline ([.github/workflows/release.yml](../.github/workflows/release.yml))
Triggered on main branch changes or manual dispatch:

1. **Manifest-Based Mod Download**: Downloads mod JARs from existing manifest URLs to temporary mods directory
2. **Change Analysis**: Determines version bump type based on modified files and change patterns  
3. **Build Process**: Executes [build.sh](../build.sh) to generate .mrpack with full mod scanning
4. **Validation**: Runs comprehensive tests and validation
5. **Release Creation**: Creates GitHub release with artifacts
6. **Distribution**: Uploads to Modrinth and other platforms
7. **Cleanup**: Removes temporarily downloaded mod files

**Version Bump Logic:**
- **MAJOR (X.0.0)**: Breaking changes (Minecraft updates, major incompatible changes)
- **MINOR (X.Y.0)**: Modpack content changes (mods added/removed, significant mod updates)
- **PATCH (X.Y.Z)**: Configuration, scripts, bug fixes, infrastructure (no mod content changes)

**Trigger Paths:**
- `config/**` - Configuration changes
- `mods/**` - Mod additions/removals (triggers GitHub Actions)
- `scripts/**` - CraftTweaker script changes
- `shaderpacks/**` - Shader pack changes
- `modrinth.index.json` - Manifest updates
- `mod_overrides.conf` - URL override changes

**Note**: The `mods/` directory is excluded from Git tracking but monitored by the build system for changes.

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

### Build Process Flow

The build system operates in two distinct modes depending on the environment:

#### Local Development Mode
1. **Initialization**
   - Environment setup and dependency checking
   - Cache directory creation
   - Statistics initialization

2. **Mod Discovery**
   - Scan existing mods directory for .jar files
   - Extract mod metadata from filenames
   - Generate potential mod slugs for API queries

3. **URL Resolution**
   - Query Modrinth API for official download URLs
   - Fallback to CurseForge API if needed
   - Apply manual overrides for problematic mods
   - Validate download URLs and file integrity

4. **Environment Detection**
   - Determine client/server compatibility
   - Apply manual environment overrides
   - Classify mods by environment requirements

5. **Manifest Generation**
   - Create modrinth.index.json with external URLs
   - Include file integrity hashes
   - Set environment specifications
   - Add metadata and version information

#### CI/Automation Mode
1. **Manifest-Based Mod Acquisition**
   - Download mod JARs from existing manifest URLs
   - Create temporary mods directory
   - Verify download success for build process

2. **Standard Build Process**
   - Execute same mod discovery and analysis as local mode
   - Generate updated manifest with new version
   - Create .mrpack with current configurations

3. **Cleanup**
   - Remove temporarily downloaded mod files
   - Preserve only the generated artifacts

### Package Creation (Both Modes)
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
│   └── SYSTEM_DOCUMENTATION.md
├── config/                  # PrismLauncher instance config
├── mods/                    # Mod JAR files (excluded from Git)
├── scripts/                 # CraftTweaker scripts
├── shaderpacks/             # Shader files
├── tools/
│   └── core/
│       ├── [update-mods.sh](../tools/update-mods.sh)  # Advanced update system
│       └── [validate-dependencies.sh](../tools/validate-dependencies.sh)
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
**/docs/**: Comprehensive system documentation
**/config/**: PrismLauncher-specific configuration files
**/mods/**: Mod JAR files (excluded from Git tracking, populated by build system)
**/scripts/**: CraftTweaker scripts
**/shaderpacks/**: Shader files
**/tools/**: Advanced management utilities
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

## Quick Reference

### Essential Commands
| Command | Purpose | Script |
|---------|---------|--------|
| `../build.sh` | Build .mrpack package | [build.sh](../build.sh) |
| `../manage-modpack.sh full-check` | Complete validation | [manage-modpack.sh](../manage-modpack.sh) |
| `../tools/update-mods.sh` | Update mods | [update-mods.sh](../tools/update-mods.sh) |
| `../validate-directory-structure.sh` | Validate structure | [validate-directory-structure.sh](../validate-directory-structure.sh) |

### Key Files
| File | Purpose | Link |
|------|---------|------|
| Modpack Manifest | Main configuration | [modrinth.index.json](../modrinth.index.json) |
| URL Overrides | Custom download URLs | [mod_overrides.conf](../mod_overrides.conf) |
| Change Log | Version history | [CHANGELOG.md](../CHANGELOG.md) |
| User Guide | End-user documentation | [README.md](../README.md) |

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
