@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AesGcm.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = '8f7c9a3e-5b2d-4e1a-9c8f-7d6e5a4b3c2d'

    # Author of this module
    Author = 'AES-GCM Module'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for AES-256-GCM authenticated encryption. Compatible with Windows 7, 10, and 11 using native .NET Framework or .NET Core. Supports air-gapped systems with no external dependencies. Tested against Google Wycheproof cryptographic test vectors.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'New-AesGcmKey',
        'New-AesGcmNonce',
        'ConvertTo-AesGcmEncrypted',
        'ConvertFrom-AesGcmEncrypted',
        'Test-AesGcmImplementation'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # List of all files packaged with this module
    FileList = @(
        'AesGcm.psm1',
        'AesGcm.psd1',
        'Classes/AesGcmNative.ps1',
        'Classes/AesGcmLegacy.ps1',
        'TestVectors/aes_gcm_test.json'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('AES', 'GCM', 'Encryption', 'Cryptography', 'Security', 'Windows', 'AES-256', 'Authenticated-Encryption', 'Air-Gapped')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 1.0.0
- Initial release
- AES-256-GCM authenticated encryption and decryption
- Automatic detection and fallback between .NET implementations
- Native System.Security.Cryptography.AesGcm support (.NET Core 3.0+)
- BCrypt CNG P/Invoke fallback for .NET Framework 3.5+
- Hex string input/output format
- Support for additional authenticated data (AAD)
- Automatic or explicit nonce generation
- 316 Wycheproof test vectors included
- Compatible with Windows 7, 10, and 11
- No external dependencies - works on air-gapped systems
'@
        }
    }
}
