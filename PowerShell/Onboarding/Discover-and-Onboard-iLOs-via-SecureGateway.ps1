<#
.SYNOPSIS
Discover and onboard HPE iLOs to Compute Ops Management (COM) through an HPE Secure Gateway, in a single batch job.

.DESCRIPTION
This PowerShell script is the Secure-Gateway-native companion to 'Prepare-and-Connect-iLOs-to-COM-v2.ps1'.

Where the v2 script is the universal, CSV-driven onboarding tool (direct / web proxy / Secure Gateway, with local
iLO firmware staging via HPEiLOCmdlets), this script targets one specific scenario: a fleet of iLOs sitting behind an
HPE Secure Gateway appliance that is already deployed and operational in your Compute Ops Management instance.

It leverages the native, gateway-driven onboarding workflow introduced in HPECOMCmdlets v1.0.26:
- 'Invoke-HPECOMSecureGatewayServerDiscovery' runs an active network discovery from the Secure Gateway to find the
  HPE iLO devices on its local subnet that are not yet connected to Compute Ops Management.
- 'Get-HPECOMSecureGatewayServerDiscovery' returns the discovered servers, reporting for each one the IP, iLO
  generation, iLO firmware version, whether an iLO firmware update is required, and the iLO certificate fingerprint.
- 'Connect-HPECOMSecureGatewayDiscoveredServer' submits a single batch onboarding job per Secure Gateway. Compute Ops
  Management then orchestrates the whole onboarding server-side:
    - generates the Secure Gateway activation key automatically (no activation key to provide),
    - updates the iLO firmware on each server reported as 'iLOUpdateRequired = Yes' (minimum iLO 5 v3.09, iLO 6 v1.64,
      iLO 7 v1.12.00),
    - optionally configures DNS and NTP on the iLO, and assigns a subscription, location, service delivery contact
      and tags,
    - connects each iLO to Compute Ops Management through the Secure Gateway.

Because all the heavy lifting happens server-side, this script is deliberately much thinner than the v2 script:
- NO CSV of iLO IP addresses is required - the Secure Gateway discovers them for you.
- NO HPEiLOCmdlets dependency and NO local firmware .bin files - the gateway updates the iLO firmware.
- NO per-iLO activation key generation - Compute Ops Management generates it automatically.

Servers whose discovery reports 'iLOUpdateRequired = Unknown' (the iLO generation or firmware version could not be
determined) are skipped and reported, because the Secure Gateway cannot safely decide whether a firmware update is
required.

This script is idempotent: discovery only ever returns iLOs that are not yet connected to Compute Ops Management, so
re-running it will not disturb servers that have already been onboarded.

WHEN TO USE THIS SCRIPT vs. Prepare-and-Connect-iLOs-to-COM-v2.ps1:
- Use THIS script when every target iLO is reachable through a Secure Gateway and you want the simplest possible,
  discovery-driven, server-side onboarding (no CSV, no local firmware staging).
- Use the V2 script when you need any of: direct or web-proxy connectivity, a CSV-driven list with per-iLO
  credentials, local iLO firmware staging on the LAN, or onboarding iLOs that are below the COM minimum firmware in an
  environment without a Secure Gateway.

NOTE ON DNS / NTP:
The Secure Gateway sends the DNS and NTP values you supply (-Dns / -Ntp) as part of the onboarding request, but
Compute Ops Management only applies them during the iLO's initial network provisioning. If an iLO already has DNS or
NTP configured (statically or via DHCP), the existing configuration is NOT overwritten.

iLO CREDENTIALS:
Two modes are supported (configured in the variables section, not as parameters):
- Shared credential (default): the single $iLOUserName account is applied to every discovered iLO; its password is
  prompted once at runtime.
- Per-iLO credentials: set $iLOCredentialCsv to a CSV file (columns 'IP', 'Username', 'Password') to give each iLO its
  own credential, matched by IP address. iLOs not listed in the CSV fall back to the shared $iLOUserName credential if
  its password is supplied at the prompt; otherwise they are skipped and reported.

IMPORTANT: Up to 1000 servers can be added every 24 hours. To add more, contact HPE Product Support.

.PARAMETER Check
Runs discovery only and prints a triage table of the discovered servers (Ready to onboard / Firmware update required /
Skipped - Unknown), without onboarding anything. Useful as a pre-flight before a real run.

.PARAMETER Rescan
Forces a fresh network discovery ('Invoke-HPECOMSecureGatewayServerDiscovery') before reading the results. Without this
switch, the script reads the results of the most recent discovery already stored on the Secure Gateway. Note that the
scan duration depends on the size of the subnet behind the Secure Gateway and can take a long time on large subnets.

.PARAMETER PromptForSubscriptionKey
Interactively select the COM subscription key to use. When specified, the script lists all available subscriptions
(key, tier, eval status, available licenses) and prompts for the one to use, overriding $SubscriptionTier / $UseEval.

.PARAMETER Force
Suppresses the discovery scan confirmation prompt so the script can run unattended.

.PARAMETER WhatIf
Previews the onboarding batch job (the payload that would be sent) without making any change.

.PARAMETER TestCredentialCsv
Loads the per-iLO credential CSV ($iLOCredentialCsv) and prints the resulting credential map (IP -> Username, plus the
count of loaded rows and any rows skipped for a missing IP/Username), then exits. This validates the CSV offline -
no HPE GreenLake connection, no network discovery and no onboarding are performed. Passwords are never displayed.

.PARAMETER Verbose
Enables verbose output.

.EXAMPLE
Example 1: Pre-flight only - run a fresh discovery and print the triage table, without onboarding anything

.\Discover-and-Onboard-iLOs-via-SecureGateway.ps1 -Check -Rescan -Force

Runs a new network discovery from the Secure Gateway (-Rescan), bypasses the scan confirmation prompt (-Force), then
displays the discovered servers as a triage table (Ready / Needs firmware update / Skipped) and exports a CSV report.
No iLO credentials are requested and no server is onboarded (-Check).

Output:

========================================================================================================
  Discover-and-Onboard-iLOs-via-SecureGateway
  Version: 1.0.0
  Last Modified: June 23, 2026
  Author: Hewlett Packard Enterprise
========================================================================================================

                                                                                                                        
[Workspace: My_Workspace] - Successfully connected to the HPE GreenLake workspace.
[Workspace: My_Workspace] - COM instance 'eu-central' successfully found.
[Workspace: My_Workspace] - Secure Gateway 'sg01.domain.com' successfully found.

[Secure Gateway: sg01.domain.com] - Running a network discovery scan...
                                                                                                                        
-----------------------------------                                                                                     
SECURE GATEWAY DISCOVERY - TRIAGE
-----------------------------------
  
  IP           iLO     Firmware UpdateRequired Action
  --           ---     -------- -------------- ------
  192.168.0.32 iLO 6   1.61     Yes            Onboard + auto firmware update
  192.168.1.44 Unknown 3.09     Unknown        Skipped - condition unknown
  192.168.1.45 iLO 5   3.10     No             Ready - onboard as-is

  Discovered: 3  |  Ready: 1  |  Needs firmware update: 1  |  Skipped (Unknown): 1
                                                                                                                        
[Workspace: My_Workspace] - Sufficient licenses available (11) for the number of servers to onboard (2).
[Workspace: My_Workspace] - Location 'Paris' successfully found.

[Secure Gateway: sg01.domain.com] - Pre-flight check complete. 2 server(s) ready to onboard, 1 skipped (Unknown). No changes were made.

📄 Status report exported to: C:\Scripts\Secure_Gateway\SG_Discovery_Check_Status_20260623_1118.csv


.EXAMPLE
Example 2: Discover and onboard every iLO behind the Secure Gateway

.\Discover-and-Onboard-iLOs-via-SecureGateway.ps1

Output:

========================================================================================================
  Discover-and-Onboard-iLOs-via-SecureGateway
  Version: 1.0.0
  Last Modified: June 23, 2026
  Author: Hewlett Packard Enterprise
========================================================================================================


Enter password for iLO account 'administrator': ********

[Workspace: My_Workspace] - Successfully connected to the HPE GreenLake workspace.
[Workspace: My_Workspace] - COM instance 'eu-central' successfully found.
[Workspace: My_Workspace] - Secure Gateway 'sg01.domain.com' successfully found.

-----------------------------------
SECURE GATEWAY DISCOVERY - TRIAGE
-----------------------------------
  
  IP           iLO     Firmware UpdateRequired Action
  --           ---     -------- -------------- ------
  192.168.0.32 iLO 6   1.61     Yes            Onboard + auto firmware update
  192.168.1.44 Unknown 3.09     Unknown        Skipped - condition unknown
  192.168.1.45 iLO 5   3.10     No             Ready - onboard as-is

  Discovered: 3  |  Ready: 1  |  Needs firmware update: 1  |  Skipped (Unknown): 1
                                                                                                                        
[Workspace: My_Workspace] - Sufficient licenses available (11) for the number of servers to onboard (2).
[Workspace: My_Workspace] - Location 'Paris' successfully found.

[Secure Gateway: sg01.domain.com] - Submitting onboarding for 2 server(s)...
WARNING: 1 of 2 server(s) have an iLO below the minimum required firmware version and will be updated by the Secure Gateway before onboarding. Updating the iLO firmware reboots the iLO.

Confirm Secure Gateway server onboarding
Do you want to onboard 2 server(s) and update the iLO firmware on 1 of them?
[Y] Yes  [N] No  [?] Help (default is "N"): y
Waiting for job completion [Current state: RUNNING                                                             ]

[Secure Gateway: sg01.domain.com] - Onboarding job completed.

[Workspace: My_Workspace] - Verifying onboarded servers in Compute Ops Management...

Onboarding summary: 1 succeeded, 0 submitted, 0 failed, 1 warnings, 1 skipped (Total: 3)

⚠️ Secure Gateway onboarding completed with items to review!
   Please review the detailed status report below.

📄 Status report exported to: C:\Scripts\Secure_Gateway\SG_Onboarding_Status_20260623_1145.csv


.EXAMPLE
Example 3: Force a fresh scan, then onboard unattended

.\Discover-and-Onboard-iLOs-via-SecureGateway.ps1 -Rescan -Force

.EXAMPLE
Example 4: Validate the per-iLO credential CSV offline (no connection, no discovery, no onboarding)

.\Discover-and-Onboard-iLOs-via-SecureGateway.ps1 -TestCredentialCsv

Loads the CSV referenced by $iLOCredentialCsv and prints the resulting credential map (IP -> Username, password length),
the number of credentials loaded and any skipped rows, then exits. Passwords are never displayed.

Output:

========================================================================================================
  Discover-and-Onboard-iLOs-via-SecureGateway
  Version: 1.0.0
  Last Modified: June 23, 2026
  Author: Hewlett Packard Enterprise
========================================================================================================

WARNING: Skipping a row with a missing IP or Username (IP='192.168.1.47', Username='').

Credential map loaded from 'Private\Onboarding\Secure_Gateway\test_ilo_creds.csv':
  
  IP           Username      PasswordLength
  --           --------      --------------
  192.168.1.45 admin                     11
  192.168.1.46 Administrator              7

  Loaded: 2 credential(s)  |  Skipped rows: 1

Test complete. No connection, discovery or onboarding was performed.

.NOTES
This script generates a CSV report with the status of each discovered server.

Disclaimer: The script is provided as-is and is not officially supported by HPE. Test it in a non-production
environment before running it in production. Use at your own risk.

  Author: lionel.jullien@hpe.com
#>

#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.26' }

param (

    [switch]$Check,

    [switch]$Rescan,

    [switch]$PromptForSubscriptionKey,

    [switch]$Force,

    [switch]$WhatIf,

    [switch]$TestCredentialCsv,

    [switch]$Verbose

)

#Region -------------------------------------------------------- Variables definition -----------------------------------------------------------------------------------------

# ========================================================================================================
# REQUIRED CONFIGURATION - Update these variables before running the script
# ========================================================================================================

# HPE GreenLake workspace name (must already exist in your HPE GreenLake account)
$WorkspaceName = 'My_Workspace'

# Compute Ops Management (COM) service instance region where the Secure Gateway is registered
# (us-west, eu-central, ap-northeast, etc.). The COM instance must already be provisioned in your workspace.
$Region = "eu-central"

# Name (hostname/FQDN) of the HPE Secure Gateway appliance through which the iLOs are discovered and onboarded.
# The Secure Gateway must already be added and operational in your COM instance.
$SecureGatewayName = "sg01.domain.com"

# iLO account credentials used to onboard the discovered servers.
# This account must have Administrator privileges, or at minimum the "Configure iLO Settings" privilege.
#
# Two modes are supported:
#   - SHARED credential (default): the single $iLOUserName account below is applied to every discovered iLO; the
#     password is prompted once at runtime.
#   - PER-iLO credentials: if your iLOs use different accounts/passwords, provide a CSV file in $iLOCredentialCsv below
#     with the columns 'IP', 'Username' and 'Password'. Each discovered iLO is then matched to its credential by IP
#     address. iLOs without a matching CSV row fall back to the shared $iLOUserName credential (if its password is
#     provided at the prompt), otherwise they are skipped and reported.
$iLOUserName = 'administrator'

# OPTIONAL: path to a CSV of per-iLO credentials (columns: IP,Username,Password). Leave commented out to use the
# single shared $iLOUserName credential for every iLO.
# Example CSV content:
#   IP,Username,Password
#   192.168.1.45,admin,Password123
#   192.168.1.46,Administrator,S3cr3t!
# Security note: storing iLO passwords in clear text is a risk - restrict access to the file and delete it after use.
# $iLOCredentialCsv = "C:\path\to\iLO_credentials.csv"

# ========================================================================================================
# HPE GREENLAKE AUTHENTICATION CONFIGURATION
# ========================================================================================================
# ⚠️ IMPORTANT: Define ONLY ONE of the two options. Comment out the one you don't use.

# Option 1: Standard HPE GreenLake account OR password-based SAML SSO account.
# Use for a standard username/password account, OR a federated (SSO) account that requires a PASSWORD
# (Okta, Microsoft Entra ID, PingID) - federation is detected automatically by Connect-HPEGL -Credential.
# This path needs no interactive push/TOTP approval, so it is the recommended method for unattended runs.
$HPEAccount = "user@company.com"

# Option 2: Passwordless SAML SSO authentication (push notification or TOTP - no password).
# This path requires an INTERACTIVE approval at connect time, so it is not suited to unattended automation.
# Uncomment and comment out $HPEAccount above to use it.
# $SSOAccount = "user@company.com"

# ========================================================================================================
# SUBSCRIPTION KEY CONFIGURATION
# ========================================================================================================
# The script automatically selects the first available subscription key matching the criteria below,
# UNLESS you run it with -PromptForSubscriptionKey (in which case these two variables are ignored).
#   - $SubscriptionTier: 'PROLIANT' or 'ALLETRA'
#   - $UseEval: $True to allow evaluation subscriptions, $False to exclude them.
$SubscriptionTier = "PROLIANT"
$UseEval = $False

# ========================================================================================================
# OPTIONAL CONFIGURATION - Comment out or modify as needed
# ========================================================================================================

# DNS server IP to configure on the iLO during onboarding (optional).
# Note: only applied during the iLO's initial provisioning; an iLO that already has DNS keeps its current value.
# $Dns = "192.168.2.1"

# NTP server IP/hostname to configure on the iLO during onboarding (optional).
# Note: only applied during the iLO's initial provisioning; an iLO that already has NTP keeps its current value.
# $Ntp = "1.1.1.1"

# Location to assign to the onboarded servers (optional but recommended; must already exist in the workspace).
# Required for automated HPE support case creation and service delivery.
# $LocationName = "Paris"

# Service delivery contact email to assign to the onboarded servers (optional).
# $ServiceDeliveryContact = "support@company.com"

# Device tags (optional), as a comma-separated string "Name=Value, Name=Value".
# $Tags = "Country=FR, App=AI, Department=IT"

# ========================================================================================================
# SCRIPT VERSION INFORMATION
# ========================================================================================================
$script:ScriptVersion = "1.0.0"
$script:ScriptName = "Discover-and-Onboard-iLOs-via-SecureGateway"
$script:LastModified = "June 23, 2026"
$script:Author = "Hewlett Packard Enterprise"

#EndRegion

#Region -------------------------------------------------------- Preparation -----------------------------------------------------------------------------------------

# Display script banner with version information
Write-Host "`n========================================================================================================" -ForegroundColor Cyan
Write-Host "  $script:ScriptName" -ForegroundColor Cyan
Write-Host "  Version: $script:ScriptVersion" -ForegroundColor Cyan
Write-Host "  Last Modified: $script:LastModified" -ForegroundColor Cyan
Write-Host "  Author: $script:Author" -ForegroundColor Cyan
Write-Host "========================================================================================================`n" -ForegroundColor Cyan

# Set Verbose preference
if ($Verbose) { $VerbosePreference = "Continue" }
else { $VerbosePreference = "SilentlyContinue" }

# Validate authentication configuration - Ensure only one authentication method is defined
if ($HPEAccount -and $SSOAccount) {
    Write-Host "Error: Both `$HPEAccount and `$SSOAccount are defined. Please use only ONE authentication method." -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}
if (-not $HPEAccount -and -not $SSOAccount) {
    Write-Host "Error: Neither `$HPEAccount nor `$SSOAccount is defined. Please configure ONE authentication method." -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

# Validate required configuration
if (-not $WorkspaceName -or -not $Region -or -not $SecureGatewayName) {
    Write-Host "Error: `$WorkspaceName, `$Region and `$SecureGatewayName must all be defined in the variables section." -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

# -TestCredentialCsv: load and display the per-iLO credential CSV map, then exit (offline test - no connection needed)
if ($TestCredentialCsv) {
    if (-not $iLOCredentialCsv) {
        Write-Host "Error: `$iLOCredentialCsv is not set. Set it in the variables section before using -TestCredentialCsv." -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
    if (-not (Test-Path -Path $iLOCredentialCsv)) {
        Write-Host "Error: iLO credential CSV file '$iLOCredentialCsv' not found." -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }

    $testMap = @{}
    $skipped = 0
    try {
        foreach ($row in (Import-Csv -Path $iLOCredentialCsv)) {
            if ([string]::IsNullOrWhiteSpace($row.IP) -or [string]::IsNullOrWhiteSpace($row.Username)) {
                Write-Warning "Skipping a row with a missing IP or Username (IP='$($row.IP)', Username='$($row.Username)')."
                $skipped++
                continue
            }
            $rowSecurePassword = ConvertTo-SecureString $row.Password -AsPlainText -Force
            $testMap[$row.IP.Trim()] = [System.Management.Automation.PSCredential]::new($row.Username.Trim(), $rowSecurePassword)
        }
    }
    catch {
        Write-Host "Error: Failed to read iLO credential CSV '$iLOCredentialCsv'. Status: $_" -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }

    Write-Host "`nCredential map loaded from '$iLOCredentialCsv':" -ForegroundColor Cyan
    if ($testMap.Count -gt 0) {
        $tableOutput = $testMap.GetEnumerator() | Sort-Object Name | Select-Object `
        @{N = 'IP'; E = { $_.Key } }, `
        @{N = 'Username'; E = { $_.Value.UserName } }, `
        @{N = 'PasswordLength'; E = { $_.Value.GetNetworkCredential().Password.Length } } `
        | Format-Table -AutoSize | Out-String
        ($tableOutput.TrimEnd() -split "`n") | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-Host "  (no valid credential rows found)" -ForegroundColor Yellow
    }

    Write-Host "`n  Loaded: $($testMap.Count) credential(s)  |  Skipped rows: $skipped" -ForegroundColor Cyan
    Write-Host "`nTest complete. No connection, discovery or onboarding was performed.`n" -ForegroundColor Green
    Read-Host -Prompt "Hit return to close"
    exit
}

# Build the iLO credential(s). Skipped in -Check mode (pre-flight discovery does not need iLO credentials).
#   - Per-iLO mode:  load the CSV (IP,Username,Password) into a hashtable keyed by IP address.
#   - Shared mode:   prompt once for the $iLOUserName password and apply it to every iLO.
$iLOCredentialMap = @{}     # IP -> PSCredential (per-iLO mode)
$iLOCredential = $null      # shared / fallback credential

if (-not $Check) {
    if ($iLOCredentialCsv) {
        if (-not (Test-Path -Path $iLOCredentialCsv)) {
            Write-Host "Error: iLO credential CSV file '$iLOCredentialCsv' not found." -ForegroundColor Red
            Read-Host -Prompt "Hit return to close"
            exit
        }
        try {
            foreach ($row in (Import-Csv -Path $iLOCredentialCsv)) {
                if ([string]::IsNullOrWhiteSpace($row.IP) -or [string]::IsNullOrWhiteSpace($row.Username)) {
                    Write-Warning "Skipping a row in '$iLOCredentialCsv' with a missing IP or Username."
                    continue
                }
                $rowSecurePassword = ConvertTo-SecureString $row.Password -AsPlainText -Force
                $iLOCredentialMap[$row.IP.Trim()] = [System.Management.Automation.PSCredential]::new($row.Username.Trim(), $rowSecurePassword)
            }
        }
        catch {
            Write-Host "Error: Failed to read iLO credential CSV '$iLOCredentialCsv'. Status: $_" -ForegroundColor Red
            Read-Host -Prompt "Hit return to close"
            exit
        }
        Write-Host "`nLoaded $($iLOCredentialMap.Count) per-iLO credential(s) from '$iLOCredentialCsv'." -ForegroundColor Green

        # Optional shared fallback for iLOs not listed in the CSV (leave the password blank to skip those iLOs)
        if ($iLOUserName) {
            Write-Host ""
            $iLOSecurePassword = Read-Host -AsSecureString "Enter fallback password for iLO account '$iLOUserName' (used for iLOs not in the CSV; leave blank to skip them)"
            if ($iLOSecurePassword.Length -gt 0) {
                $iLOCredential = [System.Management.Automation.PSCredential]::new($iLOUserName, $iLOSecurePassword)
            }
        }
    }
    else {
        # Shared credential mode: one account/password for every iLO
        Write-Host ""
        $iLOSecurePassword = Read-Host -AsSecureString "Enter password for iLO account '$iLOUserName'"
        $iLOCredential = [System.Management.Automation.PSCredential]::new($iLOUserName, $iLOSecurePassword)
    }
}

# Object to store the per-server status for the final report
$OnboardStatus = [System.Collections.ArrayList]::new()

#EndRegion

#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

try {
    # Check if already connected to COM in this region
    Get-HPECOMServer -Region $Region -Verbose:$Verbose -ErrorAction Stop | Out-Null
}
catch {
    # Not connected - connect to the HPE GreenLake workspace
    try {
        if ($SSOAccount) {
            Write-Verbose "Using passwordless SAML SSO authentication with account: $SSOAccount"
            $GLPConnection = Connect-HPEGL -PasswordlessSSOEmail $SSOAccount -Workspace $WorkspaceName -Verbose:$Verbose
        }
        else {
            Write-Verbose "Using standard / password-based SSO authentication with account: $HPEAccount"
            Write-Host ""
            $HPEAccountSecuredPassword = Read-Host -AsSecureString "Enter password for your HPE GreenLake account '$HPEAccount'"
            $GLPcredentials = New-Object System.Management.Automation.PSCredential ($HPEAccount, $HPEAccountSecuredPassword)
            $GLPConnection = Connect-HPEGL -Credential $GLPcredentials -Workspace $WorkspaceName -Verbose:$Verbose
        }

        if ($GLPConnection) {
            "`n[Workspace: {0}] - Successfully connected to the HPE GreenLake workspace." -f $WorkspaceName | Write-Host -ForegroundColor Green
        }
        else {
            "[Workspace: {0}] - Error connecting to the HPE GreenLake workspace. Please check your credentials and try again." -f $WorkspaceName | Write-Host -ForegroundColor Red
            Read-Host -Prompt "Hit return to close"
            exit
        }
    }
    catch {
        "[Workspace: {0}] - Error connecting to the HPE GreenLake workspace. Status: {1}" -f $WorkspaceName, $_ | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
}

#EndRegion

#Region -------------------------------------------------------- Checking COM instance -------------------------------------------------------------------------------------

try {
    $COMInstance = Get-HPEGLService -Name "Compute Ops Management" -Region $Region -ShowProvisioned -Verbose:$Verbose -ErrorAction Stop

    if ($COMInstance) {
        "[Workspace: {0}] - COM instance '{1}' successfully found." -f $WorkspaceName, $Region | Write-Host -f Green
    }
    else {
        "[Workspace: {0}] - Compute Ops Management '{1}' instance cannot be found. Please check your configuration and try again." -f $WorkspaceName, $Region | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
}
catch {
    "[Workspace: {0}] - Error checking Compute Ops Management '{1}' instance. Status: {2}" -f $WorkspaceName, $Region, $_ | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

#EndRegion

#Region -------------------------------------------------------- Checking Secure Gateway -------------------------------------------------------------------------------------

try {
    $SecureGatewayFound = Get-HPECOMAppliance -Region $Region -Name $SecureGatewayName -Type SecureGateway -Verbose:$Verbose -ErrorAction Stop
}
catch {
    "[Workspace: {0}] - Error checking Secure Gateway '{1}'. Status: {2}" -f $WorkspaceName, $SecureGatewayName, $_ | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

if ($SecureGatewayFound) {
    "[Workspace: {0}] - Secure Gateway '{1}' successfully found." -f $WorkspaceName, $SecureGatewayName | Write-Host -f Green
}
else {
    "[Workspace: {0}] - Secure Gateway '{1}' not found in the Compute Ops Management instance. Please add the Secure Gateway appliance before running this script." -f $WorkspaceName, $SecureGatewayName | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

#EndRegion

#Region -------------------------------------------------------- Secure Gateway server discovery -------------------------------------------------------------------------------------

if ($Rescan) {
    try {
        "`n[Secure Gateway: {0}] - Running a network discovery scan..." -f $SecureGatewayName | Write-Host -ForegroundColor Cyan
        Write-Warning "The scan duration depends on the size of the subnet behind the Secure Gateway. Scanning a large subnet can take a long time (from several minutes to much longer). Please be patient..."
        if ($Force) {
            Invoke-HPECOMSecureGatewayServerDiscovery -Region $Region -SecureGateway $SecureGatewayName -Force -Verbose:$Verbose -ErrorAction Stop | Out-Null
        }
        else {
            Invoke-HPECOMSecureGatewayServerDiscovery -Region $Region -SecureGateway $SecureGatewayName -Verbose:$Verbose -ErrorAction Stop | Out-Null
        }
    }
    catch {
        "[Secure Gateway: {0}] - Error running the discovery scan. Status: {1}" -f $SecureGatewayName, $_ | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
}

try {
    $DiscoveredServers = @(Get-HPECOMSecureGatewayServerDiscovery -Region $Region -SecureGateway $SecureGatewayName -Verbose:$Verbose -ErrorAction Stop)
}
catch {
    "[Secure Gateway: {0}] - Error retrieving discovered servers. Status: {1}" -f $SecureGatewayName, $_ | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

if (-not $DiscoveredServers -or $DiscoveredServers.Count -eq 0) {
    "`n[Secure Gateway: {0}] - No servers discovered. Run a discovery first (use -Rescan), or all reachable iLOs may already be connected to Compute Ops Management." -f $SecureGatewayName | Write-Host -ForegroundColor Yellow
    Disconnect-HPEGL | Out-Null
    Read-Host -Prompt "Hit return to close"
    exit
}

# Triage the discovered servers by firmware-update requirement
$ServersUnknown = @($DiscoveredServers | Where-Object { $_.iLOUpdateRequired -eq 'Unknown' })
$ServersToOnboard = @($DiscoveredServers | Where-Object { $_.iLOUpdateRequired -ne 'Unknown' })
$ServersNeedingFW = @($ServersToOnboard | Where-Object { $_.iLOUpdateRequired -eq 'Yes' })
$ServersReady = @($ServersToOnboard | Where-Object { $_.iLOUpdateRequired -eq 'No' })

# Show the discovery triage table
"`n-----------------------------------" | Write-Host -f Yellow
"SECURE GATEWAY DISCOVERY - TRIAGE" | Write-Host -f Yellow
"-----------------------------------" | Write-Host -f Yellow

$triageTable = $DiscoveredServers | Select-Object `
@{N = 'IP'; E = { $_.IP } }, `
@{N = 'iLO'; E = { $_.iLOGeneration } }, `
@{N = 'Firmware'; E = { $_.iLOVersion } }, `
@{N = 'UpdateRequired'; E = { $_.iLOUpdateRequired } }, `
@{N = 'Action'; E = {
        switch ($_.iLOUpdateRequired) {
            'No' { 'Ready - onboard as-is' }
            'Yes' { 'Onboard + auto firmware update' }
            'Unknown' { 'Skipped - condition unknown' }
        }
    }
} | Format-Table -AutoSize | Out-String
($triageTable.TrimEnd() -split "`n") | ForEach-Object { Write-Host "  $_" }

"`n  Discovered: {0}  |  Ready: {1}  |  Needs firmware update: {2}  |  Skipped (Unknown): {3}" -f `
    $DiscoveredServers.Count, $ServersReady.Count, $ServersNeedingFW.Count, $ServersUnknown.Count | Write-Host -ForegroundColor Cyan

# Record the skipped (Unknown) servers in the report
foreach ($srv in $ServersUnknown) {
    [void]$OnboardStatus.Add([PSCustomObject]@{
            IP                = $srv.IP
            iLOGeneration     = $srv.iLOGeneration
            iLOVersion        = $srv.iLOVersion
            iLOUpdateRequired = $srv.iLOUpdateRequired
            SecureGateway     = $SecureGatewayName
            Status            = "Skipped"
            Details           = "iLO condition could not be determined (iLOUpdateRequired = Unknown); not onboarded."
        })
}

#EndRegion

#Region -------------------------------------------------------- Checking COM subscription -------------------------------------------------------------------------------------

# Number of servers we intend to onboard (excludes the Unknown ones)
$OnboardCount = $ServersToOnboard.Count

try {
    $AvailableCOMSubscription = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server -Verbose:$Verbose -ErrorAction Stop

    if ($PromptForSubscriptionKey) {
        if (-not $AvailableCOMSubscription) {
            "[Workspace: {0}] - No subscriptions with available licenses found." -f $WorkspaceName | Write-Host -ForegroundColor Red
            Read-Host -Prompt "Hit return to close"
            exit
        }

        Write-Host "`n  Available COM subscriptions:" -ForegroundColor Cyan
        $tableOutput = $AvailableCOMSubscription | Select-Object `
        @{N = 'Key'; E = { $_.key } }, `
        @{N = 'Tier'; E = { $_.tier } }, `
        @{N = 'IsEval'; E = { $_.isEval } }, `
        @{N = 'Available'; E = { $_.AvailableQuantity } }, `
        @{N = 'TotalCount'; E = { $_.quantity } } `
        | Format-Table -AutoSize | Out-String
        ($tableOutput.TrimEnd() -split "`n") | ForEach-Object { Write-Host "  $_" }

        $SelectedSubscriptionKey = $null
        do {
            Write-Host ""
            $enteredKey = (Read-Host "  Enter the subscription key to use for onboarding").Trim()
            $matchedSub = $AvailableCOMSubscription | Where-Object { $_.key -eq $enteredKey }
            if ($matchedSub) {
                $SelectedSubscriptionKey = $enteredKey
                Write-Host "  Subscription key '$SelectedSubscriptionKey' selected (Tier: $($matchedSub.tier), Available licenses: $($matchedSub.AvailableQuantity))." -ForegroundColor Green
            }
            else {
                Write-Host "  Invalid subscription key. Please enter a key from the list above." -ForegroundColor Yellow
            }
        } while (-not $SelectedSubscriptionKey)

        $AvailableCOMSubscription = $matchedSub
        $TotalCount = [int]$matchedSub.AvailableQuantity
    }
    else {
        $AvailableCOMSubscription = $AvailableCOMSubscription | Where-Object { $_.tier -match $SubscriptionTier -and $_.isEval -eq $UseEval }
        $TotalCount = ($AvailableCOMSubscription | Select-Object -ExpandProperty AvailableQuantity) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $SelectedSubscriptionKey = $AvailableCOMSubscription | Select-Object -First 1 -ExpandProperty key
    }

    if ($AvailableCOMSubscription -and $TotalCount -ge $OnboardCount) {
        "`n[Workspace: {0}] - Sufficient licenses available ({1}) for the number of servers to onboard ({2})." -f $WorkspaceName, $TotalCount, $OnboardCount | Write-Host -ForegroundColor Green
    }
    elseif ($AvailableCOMSubscription -and $TotalCount -lt $OnboardCount) {
        "`n[Workspace: {0}] - Not enough licenses available ({1}) for the number of servers to onboard ({2}). Please check your Compute Ops Management subscription and try again." -f $WorkspaceName, $TotalCount, $OnboardCount | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
    else {
        "`n[Workspace: {0}] - No subscription with available license found for tier '{1}'. Please check your Compute Ops Management subscription and try again." -f $WorkspaceName, $SubscriptionTier | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
}
catch {
    "[Workspace: {0}] - Error checking Compute Ops Management subscription. Status: {1}" -f $WorkspaceName, $_ | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"
    exit
}

#EndRegion

#Region -------------------------------------------------------- Checking COM location (if defined) -------------------------------------------------------------------------------------

if ($LocationName) {
    try {
        $LocationFound = Get-HPEGLLocation -Name $LocationName -Verbose:$Verbose -ErrorAction Stop
    }
    catch {
        "[Workspace: {0}] - Error checking workspace location. Status: {1}" -f $WorkspaceName, $_ | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }

    if (-not $LocationFound) {
        "[Workspace: {0}] - Location '{1}' not found in the HPE GreenLake workspace. Please create the location before running this script." -f $WorkspaceName, $LocationName | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
    else {
        "[Workspace: {0}] - Location '{1}' successfully found." -f $WorkspaceName, $LocationName | Write-Host -ForegroundColor Green
    }
}

#EndRegion

#Region -------------------------------------------------------- Check mode (pre-flight only) -------------------------------------------------------------------------------------

if ($Check) {
    # Record the would-be onboarding intent for each ready / needs-FW server
    foreach ($srv in $ServersToOnboard) {
        [void]$OnboardStatus.Add([PSCustomObject]@{
                IP                = $srv.IP
                iLOGeneration     = $srv.iLOGeneration
                iLOVersion        = $srv.iLOVersion
                iLOUpdateRequired = $srv.iLOUpdateRequired
                SecureGateway     = $SecureGatewayName
                Status            = "Ready"
                Details           = if ($srv.iLOUpdateRequired -eq 'Yes') { "Would onboard with an automatic iLO firmware update." } else { "Would onboard as-is (firmware already compliant)." }
            })
    }

    "`n[Secure Gateway: {0}] - Pre-flight check complete. {1} server(s) ready to onboard, {2} skipped (Unknown). No changes were made." -f $SecureGatewayName, $OnboardCount, $ServersUnknown.Count | Write-Host -ForegroundColor Cyan

    $Date = Get-Date -Format "yyyyMMdd_HHmm"
    $ScriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $reportFile = Join-Path $ScriptDirectory "SG_Discovery_Check_Status_$Date.csv"
    $OnboardStatus | Export-Csv -Path $reportFile -NoTypeInformation -Force -Encoding UTF8
    Write-Host "`n📄 Status report exported to: $reportFile`n" -ForegroundColor Cyan

    Disconnect-HPEGL | Out-Null
    Read-Host -Prompt "Hit return to close"
    exit
}

#EndRegion

#Region -------------------------------------------------------- Onboarding via Secure Gateway -------------------------------------------------------------------------------------

if ($OnboardCount -eq 0) {
    "`n[Secure Gateway: {0}] - No servers eligible for onboarding (all discovered servers were 'Unknown' and skipped)." -f $SecureGatewayName | Write-Host -ForegroundColor Yellow
}
else {

    # Build the splat for Connect-HPECOMSecureGatewayDiscoveredServer with only the optional values that are set.
    # Note: IloCredential is added below only in shared-credential mode; in per-iLO mode each server carries its own.
    $onboardParams = @{
        SubscriptionKey = $SelectedSubscriptionKey
    }
    if ($Dns) { $onboardParams.Dns = $Dns }
    if ($Ntp) { $onboardParams.Ntp = $Ntp }
    if ($LocationName) { $onboardParams.LocationName = $LocationName }
    if ($ServiceDeliveryContact) { $onboardParams.ServiceDeliveryContact = $ServiceDeliveryContact }
    if ($Tags) { $onboardParams.Tags = $Tags }
    if ($Force) { $onboardParams.Force = $true }
    if ($WhatIf) { $onboardParams.WhatIf = $true }

    # Resolve the iLO credential for each server.
    #   - Per-iLO mode (CSV loaded): attach an 'IloCredential' property to each server, matched by IP, with optional
    #     shared fallback. Servers with no credential at all are skipped and reported.
    #   - Shared mode: pass a single -IloCredential on the command line for all servers.
    $ServersForOnboarding = [System.Collections.ArrayList]::new()

    if ($iLOCredentialMap.Count -gt 0) {
        foreach ($srv in $ServersToOnboard) {
            $cred = $iLOCredentialMap[$srv.IP]
            if (-not $cred) { $cred = $iLOCredential }   # shared fallback (may be $null)
            if (-not $cred) {
                Write-Warning ("iLO '{0}': No credential found in the CSV and no shared fallback provided; skipping." -f $srv.IP)
                [void]$OnboardStatus.Add([PSCustomObject]@{
                        IP                = $srv.IP
                        iLOGeneration     = $srv.iLOGeneration
                        iLOVersion        = $srv.iLOVersion
                        iLOUpdateRequired = $srv.iLOUpdateRequired
                        SecureGateway     = $SecureGatewayName
                        Status            = "Skipped"
                        Details           = "No iLO credential available (not in the CSV and no shared fallback provided)."
                    })
                continue
            }
            $srv | Add-Member -NotePropertyName IloCredential -NotePropertyValue $cred -Force
            [void]$ServersForOnboarding.Add($srv)
        }
    }
    else {
        # Shared credential mode
        $onboardParams.IloCredential = $iLOCredential
        foreach ($srv in $ServersToOnboard) { [void]$ServersForOnboarding.Add($srv) }
    }

    if ($ServersForOnboarding.Count -eq 0) {
        "`n[Secure Gateway: {0}] - No servers have a usable iLO credential; nothing to onboard." -f $SecureGatewayName | Write-Host -ForegroundColor Yellow
    }
    else {

        "`n[Secure Gateway: {0}] - Submitting onboarding for {1} server(s)..." -f $SecureGatewayName, $ServersForOnboarding.Count | Write-Host -ForegroundColor Cyan

        try {
            # Pipe the eligible (non-Unknown, credentialed) discovered servers to the batch onboarding cmdlet
            $ServersForOnboarding | Connect-HPECOMSecureGatewayDiscoveredServer @onboardParams -Verbose:$Verbose -ErrorAction Stop | Out-Null

            if ($WhatIf) {
                "`n[Secure Gateway: {0}] - WhatIf preview complete. No changes were made." -f $SecureGatewayName | Write-Host -ForegroundColor Cyan
                Disconnect-HPEGL | Out-Null
                Read-Host -Prompt "Hit return to close"
                exit
            }

            # Record onboarding intent for each eligible server (the batch job result is region-wide, not per-IP)
            foreach ($srv in $ServersForOnboarding) {
                [void]$OnboardStatus.Add([PSCustomObject]@{
                        IP                = $srv.IP
                        iLOGeneration     = $srv.iLOGeneration
                        iLOVersion        = $srv.iLOVersion
                        iLOUpdateRequired = $srv.iLOUpdateRequired
                        SecureGateway     = $SecureGatewayName
                        Status            = "Submitted"
                        Details           = if ($srv.iLOUpdateRequired -eq 'Yes') { "Onboarding submitted with an automatic iLO firmware update." } else { "Onboarding submitted (firmware already compliant)." }
                    })
            }

            "[Secure Gateway: {0}] - Onboarding job completed." -f $SecureGatewayName | Write-Host -ForegroundColor Green
        }
        catch {
            "[Secure Gateway: {0}] - Error during onboarding. Status: {1}" -f $SecureGatewayName, $_ | Write-Host -ForegroundColor Red
            foreach ($srv in $ServersForOnboarding) {
                [void]$OnboardStatus.Add([PSCustomObject]@{
                        IP                = $srv.IP
                        iLOGeneration     = $srv.iLOGeneration
                        iLOVersion        = $srv.iLOVersion
                        iLOUpdateRequired = $srv.iLOUpdateRequired
                        SecureGateway     = $SecureGatewayName
                        Status            = "Failed"
                        Details           = "Onboarding batch job failed: $_"
                    })
            }
        }
    }
}

#EndRegion

#Region -------------------------------------------------------- Post-onboard verification -------------------------------------------------------------------------------------

if ($OnboardCount -gt 0) {
    try {
        "`n[Workspace: {0}] - Verifying onboarded servers in Compute Ops Management..." -f $WorkspaceName | Write-Host -ForegroundColor Cyan
        $COMServers = @(Get-HPECOMServer -Region $Region -Verbose:$Verbose -ErrorAction Stop)

        foreach ($entry in ($OnboardStatus | Where-Object { $_.Status -eq 'Submitted' })) {
            $match = $COMServers | Where-Object { $_.iLOIPAddress -eq $entry.IP }
            if ($match) {
                $entry.Status = "Success"
                $entry.Details = "Server present in Compute Ops Management (SN: $($match.serialNumber))."
            }
            else {
                $entry.Status = "Warning"
                $entry.Details = "Onboarding submitted but the server is not yet visible in Compute Ops Management. It may still be connecting (firmware updates reboot the iLO and can take several minutes)."
            }
        }
    }
    catch {
        Write-Warning "Could not verify onboarded servers: $_"
    }
}

#EndRegion

#Region -------------------------------------------------------- Generating output -------------------------------------------------------------------------------------

$ScriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Date = Get-Date -Format "yyyyMMdd_HHmm"
$reportFile = Join-Path $ScriptDirectory "SG_Onboarding_Status_$Date.csv"

$successCount = ($OnboardStatus | Where-Object { $_.Status -eq "Success" }).Count
$submittedCount = ($OnboardStatus | Where-Object { $_.Status -eq "Submitted" }).Count
$warningCount = ($OnboardStatus | Where-Object { $_.Status -eq "Warning" }).Count
$failureCount = ($OnboardStatus | Where-Object { $_.Status -eq "Failed" }).Count
$skippedCount = ($OnboardStatus | Where-Object { $_.Status -eq "Skipped" }).Count
$totalCount = ($OnboardStatus | Measure-Object).Count

Write-Host "`nOnboarding summary: $successCount succeeded, $submittedCount submitted, $failureCount failed, $warningCount warnings, $skippedCount skipped (Total: $totalCount)`n" -ForegroundColor Cyan

if ($failureCount -eq 0 -and $warningCount -eq 0 -and ($successCount + $submittedCount) -gt 0) {
    Write-Host "✅ Secure Gateway onboarding completed successfully!" -ForegroundColor Green
    Write-Host "   Servers have been connected to Compute Ops Management in the '$Region' region through '$SecureGatewayName'." -ForegroundColor Cyan
}
else {
    Write-Host "⚠️  Secure Gateway onboarding completed with items to review!" -ForegroundColor Yellow
    Write-Host "   Please review the detailed status report below." -ForegroundColor Yellow
}

$OnboardStatus | Export-Csv -Path $reportFile -NoTypeInformation -Force -Encoding UTF8
Write-Host "`n📄 Status report exported to: $reportFile`n" -ForegroundColor Cyan

#EndRegion

Disconnect-HPEGL | Out-Null
Read-Host -Prompt "Hit return to close"
