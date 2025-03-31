
<#
This PowerShell script automates the process of importing device subscriptions into HPE GreenLake using the HPECOMCmdlets PowerShell module.

The script requires an XLSX file containing a list of HPE GreenLake subscription keys to be imported. The file must include a column named "License Key" with the subscription keys.

Requirements:
    - PowerShell 7.x or later.
    - HPECOMCmdlets PowerShell module (automatically installed if not already present).
    - An XLSX file containing HPE GreenLake subscription keys. The file must include a column named "License Key" with the subscription keys.
    - Network access to HPE GreenLake.
    - HPE GreenLake user account:
        - With the Workspace Administrator or Workspace Operator role.
        - If using custom roles, ensure the account has the "Devices and Subscription Service Edit" permission.
    - HPE GreenLake workspace already set up.

Usage Instructions:
    1. Run the script in a PowerShell 7 environment with the following parameters:
            - `HPEAccount`: Your HPE GreenLake account email.
            - `WorkspaceName`: The name of the HPE GreenLake workspace to connect to.
            - `Path`: The path to the XLSX file containing the subscription keys.
    2. The script will prompt you to enter your HPE GreenLake account password.
    3. Review the output to verify that the subscriptions were successfully imported into HPE GreenLake.


Example: 

& '.\Import-device-subscriptions.ps1' -HPEAccount 'email@domain.com' -WorkspaceName 'HPE Mougins' -Path 'Z:\Gen11 COM Subscriptions.xlsx'

Output:

    [Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.
    
    [Workspace: HPE Mougins] - Subscription '1234567890' added successfully.
    [Workspace: HPE Mougins] - Subscription '0987654321' added successfully.
    [Workspace: HPE Mougins] - Subscription 'abcdefghij' failed to be added - Details: Subscription already exists in the workspace! No action needed.
    Hit return to close:


Disclaimer: The script is provided as-is and is not officially supported by HPE. It is recommended to test the script in a non-production environment before running it in a production environment. Use the script at your own risk.


  Author: lionel.jullien@hpe.com
  Date:   March 2025
  Script source: https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Import-device-subscriptions.ps1 
  


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
    # Path to the XLSX file that contains the list of HPE GreenLake subscription keys to be imported
    # This parameter is required to specify the file path
    # The file should contain a column named "License Key" with the subscription keys
    [string]$Path,
    
    # HPE GreenLake account email
    # This parameter is required to connect to HPE GreenLake
    [string]$HPEAccount,

    # HPE GreenLake workspace name
    # This parameter is required to specify the workspace to connect to
    [string]$WorkspaceName,

    [switch]$Verbose

    
)


#Region -------------------------------------------------------- Preparation -----------------------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($HPEAccount)) {
    "HPEAccount parameter is required. Please provide your HPE GreenLake account email." | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

if ([string]::IsNullOrWhiteSpace($WorkspaceName)) {
    "WorkspaceName parameter is required. Please provide your HPE GreenLake workspace name." | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

# Check if PSGallery repository is registered and install HPECOMCmdlets module
if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository..."
    Register-PSRepository -Default
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
    Import-Module HPECOMCmdlets
}
else {
    $installedModuleVersion = [version](Get-Module HPECOMCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Version)
    $latestVersion = [version](Find-Module -Name HPECOMCmdlets | Select-Object -ExpandProperty Version)

    if ($installedModuleVersion -lt $latestVersion) {
        Write-Host "A newer version of HPECOMCmdlets module is available, updating now..."

        Try {
            Install-Module -Name HPECOMCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop

        }
        catch {
            $_
            Read-Host "Hit return to close"
            exit
        }
    }
    Import-Module HPECOMCmdlets
}


# Importing Excel file
if (-not (Test-Path $Path)) {
    "Excel file '{0}' not found. Please check your file path and try again." -f $Path | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}
else {
    try {
        # Ensure the ImportExcel module is installed
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Install-Module -Name ImportExcel -Force -AllowClobber -AcceptLicense
        }
        Import-Module ImportExcel

        # Import the Excel file
        $Subscriptions = (Import-Excel -Path $Path)."License Key"
    }
    catch {
        "Failed to import Excel file. Error: $_" | Write-Host -f Red
        Read-Host -Prompt "Hit return to close"
        exit
    }
}

# Check if the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7 ) {
    Write-Error "PowerShell 7.x is required. Please run this script in PowerShell 7."
    Read-Host -Prompt "Hit return to close"
    exit
}


# Set Verbose preference
$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

#EndRegion


#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

# Connect ot HPE GreenLake workspace

try {
    # Check if already connected to HPE GreenLake
    Get-HPEGLWorkspace -ShowCurrent -Verbose:$Verbose -ErrorAction Stop | Out-Null
}
catch {
    # Ask for password
    $HPEAccountSecuredPassword = Read-Host -AsSecureString "Enter password for your HPE GreenLake account '$HPEAccount'"
    $GLPcredentials = New-Object System.Management.Automation.PSCredential ($HPEAccount, $HPEAccountSecuredPassword)
    # Connect ot HPE GreenLake workspace
    $GLPConnection = Connect-HPEGL -Credential $GLPcredentials -Workspace $WorkspaceName -Verbose:$Verbose
}


if ($GLPConnection -or $HPEGreenLakeSession) {
    "`n[Workspace: {0}] - Successfully connected to the HPE GreenLake workspace.`n" -f $WorkspaceName | Write-Host -ForegroundColor Green

}
else {
    "[Workspace: {0}] - Error connecting to the HPE GreenLake workspace. Please check your credentials and try again." -f $WorkspaceName | Write-Host -ForegroundColor Red
    Read-Host -Prompt "Hit return to close" 
    exit
}

#EndRegion


#Region -------------------------------------------------------- Importing COM subscriptions -------------------------------------------------------------------------------------


foreach ($Subscription in $Subscriptions | Select-Object -First 2) {
    
    try {
   
        $AddCOMSubscription = New-HPEGLSubscription -SubscriptionKey $Subscription -Verbose:$Verbose -ErrorAction Stop 
   
        # Check if the subscription was added successfully
        if ($AddCOMSubscription.status -eq "Complete") {
            "[Workspace: {0}] - Subscription '{1}' added successfully." -f $WorkspaceName, $Subscription | Write-Host -f Green
        }
        else {
            "[Workspace: {0}] - Subscription '{1}' failed to be added - Details: {2}" -f $WorkspaceName, $Subscription, $AddCOMSubscription.details | Write-Host -f Red
        }
    }
    catch {
   
        "[Workspace: {0}] - Error importing the subscription. Status: {1}" -f $WorkspaceName, $_ | Write-Host -f Red
        continue
    }
}



#EndRegion       


       
# Disconnect-OVMgmt
Read-Host -Prompt "Operation completed. Hit return to close"


