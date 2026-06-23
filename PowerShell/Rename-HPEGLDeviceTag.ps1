#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.26' }

<#
.SYNOPSIS
    Renames a device tag key (e.g. 'Plant_name' -> 'Plant_Name') across all devices in an HPE GreenLake workspace.

.DESCRIPTION
    HPE GreenLake device tag keys are case-sensitive, so 'Plant_name' and 'Plant_Name' are treated as two
    different tags. This script finds every device whose tags contain the source tag key, then for each device
    it removes that tag and re-adds it under the target tag key. By default the original value is preserved; an
    optional -NewValue overrides it. A verification pass at the end confirms no device still carries the source key.

    The source/target keys are matched case-sensitively, so this also handles pure casing changes such as
    'Plant_name' -> 'Plant_Name'.

    Workflow:
      1. Imports the HPECOMCmdlets module and connects to HPE GreenLake.
      2. Retrieves all devices and filters those with a case-sensitive match on -SourceTagKey.
      3. For each matching device: removes -SourceTagKey and adds -TargetTagKey=<value>.
      4. Re-queries devices to verify the source key no longer exists.

.PARAMETER SourceTagKey
    The existing tag key to rename (matched case-sensitively). Required. Example: 'Plant_name'.

.PARAMETER TargetTagKey
    The new tag key to apply in its place. Required. Example: 'Plant_Name'.

.PARAMETER NewValue
    Optional. When specified, all renamed tags are set to this value instead of preserving each device's
    original value.

.PARAMETER Email
    HPE GreenLake account email used for login. If not provided, the script prompts for it.

.PARAMETER WorkspaceName
    HPE GreenLake workspace name to connect to. If not provided, the script prompts for it.

.NOTES
    Prerequisites:
      - PowerShell 7.0 or later.
      - HPECOMCmdlets module v1.0.26 or later.
      - An HPE GreenLake account with permission to edit device tags
        (Workspace Administrator/Operator, or a custom role with "Devices and Subscription Service Edit").

    Authentication:
      The script authenticates with passwordless SAML SSO via -PasswordlessSSOEmail (push notification or TOTP).
      To use a different method, edit the connection block:
        - Standard account or password-based SSO: Connect-HPEGL -Credential (Get-Credential -UserName $Email) -Workspace $WorkspaceName
          (password-based SSO requires v1.0.26+; federation is detected automatically).
        - Passwordless SSO (default): Connect-HPEGL -PasswordlessSSOEmail $Email -Workspace $WorkspaceName

    Disclaimer: Provided as-is, not officially supported by HPE. Test in a non-production environment first.

    Author: lionel.jullien@hpe.com

.EXAMPLE
    .\Tag renaming.ps1 -SourceTagKey 'Plant_name' -TargetTagKey 'Plant_Name'

    Renames every 'Plant_name' tag to 'Plant_Name' (preserving values), prompting for email and workspace,
    and prints a per-device status plus a final verification.

.EXAMPLE
    .\Tag renaming.ps1 -SourceTagKey 'Env' -TargetTagKey 'Environment' -Email 'user@company.com' -WorkspaceName 'HPE Mougins'

    Renames the 'Env' tag key to 'Environment' on all matching devices, preserving each device's value.

.EXAMPLE
    .\Tag renaming.ps1 -SourceTagKey 'Site' -TargetTagKey 'Location' -NewValue 'Paris'

    Renames the 'Site' tag key to 'Location' and sets every renamed tag's value to 'Paris'.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceTagKey,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetTagKey,

    [string]$NewValue,

    [string]$Email,

    [string]$WorkspaceName
)

if (-not $Email) { $Email = Read-Host "Enter your HPE GreenLake email (used for login)" }
if (-not $WorkspaceName) { $WorkspaceName = Read-Host "Enter your HPE GreenLake workspace name" }

try {
    Import-Module HPECOMCmdlets -ErrorAction Stop
    $moduleVersion = (Get-Module HPECOMCmdlets).Version
    Write-Host "HPECOMCmdlets module v$moduleVersion imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to import HPECOMCmdlets module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Install the module using: Install-Module HPECOMCmdlets" -ForegroundColor Yellow
    exit 1
}

Write-Host "Connecting to HPE GreenLake..." -ForegroundColor Yellow

try {
    # Passwordless SAML SSO (push notification or TOTP). Requires HPECOMCmdlets v1.0.26+.
    Connect-HPEGL -PasswordlessSSOEmail $Email -Workspace $WorkspaceName -ErrorAction Stop -RemoveExistingCredentials | Out-Null
    # Alternative - standard account or password-based SSO (federation auto-detected, v1.0.26+):
    # Connect-HPEGL -Credential (Get-Credential -UserName $Email -Message "Enter your HPE GreenLake credentials") -Workspace $WorkspaceName -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null
    Write-Host "Connected to HPE GreenLake successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to connect to HPE GreenLake: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}



# Find devices whose tags contain the source key (case-sensitive match)
$devicesWithSourceTag = Get-HPEGLDevice | Where-Object {
    $_.tags.PSObject.Properties.Name -ccontains $SourceTagKey
}

Write-Host "`nFound $($devicesWithSourceTag.Count) device(s) with tag key '$SourceTagKey' to rename to '$TargetTagKey'" -ForegroundColor Yellow

foreach ($device in $devicesWithSourceTag) {
    $value = if ($PSBoundParameters.ContainsKey('NewValue')) { $NewValue } else { $device.tags.$SourceTagKey }
    Write-Host "  [$($device.serialNumber)] Renaming tag: $SourceTagKey=$($device.tags.$SourceTagKey) -> $TargetTagKey=$value" -ForegroundColor Cyan
    $removeResult = Remove-HPEGLDeviceTagFromDevice -SerialNumber $device.serialNumber -Tags $SourceTagKey
    $addResult = Add-HPEGLDeviceTagToDevice -SerialNumber $device.serialNumber -Tags "$TargetTagKey=$value"

    $removeStatus = $removeResult.Status
    $addStatus = $addResult.Status
    if ($removeStatus -eq 'Complete' -and $addStatus -in 'Complete', 'Warning') {
        Write-Host "  [$($device.serialNumber)] Done  (remove: $removeStatus | add: $addStatus)" -ForegroundColor Green
    }
    else {
        Write-Host "  [$($device.serialNumber)] Issue (remove: $removeStatus | add: $addStatus)" -ForegroundColor Red
    }
}

Write-Host "`nVerification:" -ForegroundColor Yellow
$remaining = Get-HPEGLDevice | Where-Object { $_.tags.PSObject.Properties.Name -ccontains $SourceTagKey }
if ($remaining) {
    Write-Host "  WARNING: $($remaining.Count) device(s) still have the '$SourceTagKey' tag:" -ForegroundColor Red
    $remaining | ForEach-Object { Write-Host "    - $($_.serialNumber)" -ForegroundColor Red }
}
else {
    Write-Host "  All matching devices now use the '$TargetTagKey' tag key." -ForegroundColor Green
}

