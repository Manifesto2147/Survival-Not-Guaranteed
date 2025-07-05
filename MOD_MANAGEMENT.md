# Mod Management System

Comprehensive tooling for safely managing mod updates while maintaining dependency integrity.

## 🚀 Quick Start

```bash
# Run the full workflow (recommended)
./manage-mods.sh workflow

# Or use interactive mode
./manage-mods.sh interactive

# Quick update check
./manage-mods.sh check
```

## 📋 Scripts Overview

### 1. `manage-mods.sh` - Master Script
The main entry point that orchestrates the entire mod management workflow.

**Commands:**
- `workflow` - Complete update workflow (default)
- `check` - Quick update check
- `interactive` - Interactive mode with menu
- `validate` - Dependency validation only
- `prerequisites` - Check system requirements

### 2. `check-mod-updates.sh` - Update Checker
Checks for available mod updates while analyzing dependencies.

**Commands:**
- `check` - Full update check with dependency analysis (default)
- `dependencies` - Build dependency graph only
- `updates` - Check for updates only
- `analyze` - Analyze update safety
- `recommend` - Generate update recommendations
- `clean` - Clean up temporary files

### 3. `apply-mod-updates.sh` - Update Applicator
Safely applies mod updates with automatic backup and rollback.

**Commands:**
- `safe` - Apply all safe (low-risk) updates
- `update <project>` - Apply specific update by project ID
- `list` - List available updates
- `restore <backup>` - Restore from backup directory
- `clean` - Clean up temporary files and backups

### 4. `validate-dependencies.sh` - Dependency Validator
Validates mod dependencies and environment compatibility.

**Commands:**
- `validate` - Run full dependency validation (default)
- `libraries` - Check essential libraries only
- `deps` - Check dependency relationships only
- `conflicts` - Check for mod conflicts only
- `env` - Validate environment compatibility only
- `version` - Check version compatibility only
- `report` - Generate comprehensive dependency report

## 🔧 Complete Workflow

The full workflow provides maximum safety and validation:

### Step 1: Prerequisites Check
- Ensures you're on the `develop` branch
- Verifies all required tools are installed
- Checks for required scripts

### Step 2: Dependency Validation
- Validates current mod dependencies
- Checks for essential libraries
- Identifies potential conflicts
- Verifies environment compatibility

### Step 3: Update Discovery
- Scans all mods for available updates
- Analyzes dependency relationships
- Categorizes updates by risk level
- Validates URLs and compatibility

### Step 4: Safe Update Application
- Automatically creates backups
- Applies low-risk updates first
- Validates after each update
- Provides rollback capability

### Step 5: Post-Update Validation
- Re-validates dependencies
- Checks for new conflicts
- Verifies pack integrity
- Generates comprehensive reports

## 🛡️ Safety Features

### Automatic Backups
- Creates timestamped backups before any changes
- Includes manifest, configs, and mod overrides
- Simple restore command for rollback

### Dependency Analysis
- Tracks mod dependency relationships
- Identifies essential libraries
- Prevents breaking dependent mods
- Validates environment compatibility

### Risk Assessment
- Categorizes updates by risk level
- Considers dependency complexity
- Provides safety recommendations
- Allows selective updates

### Validation Checks
- JSON syntax validation
- Manifest structure verification
- URL accessibility testing
- Version compatibility checks

## 📊 Understanding Output

### Update Risk Levels
- **Low Risk**: Standalone mods with few dependencies
- **Medium Risk**: Mods with multiple dependencies
- **High Risk**: Essential libraries or complex mods

### Environment Categories
- **Universal**: Works on both client and server
- **Client-Only**: Client-side only (UI, audio, etc.)
- **Server-Only**: Server-side only (rare)

### Dependency Status
- **✅ Pass**: All checks successful
- **⚠️ Warning**: Issues found but not critical
- **❌ Fail**: Critical issues that need attention

## 🔍 Troubleshooting

### Common Issues

#### "Not on develop branch"
```bash
git checkout develop
```

#### "Required tool missing"
```bash
# Install missing tools
brew install jq curl git
```

#### "Dependency validation failed"
- Review the specific errors
- Check if essential libraries are present
- Verify mod compatibility
- Consider updating dependencies first

#### "Update application failed"
- Check the backup directory
- Restore using: `./apply-mod-updates.sh restore <backup_dir>`
- Review failed update details

### Recovery Commands

```bash
# Restore from backup
./apply-mod-updates.sh restore backup_20250705_120000

# Clean up and start over
./check-mod-updates.sh clean
./apply-mod-updates.sh clean

# Re-validate after changes
./validate-dependencies.sh validate
```

## 📁 Generated Files

### Temporary Files
- `temp_update_check/` - Temporary mod analysis data
- `mod_dependencies.json` - Dependency graph cache
- `update_report.json` - Available updates report
- `dependency_report.json` - Comprehensive dependency analysis

### Backup Files
- `backup_YYYYMMDD_HHMMSS/` - Timestamped backups
- `applied_updates.json` - Log of applied updates
- `known_dependencies.json` - Dependency database

## 🎯 Best Practices

### Before Updates
1. Always work on the `develop` branch
2. Commit current changes first
3. Run dependency validation
4. Check for conflicts

### During Updates
1. Apply safe updates first
2. Test each major update individually
3. Validate after each batch
4. Keep backups organized

### After Updates
1. Test the pack in PrismLauncher
2. Verify all mods load correctly
3. Check for new conflicts
4. Update version numbers if needed

### Production Deployment
1. Merge develop to main only after thorough testing
2. Use semantic versioning
3. Document all changes
4. Tag releases appropriately

## 🔗 Integration with CI/CD

The mod management system integrates with the existing GitHub Actions workflows:

- **Develop Branch**: Enhanced validation and testing
- **Main Branch**: Production releases
- **Local Testing**: Pre-push validation

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section
2. Review generated log files
3. Ensure all prerequisites are met
4. Consider restoring from backup

## 🚀 Future Enhancements

Planned improvements:
- CurseForge API integration
- Advanced conflict resolution
- Performance impact analysis
- Automated testing integration
- Dependency update notifications
