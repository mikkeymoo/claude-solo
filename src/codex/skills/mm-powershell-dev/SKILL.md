---
name: mm-powershell-dev
description: "Claude-solo command skill"
---

# mm-powershell-dev

Claude-solo command skill

## Instructions
# /powershell-dev Command

Comprehensive PowerShell development command for module creation, DSC configuration, and Windows automation.

## Usage
```
/powershell-dev [action] [options]
```

## Actions

### init - Initialize PowerShell Project
```
/powershell-dev init [module-name] [--type Module|Script|DSC]
```

Creates PowerShell project structure:
```
MyModule/
├── MyModule.psd1         # Module manifest
├── MyModule.psm1         # Module script
├── Public/               # Public functions
├── Private/              # Private functions
├── Classes/              # PowerShell classes
├── Tests/                # Pester tests
├── DSCResources/         # DSC resources
├── en-US/                # Localization
├── docs/                 # Documentation
├── Examples/             # Usage examples
└── build.ps1             # Build script
```

### module - Module Management
```
/powershell-dev module [--publish] [--sign] [--version]
```

Module operations:
- Create module manifest
- Update version
- Sign with certificate
- Publish to PSGallery
- Generate help files

### test - Run Pester Tests
```
/powershell-dev test [--coverage] [--outputformat]
```

Testing features:
- Unit test execution
- Code coverage analysis
- Integration tests
- Performance tests
- Mock generation

### analyze - Script Analysis
```
/powershell-dev analyze [--fix] [--severity]
```

PSScriptAnalyzer checks:
- Best practice violations
- Security issues
- Performance problems
- Compatibility issues
- Auto-fix common issues

### dsc - DSC Configuration
```
/powershell-dev dsc [--compile] [--apply] [--test]
```

DSC management:
- Create configurations
- Compile MOF files
- Apply configurations
- Test compliance
- Generate reports

### class - Class Development
```
/powershell-dev class [class-name] [--inherit]
```

Class generation:
- Create PowerShell classes
- Implement inheritance
- Add properties/methods
- Generate constructors
- Create enums

### cmdlet - Cmdlet Development
```
/powershell-dev cmdlet [cmdlet-name] [--advanced]
```

Cmdlet creation:
- Generate cmdlet template
- Add parameter sets
- Implement pipeline
- Add help documentation
- Create aliases

## Configuration

### Module Manifest (MyModule.psd1)
```powershell
@{
    # Module information
    RootModule = 'MyModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author = 'Your Name'
    CompanyName = 'Your Company'
    Copyright = '(c) 2024. All rights reserved.'
    Description = 'Comprehensive PowerShell module'
    PowerShellVersion = '7.0'

    # Exports
    FunctionsToExport = @('Get-*', 'Set-*', 'New-*', 'Remove-*')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    # Dependencies
    RequiredModules = @()
    RequiredAssemblies = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Automation', 'DevOps', 'Windows')
            LicenseUri = 'https://github.com/user/repo/LICENSE'
            ProjectUri = 'https://github.com/user/repo'
            IconUri = 'https://github.com/user/repo/icon.png'
            ReleaseNotes = 'Initial release'
            Prerelease = ''
            RequireLicenseAcceptance = $false
        }
    }
}
```

### PSScriptAnalyzer Settings
```powershell
# PSScriptAnalyzerSettings.psd1
@{
    Severity = @('Error', 'Warning', 'Information')

    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
        PSUseDeclaredVarsMoreThanAssignment = @{
            Enable = $true
        }
        PSUsePSCredentialType = @{
            Enable = $true
        }
    }

    ExcludeRules = @()
}
```

## Advanced Function Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description

    .DESCRIPTION
        Detailed description

    .PARAMETER ParameterName
        Parameter description

    .EXAMPLE
        Verb-Noun -ParameterName "Value"

    .NOTES
        Author: Your Name
        Date: 2024-01-01
        Version: 1.0.0
    #>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Medium',
        DefaultParameterSetName = 'Default'
    )]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Default'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [Alias('Path')]
        [string[]]$FilePath,

        [Parameter()]
        [ValidateSet('Option1', 'Option2', 'Option3')]
        [string]$Mode = 'Option1',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"

        # Initialize resources
        $ErrorActionPreference = 'Stop'
    }

    process {
        foreach ($path in $FilePath) {
            try {
                if ($PSCmdlet.ShouldProcess($path, "Process file")) {
                    # Main logic here
                    $result = [PSCustomObject]@{
                        Path = $path
                        Status = 'Success'
                        Timestamp = Get-Date
                    }

                    Write-Output $result
                }
            }
            catch {
                Write-Error "Failed to process $path : $_"
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand.Name)"

        # Cleanup resources
    }
}
```

## DSC Resource Development

```powershell
# Generated by /powershell-dev dsc --resource

[DscResource()]
class MyDscResource {
    [DscProperty(Key)]
    [string]$Name

    [DscProperty(Mandatory)]
    [string]$Path

    [DscProperty()]
    [string]$Ensure = 'Present'

    [DscProperty(NotConfigurable)]
    [datetime]$CreatedDate

    [MyDscResource] Get() {
        Write-Verbose "Getting resource $($this.Name)"

        $current = [MyDscResource]::new()
        $current.Name = $this.Name

        if (Test-Path $this.Path) {
            $current.Ensure = 'Present'
            $current.Path = $this.Path
            $current.CreatedDate = (Get-Item $this.Path).CreationTime
        }
        else {
            $current.Ensure = 'Absent'
        }

        return $current
    }

    [bool] Test() {
        Write-Verbose "Testing resource $($this.Name)"

        $current = $this.Get()

        if ($this.Ensure -eq 'Present') {
            return $current.Ensure -eq 'Present'
        }
        else {
            return $current.Ensure -eq 'Absent'
        }
    }

    [void] Set() {
        Write-Verbose "Setting resource $($this.Name)"

        if ($this.Ensure -eq 'Present') {
            if (-not (Test-Path $this.Path)) {
                New-Item -Path $this.Path -ItemType File -Force
            }
        }
        else {
            if (Test-Path $this.Path) {
                Remove-Item -Path $this.Path -Force
            }
        }
    }
}
```

## Pester Test Template

```powershell
# Generated by /powershell-dev test --create

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath\MyModule.psd1" -Force
}

Describe "Function-Name" {
    Context "Parameter Validation" {
        It "Should require mandatory parameters" {
            { Function-Name } | Should -Throw
        }

        It "Should validate parameter types" {
            { Function-Name -Parameter "Invalid" } | Should -Throw
        }
    }

    Context "Functionality" {
        BeforeEach {
            # Setup test environment
            $testData = @{
                Name = "Test"
                Value = 123
            }
        }

        It "Should process valid input" {
            $result = Function-Name -InputObject $testData
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Success"
        }

        It "Should support pipeline input" {
            $result = $testData | Function-Name
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle errors gracefully" {
            Mock Get-Item { throw "Access denied" }

            { Function-Name -Path "C:\Invalid" } | Should -Throw
        }
    }

    Context "Output" {
        It "Should return correct type" {
            $result = Function-Name -InputObject "Test"
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Should include required properties" {
            $result = Function-Name -InputObject "Test"
            $result.PSObject.Properties.Name | Should -Contain "Status"
            $result.PSObject.Properties.Name | Should -Contain "Timestamp"
        }
    }
}
```

## Windows Integration

### Active Directory
```
/powershell-dev ad [--cmdlets] [--schema]
```

AD integration:
- User management cmdlets
- Group management
- OU operations
- Schema extensions
- GPO management

### Exchange
```
/powershell-dev exchange [--mailbox] [--transport]
```

Exchange management:
- Mailbox cmdlets
- Transport rules
- Distribution groups
- Mail flow monitoring
- Compliance management

### Azure
```
/powershell-dev azure [--resources] [--automation]
```

Azure integration:
- Resource management
- Automation accounts
- ARM templates
- Policy definitions
- Cost management

## Performance Optimization

### Parallel Processing
```powershell
# Generated by /powershell-dev optimize --parallel

$items | ForEach-Object -Parallel {
    # Process in parallel
    Process-Item $_
} -ThrottleLimit 10

# Or using runspaces
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
$runspacePool.Open()

$jobs = foreach ($item in $items) {
    $powershell = [powershell]::Create()
    $powershell.RunspacePool = $runspacePool
    $powershell.AddScript($scriptBlock).AddArgument($item)

    [PSCustomObject]@{
        PowerShell = $powershell
        Handle = $powershell.BeginInvoke()
    }
}
```

### Memory Optimization
```powershell
# Generated by /powershell-dev optimize --memory

# Use streaming instead of loading all data
Get-Content $largefile -ReadCount 1000 | ForEach-Object {
    # Process batch
}

# Dispose objects properly
try {
    $stream = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Open)
    # Use stream
}
finally {
    if ($stream) { $stream.Dispose() }
}
```

## Security Features

### Credential Management
```
/powershell-dev security --credential
```

Security features:
- Secure credential storage
- Certificate management
- Encryption/decryption
- Secret vaults
- JEA endpoints

### Code Signing
```
/powershell-dev sign [--certificate]
```

Signing operations:
- Script signing
- Module signing
- Catalog signing
- Signature validation

## Documentation

### Help Generation
```
/powershell-dev help [--online] [--updateable]
```

Documentation features:
- MAML help generation
- Online help
- About topics
- Conceptual help
- Updateable help

## Best Practices Enforced

1. **Use approved verbs** for all functions
2. **Implement help** for all public functions
3. **Support pipeline** where appropriate
4. **Use ShouldProcess** for destructive operations
5. **Write Pester tests** with 80% coverage
6. **Follow PSScriptAnalyzer** rules
7. **Use semantic versioning**
8. **Sign scripts** for production
9. **Handle errors** with try/catch
10. **Use proper types** and validation

## Example Session

```
User: /powershell-dev init MyAutomation --type Module
Claude: Creating PowerShell module structure...
        ✅ Created module manifest
        ✅ Set up directory structure
        ✅ Generated test framework
        ✅ Created build script

User: /powershell-dev cmdlet Get-SystemInfo --advanced
Claude: Generating advanced cmdlet...
        ✅ Created Get-SystemInfo.ps1
        ✅ Added parameter sets
        ✅ Implemented pipeline support
        ✅ Generated help documentation

User: /powershell-dev test --coverage
Claude: Running Pester tests...
        ✅ 24 tests passed
        ✅ 0 tests failed
        ✅ Code coverage: 85%
        ✅ No PSScriptAnalyzer issues
```
