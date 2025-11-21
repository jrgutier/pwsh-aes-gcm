# GitHub Actions Workflows

This directory contains CI/CD workflows for the AES-GCM PowerShell module.

## Workflows

### CI (`ci.yml`)

**Triggers:** Push to main/develop/claude/** branches, pull requests

**Purpose:** Comprehensive testing across multiple Windows and PowerShell versions

**Jobs:**

1. **test** - Matrix testing on:
   - OS: windows-2019, windows-2022, windows-latest
   - PowerShell: 5.1 (Windows PowerShell), 7.x (PowerShell Core)

   Tests performed:
   - Module import validation
   - Module manifest validation
   - Full test suite (Wycheproof test vectors)
   - Example script execution
   - Empty plaintext edge case testing

2. **verify-implementations** - Validates both implementations:
   - Native .NET implementation (PowerShell 7)
   - BCrypt P/Invoke implementation (PowerShell 5.1)

### Code Quality (`code-quality.yml`)

**Triggers:** Push to main/develop/claude/** branches, pull requests

**Purpose:** Code quality and security validation

**Jobs:**

1. **lint** - PSScriptAnalyzer linting
   - Runs with PSGallery settings
   - Checks for warnings and errors
   - Fails on errors

2. **validate-syntax** - PowerShell syntax validation
   - Parses all `.ps1`, `.psm1`, `.psd1` files
   - Validates syntax correctness

3. **security-scan** - Security analysis
   - Runs PSScriptAnalyzer security rules
   - Identifies potential security issues

### Release (`release.yml`)

**Triggers:**
- Push tags matching `v*.*.*` (e.g., `v1.0.0`)
- Manual workflow dispatch with version input

**Purpose:** Automated release creation

**Jobs:**

1. **create-release** - Creates GitHub release
   - Validates module and runs tests
   - Creates release package (zip file)
   - Generates release notes
   - Creates GitHub release with artifacts

2. **test-release** - Validates release package
   - Downloads and tests the release artifact
   - Ensures module works from packaged form

## Creating a Release

To create a new release:

1. **Update version in `AesGcm.psd1`:**
   ```powershell
   ModuleVersion = '1.1.0'
   ```

2. **Commit the version change:**
   ```bash
   git add AesGcm.psd1
   git commit -m "chore: bump version to 1.1.0"
   git push
   ```

3. **Create and push a tag:**
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

The release workflow will automatically:
- Run tests
- Create a release package
- Generate release notes
- Publish to GitHub Releases

## Workflow Status Badges

Add these badges to your README.md:

```markdown
![CI](https://github.com/YOUR_USERNAME/pwsh-aes-gcm/workflows/CI/badge.svg)
![Code Quality](https://github.com/YOUR_USERNAME/pwsh-aes-gcm/workflows/Code%20Quality/badge.svg)
```

## Local Testing

Before pushing, you can test locally:

```powershell
# Import module
Import-Module ./AesGcm.psd1 -Force -Verbose

# Run tests
Test-AesGcmImplementation -Verbose

# Run PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
```

## Maintenance

- **Dependabot** is configured to keep GitHub Actions updated
- Review and merge dependabot PRs regularly
- Test workflows run on every push to ensure code quality
