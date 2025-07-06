# Survival Not Guaranteed - Complete System Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Branch Architecture](#branch-architecture)
3. [Core Components](#core-components)
4. [Automation System](#automation-system)
5. [Management Tools](#management-tools)
6. [Build System](#build-system)
7. [Deployment Pipeline](#deployment-pipeline)
8. [File Structure](#file-structure)
9. [Configuration Management](#configuration-management)
10. [Troubleshooting and Maintenance](#troubleshooting-and-maintenance)

## System Overview

Survival Not Guaranteed is a Minecraft modpack built on NeoForge 1.21.1 featuring 141+ carefully curated mods. The project employs a sophisticated automated management system designed for zero-intervention operations, comprehensive dependency management, and reliable deployment.

### Key Characteristics
- **Target Audience**: Players seeking challenging survival gameplay with fantasy RPG elements
- **Mod Count**: 141 mods (119 universal, 11 client-only, 11 server-only)
- **Distribution**: .mrpack format with 100% external downloads
- **Architecture**: Multi-platform with automated CI/CD pipeline
- **Management**: Fully automated mod updates and dependency resolution

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

1. **Change Analysis**: Determines version bump type based on modified files
2. **Build Process**: Executes [build.sh](../build.sh) to generate .mrpack
3. **Validation**: Runs comprehensive tests and validation
4. **Release Creation**: Creates GitHub release with artifacts
5. **Distribution**: Uploads to Modrinth and other platforms

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

### Build Process Flow

1. **Initialization**
   - Environment setup and dependency checking
   - Cache directory creation
   - Statistics initialization

2. **Mod Discovery**
   - Scan mods directory for .jar files
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

6. **Package Creation**
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

## Deployment Pipeline

### Version Management
- **Semantic Versioning**: MAJOR.MINOR.PATCH format
- **Auto-increment**: Based on change analysis
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
├── minecraft/
│   ├── mods/               # Mod JAR files
│   ├── config/             # Mod configurations
│   ├── scripts/            # CraftTweaker scripts
│   ├── shaderpacks/        # Shader files
│   └── servers.dat         # Server list
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
├── README.md               # User documentation
└── CHANGELOG.md            # Version history
```

### Directory Purposes

**/.github/workflows/**: Automation and CI/CD pipeline definitions
**/docs/**: Comprehensive system documentation
**/config/**: PrismLauncher-specific configuration files
**/minecraft/**: Standard Minecraft directory structure for PrismLauncher
**/tools/**: Advanced management utilities
**Root Level**: Primary scripts and configuration files

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
- **[minecraft/config/](../minecraft/config/)**: Individual mod configurations
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
