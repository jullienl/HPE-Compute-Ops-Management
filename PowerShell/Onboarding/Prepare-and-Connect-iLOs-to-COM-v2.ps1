<#
.SYNOPSIS
Prepare and Onboard HPE iLOs to Compute Ops Management (COM) with Automated Configuration and Firmware Compliance.

July 1, 2025:
 - Added general improvements and bug fixes to the entire script.
 - Added special logic for A55/A56 server hardware platforms (Gen11) to handle compatibility between iLO firmware and system ROM versions, per customer advisory: https://support.hpe.com/hpesc/public/docDisplay?docId=emr_na-a00143446en_us.
 - Enhanced error handling and streamlined logging for clearer output and easier troubleshooting.
 - Fixed CSV export to always generate the file in the script directory and prevent duplicate reports.
 - The authenticity and integrity verification output for the modules has been streamlined to display only essential information and critical alerts.

June 10, 2025:
 - Fixed a bug where the script could select a COM activation key without an associated subscription key, which caused license assignment failures during onboarding. The script now ensures that only activation keys with valid subscription assignments are used.
 - Fixed a bug where the script did not always generate a new COM activation key with a valid subscription key, leading to onboarding failures. The script now always generates a new activation key that is properly associated with a subscription.
 - The script now verifies that the COM activation key will remain valid for at least 10 minutes before use, preventing onboarding failures due to imminent key expiration.

 June 4, 2025:
 - Improved session reliability: The script now actively maintains the HPE GreenLake session throughout execution to prevent timeouts that could disrupt operations.
 - Enhanced documentation: Added guidance in the script header for optimizing performance during large-scale server onboarding and reducing firmware update delays.
 - Module management improvements: The script always installs and uses the latest version of HPEiLOCmdlets, ensuring compatibility with PowerShell 7.5.0 and resolving known PSCredential login issues.
 - Security enhancements: The script verifies the authenticity and integrity of the HPEiLOCmdlets and HPECOMCmdlets modules before use (on Windows systems only) to ensure only trusted code is executed.
 - Changed the timing of COM activation key generation: The activation key is now generated just before onboarding each iLO, and its expiration time is set to 1 day (increased from the default 1 hour) to provide more flexibility and reduce the risk of key expiration during large onboarding operations.


.DESCRIPTION
This PowerShell script automates the process of connecting HPE Gen10 and later servers to HPE Compute Ops Management (COM).
It also allows you to prepare and configure iLO settings, such as DNS, NTP, and firmware updates, before connecting the servers to COM. 

This preparation is essential to ensure that iLOs are ready for COM and can effectively communicate and be managed by the platform, it includes:
- Setting up DNS: To ensure iLO can reach the cloud platform
- Setting up NTP: To ensure the date and time of iLO are correct
- Updating iLO firmware: To meet the COM minimum iLO firmware requirement to support adding servers with a COM activation key (iLO5 3.09 or later, or iLO6 1.64 or later).

The script requires all iLOs to use the same iLO account username and password and a CSV file that contains the list of iLO IP addresses or resolvable hostnames to be connected to COM.

To see a demonstration of this script in action, watch the following video: https://youtu.be/ZV0bmqmODmU.

The script performs the following actions:
1. Connects to HPE GreenLake.
2. Checks the COM instance.
3. Checks the Secure Gateway (if defined)
4. Checks the COM subscription.
5. Generates a COM activation key.
6. Prepares and configures iLO settings:
    - DNS: Sets DNS servers (if specified) to ensure iLOs can reach the cloud platform
    - SNTP: Sets SNTP servers (if specified) to ensure the date and time of iLOs are correct, crucial for securing the mutual TLS (mTLS) connections between COM and iLO.
    - Firmware: Updates iLO firmware (if needed) to ensure the iLO firmware meets the COM minimum requirement to support onboarding via COM activation key.
        - If the minimum firmware is not met, the script updates the firmware using the iLO firmware flash file specified.
7. Connects iLOs to COM with the following options:
    - Connects iLOs directly (if no proxy settings are specified).
    - Connects iLOs via a web proxy or secure gateway (if specified).
    - Connects iLOs via a web proxy and credentials (if specified).
8. Assigns tags and location to devices (if specified).
9. Generates and exports a CSV file with the status of the operation, including iLO and server details, and the results of each configuration step.
 
If location and tags are defined in the variables section, each server corresponding to the iLO defined in the CSV file is assigned to the same location in the HPE GreenLake workspace and with the same tags.

The script can be run with the following parameters:
- `Check`: Switch to check the COM instance, subscription, location, and iLO settings without making any changes to the iLO settings. Useful for pre-checking before onboarding.
- `SkipCertificateValidation`: Switch to bypass certificate validation when connecting to iLO. Use with caution. This switch is only intended to be used against known hosts using a self-signed certificate.
- `DisconnectiLOfromOneView`: Switch to disconnect the iLO from HPE OneView before onboarding to COM.
- `Verbose`: Switch to enable verbose output.

Note: The script requires the HPEiLOCmdlets and HPECOMCmdlets PowerShell modules to connect to iLOs and HPE GreenLake, respectively. The two modules are automatically installed if not already present.


Prerequisites:
- PowerShell 7.
- PowerShell Modules:
    - HPEiLOCmdlets (https://www.powershellgallery.com/packages/HPEiLOCmdlets)
        - Required for connecting to HPE iLOs and performing all iLO configuration and management tasks.
        - The script automatically installs and uses the latest available version to ensure compatibility and access to the newest features and bug fixes.
        - Minimum supported version: 5.1.0.0 (earlier versions are not supported due to known issues).
        - On Windows systems, the script verifies the authenticity and integrity of the module before use to ensure only trusted code is executed.
    - HPECOMCmdlets (https://www.powershellgallery.com/packages/HPECOMCmdlets)
        - Required for connecting to HPE GreenLake and Compute Ops Management, and for performing all related configuration and management tasks.
        - The script automatically installs and uses the latest available version to ensure compatibility and access to the newest features and bug fixes.
        - On Windows systems, the script verifies the authenticity and integrity of the module before use to ensure only trusted code is executed.
- Ensure network access to both HPE GreenLake and all target HPE iLOs.
- Verify that the servers to be onboarded are not already assigned to another COM service instance in any workspace.
- HPE GreenLake user account requirements:
    - Must have the Workspace Administrator or Workspace Operator role.
    - If using custom roles, the account must have "Devices and Subscription Service Edit" permission.
    - Must also have the COM Administrator or Operator role.
- HPE GreenLake environment must have:
    - A workspace with a provisioned COM service instance.
    - An active COM subscription with sufficient licenses for all iLOs listed in the CSV file.
    - A defined location (required for automated HPE support case creation and services).
    - A Secure Gateway added to the COM instance (if applicable).
- iLO requirements:
    - Each iLO must have a reachable IP address.
    - An iLO account with Administrator privileges, or at minimum, the "Configure iLO Settings" privilege.
    - The password for the iLO account.

How to use:
1. Create a CSV file with the list of iLO IP addresses or resolvable hostnames to be connected to COM. The CSV file must have a header "IP" and contain the iLO IP addresses or hostnames in the first column.
    - Example:
        IP
        192.168.0.20
        192.168.0.21
        192.168.1.56
    - Note: The first line is the header and must be "IP".
2. Update the variables in the script as needed.
    - Path to the CSV file containing the list of iLO IP addresses or resolvable hostnames
    - Path to the iLO firmware flash files for iLO5 and iLO6.
    - Username of the iLO account.
    - DNS servers to configure in iLO (optional).
    - SNTP servers to configure in iLO (optional).
    - iLO Web Proxy or Secure Gateway settings (optional). Note that you cannot use both web proxy variables and Secure Gateway variables simultaneously! 
    - HPE GreenLake account with HPE GreenLake and COM administrative privileges.
    - HPE GreenLake workspace name where the COM instance is provisioned.
    - Region where the COM instance is provisioned.
    - Location name where the devices will be assigned (optional).
    - Tags to assign to devices (optional).
3. Run the script in a PowerShell 7 environment.
4. Review the output to ensure that the iLOs are successfully connected to COM.

Note: 
- The script can be run multiple times with different CSV files to assign different tags or locations to servers.
- Firmware updates can take significantly longer when the iLO firmware binary is not located on the local network, due to slower file transfer speeds. 
  To optimize the process, make sure the iLO firmware binary is accessible on the same local network as your iLOs. 
  This typically allows updates to complete more quickly and significantly reduces overall delays.
- To accelerate onboarding through parallel processing, consider splitting your list of iLOs into multiple CSV files and running several instances of the script simultaneously, each with a different CSV file.

.EXAMPLE

Example 1: Pre-checking before onboarding

```powershell
.\Prepare-and-Connect-iLOs-to-COM-v2.ps1 -Check
```

Output:
```

    Enter password for iLO account 'administrator': ********
    Enter password for your HPE GreenLake account 'email@domain.com': ********
    [Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.

    ------------------------------
    COM CONFIGURATION CHECK STATUS
    ------------------------------
    - Provisionned instance: OK
    - Subscription: OK                                                                                                    
            - Status: Sufficient licenses available (19) for the number of iLOs (3).
    - Location: Failed
            - Status: Location 'Nice' not found in the HPE GreenLake workspace. Please create the location before running this script.

    ------------------------------
    iLO CONFIGURATION CHECK STATUS
    ------------------------------

    - [192.168.0.20] (v3.08 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004G)
            - DNS: Warning
                    - Current: None
                    - Missing: 192.168.2.1, 192.168.2.3
            - SNTP: Warning
                    - Current: None
                    - Missing: 1.1.1.1, 2.2.2.2
            - iLO firmware: Warning
                    - Current: 3.08
                    - Required: 3.09 or later
            - iLO connection to COM: Disconnected
            - Tags: Warning
                    - Current: None                                                                                        
                    - Missing: Country=FR, App=AI, Department=IT
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    - [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
            - DNS: Ok
                    - Current: 192.168.2.1, 192.168.2.3
                    - Missing: None
            - SNTP: Ok
                    - Current: 1.1.1.1, 2.2.2.2
                    - Missing: None
            - iLO firmware: OK
                    - Current: 3.1
                    - Required: 3.09 or later
            - iLO connection to COM: Disconnected
            - Tags: Warning
                    - Current: None                                                                                        
                    - Missing: Country=FR, App=AI, Department=IT
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    - [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
            - DNS: Ok
                    - Current: 192.168.2.1, 192.168.2.3
                    - Missing: None
            - SNTP: Warning
                    - Current: None
                    - Missing: 1.1.1.1, 2.2.2.2
            - iLO firmware: Warning
                    - Current: 1.62
                    - Required: 1.64 or later
            - iLO connection to COM: Disconnected
            - Tags: Warning
                    - Current: None                                                                                        
                    - Missing: Country=FR, App=AI, Department=IT
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    The status of the check has been exported to 'Z:\Onboarding\iLO_Check_Status_20250227_1011.csv'
    Hit return to close:

```

.EXAMPLE

Example 2: Onboarding

```powershell
.\Prepare-and-Connect-iLOs-to-COM-v2.ps1  
```

Output:
```
    Enter password for iLO account 'administrator': ********
    Enter password for your HPE GreenLake account 'email@domain.com': ********
    [Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.
    [Workspace: HPE Mougins] - COM instance 'eu-central' successfully found.
    [Workspace: HPE Mougins] - Sufficient licenses available (19) for the number of iLOs (3).                               
    [Workspace: HPE Mougins] - Successfully generated COM activation key '3CJ7S2DH8' for region 'eu-central'.

    - [192.168.0.20] (v3.08 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004G)
            - DNS: InProgress
                    - Status: DNS settings set successfully!
            - SNTP: InProgress
                    - Status: SNTP settings set successfully. Message: ResetRequired
                    - Status: Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed...
                    - Status: iLO reset has been detected. Waiting for iLO to be back online...
                    - Status: iLO SNTP settings updated successfully and iLO is back online.
                    - Status: Reconnecting to iLO...
            - iLO firmware: InProgress
                    - Status: iLO5 firmware update in progress as firmware is lower than v3.09...
                    - Status: iLO firmware must be activated. Waiting for the reset to be performed...
                    - Status: iLO reset has been detected. Waiting for iLO to be back online...
                    - Status: iLO firmware updated successfully and iLO is back online.
                    - Status: Reconnecting to iLO...
                    - Status: Waiting for iLO to be ready for COM connection...
                    - Status: iLO is ready for COM connection.
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress                                                                                             
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: Location assigned successfully.

    - [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
            - DNS: Skipped
                    - Status: DNS configuration is not required as the DNS servers are already defined.
            - SNTP: Skipped
                    - Status: SNTP configuration is not required as the SNTP servers are already defined.
            - iLO firmware: Skipped
                    - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
            - Tags: InProgress
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: Location assigned successfully.

    - [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
            - DNS: Skipped
                    - Status: DNS configuration is not required as the DNS servers are already defined.
            - SNTP: Skipped
                    - Status: SNTP configuration is not required as the SNTP servers are already defined.
            - iLO firmware: Skipped
                    - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
            - DNS: Skipped
                    - Status: DNS configuration is not required as the DNS servers are already defined.
            - SNTP: Skipped
                    - Status: SNTP configuration is not required as the SNTP servers are already defined.
            - iLO firmware: Skipped
                    - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
            - Tags: InProgress
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: Location assigned successfully.

    - [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
            - DNS: Skipped
                    - Status: DNS configuration is not required as the DNS servers are already defined.
            - SNTP: InProgress
                    - Status: SNTP settings set successfully. Message: ResetRequired
                    - Status: Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed...
                    - Status: iLO reset has been detected. Waiting for iLO to be back online...
                    - Status: iLO SNTP settings updated successfully and iLO is back online.
                    - Status: Reconnecting to iLO...
            - iLO firmware: InProgress
                    - Status: iLO6 firmware update in progress as firmware is lower than v1.64...
                    - Status: iLO firmware must be activated. Waiting for the reset to be performed...!
                    - Status: iLO reset has been detected. Waiting for iLO to be back online...
                    - Status: iLO is back online and iLO firmware updated successfully.
                    - Status: Reconnecting to iLO...
                    - Status: Waiting for iLO to be ready for COM connection...
                    - Status: iLO is ready for COM connection.
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: Location assigned successfully.

    Operation completed successfully! All servers have been configured and connected to the Compute Ops Management instance in the 'eu-central' region.
    The status of the operation has been exported to 'Z:\Onboarding\iLO_Onboarding_Status_20250227_1046.csv'
    Hit return to close:

```
.NOTES

Note: The script generates a CSV file with the status of the operation, including the iLO IP address, hostname, serial number, iLO generation, iLO firmware version, server model, and the status of the configuration and connection to COM.

Disclaimer: The script is provided as-is and is not officially supported by HPE. It is recommended to test the script in a non-production environment before running it in a production environment. Use the script at your own risk.



  Author: lionel.jullien@hpe.com
  Date:   Feb 2025
  Script source: https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1
    
#################################################################################
#        (C) Copyright 2017 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>


param (
    
    [switch]$Check,
    
    [switch]$SkipCertificateValidation,
    
    [switch]$DisconnectiLOfromOneView,

    [switch]$Verbose
    
)

#Region -------------------------------------------------------- Variables definition -----------------------------------------------------------------------------------------

# Path to the CSV file containing the list of iLO IP addresses or resolvable hostnames
$iLOcsvPath = "Z:\Onboarding\iLOs.csv"

# Path to the iLO firmware flash files for iLO5 and iLO6
$iLO5binFile = "Z:\Onboarding\ilo5_309.bin"
$iLO6binFile = "Z:\Onboarding\ilo6_166.bin"

# Username of the iLO account
$iLOUserName = "administrator"

# DNS servers to configure in iLO (optional)
$DNSservers = , @("192.168.2.1", "192.168.2.3")
$DNStypes = , @("Primary", "Secondary")

# SNTP servers to configure in iLO (optional)
$SNTPservers = , @("1.1.1.1", "2.2.2.2")

# Note: You cannot use both web proxy variables and Secure Gateway variables simultaneously! 
# iLO Web Proxy (optional) 
# $WebProxyServer = "web-proxy.domain.com"
# $WebProxyPort = "8088"
# $WebProxyUsername = "myproxyuser"
# $WebProxyPassword = (Read-Host -AsSecureString "Enter password for proxy account '$WebProxyUsername'")

# Secure Gateway FQDN (optional)
# $SecureGateway = "sg01.domain.lab"

# HPE GreenLake account with HPE GreenLake and Compute Ops Management administrative privileges
# Non-SAML OKTA user account:
$HPEAccount = "email@domain.com"
$OktaSSOEmail = $false 
# SAML OKTA user account:
# $HPEAccount = "firstname.lastname@hpe.com"
# $OktaSSOEmail = $true 

# HPE GreenLake workspace name where the Compute Ops Management instance is provisioned
$WorkspaceName = "HPE"

# Region where the Compute Ops Management instance is provisioned
$Region = "eu-central"

# Location name where the devices will be assigned (optional)
# (Required for automated HPE support case creation and services)
$LocationName = "Mougins"

# Tags to assign to devices (optional)
$Tags = "Country=FR, App=AI, Department=IT" 

#EndRegion

#Region -------------------------------------------------------- Preparation -----------------------------------------------------------------------------------------

# Check if the script is running in PowerShell 7 
if ($PSVersionTable.PSVersion.Major -ne 7) {
    Write-Host "Error: PowerShell 7 is required to run this script. Please launch this script in a PowerShell 7 session and try again." -ForegroundColor Red
    Read-Host -Prompt "Hit return to close"    
    exit
}

# Ask for the iLO account password
$iLOSecuredPassword = (Read-Host -AsSecureString "Enter password for iLO account '$iLOUserName'")

# Importing iLO list
if (-not (Test-Path $iLOcsvPath)) {
    "Error: iLO CSV file '{0}' not found. Please check your CSV file path and try again." -f $iLOcsvPath | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}
else {
    $iLOs = Import-Csv -Path $iLOcsvPath
}

# Check if iLO firmware files are present
if ($iLO5binFile) {
    if (-not (Test-Path $iLO5binFile)) {
        "Error: iLO5 firmware file '{0}' not found. Please check your iLO5 firmware file path and try again." -f $iLO5binFile | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }
}

if ($iLO6binFile) {
    if (-not (Test-Path $iLO6binFile)) {
        "Error: iLO6 firmware file '{0}' not found. Please check your iLO6 firmware file path and try again." -f $iLO6binFile | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }
}

# Creating object to store status of the operation
$iLOPreparationStatus = [System.Collections.ArrayList]::new()

# Set Verbose preference
if ($Verbose) { $VerbosePreference = "Continue" }
else { $VerbosePreference = "SilentlyContinue" }

#EndRegion

#Region -------------------------------------------------------- Modules to install --------------------------------------------------------------------------------------------

# Check if PSGallery repository is registered and install HPEiLOCmdlets and HPECOMCmdlets modules
if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository..."
    Register-PSRepository -Default
}

# Check if HPEiLOCmdlets module is installed and ensure the latest version is installed
If (-not (Get-Module HPEiLOCmdlets -ListAvailable)) {
    Write-Host "HPEiLOCmdlets module not found, installing now..."

    Try {
        Install-Module -Name HPEiLOCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop
    }
    catch {
        $_
        Read-Host "Hit return to close"
        exit
    }
}
else {
    $installedModuleVersion = [version](Get-Module HPEiLOCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Version)
    $latestVersion = [version](Find-Module -Name HPEiLOCmdlets | Select-Object -ExpandProperty Version)

    if ($installedModuleVersion -lt $latestVersion) {
        "Version of HPEiLOCmdlets module installed '{0}' is outdated. Updating now to '{1}'..." -f $installedModuleVersion, $latestVersion | Write-Host -f Yellow
        
        Try {
            Install-Module -Name HPEiLOCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop
            # Uninstall the old version of the module
            Uninstall-Module -Name HPEiLOCmdlets -RequiredVersion $installedModuleVersion -Force -ErrorAction SilentlyContinue
        }
        catch {
            $_
            Read-Host "Hit return to close"
            exit
        }
    }
}

# Check if HPECOMCmdlets module is installed and ensure the latest version is installed
If (-not (Get-Module HPECOMCmdlets -ListAvailable)) {
    Write-Host "HPECOMCmdlets module not found, installing now..."
    Try {
        Install-Module -Name HPECOMCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop
    }
    catch {
        $_
        Read-Host "Hit return to close"
        exit
    }
}
else {
    $installedModuleVersion = [version](Get-Module HPECOMCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Version)
    $latestVersion = [version](Find-Module -Name HPECOMCmdlets | Select-Object -ExpandProperty Version)

    if ($installedModuleVersion -lt $latestVersion) {
        "Version of HPECOMCmdlets module installed '{0}' is outdated. Updating now to '{1}'..." -f $installedModuleVersion, $latestVersion | Write-Host -f Yellow

        Try {
            Install-Module -Name HPECOMCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop
            # Uninstall the old version of the module
            Uninstall-Module -Name HPECOMCmdlets -RequiredVersion $installedModuleVersion -Force -ErrorAction SilentlyContinue

        }
        catch {
            $_
            Read-Host "Hit return to close"
            exit
        }
    }
}

#EndRegion

#Region -------------------------------------------------------- Verification of the HPEiLOCmdlets module's authenticity and integrity before use. --------------------------------------------------------------------------------------------

# Ensure the module is installed
$module = Get-Module -Name HPEiLOCmdlets -ListAvailable
if (-not $module) {
    "'HPEiLOCmdlets' module is not installed. Please install it using 'Install-Module -Name HPEiLOCmdlets'." | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

if ($isWindows) {

    # Verify the authenticity and integrity of the HPEiLOCmdlets module
    "`nVerifying the authenticity and integrity of the HPEiLOCmdlets module..." | Write-Host -f Cyan

    # Get module path
    $modulePath = (Get-Module -Name HPEiLOCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 ).ModuleBase

    if (-not (Test-Path $modulePath)) {
        "Module path not found: {0}" -f $modulePath | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Check module metadata
    $psd1Path = Join-Path $modulePath "HPEiLOCmdlets.psd1"
    if (-not (Test-Path $psd1Path)) {
        "Module manifest (.psd1) not found at: {0}" -f $psd1Path | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    $metadata = Import-PowerShellDataFile -Path $psd1Path
    if ($metadata.CompanyName -notlike "*Hewlett Packard Enterprise*" -and $metadata.Author -notlike "*Hewlett Packard Enterprise*") {
        "Module metadata does not match HPE. CompanyName: {0}, Author: {1}" -f $metadata.CompanyName, $metadata.Author | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Get all relevant module files (.psm1, .psd1, .dll)
    $files = Get-ChildItem -Path $modulePath -Recurse -Include *.psm1, *.psd1, *.ps1xml, *.dll -ErrorAction SilentlyContinue
    if (-not $files) {
        "No relevant module files (.psm1, .psd1, .ps1xml, .dll) found in: {0}" -f $modulePath | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Verify digital signatures and certificates
    foreach ($file in $files) {

        # Skip log4net.dll file
        # log4net.dll is a third-party library used by HPEiLOCmdlets and is not signed by HPE but by Microsoft.
        if ($file.Name -eq "log4net.dll") {
            "Verifying file: " | Write-Host -NoNewline
            "$($file.Name) (third-party library)" | Write-Host -f Cyan
            
            try {
                # Get file version info
                $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName)
                
                if ($versionInfo.CompanyName -like "*Apache Software Foundation*" -and 
                    $versionInfo.ProductName -like "*log4net*") {
                    # "File verification: " | Write-Host -NoNewline
                    # "Valid log4net library" | Write-Host -f Green
                    # "Company: {0}" -f $versionInfo.CompanyName | Write-Host -f Green
                    # "Product: {0}" -f $versionInfo.ProductName | Write-Host -f Green
                    # "Version: {0}" -f $versionInfo.FileVersion | Write-Host -f Green
                }
                else {
                    "Unexpected file properties for log4net.dll" | Write-Host -f Red
                    # "Company: {0}" -f $versionInfo.CompanyName | Write-Host -f Red
                    # "Product: {0}" -f $versionInfo.ProductName | Write-Host -f Red
                    Read-Host -Prompt "Hit return to close"
                    exit
                }
            }
            catch {
                "Could not read file version info for log4net.dll: {0}" -f $_.Exception.Message | Write-Host -f Yellow
            }
            continue
        }

        "Verifying file: " | Write-Host -NoNewline
        "$($file.Name)" | Write-Host -f Cyan
        
        # Check digital signature
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName

        # Verify the signature is valid (this includes timestamping validation)
        if ($signature.Status -eq "Valid") {
            # "Digital signature status: " | Write-Host -NoNewline
            # "Valid" | Write-Host -f Green
            
            # Verify signer is HPE (only for signed files)
            if ($signature.SignerCertificate.Subject -notlike "*Hewlett Packard Enterprise*") {
                # "Signer: " | Write-Host -NoNewline
                # "{0}" -f $signature.SignerCertificate.Subject | Write-Host -f Red
                "The module is not signed by Hewlett Packard Enterprise (HPE). Aborting operation for security reasons." | Write-Host -f Red
                Read-Host -Prompt "Hit return to close"
                exit
            }
            # else {
            #     "Signer: " | Write-Host -NoNewline
            #     "Hewlett Packard Enterprise (verified)" | Write-Host -f Green
            # }
        }
        elseif ($signature.Status -eq "NotSigned") {
            # "Digital signature status: " | Write-Host -NoNewline
            # "Not signed" | Write-Host -f Yellow
            "Warning: File {0} is not digitally signed. This may indicate a security risk." -f $file.Name | Write-Host -f Yellow
            Read-Host -Prompt "Hit return to close"
            exit
        }
        else {
            # "Digital signature status: " | Write-Host -NoNewline
            # "{0}" -f $signature.Status | Write-Host -f Red
            "Digital signature verification failed for file: {0}. The module's authenticity could not be confirmed. Aborting operation." -f $file.Name | Write-Host -f Red
            Read-Host -Prompt "Hit return to close"
            exit
        }

        # Write-Host "Verification completed." -ForegroundColor Cyan

    }     

    # If all checks pass
    Write-Host "HPEiLOCmdlets module verification successful. All signatures, certificates, and metadata are valid."
    Write-Host "Proceeding to import module..."
}

# Import HPEiLOCmdlets module
Import-Module HPEiLOCmdlets


#EndRegion

#Region -------------------------------------------------------- Verification of the HPECOMCmdlets module's authenticity and integrity before use. --------------------------------------------------------------------------------------------

# Ensure the module is installed
$module = Get-Module -Name HPECOMCmdlets -ListAvailable
if (-not $module) {
    "'HPECOMCmdlets' module is not installed. Please install it using 'Install-Module -Name HPECOMCmdlets'." | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

if ($isWindows) {

    # Verify the authenticity and integrity of the HPECOMCmdlets module
    "`nVerifying the authenticity and integrity of the HPECOMCmdlets module..." | Write-Host -f Cyan

    # Get module path
    $modulePath = (Get-Module -Name HPECOMCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 ).ModuleBase

    if (-not (Test-Path $modulePath)) {
        "Module path not found: {0}" -f $modulePath | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Check module metadata
    $psd1Path = Join-Path $modulePath "HPECOMCmdlets.psd1"
    if (-not (Test-Path $psd1Path)) {
        "Module manifest (.psd1) not found at: {0}" -f $psd1Path | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    $metadata = Import-PowerShellDataFile -Path $psd1Path
    if ($metadata.CompanyName -notlike "Hewlett-Packard Enterprise" -and $metadata.Author -notlike "Lionel Jullien") {
        "Module metadata does not match HPE. CompanyName: {0}, Author: {1}" -f $metadata.CompanyName, $metadata.Author | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Get all relevant module files (.psm1, .psd1, .dll)
    $files = Get-ChildItem -Path $modulePath -Recurse -Include *.psm1, *.psd1, *.ps1xml
    if (-not $files) {
        "No relevant module files (.psm1, .psd1, .ps1xml) found in: {0}" -f $modulePath | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    # Verify digital signatures and certificates
    foreach ($file in $files) {
        "Verifying file: " | Write-Host -NoNewline
        "$($file.Name)" | Write-Host -f Cyan
        
        # Check digital signature
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName

        # Verify the signature is valid (this includes timestamping validation)
        if ($signature.Status -eq "Valid") {
            # "Digital signature status: " | Write-Host -NoNewline
            # "Valid" | Write-Host -f Green
            
            # Verify signer is HPE (only for signed files)
            if ($signature.SignerCertificate.Subject -notlike "*Hewlett Packard Enterprise*") {
                # "Signer: " | Write-Host -NoNewline
                # "{0}" -f $signature.SignerCertificate.Subject | Write-Host -f Red
                "The module is not signed by Hewlett Packard Enterprise (HPE). Aborting operation for security reasons." | Write-Host -f Red
                Read-Host -Prompt "Hit return to close"
                exit
            }
            # else {
            #     "Signer: " | Write-Host -NoNewline
            #     "Hewlett Packard Enterprise (verified)" | Write-Host -f Green
            # }
        }
        elseif ($signature.Status -eq "NotSigned") {
            # "Digital signature status: " | Write-Host -NoNewline
            # "Not signed" | Write-Host -f Yellow
            "Warning: File {0} is not digitally signed. This may indicate a security risk." -f $file.Name | Write-Host -f Yellow
            Read-Host -Prompt "Hit return to close"
            exit
        }
        else {
            # "Digital signature status: " | Write-Host -NoNewline
            # "{0}" -f $signature.Status | Write-Host -f Red
            "Digital signature verification failed for file: {0}. The module's authenticity could not be confirmed. Aborting operation." -f $file.Name | Write-Host -f Red
            Read-Host -Prompt "Hit return to close"
            exit
        }        

        # Write-Host "Verification completed." -ForegroundColor Cyan
    }

    # If all checks pass
    Write-Host "HPECOMCmdlets module verification successful. All signatures, certificates, and metadata are valid."
    Write-Host "Proceeding to import module..."
}

# Import the HPECOMCmdlets module 
Import-Module HPECOMCmdlets


#EndRegion

#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

try {
    # Check if already connected to HPE GreenLake
    Get-HPEGLWorkspace -ShowCurrent -Verbose:$Verbose -ErrorAction Stop | Out-Null
}
catch {
    if ($OktaSSOEmail) {
        # Connect to HPE GreenLake workspace using SAML SSO
        $GLPConnection = Connect-HPEGL -SSOEmail $HPEAccount -Workspace $WorkspaceName -Verbose:$Verbose
    }
    else {
        # Ask for password
        $HPEAccountSecuredPassword = Read-Host -AsSecureString "Enter password for your HPE GreenLake account '$HPEAccount'"
        $GLPcredentials = New-Object System.Management.Automation.PSCredential ($HPEAccount, $HPEAccountSecuredPassword)
        # Connect to HPE GreenLake workspace
        $GLPConnection = Connect-HPEGL -Credential $GLPcredentials -Workspace $WorkspaceName -Verbose:$Verbose
    }
}
  
if ($GLPConnection -or $HPEGreenLakeSession) {
    "`n[Workspace: {0}] - Successfully connected to the HPE GreenLake workspace." -f $WorkspaceName | Write-Host -ForegroundColor Green

}
else {
    "[Workspace: {0}] - Error connecting to the HPE GreenLake workspace. Please check your credentials and try again." -f $WorkspaceName | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

#EndRegion

#Region -------------------------------------------------------- Checking COM instance -------------------------------------------------------------------------------------

try {
    $COMInstance = Get-HPEGLService -Name "Compute Ops Management" -Region $Region -ShowProvisioned -Verbose:$Verbose -ErrorAction Stop

    if (-not $Check) {

        if ($COMInstance) {
            "[Workspace: {0}] - COM instance '{1}' successfully found." -f $WorkspaceName, $region | Write-Host -f Green
            
        }
        else {
            "[Workspace: {0}] - Error checking Compute Ops Management '{1}' instance. Please check your configuration and try again." -f $WorkspaceName, $Region | Write-Host -ForegroundColor Red
            Read-Host -Prompt "Hit return to close" 
            exit
        }
    }
    else {

        "`n------------------------------" | Write-Host -f Yellow
        "COM CONFIGURATION CHECK STATUS" | Write-Host -f Yellow
        "------------------------------" | Write-Host -f Yellow

        "  - Provisionned instance: " | Write-Host -NoNewline
        
        if ($COMInstance) {
            "OK" | Write-Host -ForegroundColor Green
        }
        else {
            "Failed" | Write-Host -f Red
            "`t - Status: " | Write-Host -NoNewline
            "Compute Ops Management '{0}' instance cannot be found. Please check your configuration and try again." -f $Region | Write-Host -ForegroundColor Red
        }
    }
}
catch {
    "[Workspace: {0}] - Error checking Compute Ops Management '{1}' instance. Please check your configuration and try again. Status: {2}" -f $WorkspaceName, $Region, $_ | Write-Host -ForegroundColor Red	
    Read-Host -Prompt "Hit return to close" 
    exit
}



#EndRegion

#Region -------------------------------------------------------- Checking COM subscription -------------------------------------------------------------------------------------

# Make sure subscription with available license is available before onboarding the iLO
    
try {

    $AvailableCOMSubscription = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server -Verbose:$Verbose -ErrorAction Stop
            
    $TotalCount = ($AvailableCOMSubscription | Select-Object -ExpandProperty AvailableQuantity) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        
    if (-not $Check) {

        # Check to enough license available for the amount of iLOs
        if ($AvailableCOMSubscription -and $TotalCount -lt $iLOs.Count) {
            "[Workspace: {0}] - Not enough licenses available ({1}) for the amount of iLOs ({2}). Please check your Compute Ops Management subscription and try again." -f $WorkspaceName, $TotalCount, $iLOs.Count | Write-Host -f Red
        }
        elseif ($AvailableCOMSubscription -and $TotalCount -ge $iLOs.Count) {
            "[Workspace: {0}] - Sufficient licenses available ({1}) for the number of iLOs ({2})." -f $WorkspaceName, $TotalCount, $iLOs.Count | Write-Host -f Green
        }
        else {
            "[Workspace: {0}] - No subscription with available license found. Please check your Compute Ops Management subscription and try again." -f $WorkspaceName | Write-Host -f Red
            Read-Host -Prompt "Hit return to close" 
            exit
        }
    }
    else {
        
        "  - Subscription: " | Write-Host -NoNewline

        if ($AvailableCOMSubscription -and $TotalCount -lt $iLOs.Count) {
            "Failed" | Write-Host -f Red
            "`t - Status: " | Write-Host -NoNewline
            "Not enough licenses available ({0}) for the amount of iLOs ({1})." -f $TotalCount, $iLOs.Count | Write-Host -ForegroundColor Red
        }
        elseif ($AvailableCOMSubscription -and $TotalCount -ge $iLOs.Count) {
            "OK" | Write-Host -ForegroundColor Green
            "`t - Status: " | Write-Host -NoNewline
            "Sufficient licenses available ({0}) for the number of iLOs ({1})." -f $TotalCount, $iLOs.Count | Write-Host -ForegroundColor Green
        }
        else {
            "Failed" | Write-Host -f Red
            "`t - Status: " | Write-Host -NoNewline
            "No subscription with available license found." | Write-Host -ForegroundColor Red
        }
    }
}
catch {
    "[Workspace: {0}] - Error checking Compute Ops Management subscription. Status: {1}" -f $WorkspaceName, $_ | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

#EndRegion       

#Region -------------------------------------------------------- Checking COM location (if defined) -------------------------------------------------------------------------------------
    
if ($LocationName) {

    # Check if location exists in the workspace

    try {
        $LocationFound = Get-HPEGLLocation -Name $LocationName -Verbose:$Verbose -ErrorAction Stop

    }
    catch {
        "[Workspace: {0}] - Error checking workspace location. Status: {1}" -f $WorkspaceName, $_ | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    if (-not $Check) {

        if (-not $LocationFound) {
            "[Workspace: {0}] - Location '{1}' not found in the HPE GreenLake workspace. Please create the location before running this script." -f $WorkspaceName, $LocationName | Write-Host -f Red
            Read-Host -Prompt "Hit return to close" 
            exit
        }
    }
    else {
        
        "  - Location: " | Write-Host -NoNewline

        if ($LocationFound) {
            "OK" | Write-Host -ForegroundColor Green
        }
        else {
            "Failed" | Write-Host -f Red
            "`t - Status: " | Write-Host -NoNewline
            "Location '{0}' not found in the HPE GreenLake workspace. Please create the location before running this script." -f $LocationName | Write-Host -foregroundColor Red
        }
    }
} 


#EndRegion   

#Region -------------------------------------------------------- Checking Secure Gateway (if defined) -------------------------------------------------------------------------------------
    
if ($SecureGateway) {

    # Check if Secure Gateway exists in the workspace

    try {
        $SecureGatewayFound = Get-HPECOMAppliance -Region $Region -Name $SecureGateway -Verbose:$Verbose -ErrorAction Stop
    }
    catch {
        "[Workspace: {0}] - Error checking Secure Gateway '{1}' in the Compute Ops Management instance. Status: {2}" -f $WorkspaceName, $SecureGateway, $_ | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }

    if (-not $Check) {

        if (-not $SecureGatewayFound) {
            "[Workspace: {0}] - Secure Gateway '{1}' not found in the Compute Ops Management instance. Please add the Secure Gateway appliance before running this script." -f $WorkspaceName, $SecureGateway | Write-Host -f Red
            Read-Host -Prompt "Hit return to close" 
            exit
        }
    }
    else {
        
        "  - Secure Gateway: " | Write-Host -NoNewline

        if ($SecureGatewayFound) {
            "OK" | Write-Host -ForegroundColor Green
        }
        else {
            "Failed" | Write-Host -f Red
            "`t - Status: " | Write-Host -NoNewline
            "Secure Gateway '{0}' not found in the Compute Ops Management instance. Please add the Secure Gateway appliance before running this script." -f $SecureGateway | Write-Host -foregroundColor Red
        }
    }
} 


#EndRegion  

#Region -------------------------------------------------------- Checking or configuring and connecting iLOs to COM -------------------------------------------------------------------------------

if ($Check) {
    "`n------------------------------" | Write-Host -f Yellow
    "iLO CONFIGURATION CHECK STATUS" | Write-Host -f Yellow
    "------------------------------" | Write-Host -f Yellow
}

ForEach ($iLO in $iLOs) { 

    #Region Create object for the output

    $iLOConnection = $False

    $objStatus = [pscustomobject]@{  
        iLO                       = $Ilo.IP
        Hostname                  = $Null
        SerialNumber              = $Null
        PartNumber                = $Null
        iLOGeneration             = $Null
        iLOFirmwareVersion        = $Null
        ServerModel               = $Null
        ServerGeneration          = $Null
        ServerSystemROM           = $Null
        ServerSystemROMVersion    = $Null
        ServerSystemROMFamily     = $Null
        Status                    = $Null
        Details                   = $Null
        DNSSettingsStatus         = $Null
        DNSSettingsDetails        = $Null
        NTPSettingsStatus         = $Null
        NTPSettingsDetails        = $Null
        ProxySettingsStatus       = $Null
        ProxySettingsDetails      = $Null
        FirmwareStatus            = $Null
        FirmwareDetails           = $Null
        iLOConnectionStatus       = $Null
        iLOConnectionDetails      = $Null
        TagsAssignmentStatus      = $Null
        TagsAssignmentDetails     = $Null
        LocationAssignmentStatus  = $Null
        LocationAssignmentDetails = $Null
        OnboardingType            = $Null
        Exception                 = $Null
    }

    #EndRegion

    #Region Connecting to iLO

    # Testing network access to iLO
    $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue

    if ($pingResult.Status -ne 'Success') {
        "`n  - [{0}]" -f $iLO.IP | Write-Host
        "`t - Connecting to iLO: " | Write-Host -NoNewline
        "Failed" | Write-Host -f Red
        "`t`t - Status: " | Write-Host -NoNewline	
        "Unable to access iLO. Please check your network connection or ensure that your VPN is connected." -f $iLO.IP | Write-Host -f Red       
        $objStatus.Status = "Failed"
        $objStatus.Details = "Unable to access iLO at $($iLO.IP)"
        [void]$iLOPreparationStatus.Add($objStatus)
        continue
        
    }
    
    $iLOcredentials = New-Object System.Management.Automation.PSCredential ($iLOUserName, $iLOSecuredPassword)
    
    Try {        
        if ($SkipCertificateValidation) {
            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction stop 
        }
        else {
            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction stop
        }        
       
    }
    catch {
        if ($_ -match "Could not establish trust relationship for the SSL/TLS secure channel" -or $_ -match "No such host is known") {
            "`n  - [{0}]" -f $iLO.IP | Write-Host
            "`t - Connecting to iLO: " | Write-Host -NoNewline
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline	
            "Use the -SkipCertificateValidation switch to bypass certificate validation for known hosts with self-signed certificates. Use with caution." -f $iLO.IP | Write-Host -f Red 
            $objStatus.Status = "Failed"
            $objStatus.Details = "Error connecting to iLO. Please use the -SkipCertificateValidation switch to bypass certificate validation."
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
        else {
            "`n  - [{0}]" -f $iLO.IP | Write-Host
            "`t - Connecting to iLO: " | Write-Host -NoNewline
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline	
            "Error connecting to iLO. Error: {1}" -f $iLO.IP, $_ | Write-Host -f Red 
            $objStatus.Status = "Failed"
            $objStatus.Details = $_
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
    }

    #EndRegion 

    #Region Capturing iLO information and creating tracking object
    if ($iLOConnection) {

        # Capture ilo information
        if ($iLOConnection.Hostname) {
            $hostname = $iLOConnection.Hostname
        
        }
        else {
            $hostname = $iLO.IP
        }   
            
        $objStatus.Hostname = $hostname
        
        $objStatus.iLOGeneration = $iLOConnection.TargetInfo.iLOGeneration
        
        $objStatus.iLOFirmwareVersion = $iLOConnection.TargetInfo.iLOFirmwareVersion
        
        $objStatus.ServerModel = $iLOConnection.TargetInfo.ServerModel
        
        $objStatus.ServerGeneration = $iLOConnection.TargetInfo.ServerGeneration

        $objStatus.ServerSystemROMVersion = $iLOConnection.TargetInfo.SystemROM.Split(" ")[1].Substring(1)

        $objStatus.ServerSystemROMFamily = $iLOConnection.TargetInfo.SystemROM.Split(" ")[0]

        $objStatus.ServerSystemROM = $iLOConnection.TargetInfo.SystemROM.Split(" ")[0..1] -join " "

        # List of server system ROM families that require a special onboarding process if iLO firmware is earlier than 1.62.
        # For these families, onboarding uses the workspace ID instead of a COM activation key.
        # - A55: HPE ProLiant DL365 Gen11 and HPE ProLiant DL385 Gen11
        # - A56: HPE ProLiant DL325 Gen11 and HPE ProLiant DL345 Gen11
        $ImpactedServerSystemROMFamilies = @("A55", "A56")

        if ($ImpactedServerSystemROMFamilies -contains $objStatus.ServerSystemROMFamily -and [version]$objStatus.iLOFirmwareVersion -le [version]"1.62" -and [version]$objStatus.ServerSystemROMVersion -le [version]"1.56") {
            
            $objStatus.OnboardingType = "Workspace ID"

        }
        elseif ($ImpactedServerSystemROMFamilies -contains $objStatus.ServerSystemROMFamily -and [version]$objStatus.iLOFirmwareVersion -ge [version]"1.63" -and [version]$objStatus.ServerSystemROMVersion -ge [version]"1.58") {
            
            $objStatus.OnboardingType = "Activation Key"

        }
        elseif ($ImpactedServerSystemROMFamilies -contains $objStatus.ServerSystemROMFamily -and (
                ([version]$objStatus.iLOFirmwareVersion -le [version]"1.62" -and [version]$objStatus.ServerSystemROMVersion -ge [version]"1.57") -or 
                ([version]$objStatus.iLOFirmwareVersion -ge [version]"1.63" -and [version]$objStatus.ServerSystemROMVersion -le [version]"1.56")
            )) {
            
            $objStatus.OnboardingType = "Unsupported"
            $objStatus.Status = "Failed"
            $objStatus.Details = "Unsupported iLO firmware and System ROM version combination detected! This server cannot be onboarded to COM. Skipping server..."
            [void]$iLOPreparationStatus.Add($objStatus)
            continue

        }
        else {
            # This handles all non-A55/A56 servers with default Activation Key process
            $objStatus.OnboardingType = "Activation Key"

        }

        
        $iLOChassisInfo = Get-HPEiLOChassisInfo -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop
        $objStatus.SerialNumber = $iLOChassisInfo | Select-Object -ExpandProperty SerialNumber
        $objStatus.PartNumber = $iLOChassisInfo | Select-Object -ExpandProperty SKU

        "`n  - [{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6})" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Host
        "`t - Onboarding method selected:" | Write-Host -NoNewline
        " {0}" -f $objStatus.OnboardingType | Write-Host -ForegroundColor Cyan

    }
    else {
        "`n  - [{0}]" -f $iLO.IP | Write-Host
        "`t - Connecting to iLO: " | Write-Host -NoNewline
        "Failed" | Write-Host -f Red
        $objStatus.Status = "Failed"
        $objStatus.Details = "Error connecting to iLO. Error: $iLOConnection"
        [void]$iLOPreparationStatus.Add($objStatus)
        continue
    }

    #EndRegion

    #Region Get DNS in iLO       

    if ($Check) {

        "`t - DNS: " | Write-Host -NoNewline

        Try {
        
            $iLONetworkSetting = Get-HPEiLOIPv4NetworkSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 

            $sortedCurrentDNSServers = $iLONetworkSetting | Select-Object -ExpandProperty DNSServer | Where-Object { $_ -ne "0.0.0.0" } | Where-Object { $_ -ne "" -and $_ -ne $null } | Sort-Object
                
            if ($iLONetworkSetting.Status -eq "ERROR") {

                "Failed" | Write-Host -f Red

                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO DNS settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLONetworkSetting.StatusInfo.Message | Write-Verbose

                $objStatus.DNSSettingsStatus = "Failed to retrieve iLO DNS settings."
                $objStatus.DNSSettingsDetails = $iLONetworkSetting.StatusInfo.Message
                $objStatus.Status = "Failed"
            }
            elseif ($Null -ne $sortedCurrentDNSServers) {
                                
                if ($DNSservers) {

                    # Sort DNS servers
                    $sortedDNSservers = $DNSservers | Sort-Object
                
                    # Compare the sorted arrays
                    $comparisonResult = Compare-Object -ReferenceObject $sortedDNSservers -DifferenceObject $sortedCurrentDNSServers
                
                    # Find the missing DNS servers
                    $missingDNSServers = $sortedDNSservers | Where-Object { $sortedCurrentDNSServers -notcontains $_ }
                
                    if ($sortedCurrentDNSServers.length -gt 1) {
                        $FormattedCurrentDNSServers = $sortedCurrentDNSServers -join ", "
                    }
                    else {
                        $FormattedCurrentDNSServers = $sortedCurrentDNSServers
                    }
                
                    if ($missingDNSServers.length -gt 1) {
                        $FormattedmissingDNSServers = $missingDNSServers -join ", "
                    }
                    else {
                        $FormattedmissingDNSServers = $missingDNSServers
                    }               

                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS settings found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedCurrentDNSServers | Write-Verbose 

                    if ($comparisonResult) {
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "{0}" -f $FormattedmissingDNSServers | Write-Host -ForegroundColor Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is required. Missing: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedmissingDNSServers | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Warning"
                        $objStatus.DNSSettingsDetails = "DNS servers found: $FormattedCurrentDNSServers - Missing DNS servers: $FormattedmissingDNSServers"
                    }
                    else {
                        "Ok" | Write-Host -f Green
                        "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is not required as the DNS servers are already correctly configured." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Complete"
                        $objStatus.DNSSettingsDetails = "DNS configuration is not required as the DNS servers are already correctly configured."
                    }
                }    
                else {
                    "Ok" | Write-Host -f Green
                    "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration will be skipped as no DNS server configuration is requested." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.DNSSettingsStatus = "Complete"
                    $objStatus.DNSSettingsDetails = "DNS configuration will be skipped as no DNS server configuration is requested."
                }
            }
            else {

                if ($DNSservers) {

                    # Flatten the array
                    $flattenedDNSservers = @($DNSservers | ForEach-Object { $_ })

                    if ($flattenedDNSservers.count -gt 1) {
                        $FormattedDNSservers = $flattenedDNSservers -join ", "
                    }
                    else {
                        $FormattedDNSservers = $flattenedDNSservers
                    }

                    "Warning" | Write-Host -f Yellow
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "`t`t - Missing: " | Write-Host -NoNewline
                    "{0}" -f $FormattedDNSservers | Write-Host -ForegroundColor Yellow

                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is required as no DNS servers are defined!" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.DNSSettingsStatus = "Warning"
                    $objStatus.DNSSettingsDetails = "DNS configuration is required as no DNS servers are defined!"
                }
                else {
                    "Failed" | Write-Host -f Red
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Warning: No DNS server defined! This may cause issues with iLO connectivity to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.DNSSettingsStatus = "Warning"
                    $objStatus.DNSSettingsDetails = "No DNS server defined! This may cause issues with iLO connectivity to COM."
                    $objStatus.Status = "Failed"
                }
            }                    
        }
        catch {
            "Failed" | Write-Host -f Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO DNS settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.DNSSettingsStatus = "Failed"
            $objStatus.DNSSettingsDetails = $_
            $objStatus.Status = "Failed"
        }
    }

    #EndRegion 
        
    #Region Set DNS in iLO if defined via the DNS variables
    if (-not $Check) {

        "`t - DNS: " | Write-Host -NoNewline

        Try {

            $sortedCurrentDNSServers = $Null

            # Check if DNS servers are defined
            $iLONetworkSetting = Get-HPEiLOIPv4NetworkSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 

            $sortedCurrentDNSServers = $iLONetworkSetting | Select-Object -ExpandProperty DNSServer | Where-Object { $_ -ne "0.0.0.0" } | Where-Object { $_ -ne "" -and $_ -ne $null } | Sort-Object

            if ($sortedCurrentDNSServers.length -gt 1) {
                $FormattedCurrentDNSServers = $sortedCurrentDNSServers -join ", "
            }
            else {
                $FormattedCurrentDNSServers = $sortedCurrentDNSServers
            }
        
            if ($iLONetworkSetting.Status -eq "ERROR") {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Failed to retrieve iLO DNS settings. StatusInfo: {0}" -f $iLONetworkSetting.StatusInfo.Message | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO DNS settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLONetworkSetting.StatusInfo.Message | Write-Verbose
                $objStatus.DNSSettingsStatus = "Failed to retrieve iLO DNS settings."
                $objStatus.DNSSettingsDetails = $iLONetworkSetting.StatusInfo.Message
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }

        }
        Catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Failed to retrieve iLO DNS settings. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO DNS settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.DNSSettingsStatus = "Error configuring iLO DNS settings."
            $objStatus.DNSSettingsDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
    
        # Set the DNS servers if defined
        if ($DNSservers) {

            try {
                $DHCPv4DNSServer = Get-HPEiLOIPv4NetworkSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty DHCPv4DNSServer

            }
            catch {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error retrieving iLO DNS settings. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO DNS settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.DNSSettingsStatus = "Failed"
                $objStatus.DNSSettingsDetails = "Error retrieving iLO DNS settings. Error: $($_)"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
                        
            if ($DHCPv4DNSServer -eq "Enabled") {
                "Warning" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "DNS settings cannot be configured because they are currently managed via DHCP. Skipping DNS configuration..." | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS settings cannot be configured because they are currently managed via DHCP. Skipping DNS configuration..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.DNSSettingsStatus = "Warning"
                $objStatus.DNSSettingsDetails = "DNS settings cannot be configured because they are currently managed via DHCP. Skipping DNS configuration..."
                
            }
            # If DHCPv4DNSServer is not enabled, set the DNS servers
            else {
                
                $comparisonResult = $Null
                $DNSupdate = $False
                $SetDNS = $False

                # If DNS servers are defined, compare the current DNS servers with the defined DNS servers
                if ($Null -ne $sortedCurrentDNSServers) {

                    # Sort both arrays
                    $sortedDNSservers = $DNSservers | Sort-Object

                    # Compare the sorted arrays
                    $comparisonResult = Compare-Object -ReferenceObject $sortedDNSservers -DifferenceObject $sortedCurrentDNSServers
                    
                    if ($comparisonResult) {
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is required as the DNS servers configuration does not match." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $SetDNS = $True
                    }
                    else {
                        "Skipped" | Write-Host -f Green
                        "`t`t - Status: " | Write-Host -NoNewline
                        "DNS configuration is not required as the DNS servers are already defined." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is not required as the DNS servers are already defined." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Skipped"
                        $objStatus.DNSSettingsDetails = "DNS configuration is not required as the DNS servers are already defined."
                    }    
                }
                # If DNS servers are not defined
                else {
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is required as no DNS servers are defined" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $SetDNS = $True
                }   

                if ($SetDNS) {
                    
                    Try {
                
                        # Set DNS servers
                        $DNSupdate = Set-HPEiLOIPv4NetworkSetting -Connection $iLOConnection -InterfaceType Dedicated -DNSServerType $dnstypes -DNSServer $DNSservers -Verbose:$Verbose -ErrorAction Stop          
                        
                        if ($DNSupdate.Status -eq "ERROR") {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error configuring DNS settings. StatusInfo: {0}" -f $DNSupdate.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO DNS settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $DNSupdate.StatusInfo.Message | Write-Verbose
                            $objStatus.DNSSettingsStatus = "Failed"
                            $objStatus.DNSSettingsDetails = "Error configuring iLO DNS settings. StatusInfo: $($DNSupdate.StatusInfo.Message)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                        elseif ($Null -eq $DNSupdate) {
                            "InProgress" | Write-Host -f Yellow
                            "`t`t - Status: " | Write-Host -NoNewline
                            "DNS settings set successfully!" | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS settings set successfully!" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                            $objStatus.DNSSettingsStatus = "Complete"
                            $objStatus.DNSSettingsDetails = "DNS settings set successfully!"
                        }
                        else {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error configuring DNS settings. StatusInfo: {0}" -f $DNSupdate.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO DNS settings. Status: {7} - StatusInfo: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $DNSupdate.Status, $DNSupdate.StatusInfo.Message | Write-Verbose
                            $objStatus.DNSSettingsStatus = $DNSupdate.status
                            $objStatus.DNSSettingsDetails = "Error configuring iLO DNS settings. StatusInfo: $($DNSupdate.StatusInfo.Message)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                        
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error configuring iLO DNS settings. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO DNS settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Error configuring iLO DNS settings."
                        $objStatus.DNSSettingsDetails = $_
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                }
            }
        }
        # If no current DNS servers and no defined DNS servers, skip the DNS configuration and return a warning
        else {

            if (-not $sortedCurrentDNSServers) {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "No DNS servers defined! This will cause issues with iLO connectivity to COM. Skipping server..." | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Warning: No DNS server defined! This may cause issues with iLO connectivity to COM. Skipping server..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.DNSSettingsStatus = "Failed"
                $objStatus.DNSSettingsDetails = "No DNS servers defined! This will cause issues with iLO connectivity to COM. Skipping server..."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - DNS configuration is not required as no DNS server configuration is requested." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.DNSSettingsStatus = "Complete"
                $objStatus.DNSSettingsDetails = "DNS configuration is not required as no DNS server configuration is requested."
            }
        }
    }
   
    
    #EndRegion 
    
    #Region Get SNTP in iLO 
    if ($Check) {

        "`t - SNTP: " | Write-Host -NoNewline
        
        Try {
            $SNTPSetting = Get-HPEiLOSNTPSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 

            $sortedCurrentSNTPServers = $SNTPSetting | Select-Object -ExpandProperty SNTPServer | Where-Object { $_ -ne "" -and $_ -ne $null } | Sort-Object
        
            if ($SNTPSetting.Status -eq "ERROR") {
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO SNTP settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $SNTPSetting.StatusInfo.Message | Write-Verbose
                "Failed" | Write-Host -f Red

                $objStatus.NTPSettingsStatus = "Failed to retrieve iLO SNTP settings."
                $objStatus.NTPSettingsDetails = $SNTPSetting.StatusInfo.Message
                $objStatus.Status = "Failed"
            }
            elseif ($Null -ne $sortedCurrentSNTPServers) {

                
                # Sort SNTP servers
                $sortedSNTPservers = $SNTPservers | Sort-Object
                
                # Compare the sorted arrays
                $comparisonResult = Compare-Object -ReferenceObject $sortedSNTPservers -DifferenceObject $sortedCurrentSNTPServers
                
                # Find the missing SNTP servers
                $missingSNTPServers = $sortedSNTPservers | Where-Object { $sortedCurrentSNTPServers -notcontains $_ }
                
                if ($sortedCurrentSNTPServers.length -gt 1) {
                    $FormattedCurrentSNTPServers = $sortedCurrentSNTPServers -join ", "
                }
                else {
                    $FormattedCurrentSNTPServers = $sortedCurrentSNTPServers
                }
                
                if ($missingSNTPServers.length -gt 1) {
                    $FormattedmissingSNTPServers = $missingSNTPServers -join ", "
                }
                else {
                    $FormattedmissingSNTPServers = $missingSNTPServers
                }
                
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP settings found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedCurrentSNTPServers | Write-Verbose 

                if ($SNTPservers) {

                    if ($comparisonResult) {
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "{0}" -f $FormattedmissingSNTPServers | Write-Host -ForegroundColor Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is required. Missing: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedmissingSNTPServers | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Warning"
                        $objStatus.NTPSettingsDetails = "SNTP servers found: $FormattedCurrentSNTPServers - Missing SNTP servers: $FormattedmissingSNTPServers"
                    }
                    else {
                        "Ok" | Write-Host -f Green
                        "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is not required as the SNTP servers are already correctly configured." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Complete"
                        $objStatus.NTPSettingsDetails = "SNTP configuration is not required as the SNTP servers are already correctly configured."
                    }
                }    
                else {
                    "Ok" | Write-Host -f Green
                    "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration will be skipped as no SNTP server configuration is requested." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.NTPSettingsStatus = "Complete"
                    $objStatus.NTPSettingsDetails = "SNTP configuration will be skipped as no SNTP server configuration is requested."
                }     
            }
            else {

                if ($SNTPservers) {

                    # Flatten the array
                    $flattenedSNTPservers = @($SNTPservers | ForEach-Object { $_ })

                    if ($flattenedSNTPservers.count -gt 1) {
                        $FormattedSNTPservers = $flattenedSNTPservers -join ", "
                    }
                    else {
                        $FormattedSNTPservers = $flattenedSNTPservers
                    }
 
                    "Warning" | Write-Host -f Yellow
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "`t`t - Missing: " | Write-Host -NoNewline
                    "{0}" -f $FormattedSNTPservers | Write-Host -ForegroundColor Yellow

                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is required as no SNTP servers are defined!" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.NTPSettingsStatus = "Warning"
                    $objStatus.NTPSettingsDetails = "SNTP configuration is required as no SNTP servers are defined!"
                }
                else {
                    "Failed" | Write-Host -f Red
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Warning: No SNTP server defined! This may cause issues with iLO connectivity to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.NTPSettingsStatus = "Warning"
                    $objStatus.NTPSettingsDetails = "No SNTP server defined! This may cause issues with iLO connectivity to COM."
                    $objStatus.Status = "Failed"
                }
            }
        
        }
        catch {
            "Failed" | Write-Host -f Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO SNTP settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.NTPSettingsStatus = "Failed"
            $objStatus.NTPSettingsDetails = $_
            $objStatus.Status = "Failed"
        }
    }

    #EndRegion 

    #Region Set SNTP in iLO if defined via the SNTP variables
    if (-not $Check) {

        "`t - SNTP: " | Write-Host -NoNewline

        Try {

            $sortedCurrentSNTPServers = $Null

            # Check if SNTP servers are defined
            $SNTPSetting = Get-HPEiLOSNTPSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 

            $sortedCurrentSNTPServers = $SNTPSetting | Select-Object -ExpandProperty SNTPServer | Where-Object { $_ -ne "" -and $_ -ne $null } | Sort-Object
        
            if ($sortedCurrentSNTPServers.length -gt 1) {
                $FormattedCurrentSNTPServers = $sortedCurrentSNTPServers -join ", "
            }
            else {
                $FormattedCurrentSNTPServers = $sortedCurrentSNTPServers
            }

            if ($SNTPSetting.Status -eq "ERROR") {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Failed to retrieve iLO SNTP settings. StatusInfo: {0}" -f $iLONetworkSetting.StatusInfo.Message | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO SNTP settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLONetworkSetting.StatusInfo.Message | Write-Verbose
                $objStatus.NTPSettingsStatus = "Failed to retrieve iLO SNTP settings."
                $objStatus.NTPSettingsDetails = $iLONetworkSetting.StatusInfo.Message
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
        }
        Catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Failed to retrieve iLO SNTP settings. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO SNTP settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.NTPSettingsStatus = "Failed"
            $objStatus.NTPSettingsDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }

        # Set the SNTP servers if defined
        if ($SNTPservers) {
        
            try {
                $DHCPv4SNTPSetting = Get-HPEiLOIPv4NetworkSetting -Connection $iLOConnection  -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty DHCPv4SNTPSetting
                
            }
            catch {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error retrieving SNTP settings. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO SNTP settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.NTPSettingsStatus = "Failed"
                $objStatus.NTPSettingsDetails = "Error retrieving iLO SNTP settings. Error: $($_)"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            
            if ($DHCPv4SNTPSetting -eq "Enabled") {
                "Warning" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "SNTP settings cannot be configured because they are currently managed via DHCP. Skipping SNTP configuration..." | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP settings cannot be configured because they are currently managed via DHCP. Skipping SNTP configuration..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.NTPSettingsStatus = "Warning"
                $objStatus.NTPSettingsDetails = "SNTP settings cannot be configured because they are currently managed via DHCP. Skipping SNTP configuration..."
                
            }
            # If DHCPv4SNTPSetting is not enabled, set the SNTP servers
            else {
                
                $ResetRequired = $False
                $SNTPupdate = $false
                $SetSNTP = $False


                # If SNTP servers are defined, compare the current SNTP servers with the defined SNTP servers
                if ($Null -ne $SNTPSetting.SNTPServer) {

                    $sortedCurrentSNTPServers = $SNTPSetting.SNTPServer | Sort-Object

                    # Sort both arrays
                    $sortedSNTPservers = $SNTPservers | Sort-Object

                    # Compare the sorted arrays
                    $comparisonResult = Compare-Object -ReferenceObject $sortedSNTPservers -DifferenceObject $sortedCurrentSNTPServers


                    if ($comparisonResult) {
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is required as the SNTP servers configuration does not match." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $SetSNTP = $True
                    }
                    else {
                        "Skipped" | Write-Host -f Green
                        "`t`t - Status: " | Write-Host -NoNewline
                        "SNTP configuration is not required as the SNTP servers are already defined." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is not required as the SNTP servers are already defined." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Skipped"
                        $objStatus.NTPSettingsDetails = "SNTP configuration is not required as the SNTP servers are already defined."
                    }    
                }
                # If SNTP servers are not defined
                else {
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is required as no SNTP servers are defined" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $SetSNTP = $True
                }

                if ($SetSNTP) {

                    # Set SNTP servers
                    Try {
                        $SNTPupdate = Set-HPEiLOSNTPSetting -Connection $iLOConnection -InterfaceType Dedicated -DHCPv4NTPServer Disabled -DHCPv6NTPServer Disabled -PropagateTimetoHost Enabled -SNTPServer $SNTPservers -Verbose:$Verbose -ErrorAction Stop
                        
                        if ($SNTPupdate.Status -eq "ERROR") {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error configuring SNTP settings. StatusInfo: {0}" -f $SNTPupdate.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO SNTP settings. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $SNTPupdate.StatusInfo.Message | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Failed"
                            $objStatus.NTPSettingsDetails = "Error configuring iLO SNTP settings. StatusInfo: $($SNTPupdate.StatusInfo.Message)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                        elseif ($SNTPupdate.Status -eq "INFORMATION" ) {
                            "InProgress" | Write-Host -f Yellow
                            "`t`t - Status: " | Write-Host -NoNewline
                            "SNTP settings set successfully. Message: {0}" -f $SNTPupdate.StatusInfo.Message | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO SNTP settings set successfully. Message: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $SNTPupdate.StatusInfo.Message | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Complete"
                            $objStatus.NTPSettingsDetails = "iLO SNTP settings set successfully."
            
                            if ($SNTPupdate.StatusInfo.Message -match "ResetRequired") {
                                $ResetRequired = $True
                            }
                        }
                        else {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error configuring SNTP settings. StatusInfo: {0}" -f $SNTPupdate.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO SNTP settings. Status: {7} - StatusInfo: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $SNTPupdate.status, $SNTPupdate.StatusInfo.Message | Write-Verbose
                            $objStatus.NTPSettingsStatus = $SNTPupdate.status
                            $objStatus.NTPSettingsDetails = "Error configuring iLO SNTP settings. StatusInfo: $($SNTPupdate.StatusInfo.Message)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error configuring SNTP settings. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error configuring iLO SNTP settings. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Error configuring iLO SNTP settings."
                        $objStatus.NTPSettingsDetails = $_
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }   
                                                     
                }                    
                
                # Reset iLO if needed after SNTP configuration 
                if ($ResetRequired) {
        
                    try {
                        $iLOResetStatus = Reset-HPEiLO -Connection $iLOConnection -Device iLO -ResetType ForceRestart -Force -Confirm:$false -Verbose:$Verbose -ErrorAction Stop
                        
                        if ($iLOResetStatus.Status -eq "WARNING") {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed..." -f $_ | Write-Host -ForegroundColor Yellow
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        }
                        else {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error resetting iLO. Status: {0} - Details: {1}" -f $iLOResetStatus.Status, $iLOResetStatus.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error resetting iLO. Status: {7} - Details: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $iLOResetStatus.Status, $iLOResetStatus.StatusInfo.Message | Write-Verbose
                            $objStatus.NTPSettingsStatus = $iLOResetStatus.Status
                            $objStatus.NTPSettingsDetails = "Error resetting iLO after SNTP settings set. StatusInfo: $($iLOResetStatus.StatusInfo.Message)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }


                        # Wait until the iLO is unreachable after the reset
                        $maxRetries = 36 # 3 minutes
                        $retryCount = 0

                        do {
                            # Testing network access to iLO
                            $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                            Start-Sleep -Seconds 5
                            $retryCount++
                        } until ($pingResult.Status -ne 'Success' -or $retryCount -ge $maxRetries)

                        if ($retryCount -ge $maxRetries) {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "iLO reset after the changes to SNTP configuration could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." | Write-Host -ForegroundColor Red
                            "[{0}] - iLO reset after the changes to SNTP configuration could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Failed"
                            $objStatus.NTPSettingsDetails = "iLO reset after the changes to SNTP configuration could not be detected after $maxRetries retries. Please check the iLO status and network connectivity."
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                        
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO reset has been detected. Waiting for iLO to be back online..." | Write-Host -ForegroundColor Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.NTPSettingsStatus = "InProgress"
                        $objStatus.NTPSettingsDetails = "iLO reset has been detected. Waiting for iLO to be back online..."
                        
                        # iLO is being reset with new changes. Waiting for the reset to be performed
                        Start-Sleep -Seconds 60

                        # Wait for the iLO to be reachable after the reset
                        $maxRetries = 36 # 3 minutes
                        $retryCount = 0

                        do {
                            # Testing network access to iLO
                            $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                            Start-Sleep -Seconds 5
                            $retryCount++
                        } until ($pingResult.Status -eq 'Success' -or $retryCount -ge $maxRetries)

                        if ($retryCount -ge $maxRetries) {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Unable to access iLO after {0} retries following SNTP configuration reset. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                            "[{0}] - Unable to access iLO after {1} retries following SNTP configuration reset. Please check the iLO status and network connectivity." -f $iLO.IP, $maxRetries | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Failed"
                            $objStatus.NTPSettingsDetails = "Unable to access iLO after $maxRetries retries following SNTP configuration reset. Please check the iLO status and network connectivity."
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }       
                        else {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "iLO SNTP settings updated successfully and iLO is back online." | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO SNTP settings updated successfully and iLO is back online." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Complete"
                            $objStatus.NTPSettingsDetails = "iLO firmware updated successfully"

                            $iLOConnection = $False

                            # Reconnect to iLO after the changes to SNTP configuration and reset
                            Try {
                                $maxRetries = 36 # 3 minutes
                                $retryCount = 0

                                "`t`t - Status: " | Write-Host -NoNewline
                                "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Reconnecting to iLO..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                                do {
                                    try {
                                        if ($SkipCertificateValidation) {
                                            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction stop
                                        }
                                        else {
                                            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction stop
                                        }

                                    }
                                    catch {
                                        Start-Sleep -Seconds 5
                                        $retryCount++
                                    }
                                } until ($iLOConnection -or $retryCount -ge $maxRetries)                               
                                
                                if ($retryCount -ge $maxRetries) {
                                    "`t`t - Status: " | Write-Host -NoNewline
                                    "Error connecting to iLO after the changes to SNTP configuration. Error: {0}" -f $iLOConnection | Write-Host -ForegroundColor Red
                                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after the changes to SNTP configuration. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOConnection | Write-Verbose
                                    $objStatus.NTPSettingsStatus = "Failed"
                                    $objStatus.NTPSettingsDetails = "Unable to connect to iLO after $maxRetries retries following SNTP configuration reset. Please check the iLO status and network connectivity."
                                    $objStatus.Status = "Failed"
                                    [void]$iLOPreparationStatus.Add($objStatus)
                                    continue
                                }

                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Reconnected to iLO. Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOConnection.TargetInfo | Write-Verbose

                                # Wait for the SNTP status to be ok
                                
                                $maxRetries = 36 # 3 minutes
                                $retryCount = 0
                                
                                do {
                                    try {
                                        $SNTPSetting = Get-HPEiLOSNTPSetting -Connection $iLOConnection -ErrorAction Stop
                                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Waiting for the SNTP status to be ok... Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $SNTPSetting.status | Write-Verbose
                                    }
                                    catch {
                                        Start-Sleep -Seconds 5
                                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve the SNTP status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose

                                        Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                                        if ($SkipCertificateValidation) {
                                            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                                        }
                                        else {
                                            $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                                        }
                                        $retryCount++
                                    }
                                } until ($SNTPSetting.Status -eq 'OK' -or $retryCount -ge $maxRetries)

                                if ($retryCount -ge $maxRetries) {
                                    "`t`t - Status: " | Write-Host -NoNewline
                                    "The SNTP status could not be detected as 'OK' after '{0}' retries. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                                    "[{0}] - The SNTP status could not be detected as 'OK' after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP | Write-Verbose
                                    $objStatus.NTPSettingsStatus = "Failed"
                                    $objStatus.NTPSettingsDetails = "The SNTP status could not be detected as 'OK' after $maxRetries retries. Please check the iLO status and network connectivity."
                                    $objStatus.Status = "Failed"
                                    [void]$iLOPreparationStatus.Add($objStatus)
                                    continue
                                }

                            }
                            catch {
                                "`t`t - Status: " | Write-Host -NoNewline
                                "Error connecting to iLO after the changes to SNTP configuration. Error: $_" | Write-Host -ForegroundColor Red
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after the changes to SNTP configuration. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after the changes to SNTP configuration. Error: $($_)"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                    }
                    catch {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error resetting iLO after the changes to SNTP configuration. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error resetting iLO after the changes to SNTP configuration. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Error resetting iLO after the changes to SNTP configuration."
                        $objStatus.NTPSettingsDetails = $_
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                }

            }                
        }
        # If no current SNTP servers and no defined SNTP servers, skip the SNTP configuration and return a warning
        else {

            if (-not $sortedCurrentSNTPServers) {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "No SNTP servers defined! This will cause issues with iLO connectivity to COM. Skipping server..." | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Warning: No SNTP server defined! This may cause issues with iLO connectivity to COM. Skipping server..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.NTPSettingsStatus = "Failed"
                $objStatus.NTPSettingsDetails = "No SNTP servers defined! This will cause issues with iLO connectivity to COM. Skipping server..."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - SNTP configuration is not required as no SNTP server configuration is requested." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.NTPSettingsStatus = "Complete"
                $objStatus.NTPSettingsDetails = "SNTP configuration is not required as no SNTP server configuration is requested."
            }
        }   
    }

    #EndRegion 

    #Region Check if iLO flash is needed
    
    # COM activation key is not supported for iLO5 versions lower than v3.09
    if ($Check) {

        "`t - iLO firmware: " | Write-Host -NoNewline

        if ($objStatus.iLOGeneration -eq "iLO5") {
    
            if ($objStatus.iLOFirmwareVersion -lt "3.09") {
                "Warning" | Write-Host -f Yellow               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $objStatus.iLOFirmwareVersion | Write-Host -ForegroundColor Yellow
                "`t`t - Required: 3.09 or later" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware version lower than v3.09 is not supported by COM activation key. Firmware update will be needed." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "Firmware update will be needed."
                $objStatus.FirmwareDetails = "iLO5 firmware version lower than v3.09 is not supported by COM activation key."
            }                   
            else {
                "OK" | Write-Host -f Green               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $objStatus.iLOFirmwareVersion | Write-Host -ForegroundColor Green
                "`t`t - Required: 3.09 or later" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 FW fully supported by COM. Firmware update will be skipped." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "iLO5 firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Firmware update will be skipped."
            }
        
        }

        # COM activation key is not supported for iLO6 versions lower than v1.64
        if ($objStatus.iLOGeneration -eq "iLO6" -and $objStatus.OnboardingType -eq "Activation Key") {
        
            If ($objStatus.iLOFirmwareVersion -lt "1.64") {   
                "Warning" | Write-Host -f Yellow               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $objStatus.iLOFirmwareVersion | Write-Host -ForegroundColor Yellow
                "`t`t - Required: 1.64 or later" | Write-Host  
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware version lower than v1.64 is not supported by COM activation key. Firmware update will be needed." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "Firmware update will be needed."
                $objStatus.FirmwareDetails = "iLO6 firmware version lower than v1.64 is not supported by COM activation key."
            }                   
            else {
                "OK" | Write-Host -f Green               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $objStatus.iLOFirmwareVersion | Write-Host -ForegroundColor Green
                "`t`t - Required: 1.64 or later" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - ServerSystemROM: {6}) - iLO6 FW fully supported by COM. Firmware update will be skipped." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "iLO6 firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Firmware update will be skipped."

            }
        
        }
        elseif ($objStatus.iLOGeneration -eq "iLO6" -and $objStatus.OnboardingType -eq "Workspace ID") {
            "OK" | Write-Host -f Green
            "`t`t - Current: " | Write-Host -NoNewline
            "{0}" -f $objStatus.iLOFirmwareVersion | Write-Host -ForegroundColor Green
            "`t`t - Required: " | Write-Host -NoNewline
            "None. Update will be skipped as onboarding will use the 'workspace ID' method." | Write-Host -ForegroundColor Green
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - ServerSystemROM: {6}) - Firmware update will be skipped as onboarding type that will be used is 'workspace ID'." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
            $objStatus.FirmwareStatus = "iLO6 firmware fully supported by COM."
            $objStatus.FirmwareDetails = "Firmware update will be skipped."

        }
    }

    #EndRegion 

    #Region Flash iLO if needed
    
    if (-not $Check) {

        $iLOFlashActivity = $False

        "`t - iLO firmware: " | Write-Host -NoNewline
    
        Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active

        # COM activation key is not supported for iLO5 versions lower than v3.09
        if ($objStatus.iLOGeneration -eq "iLO5") {
    
            if ($objStatus.iLOFirmwareVersion -lt "3.09") {

                if (-not $iLO5binFile) {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO5 firmware update is needed as firmware is lower than v3.09 but iLO5binFile cannot be found. Please provide the iLO5 firmware file path and try again." | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware update is needed as firmware is lower than v3.09 but iLO5binFile cannot be found. Please provide the iLO5 firmware file path and try again." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.FirmwareStatus = "Failed"
                    $objStatus.FirmwareDetails = "iLO5 firmware update is needed as firmware is lower than v3.09 but iLO5binFile cannot be found. Please provide the iLO5 firmware file path and try again."
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
                else {
                    # Get the full path of the iLO5 firmware file
                    $iLO5binFileFullPath = (Get-Item $iLO5binFile).FullName

                    try {

                        $TPMEnabled = $False

                        $maxRetries = 5 
                        $retryCount = 0
                               
                        do {

                            try {                               
                                $TPMStatus = Get-HPEiLOTPMStatus -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 
                                $TPMEnabled = $TPMStatus | Select-Object -ExpandProperty TPMEnabled -ErrorAction Stop
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware update is needed as firmware is lower than v3.09. TPM Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $TPMEnabled | Write-Verbose

                            }
                            catch {
                                Start-Sleep -Seconds 2                                
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Exception detected to get TPMStatus: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose

                                Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                                if ($SkipCertificateValidation) {
                                    $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                                }
                                else {
                                    $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                                }

                                $retryCount++
                            }

                        } until ($TPMEnabled -or $retryCount -ge $maxRetries)

                        if ($retryCount -ge $maxRetries) {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Failed to retrieve iLO TPM status. StatusInfo: {0}" -f $TPMEnabled | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO TPM status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $TPMEnabled | Write-Verbose
                            $objStatus.FirmwareStatus = "Failed"
                            $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $iLOConnection"
                            $objStatus.Status = "Failed"        
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }                        
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error retrieving iLO TPM status.Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO TPM status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $($_)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                }

                $FirmwareUpdateResult = $Null
            
                Try {

                    $iLOFlashActivity = $True
                    
                    $maxRetries = 20 
                    $retryCount = 0

                    "InProgress" | Write-Host -f Yellow
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO5 firmware update in progress as firmware is lower than v3.09..." | Write-Host -ForegroundColor Yellow

                    do {
                        try {  
                            if ($TPMEnabled -eq "Yes") {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO5binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -TPMEnabled -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware update in progress as firmware is lower than v3.09 (TPM Enabled)..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                            }
                            else {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO5binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware update in progress as firmware is lower than v3.09 (TPM not Enabled)..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                            }
                        }
                        catch {
                            Start-Sleep -Seconds 2
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Exception detected to update the iLO Firmware. Retrying... Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FirmwareUpdateResult | Write-Verbose

                            Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                            if ($SkipCertificateValidation) {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                            }
                            else {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                            }
    
                            Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                            $retryCount++
                        }

                    } until ($FirmwareUpdateResult.StatusInfo.Message -eq "ResetInProgress" -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error updating iLO firmware. StatusInfo: {0}" -f $FirmwareUpdateResult.StatusInfo.Message | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error updating iLO firmware. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FirmwareUpdateResult.StatusInfo.Message | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error updating iLO firmware. StatusInfo: $($FirmwareUpdateResult.StatusInfo.Message)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }            
                    
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO firmware must be activated. Waiting for the reset to be performed..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO firmware must be activated. Waiting for the reset to be performed..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                    # Wait until the iLO is unreachable after the reset
                    $maxRetries = 36 # 3 minutes
                    $retryCount = 0

                    do {
                        # Testing network access to iLO
                        $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 4
                        Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                        $retryCount++
                    } until ($pingResult.Status -ne 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }

                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO reset has been detected. Waiting for iLO to be back online..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.FirmwareStatus = "InProgress"
                    $objStatus.FirmwareDetails = "iLO reset has been detected. Waiting for iLO to be back online..."

                    # iLO is being reset with new changes. Waiting for the reset to be performed
                    Start-Sleep -Seconds 60
                        
                    # Wait for the iLO to be reachable after the reset
                    $maxRetries = 36 # 3 minutes
                    $retryCount = 0

                    do {
                        # Testing network access to iLO
                        $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 4
                        Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                        $retryCount++
                    } until ($pingResult.Status -eq 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Unable to access iLO after '{0}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Unable to access iLO after '{7}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $maxRetries | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Unable to access iLO after '$maxRetries' retries following firmware update reset. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }       
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO firmware updated successfully and iLO is back online." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO firmware updated successfully and iLO is back online." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.FirmwareStatus = "Complete"
                        $objStatus.FirmwareDetails = "iLO firmware updated successfully"

                        $iLOConnection = $False

                        # Reconnect to iLO after the FW update
                        Try {
                            $maxRetries = 36 # 3 minutes
                            $retryCount = 0

                            "`t`t - Status: " | Write-Host -NoNewline
                            "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Reconnecting to iLO..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                            do {
                                try {
                                    if ($SkipCertificateValidation) {
                                        $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction stop
                                    }
                                    else {
                                        $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction stop
                                    }

                                }
                                catch {
                                    Start-Sleep -Seconds 4
                                    Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                                    $retryCount++
                                }
                            } until ($iLOConnection -or $retryCount -ge $maxRetries)

                            if ($retryCount -ge $maxRetries) {
                                "`t`t - Status: " | Write-Host -NoNewline
                                "Error connecting to iLO after firmware update. Error: {0}" -f $iLOConnection | Write-Host -ForegroundColor Red
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after firmware update. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOConnection | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after firmware update. Error: $iLOConnection"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                        catch {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error connecting to iLO after firmware update. Error: $_" | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after firmware update. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Error connecting to iLO after firmware update. Error: $($_)"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }              
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error updating iLO firmware. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error updating iLO firmware. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                    $objStatus.FirmwareStatus = "Error updating iLO firmware."
                    $objStatus.FirmwareDetails = $_
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO5 firmware update is not needed as firmware is v3.09 or higher." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO5 firmware update is not needed as firmware is v3.09 or higher." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "iLO firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Skipping firmware update."

            }
        }

        # COM activation key is not supported for iLO6 versions lower than v1.64
        if ($objStatus.iLOGeneration -eq "iLO6" -and $objStatus.OnboardingType -eq "Activation Key") {
    
            if ($objStatus.iLOFirmwareVersion -lt "1.64") {

                if (-not $iLO6binFile) {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO6 firmware update is needed as firmware is lower than v1.64 but iLO6binFile cannot be found. Please provide the iLO6 firmware file path and try again." | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update is needed as firmware is lower than v1.64 but iLO6binFile cannot be found. Please provide the iLO6 firmware file path and try again." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.FirmwareStatus = "Failed"
                    $objStatus.FirmwareDetails = "iLO6 firmware update is needed as firmware is lower than v1.64 but iLO6binFile cannot be found. Please provide the iLO6 firmware file path and try again."
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
                else {
                    # Get the full path of the iLO6 firmware file
                    $iLO6binFileFullPath = (Get-Item $iLO6binFile).FullName

                    try {

                        $TPMEnabled = $False

                        $maxRetries = 5 
                        $retryCount = 0
                               
                        do {

                            try {                               
                                $TPMStatus = Get-HPEiLOTPMStatus -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 
                                $TPMEnabled = $TPMStatus | Select-Object -ExpandProperty TPMEnabled -ErrorAction Stop
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update is needed as firmware is lower than v1.64. TPM Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $TPMEnabled | Write-Verbose

                            }
                            catch {
                                Start-Sleep -Seconds 2
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Exception detected to get TPMStatus: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose

                                Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                                if ($SkipCertificateValidation) {
                                    $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                                }
                                else {
                                    $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                                }

                                $retryCount++
                            }

                        } until ($TPMEnabled -or $retryCount -ge $maxRetries)

                        if ($retryCount -ge $maxRetries) {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Failed to retrieve iLO TPM status. StatusInfo: {0}" -f $TPMEnabled | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO TPM status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $TPMEnabled | Write-Verbose
                            $objStatus.FirmwareStatus = "Failed"
                            $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $iLOConnection"
                            $objStatus.Status = "Failed"        
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }                        
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error retrieving iLO TPM status.Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving iLO TPM status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $($_)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                }

                $FirmwareUpdateResult = $Null
            
                Try {

                    $iLOFlashActivity = $True
                    
                    $maxRetries = 20 
                    $retryCount = 0

                    "InProgress" | Write-Host -f Yellow
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO6 firmware update in progress as firmware is lower than v1.64..." | Write-Host -ForegroundColor Yellow

                    do {

                        try {  
                            if ($TPMEnabled -eq "Yes") {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO6binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -TPMEnabled -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update in progress as firmware is lower than v1.64 (TPM Enabled)..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                            }
                            else {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO6binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update in progress as firmware is lower than v1.64 (TPM not Enabled)..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                            }
                        }
                        catch {
                            Start-Sleep -Seconds 2
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Exception detected to update the iLO Firmware. Retrying... Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FirmwareUpdateResult | Write-Verbose

                            Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                            if ($SkipCertificateValidation) {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                            }
                            else {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                            }

                            Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                            $retryCount++                          
                        }

                    } until ($FirmwareUpdateResult.StatusInfo.Message -eq "ResetInProgress" -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error updating iLO firmware. StatusInfo: {0}" -f $FirmwareUpdateResult.StatusInfo.Message | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error updating iLO firmware. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FirmwareUpdateResult.StatusInfo.Message | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error updating iLO firmware. StatusInfo: $($FirmwareUpdateResult.StatusInfo.Message)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }            
                    
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO firmware must be activated. Waiting for the reset to be performed...!" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO firmware must be activated. Waiting for the reset to be performed..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                    # Wait until the iLO is unreachable after the reset
                    $maxRetries = 36 # 3 minutes
                    $retryCount = 0

                    do {
                        # Testing network access to iLO
                        $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 4
                        Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                        $retryCount++
                    } until ($pingResult.Status -ne 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }

                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO reset has been detected. Waiting for iLO to be back online..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.FirmwareStatus = "InProgress"
                    $objStatus.FirmwareDetails = "iLO reset has been detected. Waiting for iLO to be back online..."

                    # iLO is being reset with new changes. Waiting for the reset to be performed
                    Start-Sleep -Seconds 60
                        
                    # Wait for the iLO to be reachable after the reset
                    $maxRetries = 36 # 3 minutes
                    $retryCount = 0

                    do {
                        # Testing network access to iLO
                        $pingResult = Test-Connection -ComputerName $iLO.IP -Count 2 -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 4
                        Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                        $retryCount++
                    } until ($pingResult.Status -eq 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Unable to access iLO after '{0}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Unable to access iLO after '{7}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $maxRetries | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Unable to access iLO after '$maxRetries' retries following firmware update reset. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }       
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO is back online and iLO firmware updated successfully." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO firmware updated successfully and iLO is back online." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.FirmwareStatus = "Complete"
                        $objStatus.FirmwareDetails = "iLO firmware updated successfully"

                        $iLOConnection = $False

                        # Reconnect to iLO after the FW update
                        Try {
                            $maxRetries = 36 # 3 minutes
                            $retryCount = 0

                            "`t`t - Status: " | Write-Host -NoNewline
                            "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Reconnecting to iLO..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

                            do {
                                try {
                                    if ($SkipCertificateValidation) {
                                        $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction stop
                                    }
                                    else {
                                        $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction stop
                                    }

                                }
                                catch {
                                    Start-Sleep -Seconds 4
                                    Get-HPEGLAPIcredential | Out-Null ## Perform a Get operation to keep the HPE GreenLake session active
                                    $retryCount++
                                }
                            } until ($iLOConnection -or $retryCount -ge $maxRetries)

                            if ($retryCount -ge $maxRetries) {
                                "`t`t - Status: " | Write-Host -NoNewline
                                "Error connecting to iLO after firmware update. Error: {0}" -f $iLOConnection | Write-Host -ForegroundColor Red
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after firmware update. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOConnection | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after firmware update. Error: $iLOConnection"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                        catch {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error connecting to iLO after firmware update. Error: $_" | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting to iLO after firmware update. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Error connecting to iLO after firmware update. Error: $($_)"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }             
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error updating iLO firmware. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error updating iLO firmware. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                    $objStatus.FirmwareStatus = "Error updating iLO firmware."
                    $objStatus.FirmwareDetails = $_
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO6 firmware update is not needed as firmware is v1.64 or higher." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update is not needed as firmware is v1.64 or higher." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.FirmwareStatus = "iLO firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Skipping firmware update."

            }
        }
        elseif ($objStatus.iLOGeneration -eq "iLO6" -and $objStatus.OnboardingType -eq "Workspace ID") {
            "Skipped" | Write-Host -f Green
            "`t`t - Status: " | Write-Host -NoNewline
            "iLO6 firmware update is not needed as onboarding type is 'workspace ID'" | Write-Host -ForegroundColor Green
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO6 firmware update is not needed as onboarding type is 'workspace ID'" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
            $objStatus.FirmwareStatus = "iLO firmware fully supported by the onboarding type 'workspace ID'."
            $objStatus.FirmwareDetails = "Skipping firmware update."
        }
    }

    #EndRegion    
        
    #Region Check if iLO is already connected to a COM instance

    if ($Check) {

        "`t - iLO connection to COM: " | Write-Host -NoNewline
    
        try {
            $iLOCOMOnboardingStatus = Get-HPEiLOComputeOpsManagementStatus -Connection $iLOconnection -Verbose:$Verbose -ErrorAction Stop
               
            if ($iLOCOMOnboardingStatus.Status -eq "ERROR") {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error checking iLO connection status. Message: {0}" -f $iLOCOMOnboardingStatus.StatusInfo.Message | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO connection to COM status. StatusInfo: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOCOMOnboardingStatus.StatusInfo.Message | Write-Verbose
                $objStatus.iLOConnectionStatus = "Error checking iLO connection status to Compute Ops Management."
                $objStatus.iLOConnectionDetails = $iLOCOMOnboardingStatus.StatusInfo.Message
                $objStatus.Status = "Failed"
            }
            elseif ($iLOCOMOnboardingStatus.CloudConnectStatus -eq "Connected") {
                "Connected" | Write-Host -f Green
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO already connected to COM." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO already connected to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.iLOConnectionStatus = $iLOCOMOnboardingStatus.CloudConnectStatus
                $objStatus.iLOConnectionDetails = "iLO already connected to COM."
                $objStatus.Status = "Success"
            }
            else {
                "Disconnected" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO not connected to COM. Current status: {0}" -f $iLOCOMOnboardingStatus.CloudConnectStatus | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO not connected to COM. Status: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $iLOCOMOnboardingStatus.CloudConnectStatus | Write-Verbose
                $objStatus.iLOConnectionStatus = $iLOCOMOnboardingStatus.CloudConnectStatus
                $objStatus.iLOConnectionDetails = "iLO not connected to COM."
                $objStatus.Status = "Warning"
            }
        }
        catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Failed to retrieve iLO connection status. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve iLO connection to COM status. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.iLOConnectionStatus = "Failed to retrieve iLO connection to COM status."
            $objStatus.iLOConnectionDetails = "$($_)"
            $objStatus.Status = "Failed"
        }
    }

    #EndRegion

    #Region Onboarding iLOs to COM instance

    if (-not $Check) {

        #Region -------------------------------------------------------- Waiting for the iLO to be ready for onboarding after the reset (if any) ------------------------------------------

        if ($iLOFlashActivity) {

            "`t`t - Status: " | Write-Host -NoNewline
            "Waiting for iLO to be ready for COM connection..." | Write-Host -ForegroundColor Yellow
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Waiting for iLO to be ready for COM connection..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose

            $iLOComputeOpsManagementStatus = $Null
            $maxRetries = 60 # 5 minutes 
            $retryCount = 0

            while ($retryCount -lt $maxRetries -and $iLOComputeOpsManagementStatus -ne "OK") {
                try {
                    $iLOComputeOpsManagementStatus = Get-HPEiLOComputeOpsManagementStatus -Connection $iLOconnection -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty Status -ErrorAction Stop
                    
                    if ($iLOComputeOpsManagementStatus -eq "OK") {
                        Write-Verbose "Attempt $($retryCount + 1): iLO status is OK - ready for COM connection"
                        break  
                    }
                    else {
                        Write-Verbose "Attempt $($retryCount + 1): iLO status is '$iLOComputeOpsManagementStatus' - waiting..."
                    }
                }
                catch {
                    Write-Verbose "Attempt $($retryCount + 1): Failed to get iLO status: $($_.Exception.Message)"
                }
                
                if ($iLOComputeOpsManagementStatus -ne "OK") {
                    Start-Sleep -Seconds 4
                    Get-HPEGLAPIcredential | Out-Null ## Keep the HPE GreenLake session active
                }
                
                $retryCount++
            }

            if ($retryCount -ge $maxRetries) {
                $timeoutMinutes = [math]::Round(($maxRetries * 4) / 60, 1)
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO did not reach a ready state for COM connection after $maxRetries retries ($timeoutMinutes minutes). Last status: $iLOComputeOpsManagementStatus" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO did not reach a ready state for COM connection after {7} retries ({8} minutes). Last status: {9}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $maxRetries, $timeoutMinutes, $iLOComputeOpsManagementStatus | Write-Verbose
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "iLO did not reach a ready state for COM connection after $maxRetries retries ($timeoutMinutes minutes). Last status: $iLOComputeOpsManagementStatus"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO is ready for COM connection." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO is ready for COM connection after {7} attempts." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $retryCount | Write-Verbose
            }
        }
        #EndRegion
                
        #Region -------------------------------------------------------- Generating a COM activation key (if required) ----------------------------------------------------------------------------------

        if ($objStatus.OnboardingType -eq "Activation Key") {

            "`t - COM activation key: " | Write-Host -NoNewline
            "InProgress" | Write-Host -f Yellow

            try {
                # Determine activation key type and criteria
                if ($SecureGateway) {
                    $keyType = "secure gateway"
                    $existingKeyCriteria = { $_.applianceName -and $_.SubscriptionKey -and $_.expiresAt -gt (Get-Date).AddMinutes(10) }
                }
                else {
                    $keyType = "standard"
                    $existingKeyCriteria = { $_.SubscriptionKey -and $_.expiresAt -gt (Get-Date).AddMinutes(10) }
                }

                # Check if an activation key already exists
                $ExistingActivationKey = Get-HPECOMServerActivationKey -Region $Region -ErrorAction Stop | 
                Where-Object $existingKeyCriteria |
                Sort-Object expiresAt -Descending | 
                Select-Object -First 1 -ExpandProperty ActivationKey

                if (-not $ExistingActivationKey) {
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - No existing COM {7} activation key found matching criteria. Generating a new one..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $keyType | Write-Verbose
            
                    # Get a valid subscription key for the server
                    $SubscriptionKey = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server -Verbose:$Verbose -ErrorAction Stop | 
                    Select-Object -First 1 -ExpandProperty key

                    if (-not $SubscriptionKey) {      
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error retrieving a valid subscription key for the server. Please check your configuration and try again." | Write-Host -ForegroundColor Red 
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving a valid subscription key for the server. Please check your configuration and try again." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Error retrieving a valid subscription key for the server. Please check your configuration and try again."
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
            
                    # Generate a new activation key (valid for 24 hours)
                    if ($SecureGateway) {
                        $COMActivationKey = New-HPECOMServerActivationKey -Region $Region -ExpirationInHours 24 -SecureGateway $SecureGateway -SubscriptionKey $SubscriptionKey -Verbose:$Verbose -ErrorAction Stop
                    }
                    else {
                        $COMActivationKey = New-HPECOMServerActivationKey -Region $Region -ExpirationInHours 24 -SubscriptionKey $SubscriptionKey -Verbose:$Verbose -ErrorAction Stop
                    }

                    if ($COMActivationKey) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Successfully generated COM {0} activation key '{1}' for region '{2}'." -f $keyType, $COMActivationKey, $Region | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Successfully generated COM {7} activation key '{8}' for region '{9}'." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $keyType, $COMActivationKey, $Region | Write-Verbose
                    }
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error generating COM {0} activation key. Please check your configuration and try again." -f $keyType | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error generating COM {7} activation key. Please check your configuration and try again." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $keyType | Write-Verbose
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Error generating COM {0} activation key. Please check your configuration and try again." -f $keyType
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                }
                else {
                    # Use the existing activation key
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Existing COM {0} activation key '{1}' successfully retrieved for region '{2}'." -f $keyType, $ExistingActivationKey, $Region | Write-Host -ForegroundColor Green
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Existing COM {7} activation key '{8}' successfully retrieved for region '{9}'." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $keyType, $ExistingActivationKey, $Region | Write-Verbose
                    $COMActivationKey = $ExistingActivationKey
                }   
            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error generating COM activation key. Please check your configuration and try again." | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error generating COM activation key. Please check your configuration and try again. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.Details = "Error generating COM activation key. Error: $($_)"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
        }

        #EndRegion 

        #Region -------------------------------------------------------- Connecting iLO to COM --------------------------------------------------------------------------------------------
        
        "`t - iLO connection to COM: " | Write-Host -NoNewline
        "InProgress" | Write-Host -f Yellow
        
        if ($objStatus.OnboardingType -eq "Activation Key") {
            
            try {
                if ($WebProxyUsername) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                        -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -IloProxyUserName $WebProxyUsername -IloProxyPassword $WebProxyPassword `
                        -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                elseif ($WebProxyServer) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                        -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                elseif ($SecureGateway) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                        -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $SecureGateway -IloProxyPort "8080" -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                else {
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                        -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop 
                }    
            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error connecting iLO to COM. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting iLO to COM - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.iLOConnectionStatus = "Error connecting iLO to COM."
                $objStatus.iLOConnectionDetails = $_
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
        }
        elseif ($objStatus.OnboardingType -eq "Workspace ID") {

            # Add compute device to the currently connected HPE GreenLake workspace
            try {
                $AddComputeToWorkspace = Add-HPEGLDeviceCompute -SerialNumber $objStatus.SerialNumber -PartNumber $objStatus.PartNumber -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop

            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error adding compute to workspace. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding compute to workspace - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Error adding compute to workspace. Error: $($_)"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }

            if ($AddComputeToWorkspace.status -eq "Failed") {
                "`t`t - Status: " | Write-Host -NoNewline
                "Compute not added to workspace successfully. Error: {0}" -f $AddComputeToWorkspace.details | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Compute not added to workspace successfully. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $AddComputeToWorkspace.details | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Compute not added to workspace successfully. Error: {0}" -f $AddComputeToWorkspace.details
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "`t`t - Status: " | Write-Host -NoNewline
                "Compute added to workspace successfully." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Compute added to workspace successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.Status = "Success"
                $objStatus.Details = "Compute added to workspace successfully."                
            }

            # Add the compute device to the COM service
            try {
                $AddComputeToCOMInstance = Add-HPEGLDeviceToService -DeviceSerialNumber $objStatus.SerialNumber -ServiceName "Compute Ops Management" -ServiceRegion $Region -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop

            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error adding compute to Compute Ops Management service. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding compute to Compute Ops Management service - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Error adding compute to Compute Ops Management service. Error: $($_)"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }

            if ($AddComputeToCOMInstance.status -eq "Failed") {
                "`t`t - Status: " | Write-Host -NoNewline
                "Compute not added to Compute Ops Management service successfully. Error: {0}" -f $AddComputeToCOMInstance.details | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Compute not added to Compute Ops Management service successfully. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $AddComputeToCOMInstance.details | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Compute not added to Compute Ops Management service successfully. Error: {0}" -f $AddComputeToCOMInstance.details
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "`t`t - Status: " | Write-Host -NoNewline
                "Compute added to Compute Ops Management service successfully." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Compute added to Compute Ops Management service successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.Status = "Success"
                $objStatus.Details = "Compute added to Compute Ops Management service successfully."
            }

            # Add COM service subscription to the compute device
            try {

                $SubscriptionKey = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server -ShowDeviceSubscriptions | Select-Object -First 1 | Select-Object -ExpandProperty key
                "`t`t - Status: " | Write-Host -NoNewline
                "Compute Ops Management service subscription found: {0}" -f $SubscriptionKey | Write-Host -ForegroundColor Green

                if (-not $SubscriptionKey) {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error retrieving a valid subscription key for the server. Please check your configuration and try again." | Write-Host -ForegroundColor Red 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error retrieving a valid subscription key for the server. Please check your configuration and try again." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Error retrieving a valid subscription key for the server. Please check your configuration and try again."
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
                                  
                $AssignSubscriptionToDevice = Add-HPEGLSubscriptionToDevice $objStatus.SerialNumber -SubscriptionKey $SubscriptionKey -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop

                if ($AssignSubscriptionToDevice.status -eq "Failed") {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error adding Compute Ops Management service subscription to compute. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding compute to Compute Ops Management service subscription - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Error adding compute to Compute Ops Management service subscription. Error: $($_)"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
                else {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Compute Ops Management service subscription added to compute successfully." | Write-Host -ForegroundColor Green
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Compute Ops Management service subscription added to compute successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.Status = "Success"
                    $objStatus.Details = "Compute Ops Management service subscription added to compute successfully."
                }
            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error adding Compute Ops Management service subscription to compute. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding compute to Compute Ops Management service subscription - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Error adding compute to Compute Ops Management service subscription. Error: $($_)"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }


            # Connect iLO to Compute Ops Management
            try {
                if ($WebProxyUsername) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP -SerialNumber $objStatus.SerialNumber `
                        -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -IloProxyUserName $WebProxyUsername -IloProxyPassword $WebProxyPassword `
                        -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                elseif ($WebProxyServer) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP -SerialNumber $objStatus.SerialNumber `
                        -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                elseif ($SecureGateway) {
        
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP -SerialNumber $objStatus.SerialNumber `
                        -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -IloProxyServer $SecureGateway -IloProxyPort "8080" -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
                }
                else {
                    $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP -SerialNumber $objStatus.SerialNumber `
                        -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                        -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop 
                }    
            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error connecting iLO to COM. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting iLO to COM - Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.iLOConnectionStatus = "Error connecting iLO to COM."
                $objStatus.iLOConnectionDetails = $_
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
        }

        # Check the iLO connection status to COM

        if ($OnboardingStatus.Status -eq "Failed" -or $OnboardingStatus.Status -eq "Warning") {
            # Handle failed/warning status
            "`t`t - Status: " | Write-Host -NoNewline
            "Error connecting iLO to COM. Status: {0} - Details: {1}" -f $OnboardingStatus.Status, $OnboardingStatus.iLOConnectionDetails | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error connecting iLO to COM - Status: {7} - Details: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $OnboardingStatus.Status, $OnboardingStatus.iLOConnectionDetails | Write-Verbose
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
        elseif ($OnboardingStatus.iLOConnectionDetails -match "iLO is already connected to the Compute Ops Management instance!") {
            # Handle already connected
            "`t`t - Status: " | Write-Host -NoNewline
            "iLO is already connected to COM." | Write-Host -ForegroundColor Green
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO is already connected to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
        }
        else {
            # Handle successful new connection
            "`t`t - Status: " | Write-Host -NoNewline
            "iLO successfully connected to COM." | Write-Host -ForegroundColor Green
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - iLO successfully connected to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
        }

        # Update status properties for all scenarios
        $objStatus.Status = $OnboardingStatus.Status
        $objStatus.Details = $OnboardingStatus.Details
        $objStatus.iLOConnectionStatus = if ($OnboardingStatus.iLOConnectionStatus) { $OnboardingStatus.iLOConnectionStatus } else { $OnboardingStatus.Status }
        $objStatus.iLOConnectionDetails = if ($OnboardingStatus.iLOConnectionDetails) { $OnboardingStatus.iLOConnectionDetails } else { $OnboardingStatus.Details }
        
        #EndRegion

    }
        
    #EndRegion

    #Region Check tags assigned to the device
        
    if ($Check) {

        if ($Tags) {

            "`t - Tags: " | Write-Host -NoNewline

            $CurrentDeviceTags = $Null
            $Devicefound = $Null

            # Check if the device exists in the workspace
            try {
                $Devicefound = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
      
                if (-not $Devicefound) {    
                    "Warning" | Write-Host -f Yellow
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "`t`t - Missing: " | Write-Host -NoNewline
                    $Tags | Write-Host -f Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tags will be configured after the device is connected to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                    $objStatus.TagsAssignmentStatus = "Warning"
                    $objStatus.TagsAssignmentDetails = "Tags will be configured after the device is connected to COM."
                }
                else {
    
                    $CurrentDeviceTags = $Devicefound | Select-Object -ExpandProperty Tags

                    if ($CurrentDeviceTags.Count -gt 0) {

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $CurrentDeviceTags.Count | Write-Verbose

                        # Transform $Tags defined in the script into a PSCustomObject for comparison
                        $TagsArray = $Tags -split ", "
                        $TagsHashtable = @{}

                        foreach ($Tag in $TagsArray) {
                            $key, $value = $Tag -split "="
                            $TagsHashtable[$key] = $value
                        }

                        $TagsObject = [PSCustomObject]$TagsHashtable

                        # Transform $CurrentDeviceTags into a PSCustomObject for comparison
                        $CurrentDeviceTagsHashtable = @{}

                        foreach ($CurrentDeviceTag in $CurrentDeviceTags) {
                            $CurrentDeviceTagsHashtable[$CurrentDeviceTag.Name] = $CurrentDeviceTag.Value
                        }

                        $CurrentDeviceTagsObject = [PSCustomObject]$CurrentDeviceTagsHashtable

        
                        # Initialize arrays to store missing and extra tags
                        $missingTags = @{}
                        $extraTags = @{}

                        # Check for missing tags (present in $TagsObject but not in $CurrentDeviceTagsObject)
                        foreach ($property in $TagsObject.PSObject.Properties) {
                            if (-not $CurrentDeviceTagsObject.PSObject.Properties[$property.Name] -or $CurrentDeviceTagsObject.PSObject.Properties[$property.Name].Value -ne $property.Value) {
                                $missingTags[$property.Name] = $property.Value
                            }
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Missing tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, ($missingTags | Out-String ) | Write-Verbose

                        # Check for extra tags (present in $CurrentDeviceTagsObject but not in $TagsObject)
                        foreach ($property in $CurrentDeviceTagsObject.PSObject.Properties) {
                            if (-not $TagsObject.PSObject.Properties[$property.Name] -or $TagsObject.PSObject.Properties[$property.Name].Value -ne $property.Value) {
                                $extraTags[$property.Name] = $property.Value
                            }
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Extra tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, ($extraTags | Out-String ) | Write-Verbose

                        # Format the missing tags
        
                        $MissingTagsList = [System.Collections.ArrayList]::new()
        
                        foreach ($tag in $missingTags.GetEnumerator()) { 
                            [void]$MissingTagsList.add("$($tag.Key)=$($tag.Value)")
                        }
        
                        if ($MissingTagsList.Count -gt 1) {
                            $FormattedMissingTags = $MissingTagsList -join ", "
                        }
                        elseif ($MissingTagsList.Count -eq 1) {
                            $FormattedMissingTags = $MissingTagsList[0]
                        }
                        else {
                            $FormattedMissingTags = ""
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Formatted missing tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedMissingTags | Write-Verbose

                        # Format the extra tags
        
                        $ExtraTagsList = [System.Collections.ArrayList]::new()
        
                        foreach ($tag in $extraTags.GetEnumerator()) { 
                            [void]$ExtraTagsList.add("$($tag.Key)=$($tag.Value)")
                        }

                        if ($ExtraTagsList.Count -gt 1) {
                            $FormattedExtraTags = $ExtraTagsList -join ", "
                        }
                        elseif ($ExtraTagsList.Count -eq 1) {
                            $FormattedExtraTags = $ExtraTagsList[0]
                        }
                        else {
                            $FormattedExtraTags = ""
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Formatted extra tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedExtraTags | Write-Verbose

                        # Format the tags assigned to the device

                        $CurrentDeviceTagsList = [System.Collections.ArrayList]::new()
        
                        foreach ($tag in $CurrentDeviceTags) { 
                            [void]$CurrentDeviceTagsList.add("$($tag.Name)=$($tag.Value)")
                        }
            
                        if ($CurrentDeviceTagsList.Count -gt 1) {
                            $FormattedCurrentTags = $CurrentDeviceTagsList -join ", "
                        }
                        elseif ($CurrentDeviceTagsList.Count -eq 1) {
                            $FormattedCurrentTags = $CurrentDeviceTagsList[0]
                        }
                        else {
                            $FormattedCurrentTags = ""
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Formatted currently assigned tags found: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedCurrentTags | Write-Verbose           
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Missing tags: {7} - Extra tags: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $MissingTagsList.count, $ExtraTagsList.count | Write-Verbose

                        if ($MissingTagsList.Count -gt 0 -or $ExtraTagsList.Count -gt 0) {

                            if ($MissingTagsList.Count -gt 0 -and $ExtraTagsList.Count -eq 0) {            
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Missing: " | Write-Host -NoNewline
                                Write-Host $FormattedMissingTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tag configuration is required. Missing: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedMissingTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Warning"
                                $objStatus.TagsAssignmentDetails = "Missing tags: $FormattedMissingTags"
                            }
                            elseif ($ExtraTagsList.Count -gt 0 -and $MissingTagsList.Count -eq 0) {
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Extra: " | Write-Host -NoNewline
                                Write-Host $FormattedExtraTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tag configuration is required. Extra: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedExtraTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Warning"
                                $objStatus.TagsAssignmentDetails = "Extra tags: $FormattedExtraTags"
                            }
                            elseif ($MissingTagsList.Count -gt 0 -and $ExtraTagsList.Count -gt 0) {
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Extra: " | Write-Host -NoNewline
                                Write-Host $FormattedExtraTags -f Yellow
                                "`t`t - Missing: " | Write-Host -NoNewline
                                Write-Host $FormattedMissingTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tag configuration is required. Missing: {7} - Extra: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $FormattedMissingTags, $FormattedExtraTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Warning"
                                $objStatus.TagsAssignmentDetails = "Missing tags: $FormattedMissingTags - Extra tags: $FormattedExtraTags"
                            }
                        }
                        else {
                            "OK" | Write-Host -f Green
                            "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                            "`t`t - Missing: " | Write-Host -NoNewline
                            "None" | Write-Host -ForegroundColor Green
                            "`t`t - Extra: " | Write-Host -NoNewline
                            "None" | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tags configuration is not required as tags are already defined!" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                            $objStatus.TagsAssignmentStatus = "Complete"
                            $objStatus.TagsAssignmentDetails = "Tags configuration is not required as tags are already defined!"
                        }
                
                    }
                    else {
                        "Warning" | Write-Host -f Yellow
                        "`t`t - Current: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Yellow
                        "`t`t - Missing: " | Write-Host -NoNewline
                        $Tags | Write-Host -f Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tags configuration is required as no tags are currently defined!" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.TagsAssignmentStatus = "Warning"
                        $objStatus.TagsAssignmentDetails = "Tags configuration is required as no tags are currently defined!"
                    }                    
                }
            }
            catch {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error retrieving device details in the workspace. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve device details in the workspace. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.TagsAssignmentStatus = "Error retrieving device details."
                $objStatus.TagsAssignmentDetails = $_
                $objStatus.Status = "Failed"

            }
        }
    }
    #EndRegion

    #Region Add tags to the device (if any)

    if (-not $Check -and $Tags) {

        "`t - Tags: " | Write-Host -NoNewline

        Try {
            
            $Devicefound = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
        
            if (-not $Devicefound) {    
                "Failed" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "Device not found in the workspace." | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Device not found in the workspace." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                $objStatus.TagsAssignmentStatus = "Failed"
                $objStatus.TagsAssignmentDetails = "Device not found in the workspace."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
    
                $DeviceTags = $Devicefound | Select-Object -ExpandProperty Tags
    
                # Remove existing tags (if any)
                if ($DeviceTags.Count -gt 0) {
    
                    # Initialize an empty string to store the formatted tags
                    $ExistingtagsList = [System.Collections.ArrayList]::new()
    
                    foreach ($tag in $DeviceTags) { 
                        [void]$ExistingtagsList.add("$($tag.Name)=$($tag.Value)")
                    }
                    
                    if ($ExistingtagsList.Count -gt 1) {
                        $ExistingtagsList = $ExistingtagsList -join ", "
                    }
                    else {
                        $ExistingtagsList = $ExistingtagsList[0]
                    }
    
                    Try {
                        $DeviceTagsRemovalStatus = Remove-HPEGLDeviceTagFromDevice -SerialNumber $objStatus.SerialNumber -All -Verbose:$Verbose -ErrorAction Stop
    
                        if ($DeviceTagsRemovalStatus.Status -eq "Complete") {
                            "InProgress" | Write-Host -f Yellow
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Existing tags removed successfully." | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Existing tags ({7}) removed successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $ExistingtagsList | Write-Verbose
                        }
                        else {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error removing tags. Status: {0} - Details: {1}" -f $DeviceTagsRemovalStatus.Status, $DeviceTagsRemovalStatus.Details | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error removing tags '{7}'. Status: {8} - Details: {9}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $ExistingtagsList, $DeviceTagsRemovalStatus.Status, $DeviceTagsRemovalStatus.Details | Write-Verbose
                            $objStatus.TagsAssignmentStatus = "Failed"
                            $objStatus.TagsAssignmentDetails = "Error removing tags. Status: $($DeviceTagsRemovalStatus.Status) - Details: $($DeviceTagsRemovalStatus.Details)"
                            $objStatus.Status = "Failed"                 
                        }
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error removing tags. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error removing tags '{7}'. Error: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $ExistingtagsList, $_ | Write-Verbose
                        $objStatus.TagsAssignmentStatus = "Error removing tags from device."
                        $objStatus.TagsAssignmentDetails = $_
                        $objStatus.Status = "Failed"
                    }                    
                }
                else {
                    "InProgress" | Write-Host -f Yellow            
                }
    
                try {
                    $TagsAssignmentStatus = Add-HPEGLDeviceTagToDevice -Tags $Tags -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop

                    if ($TagsAssignmentStatus.Status -eq "Complete" -or $TagsAssignmentStatus.Status -eq "Warning") {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Tags '{0}' added successfully." -f $Tags | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Tags '{7}' added successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $Tags | Write-Verbose
                        $objStatus.TagsAssignmentStatus = $TagsAssignmentStatus.Status
                        $objStatus.TagsAssignmentDetails = $TagsAssignmentStatus.Details
                    }
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error adding tags. Status: {0} - Details: {1}" -f $TagsAssignmentStatus.Status, $TagsAssignmentStatus.Details | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding tags '{7}'. Status: {8} - Details: {9}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $Tags, $TagsAssignmentStatus.Status, $TagsAssignmentStatus.Details | Write-Verbose
                        $objStatus.TagsAssignmentStatus = $TagsAssignmentStatus.Status
                        $objStatus.TagsAssignmentDetails = $TagsAssignmentStatus.Details
                        $objStatus.Status = "Failed"
                    }
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error adding tags. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error adding tags '{7}'. Error: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $Tags, $_ | Write-Verbose
                    $objStatus.TagsAssignmentStatus = "Error adding tags to device."
                    $objStatus.TagsAssignmentDetails = $_
                    $objStatus.Status = "Failed"
                }
            }
        }
        catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Error retrieving device details in the workspace. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve device details in the workspace. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.TagsAssignmentStatus = "Error retrieving device details."
            $objStatus.TagsAssignmentDetails = $_
            $objStatus.Status = "Failed"         
        }

    }

    #EndRegion

    #Region Check defined location 

    if ($Check) {

        if ($LocationName) {

            "`t - Location: " | Write-Host -NoNewline

            $Devicefound = $Null
            $DeviceLocation = $Null

            # Check if the device exists in the workspace
            try {
                $Devicefound = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
     
                if (-not $Devicefound) {  
                    "Warning" | Write-Host -f Yellow               
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "`t`t - Required: " | Write-Host -NoNewline
                    "{0}" -f $LocationName | Write-Host   
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location '{7}' will be configured after the device is connected to COM." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $LocationName | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Warning"
                    $objStatus.LocationAssignmentDetails = "Location will be configured after the device is connected to COM."
                }
                else {           
                    
                    $DeviceLocation = $Devicefound | Select-Object -ExpandProperty location_name
                                        
                    # Check if the device is already assigned to the location
    
                    if (-not $DeviceLocation) { 
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Yellow
                        "`t`t - Required: " | Write-Host -NoNewline
                        "{0}" -f $LocationName | Write-Host 
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location configuration is required as the location is not configured." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.LocationAssignmentStatus = "Warning"
                        $objStatus.LocationAssignmentDetails = "Location configuration is required as the location is not configured."
                    }
                    elseif ($DeviceLocation -eq $LocationName) {                        
                        "OK" | Write-Host -f Green               
                        "`t`t - Current: " | Write-Host -NoNewline
                        "{0}" -f $DeviceLocation | Write-Host -ForegroundColor Green
                        "`t`t - Required: " | Write-Host -NoNewline
                        "{0}" -f $LocationName | Write-Host 
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location configuration is not required as the location is already configured." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.LocationAssignmentStatus = "Complete"
                        $objStatus.LocationAssignmentDetails = "Location configuration is not required as the location is already configured."                        
                    }
                    else {
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: " | Write-Host -NoNewline
                        "{0}" -f $DeviceLocation | Write-Host -ForegroundColor Yellow
                        "`t`t - Required: " | Write-Host -NoNewline
                        "{0}" -f $LocationName | Write-Host 
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location configuration is required as the location currently defined is incorrect." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM | Write-Verbose
                        $objStatus.LocationAssignmentStatus = "Warning"
                        $objStatus.LocationAssignmentDetails = "Location configuration is required as the location currently defined is incorrect."
                    }                                
                }   
            }
            catch {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error retrieving device details in the workspace. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve device details in the workspace. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                $objStatus.LocationAssignmentStatus = "Error retrieving device details."
                $objStatus.LocationAssignmentDetails = $_
                $objStatus.Status = "Failed"
            }          
        }                 
    }
    
    #EndRegion

    #Region Assign device to location (if any)

    if (-not $Check -and $LocationName) {

        "`t - Location: " | Write-Host -NoNewline

        try {
            $DeviceLocation = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty location_name       

            if ($LocationName -ne $DeviceLocation) {
    
                # Remove location if the device is assigned to a different location
                if ($DeviceLocation) {
    
                    try {
                        $LocationRemovalStatus = Remove-HPEGLDeviceLocation -DeviceSerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
                        
                        if ($LocationRemovalStatus.Status -eq "Complete") {
                            "InProgress" | Write-Host -f Yellow
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Device removed from location successfully." | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Device removed from location '{7}' successfully." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $DeviceLocation | Write-Verbose
                        }
                        else {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error removing device from location. Status: {0} - Details: {1}" -f $LocationRemovalStatus.Status, $LocationRemovalStatus.Details | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error removing device from location '{7}'. Status: {8} - Details: {9}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $DeviceLocation, $LocationRemovalStatus.Status, $LocationRemovalStatus.Details | Write-Verbose
                            $objStatus.LocationAssignmentStatus = "Failed"
                            $objStatus.LocationAssignmentDetails = "Error removing device from location '$($DeviceLocation)'. Status: $($LocationRemovalStatus.Status) - Details: $($LocationRemovalStatus.Details)"
                            $objStatus.Status = "Failed"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }
                    catch {
                        "Failed" | Write-Host -f Red
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error removing device from location. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to remove device from location. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
                        $objStatus.LocationAssignmentStatus = "Failed to remove device from location."
                        $objStatus.LocationAssignmentDetails = $_
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }    
                }  
                else {   
                    "InProgress" | Write-Host -f Yellow
                    "`t`t - Status: " | Write-Host -NoNewline
                    "No current location assigned. Proceeding to assign new location." | Write-Host -ForegroundColor Yellow
                }
            
            
                # Assign the device to the defined location
                try {
    
                    $LocationAssignmentStatus = Set-HPEGLDeviceLocation -LocationName $LocationName -DeviceSerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop 

                    if ($LocationAssignmentStatus.Status -eq "Failed") {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error assigning location. Status: {0} - Details: {1}" -f $LocationAssignmentStatus.Status, $LocationAssignmentStatus.Details | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error assigning location '{7}'. Status: {8} - Details: {9}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $LocationName, $LocationAssignmentStatus.Status, $LocationAssignmentStatus.Details | Write-Verbose
                        $objStatus.LocationAssignmentStatus = $LocationAssignmentStatus.Status
                        $objStatus.LocationAssignmentDetails = $LocationAssignmentStatus.Details
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Location assigned successfully." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location '{7}' successfully assigned." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $LocationName | Write-Verbose
                        $objStatus.LocationAssignmentStatus = $LocationAssignmentStatus.Status
                        $objStatus.LocationAssignmentDetails = $LocationAssignmentStatus.Details
                    }                    
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error assigning location. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Error assigning location '{7}'. Error: {8}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $LocationName, $_ | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Error assigning device to location."
                    $objStatus.LocationAssignmentDetails = $_
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
    
            }
            # If the device is already assigned to the defined location
            else {
                "Complete" | Write-Host -f Green
                "`t`t - Status: " | Write-Host -NoNewline
                "Location already defined." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Location '{7}' already defined. Skipping location assignment..." -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $DeviceLocation | Write-Verbose
                $objStatus.LocationAssignmentStatus = "Location already defined."
                $objStatus.LocationAssignmentDetails = $DeviceLocation          
            }       
        }
        catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Error retrieving device details in the workspace. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5} - SystemROM: {6}) - Failed to retrieve device details in the workspace. Error: {7}" -f $iLO.IP, $objStatus.iLOFirmwareVersion, $objStatus.iLOGeneration, $objStatus.ServerModel, $objStatus.ServerGeneration, $objStatus.SerialNumber, $objStatus.ServerSystemROM, $_ | Write-Verbose
            $objStatus.LocationAssignmentStatus = "Failed to retrieve device location details."
            $objStatus.LocationAssignmentDetails = $_
            $objStatus.Status = "Failed"    
            [void]$iLOPreparationStatus.Add($objStatus)
            continue      
        }
    }


    # Add the status of the operation to the array
    [void]$iLOPreparationStatus.Add($objStatus)

    #EndRegion

}

#EndRegion

#Region -------------------------------------------------------- Generating output -------------------------------------------------------------------------------------

# Get the script's directory to ensure consistent file placement
$ScriptDirectory = if ($PSScriptRoot) { 
    $PSScriptRoot 
}
else { 
    Split-Path -Parent $MyInvocation.MyCommand.Path 
}

# Define the output file names with full paths
$Date = Get-Date -Format "yyyyMMdd_HHmm"
$OnboardingReportFile = Join-Path $ScriptDirectory "iLO_Onboarding_Status_$Date.csv"
$CheckReportFile = Join-Path $ScriptDirectory "iLO_Check_Status_$Date.csv"

# Helper function to safely export CSV with file lock handling
function Export-StatusReport {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [array]$StatusData
    )
    
    Write-Verbose "Attempting to export status report to: $FilePath"
    
    # Ensure the directory exists
    $directory = Split-Path -Parent $FilePath
    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $fileStream.Close()
            $StatusData | Export-Csv -Path $FilePath -NoTypeInformation -Force -Encoding UTF8
            Write-Verbose "Successfully exported status report to: $FilePath"
            break
        }
        catch {
            Write-Host "The file '$FilePath' is currently open. Please close the file and press any key to continue..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# Handle output based on operation mode
if (-not $Check) {
    # Onboarding mode - show results and export
    $failedDevices = $iLOPreparationStatus | Where-Object { $_.Status -eq "Failed" }
    
    if ($failedDevices) {
        $failureCount = ($failedDevices | Measure-Object).Count
        $totalCount = ($iLOPreparationStatus | Measure-Object).Count
        Write-Host "`n⚠️  Onboarding completed with issues: $failureCount of $totalCount devices failed." -ForegroundColor Yellow
        Write-Host "   Please review the detailed status report and resolve any issues before retrying." -ForegroundColor Yellow
    }
    else {
        $successCount = ($iLOPreparationStatus | Measure-Object).Count
        Write-Host "`n✅ Onboarding completed successfully!" -ForegroundColor Green
        Write-Host "   All $successCount servers have been configured and connected to Compute Ops Management in the '$region' region." -ForegroundColor Cyan
    }
    
    # Export onboarding status
    Export-StatusReport -FilePath $OnboardingReportFile -StatusData $iLOPreparationStatus
    Write-Host "`n📄 Onboarding status report exported to: $OnboardingReportFile" -ForegroundColor Cyan
}
else {
    # Check mode - show results and export
    $failedChecks = $iLOPreparationStatus | Where-Object { $_.Status -eq "Failed" -or $_.Status -eq "Error" }
    $totalChecked = ($iLOPreparationStatus | Measure-Object).Count
    
    if ($failedChecks) {
        $failureCount = ($failedChecks | Measure-Object).Count
        Write-Host "`n⚠️  Status check completed: $failureCount of $totalChecked devices have issues." -ForegroundColor Yellow
    }
    else {
        Write-Host "`n✅ Status check completed successfully!" -ForegroundColor Green
        Write-Host "   All $totalChecked devices are properly configured and connected." -ForegroundColor Cyan
    }
    
    # Export check status
    Export-StatusReport -FilePath $CheckReportFile -StatusData $iLOPreparationStatus
    Write-Host "`n📄 Status check report exported to: $CheckReportFile" -ForegroundColor Cyan
}

#EndRegion
    
# Disconnect-OVMgmt
Read-Host -Prompt "Hit return to close" 


