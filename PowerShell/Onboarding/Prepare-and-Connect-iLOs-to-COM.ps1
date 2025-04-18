
<# DEPRECATED SCRIPT

This script is deprecated and must not be used. 
A new version is now available at https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1
Please update to the latest version to ensure compatibility and access to new features.

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

# iLO Web Proxy or Secure Gateway settings (optional)
# $WebProxyServer = "myproxy.internal.net"
# $WebProxyPort = "8080"
# $WebProxyUsername = "myproxyuser"
# $WebProxyPassword = (Read-Host -AsSecureString "Enter password for proxy account '$WebProxyUsername'")

# HPE GreenLake account with HPE GreenLake and Compute Ops Management administrative privileges
$HPEAccount = "email@domain.com"

# HPE GreenLake workspace name where the Compute Ops Management instance is provisioned
$WorkspaceName = "HPE Mougins"

# Region where the Compute Ops Management instance is provisioned
$Region = "eu-central"

# Location name where the devices will be assigned (optional)
# (Required for automated HPE support case creation and services)
$LocationName = "Nice"

# Tags to assign to devices (optional)
$Tags = "Country=FR, App=AI, Department=IT" 

#EndRegion

#Region -------------------------------------------------------- Preparation -----------------------------------------------------------------------------------------

# Ask for the iLO account password
$iLOSecuredPassword = (Read-Host -AsSecureString "Enter password for iLO account '$iLOUserName'")


# Importing iLO list
if (-not (Test-Path $iLOcsvPath)) {
    "iLO CSV file '{0}' not found. Please check your CSV file path and try again." -f $iLOcsvPath | Write-Host -f Red
    Read-Host -Prompt "Hit return to close" 
    exit
}
else {
    $iLOs = Import-Csv -Path $iLOcsvPath
}
# Check if the script is running in PowerShell 7 and lower than 7.5.0
if ($PSVersionTable.PSVersion.Major -ne 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -ge 5)) {
    Write-Error "This script requires PowerShell 7.x where x < 5.0. Please run this script in the appropriate version of PowerShell 7."
    "This script requires PowerShell 7.x where x < 5.0. Please run this script in the appropriate version of PowerShell 7." | Write-Host -f Red
    Read-Host -Prompt "Hit return to close"
    exit
}

# Check if iLO firmware files are present
if ($iLO5binFile) {
    if (-not (Test-Path $iLO5binFile)) {
        "iLO5 firmware file '{0}' not found. Please check your iLO5 firmware file path and try again." -f $iLO5binFile | Write-Host -f Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }
}

if ($iLO6binFile) {
    if (-not (Test-Path $iLO6binFile)) {
        "iLO6 firmware file '{0}' not found. Please check your iLO6 firmware file path and try again." -f $iLO6binFile | Write-Host -f Red
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

    Import-Module HPEiLOCmdlets
}
else {
    $installedModuleVersion = [version](Get-Module HPEiLOCmdlets -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Version)
    $latestVersion = [version](Find-Module -Name HPEiLOCmdlets | Select-Object -ExpandProperty Version)

    if ($installedModuleVersion -lt $latestVersion) {
        "Version of HPEiLOCmdlets module installed '{0}' is outdated. Updating now to '{1}'..." -f $installedModuleVersion, $latestVersion | Write-Host -f Yellow
        
        Try {
            Install-Module -Name HPEiLOCmdlets -Force -AllowClobber -AcceptLicense -ErrorAction Stop
        }
        catch {
            $_
            Read-Host "Hit return to close"
            exit
        }
    }
    Import-Module HPEiLOCmdlets
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

#EndRegion

#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

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

#Region -------------------------------------------------------- Generating a COM activation key -------------------------------------------------------------------------------------

if (-not $Check) {


    try {

        # Check if an activation key already exists
        $ExistingActivationKey = Get-HPECOMServerActivationKey -Region $Region -ErrorAction Stop | Select-Object -First 1 -ExpandProperty ActivationKey
        
        # Generate a new activation key if none exists
        if (-not $ExistingActivationKey) {
            
            $COMActivationKey = New-HPECOMServerActivationKey -Region $Region -Verbose:$Verbose -ErrorAction Stop

            if ($COMActivationKey) {
                "[Workspace: {0}] - Successfully generated COM activation key '{1}' for region '{2}'." -f $WorkspaceName, $COMActivationKey, $Region | Write-Host -f Green
            }
            else {
                "[Workspace: {0}] - Error generating COM activation key. Please check your configuration and try again." -f $WorkspaceName | Write-Host -ForegroundColor Red
                Read-Host -Prompt "Hit return to close" 
                exit
            }
        }
        # Use the existing activation key
        else {
            "[Workspace: {0}] - Existing COM activation key '{1}' successfully retrieved for region '{2}'." -f $WorkspaceName, $ExistingActivationKey, $Region | Write-Host -f Green
            $COMActivationKey = $ExistingActivationKey

        }   
    }
    catch {
        "[Workspace: {0}] - Error generating COM activation key. Please check your configuration and try again. Status: {1}" -f $WorkspaceName, $_ | Write-Host -ForegroundColor Red
        Read-Host -Prompt "Hit return to close" 
        exit
    }
}

#EndRegion

#Region -------------------------------------------------------- Configuring and connecting iLOs to COM -------------------------------------------------------------------------------

if ($Check) {
    "`n------------------------------" | Write-Host -f Yellow
    "iLO CONFIGURATION CHECK STATUS" | Write-Host -f Yellow
    "------------------------------" | Write-Host -f Yellow
}

ForEach ($iLO in $iLOs) { 

    #Region Create object for the output

    $ErrorFound = $False
    $iLOConnection = $False

    $objStatus = [pscustomobject]@{
  
        iLO                       = $Ilo.IP
        Hostname                  = $Null
        SerialNumber              = $Null
        iLOGeneration             = $Null
        iLOFirmwareVersion        = $Null
        ServerModel               = $Null
        ServerGeneration          = $Null
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
        
        if ($iLOConnection) {

            # capture ilo information
            if ($iLOConnection.Hostname) {
                $hostname = $iLOConnection.Hostname
            
            }
            else {
                $hostname = $iLO.IP
            }   
                
            $objStatus.Hostname = $hostname
            $iLOGeneration = $iLOConnection.TargetInfo.iLOGeneration
            $objStatus.iLOGeneration = $iLOGeneration
            $iLOFirmwareVersion = $iLOConnection.TargetInfo.iLOFirmwareVersion
            $objStatus.iLOFirmwareVersion = $iLOFirmwareVersion
            $ServerModel = $iLOConnection.TargetInfo.ServerModel
            $objStatus.ServerModel = $ServerModel
            $ServerGeneration = $iLOConnection.TargetInfo.ServerGeneration
            $objStatus.ServerGeneration = $ServerGeneration

            $objStatus.SerialNumber = Get-HPEiLOChassisInfo -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty SerialNumber       

            "`n  - [{0}] (v{1} {2} - Model:{3} {4} - SN:{5})" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Host

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

    #Region Get DNS in iLO       

    if ($Check) {

        "`t - DNS: " | Write-Host -NoNewline

        $ErrorFound = $False
            
        Try {
        
            $iLONetworkSetting = Get-HPEiLOIPv4NetworkSetting -Connection $iLOConnection -Verbose:$Verbose -ErrorAction Stop 

            $sortedCurrentDNSServers = $iLONetworkSetting | Select-Object -ExpandProperty DNSServer | Where-Object { $_ -ne "0.0.0.0" } | Where-Object { $_ -ne "" -and $_ -ne $null } | Sort-Object
                
            if ($iLONetworkSetting.Status -eq "ERROR") {

                "Failed" | Write-Host -f Red
                
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO DNS settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLONetworkSetting.StatusInfo.Message | Write-Verbose

                $objStatus.DNSSettingsStatus = "Failed to retrieve iLO DNS settings."
                $objStatus.DNSSettingsDetails = $iLONetworkSetting.StatusInfo.Message
                $ErrorFound = $True
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
                
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS settings found: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedCurrentDNSServers | Write-Verbose 
                    
                    if ($comparisonResult) {
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "{0}" -f $FormattedmissingDNSServers | Write-Host -ForegroundColor Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is required. Missing: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedmissingDNSServers | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Warning"
                        $objStatus.DNSSettingsDetails = "DNS servers found: $FormattedCurrentDNSServers - Missing DNS servers: $FormattedmissingDNSServers"
                    }
                    else {
                        "Ok" | Write-Host -f Green
                        "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is not required as the DNS servers are already correctly configured." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Complete"
                        $objStatus.DNSSettingsDetails = "DNS configuration is not required as the DNS servers are already correctly configured."
                    }
                }    
                else {
                    "Ok" | Write-Host -f Green
                    "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration will be skipped as no DNS server configuration is requested." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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

                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is required as no DNS servers are defined!" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.DNSSettingsStatus = "Warning"
                    $objStatus.DNSSettingsDetails = "DNS configuration is required as no DNS servers are defined!"
                }
                else {
                    "Failed" | Write-Host -f Red
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Warning: No DNS server defined! This may cause issues with iLO connectivity to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.DNSSettingsStatus = "Warning"
                    $objStatus.DNSSettingsDetails = "No DNS server defined! This may cause issues with iLO connectivity to COM."
                    $ErrorFound = $True
                }
            }                    
        }
        catch {
            "Failed" | Write-Host -f Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO DNS settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.DNSSettingsStatus = "Failed"
            $objStatus.DNSSettingsDetails = $_
            $ErrorFound = $True
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO DNS settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLONetworkSetting.StatusInfo.Message | Write-Verbose
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
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO DNS settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO DNS settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                $objStatus.DNSSettingsStatus = "Failed"
                $objStatus.DNSSettingsDetails = "Error retrieving iLO DNS settings. Error: $_"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
                        
            if ($DHCPv4DNSServer -eq "Enabled") {
                "Warning" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "DNS settings cannot be configured because they are currently managed via DHCP. Skipping DNS configuration..." | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS settings cannot be configured because they are currently managed via DHCP. Skipping DNS configuration..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is required as the DNS servers configuration does not match." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $SetDNS = $True
                    }
                    else {
                        "Skipped" | Write-Host -f Green
                        "`t`t - Status: " | Write-Host -NoNewline
                        "DNS configuration is not required as the DNS servers are already defined." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is not required as the DNS servers are already defined." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.DNSSettingsStatus = "Skipped"
                        $objStatus.DNSSettingsDetails = "DNS configuration is not required as the DNS servers are already defined."
                    }    
                }
                # If DNS servers are not defined
                else {
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is required as no DNS servers are defined" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO DNS settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $DNSupdate.StatusInfo.Message | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS settings set successfully!" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                            $objStatus.DNSSettingsStatus = "Complete"
                            $objStatus.DNSSettingsDetails = "DNS settings set successfully!"
                        }
                        else {
                            "Failed" | Write-Host -f Red
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error configuring DNS settings. StatusInfo: {0}" -f $DNSupdate.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO DNS settings. Status: {6} - StatusInfo: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $DNSupdate.status, $DNSupdate.StatusInfo.Message | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO DNS settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Warning: No DNS server defined! This may cause issues with iLO connectivity to COM. Skipping server..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.DNSSettingsStatus = "Failed"
                $objStatus.DNSSettingsDetails = "No DNS servers defined! This will cause issues with iLO connectivity to COM. Skipping server..."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Current: {0}" -f $FormattedCurrentDNSServers | Write-Host
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - DNS configuration is not required as no DNS server configuration is requested." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO SNTP settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $SNTPSetting.StatusInfo.Message | Write-Verbose
                "Failed" | Write-Host -f Red

                $objStatus.NTPSettingsStatus = "Failed to retrieve iLO SNTP settings."
                $objStatus.NTPSettingsDetails = $SNTPSetting.StatusInfo.Message
                $ErrorFound = $True
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
                
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP settings found: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedCurrentSNTPServers | Write-Verbose 

                if ($SNTPservers) {

                    if ($comparisonResult) {
                        "Warning" | Write-Host -f Yellow               
                        "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "{0}" -f $FormattedmissingSNTPServers | Write-Host -ForegroundColor Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is required. Missing: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedmissingSNTPServers | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Warning"
                        $objStatus.NTPSettingsDetails = "SNTP servers found: $FormattedCurrentSNTPServers - Missing SNTP servers: $FormattedmissingSNTPServers"
                    }
                    else {
                        "Ok" | Write-Host -f Green
                        "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                        "`t`t - Missing: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is not required as the SNTP servers are already correctly configured." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Complete"
                        $objStatus.NTPSettingsDetails = "SNTP configuration is not required as the SNTP servers are already correctly configured."
                    }
                }    
                else {
                    "Ok" | Write-Host -f Green
                    "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration will be skipped as no SNTP server configuration is requested." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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

                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is required as no SNTP servers are defined!" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.NTPSettingsStatus = "Warning"
                    $objStatus.NTPSettingsDetails = "SNTP configuration is required as no SNTP servers are defined!"
                }
                else {
                    "Failed" | Write-Host -f Red
                    "`t`t - Current: " | Write-Host -NoNewline
                    "None" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Warning: No SNTP server defined! This may cause issues with iLO connectivity to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.NTPSettingsStatus = "Warning"
                    $objStatus.NTPSettingsDetails = "No SNTP server defined! This may cause issues with iLO connectivity to COM."
                    $ErrorFound = $True
                }
            }
        
        }
        catch {
            "Failed" | Write-Host -f Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO SNTP settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.NTPSettingsStatus = "Failed"
            $objStatus.NTPSettingsDetails = $_
            $ErrorFound = $True
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO SNTP settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLONetworkSetting.StatusInfo.Message | Write-Verbose
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
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO SNTP settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO SNTP settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                $objStatus.NTPSettingsStatus = "Failed"
                $objStatus.NTPSettingsDetails = "Error retrieving iLO SNTP settings. Error: $_"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            
            if ($DHCPv4SNTPSetting -eq "Enabled") {
                "Warning" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "SNTP settings cannot be configured because they are currently managed via DHCP. Skipping SNTP configuration..." | Write-Host -ForegroundColor Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP settings cannot be configured because they are currently managed via DHCP. Skipping SNTP configuration..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is required as the SNTP servers configuration does not match." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $SetSNTP = $True
                    }
                    else {
                        "Skipped" | Write-Host -f Green
                        "`t`t - Status: " | Write-Host -NoNewline
                        "SNTP configuration is not required as the SNTP servers are already defined." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is not required as the SNTP servers are already defined." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.NTPSettingsStatus = "Skipped"
                        $objStatus.NTPSettingsDetails = "SNTP configuration is not required as the SNTP servers are already defined."
                    }    
                }
                # If SNTP servers are not defined
                else {
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is required as no SNTP servers are defined" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO SNTP settings. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $SNTPupdate.StatusInfo.Message | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO SNTP settings set successfully. Message: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $SNTPupdate.StatusInfo.Message | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO SNTP settings. Status: {6} - StatusInfo: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $SNTPupdate.status, $SNTPupdate.StatusInfo.Message | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error configuring iLO SNTP settings. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        }
                        else {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error resetting iLO. Status: {0} - Details: {1}" -f $iLOResetStatus.Status, $iLOResetStatus.StatusInfo.Message | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error resetting iLO. Status: {6} - Details: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOResetStatus.Status, $iLOResetStatus.StatusInfo.Message | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO SNTP settings updated successfully and iLO is back online." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                            $objStatus.NTPSettingsStatus = "Complete"
                            $objStatus.NTPSettingsDetails = "iLO firmware updated successfully"

                            $iLOConnection = $False

                            # Reconnect to iLO after the changes to SNTP configuration and reset
                            Try {
                                $maxRetries = 36 # 3 minutes
                                $retryCount = 0

                                "`t`t - Status: " | Write-Host -NoNewline
                                "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Reconnecting to iLO..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

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
                                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after the changes to SNTP configuration. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection | Write-Verbose
                                    $objStatus.NTPSettingsStatus = "Failed"
                                    $objStatus.NTPSettingsDetails = "Unable to connect to iLO after $maxRetries retries following SNTP configuration reset. Please check the iLO status and network connectivity."
                                    $objStatus.Status = "Failed"
                                    [void]$iLOPreparationStatus.Add($objStatus)
                                    continue
                                }
                                
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Reconnected to iLO. Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection.TargetInfo | Write-Verbose

                                # Wait for the SNTP status to be ok
                                
                                $maxRetries = 36 # 3 minutes
                                $retryCount = 0
                                
                                do {
                                    try {
                                        $SNTPSetting = Get-HPEiLOSNTPSetting -Connection $iLOConnection -ErrorAction Stop
                                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Waiting for the SNTP status to be ok... Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $SNTPSetting.status | Write-Verbose
                                    }
                                    catch {
                                        Start-Sleep -Seconds 5
                                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve the SNTP status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection, $_ | Write-Verbose
                                        
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
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after the changes to SNTP configuration. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection, $_ | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after the changes to SNTP configuration. Error: $_"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                    }
                    catch {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error resetting iLO after the changes to SNTP configuration. Error: $_" | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error resetting iLO after the changes to SNTP configuration. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Warning: No SNTP server defined! This may cause issues with iLO connectivity to COM. Skipping server..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.NTPSettingsStatus = "Failed"
                $objStatus.NTPSettingsDetails = "No SNTP servers defined! This will cause issues with iLO connectivity to COM. Skipping server..."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "Skipped" | Write-Host -f Green
                "`t`t - Current: {0}" -f $FormattedCurrentSNTPServers | Write-Host
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - SNTP configuration is not required as no SNTP server configuration is requested." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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

        if ($iLOGeneration -eq "iLO5") {
    
            if ($iLOFirmwareVersion -lt "3.09") {
                "Warning" | Write-Host -f Yellow               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $iLOFirmwareVersion | Write-Host -ForegroundColor Yellow
                "`t`t - Required: 3.09" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware version lower than v3.09 is not supported by COM activation key. Firmware update will be needed." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "Firmware update will be needed."
                $objStatus.FirmwareDetails = "iLO5 firmware version lower than v3.09 is not supported by COM activation key."
            }                   
            else {
                "OK" | Write-Host -f Green               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $iLOFirmwareVersion | Write-Host -ForegroundColor Green
                "`t`t - Required: 3.09" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 FW fully supported by COM. Firmware update will be skipped." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "iLO5 firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Firmware update will be skipped."
            }
        
        }

        # COM activation key is not supported for iLO6 versions lower than v1.64
        if ($iLOGeneration -eq "iLO6") {
        
            If ($iLOFirmwareVersion -lt "1.64") {   
                "Warning" | Write-Host -f Yellow               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $iLOFirmwareVersion | Write-Host -ForegroundColor Yellow
                "`t`t - Required: 1.64" | Write-Host  
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware version lower than v1.64 is not supported by COM activation key. Firmware update will be needed." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "Firmware update will be needed."
                $objStatus.FirmwareDetails = "iLO6 firmware version lower than v1.64 is not supported by COM activation key."
            }                   
            else {
                "OK" | Write-Host -f Green               
                "`t`t - Current: " | Write-Host -NoNewline
                "{0}" -f $iLOFirmwareVersion | Write-Host -ForegroundColor Green
                "`t`t - Required: 1.64" | Write-Host 
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 FW fully supported by COM. Firmware update will be skipped." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "iLO6 firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Firmware update will be skipped."

            }
        
        } 
    }

    #EndRegion 

    #Region Flash iLO if needed
    
    if (-not $Check) {

        $iLOFlashActivity = $False

        "`t - iLO firmware: " | Write-Host -NoNewline
    
        # COM activation key is not supported for iLO5 versions lower than v3.09
        if ($iLOGeneration -eq "iLO5") {
    
            if ($iLOFirmwareVersion -lt "3.09") {

                if (-not $iLO5binFile) {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO5 firmware update is needed as firmware is lower than v3.09 but iLO5binFile cannot be found. Please provide the iLO5 firmware file path and try again." | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware update is needed as firmware is lower than v3.09 but iLO5binFile cannot be found. Please provide the iLO5 firmware file path and try again." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware update is needed as firmware is lower than v3.09. TPM Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $TPMEnabled | Write-Verbose

                            }
                            catch {
                                Start-Sleep -Seconds 2                                
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Exception detected to get TPMStatus: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose

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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO TPM status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $TPMEnabled | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO TPM status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $_"
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
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware update in progress as firmware is lower than v3.09 (TPM Enabled)..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

                            }
                            else {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO5binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware update in progress as firmware is lower than v3.09 (TPM not Enabled)..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                            }
                        }
                        catch {
                            Start-Sleep -Seconds 2
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Exception detected to update the iLO Firmware. Retrying... Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FirmwareUpdateResult | Write-Verbose

                            Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                            if ($SkipCertificateValidation) {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                            }
                            else {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                            }

                            $retryCount++
                        }

                    } until ($FirmwareUpdateResult.StatusInfo.Message -eq "ResetInProgress" -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error updating iLO firmware. StatusInfo: {0}" -f $FirmwareUpdateResult.StatusInfo.Message | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error updating iLO firmware. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FirmwareUpdateResult.StatusInfo.Message | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error updating iLO firmware. StatusInfo: $($FirmwareUpdateResult.StatusInfo.Message)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }            
                    
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO firmware must be activated. Waiting for the reset to be performed..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO firmware must be activated. Waiting for the reset to be performed..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

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
                        "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }

                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO reset has been detected. Waiting for iLO to be back online..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                        Start-Sleep -Seconds 5
                        $retryCount++
                    } until ($pingResult.Status -eq 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Unable to access iLO after '{0}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Unable to access iLO after '{6}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $maxRetries | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Unable to access iLO after '$maxRetries' retries following firmware update reset. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }       
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO firmware updated successfully and iLO is back online." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO firmware updated successfully and iLO is back online." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.FirmwareStatus = "Complete"
                        $objStatus.FirmwareDetails = "iLO firmware updated successfully"

                        $iLOConnection = $False

                        # Reconnect to iLO after the FW update
                        Try {
                            $maxRetries = 36 # 3 minutes
                            $retryCount = 0

                            "`t`t - Status: " | Write-Host -NoNewline
                            "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Reconnecting to iLO..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

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
                                "Error connecting to iLO after firmware update. Error: {0}" -f $iLOConnection | Write-Host -ForegroundColor Red
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after firmware update. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after firmware update. Error: $iLOConnection"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                        catch {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error connecting to iLO after firmware update. Error: $_" | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after firmware update. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Error connecting to iLO after firmware update. Error: $_"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }              
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error updating iLO firmware. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error updating iLO firmware. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO5 firmware update is not needed as firmware is v3.09 or higher." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "iLO firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Skipping firmware update."

            }
        }

        # COM activation key is not supported for iLO6 versions lower than v1.64
        if ($iLOGeneration -eq "iLO6") {
    
            if ($iLOFirmwareVersion -lt "1.64") {

                if (-not $iLO6binFile) {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO6 firmware update is needed as firmware is lower than v1.64 but iLO6binFile cannot be found. Please provide the iLO6 firmware file path and try again." | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware update is needed as firmware is lower than v1.64 but iLO6binFile cannot be found. Please provide the iLO6 firmware file path and try again." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware update is needed as firmware is lower than v1.64. TPM Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $TPMEnabled | Write-Verbose

                            }
                            catch {
                                Start-Sleep -Seconds 2
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Exception detected to get TPMStatus: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose

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
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO TPM status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $TPMEnabled | Write-Verbose
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
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving iLO TPM status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error retrieving iLO TPM status. Error: $_"
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
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware update in progress as firmware is lower than v1.64 (TPM Enabled)..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

                            }
                            else {
                                $FirmwareUpdateResult = Update-HPEiLOFirmware -Connection $iLOConnection -Location $iLO6binFileFullPath -UploadTimeout 700 -confirm:$false -Verbose:$Verbose -ErrorAction Stop -WarningAction SilentlyContinue
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware update in progress as firmware is lower than v1.64 (TPM not Enabled)..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                            }
                        }
                        catch {
                            Start-Sleep -Seconds 2
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Exception detected to update the iLO Firmware. Retrying... Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FirmwareUpdateResult | Write-Verbose

                            Disconnect-HPEiLO -Connection $iLOConnection -Verbose:$Verbose -ErrorAction SilentlyContinue

                            if ($SkipCertificateValidation) {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -DisableCertificateAuthentication -ErrorAction SilentlyContinue
                            }
                            else {
                                $iLOConnection = Connect-HPEiLO -IP $iLO.IP -Credential $iLOcredentials -Verbose:$Verbose -ErrorAction SilentlyContinue
                            }

                            $retryCount++
                        }

                    } until ($FirmwareUpdateResult.StatusInfo.Message -eq "ResetInProgress" -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Error updating iLO firmware. StatusInfo: {0}" -f $FirmwareUpdateResult.StatusInfo.Message | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error updating iLO firmware. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FirmwareUpdateResult.StatusInfo.Message | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Error updating iLO firmware. StatusInfo: $($FirmwareUpdateResult.StatusInfo.Message)"
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }            
                    
                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO firmware must be activated. Waiting for the reset to be performed...!" | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO firmware must be activated. Waiting for the reset to be performed..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

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
                        "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "iLO reset after firmware update could not be detected after $maxRetries retries. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }

                    "`t`t - Status: " | Write-Host -NoNewline
                    "iLO reset has been detected. Waiting for iLO to be back online..." | Write-Host -ForegroundColor Yellow
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO reset has been detected. Waiting for iLO to be back online..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
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
                        Start-Sleep -Seconds 5
                        $retryCount++
                    } until ($pingResult.Status -eq 'Success' -or $retryCount -ge $maxRetries)

                    if ($retryCount -ge $maxRetries) {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "Unable to access iLO after '{0}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $maxRetries | Write-Host -ForegroundColor Red
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Unable to access iLO after '{6}' retries following firmware update reset. Please check the iLO status and network connectivity." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $maxRetries | Write-Verbose
                        $objStatus.FirmwareStatus = "Failed"
                        $objStatus.FirmwareDetails = "Unable to access iLO after '$maxRetries' retries following firmware update reset. Please check the iLO status and network connectivity."
                        $objStatus.Status = "Failed"
                        [void]$iLOPreparationStatus.Add($objStatus)
                        continue
                    }       
                    else {
                        "`t`t - Status: " | Write-Host -NoNewline
                        "iLO is back online and iLO firmware updated successfully." | Write-Host -ForegroundColor Green
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO firmware updated successfully and iLO is back online." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        $objStatus.FirmwareStatus = "Complete"
                        $objStatus.FirmwareDetails = "iLO firmware updated successfully"

                        $iLOConnection = $False

                        # Reconnect to iLO after the FW update
                        Try {
                            $maxRetries = 36 # 3 minutes
                            $retryCount = 0

                            "`t`t - Status: " | Write-Host -NoNewline
                            "Reconnecting to iLO..." | Write-Host -ForegroundColor Yellow
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Reconnecting to iLO..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose

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
                                "Error connecting to iLO after firmware update. Error: {0}" -f $iLOConnection | Write-Host -ForegroundColor Red
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after firmware update. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOConnection | Write-Verbose
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Error connecting to iLO after firmware update. Error: $iLOConnection"
                                [void]$iLOPreparationStatus.Add($objStatus)
                                continue
                            }
                        }
                        catch {
                            "`t`t - Status: " | Write-Host -NoNewline
                            "Error connecting to iLO after firmware update. Error: $_" | Write-Host -ForegroundColor Red
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting to iLO after firmware update. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Error connecting to iLO after firmware update. Error: $_"
                            [void]$iLOPreparationStatus.Add($objStatus)
                            continue
                        }
                    }             
                }
                catch {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error updating iLO firmware. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error updating iLO firmware. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO6 firmware update is not needed as firmware is v1.64 or higher." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.FirmwareStatus = "iLO firmware fully supported by COM."
                $objStatus.FirmwareDetails = "Skipping firmware update."

            }
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
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO connection to COM status. StatusInfo: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOCOMOnboardingStatus.StatusInfo.Message | Write-Verbose
                $objStatus.iLOConnectionStatus = "Error checking iLO connection status to Compute Ops Management."
                $objStatus.iLOConnectionDetails = $iLOCOMOnboardingStatus.StatusInfo.Message
                $ErrorFound = $True
            }
            elseif ($iLOCOMOnboardingStatus.CloudConnectStatus -eq "Connected") {
                "Connected" | Write-Host -f Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO already connected to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.iLOConnectionStatus = $iLOCOMOnboardingStatus.CloudConnectStatus
                $objStatus.iLOConnectionDetails = "iLO already connected to COM."
            }
            else {
                "Disconnected" | Write-Host -f Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO not connected to COM. Status: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $iLOCOMOnboardingStatus.CloudConnectStatus | Write-Verbose
                $objStatus.iLOConnectionStatus = $iLOCOMOnboardingStatus.CloudConnectStatus
                $objStatus.iLOConnectionDetails = "iLO not connected to COM."
            }
        }
        catch {
            "Failed" | Write-Host -f Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve iLO connection to COM status. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.iLOConnectionStatus = "Failed to retrieve iLO connection to COM status."
            $objStatus.iLOConnectionDetails = $_
            $ErrorFound = $True
        }
    }

    #EndRegion

    #Region Onboarding iLOs to COM instance

    if (-not $Check) {

        # Wait for the iLO to be ready for onboarding after the reset
        if ($iLOFlashActivity) {

            "`t`t - Status: " | Write-Host -NoNewline
            "Waiting for iLO to be ready for COM connection..." | Write-Host -ForegroundColor Yellow
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Waiting for iLO to be ready for COM connection..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
            
            $iLOComputeOpsManagementStatus = $Null

            $maxRetries = 60 # 5 minutes 
            $retryCount = 0

            do {
                try {
                    $iLOComputeOpsManagementStatus = Get-HPEiLOComputeOpsManagementStatus -Connection $iLOconnection -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty Status -ErrorAction Stop
                   
                    Start-Sleep -Seconds 5
                    $retryCount++
                }
                catch {
                    Start-Sleep -Seconds 5
                    $retryCount++
                }
                
            } until ($iLOComputeOpsManagementStatus -eq "OK" -or $retryCount -ge $maxRetries)

            if ($retryCount -ge $maxRetries) {
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO did not reach a ready state for COM connection after $maxRetries retries." | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO did not reach a ready state for COM connection after {6} retries." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $maxRetries | Write-Verbose
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "iLO did not reach a ready state for COM connection after $maxRetries retries."
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }
            else {
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO is ready for COM connection." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO is ready for COM connection." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
            }
        }
            
        try {

            "`t - iLO connection to COM: " | Write-Host -NoNewline
            "InProgress" | Write-Host -f Yellow
    
            if ($WebProxyUsername) {
    
                $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                    -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                    -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -IloProxyUserName $WebProxyUsername -IloProxyPassword $WebProxyPassword -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
            }
            elseif ($WebProxyServer) {
    
                $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                    -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView `
                    -IloProxyServer $WebProxyServer -IloProxyPort $WebProxyPort -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop
            }
            else {
                $OnboardingStatus = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOcredentials -IloIP $iLO.IP `
                    -ActivationKeyfromCOM $COMActivationKey -SkipCertificateValidation:$SkipCertificateValidation -DisconnectiLOfromOneView:$DisconnectiLOfromOneView -Verbose:$Verbose -InformationAction SilentlyContinue -ErrorAction Stop 
            }    
            
            if ($OnboardingStatus.Status -eq "Failed" -or $OnboardingStatus.Status -eq "Warning") {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error connecting iLO to COM. Status: {0} - Details: {1}" -f $OnboardingStatus.Status, $OnboardingStatus.iLOConnectionDetails | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting iLO to COM - Status: {6} - Details: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $OnboardingStatus.Status, $OnboardingStatus.iLOConnectionDetails | Write-Verbose

                $objStatus.Status = $OnboardingStatus.Status
                $objStatus.Details = $OnboardingStatus.Details

                if ($OnboardingStatus.iLOConnectionStatus) {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.iLOConnectionStatus
                }
                else {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.Status
                }

                if ($OnboardingStatus.iLOConnectionDetails) {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.iLOConnectionDetails
                }
                else {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.Details
                }

                [void]$iLOPreparationStatus.Add($objStatus)
                continue                
            }
            elseif ($OnboardingStatus.iLOConnectionDetails -match "iLO is already connected to the Compute Ops Management instance!") {
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO is already connected to COM." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO is already connected to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose	
                
                $objStatus.Status = $OnboardingStatus.Status
                $objStatus.Details = $OnboardingStatus.Details
                
                if ($OnboardingStatus.iLOConnectionStatus) {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.iLOConnectionStatus
                }
                else {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.Status
                }

                if ($OnboardingStatus.iLOConnectionDetails) {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.iLOConnectionDetails
                }
                else {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.Details
                }               
            }
            else {
                "`t`t - Status: " | Write-Host -NoNewline
                "iLO successfully connected to COM." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - iLO successfully connected to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose	
                
                $objStatus.Status = $OnboardingStatus.Status
                $objStatus.Details = $OnboardingStatus.Details
                
                if ($OnboardingStatus.iLOConnectionStatus) {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.iLOConnectionStatus
                }
                else {
                    $objStatus.iLOConnectionStatus = $OnboardingStatus.Status
                }

                if ($OnboardingStatus.iLOConnectionDetails) {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.iLOConnectionDetails
                }
                else {
                    $objStatus.iLOConnectionDetails = $OnboardingStatus.Details
                }               
            }
        }
        catch {
            "`t`t - Status: " | Write-Host -NoNewline
            "Error connecting iLO to COM. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error connecting iLO to COM - Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.iLOConnectionStatus = "Error connecting iLO to COM."
            $objStatus.iLOConnectionDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
    }
    #EndRegion

    #Region Check tags assigned to the device
        
    if ($Check) {

        if ($Tags) {

            "`t - Tags: " | Write-Host -NoNewline

            $CurrentDeviceTags = $Null

            # Check if the device exists in the workspace
            try {
                $Devicefound = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
            }
            catch {
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve device details in the workspace. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                $objStatus.LocationAssignmentStatus = "Failed"
                $objStatus.LocationAssignmentDetails = $_
                $ErrorFound = $True
            }
            
            if (-not $Devicefound) {    
                "Warning" | Write-Host -f Yellow
                "`t`t - Current: " | Write-Host -NoNewline
                "None" | Write-Host -ForegroundColor Yellow
                "`t`t - Missing: " | Write-Host -NoNewline
                $Tags | Write-Host -f Yellow
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tags will be configured after the device is connected to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                $objStatus.LocationAssignmentStatus = "Warning"
                $objStatus.LocationAssignmentDetails = "Tags will be configured after the device is connected to COM."
            }
            else {
            
                Try {
                    $CurrentDeviceTags = $Devicefound | Select-Object -ExpandProperty Tags

                    if ($CurrentDeviceTags.Count -gt 0) {

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $CurrentDeviceTags.Count | Write-Verbose

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

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Missing tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, ($missingTags | Out-String ) | Write-Verbose

                        # Check for extra tags (present in $CurrentDeviceTagsObject but not in $TagsObject)
                        foreach ($property in $CurrentDeviceTagsObject.PSObject.Properties) {
                            if (-not $TagsObject.PSObject.Properties[$property.Name] -or $TagsObject.PSObject.Properties[$property.Name].Value -ne $property.Value) {
                                $extraTags[$property.Name] = $property.Value
                            }
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Extra tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, ($extraTags | Out-String ) | Write-Verbose

                        # Format the missing tags
                
                        $MissingTagsList = [System.Collections.ArrayList]::new()
                
                        foreach ($tag in $missingTags.GetEnumerator()) { 
                            [void]$MissingTagsList.add("$($tag.Key)=$($tag.Value)")
                        }
                
                        if ($MissingTagsList.Count -gt 0) {
                            $FormattedMissingTags = $MissingTagsList -join ", "
                        }
                        else {
                            $FormattedMissingTags = $MissingTagsList[0]
                        }
                
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Formatted missing tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedMissingTags | Write-Verbose

                        # Format the extra tags
                
                        $ExtraTagsList = [System.Collections.ArrayList]::new()
                
                        foreach ($tag in $extraTags.GetEnumerator()) { 
                            [void]$ExtraTagsList.add("$($tag.Key)=$($tag.Value)")
                        }
       
                        if ($ExtraTagsList.Count -gt 0) {
                            $FormattedExtraTags = $ExtraTagsList -join ", "
                        }
                        else {
                            $FormattedExtraTags = $ExtraTagsList[0]
                        }
                
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Formatted extra tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedExtraTags | Write-Verbose

                        # Format the tags assigned to the device

                        $CurrentDeviceTagsList = [System.Collections.ArrayList]::new()
                
                        foreach ($tag in $CurrentDeviceTags) { 
                            [void]$CurrentDeviceTagsList.add("$($tag.Name)=$($tag.Value)")
                        }
                    
                        if ($CurrentDeviceTagsList.Count -gt 0) {
                            $FormattedCurrentTags = $CurrentDeviceTagsList -join ", "
                        }
                        else {
                            $FormattedCurrentTags = $CurrentDeviceTagsList[0]
                        }

                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Formatted currently assigned tags founds: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedCurrentTags | Write-Verbose

               
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Missing tags: {6} - Extra tags: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $MissingTagsList.count, $ExtraTagsList.count | Write-Verbose
    
                        if ($MissingTagsList.Count -gt 0 -or $ExtraTagsList.Count -gt 0) {

                            if ($MissingTagsList.Count -gt 0 -and $ExtraTagsList.Count -eq 0) {            
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Missing: " | Write-Host -NoNewline
                                Write-Host $FormattedMissingTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tag configuration is required. Missing: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedmissingTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Tags found: $FormattedCurrentTags"
                                $objStatus.TagsAssignmentDetails = "Missing tags: $FormattedmissingTags"
                            }
                            elseif ($ExtraTagsList.Count -gt 0 -and $MissingTagsList.Count -eq 0) {
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Extra: " | Write-Host -NoNewline
                                Write-Host $FormattedExtraTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tag configuration is required. Extra: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedExtraTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Tags found: $FormattedCurrentTags"
                                $objStatus.TagsAssignmentDetails = "Extra tags: $FormattedExtraTags"
                            }
                            elseif ($MissingTagsList.Count -gt 0 -and $ExtraTagsList.Count -gt 0) {
                                "Warning" | Write-Host -f Yellow               
                                "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                                "`t`t - Extra: " | Write-Host -NoNewline
                                Write-Host $FormattedExtraTags -f Yellow
                                "`t`t - Missing: " | Write-Host -NoNewline
                                Write-Host $FormattedMissingTags -f Yellow
                                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tag configuration is required. Missing: {6} - Extra: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $FormattedmissingTags, $FormattedExtraTags | Write-Verbose
                                $objStatus.TagsAssignmentStatus = "Tags found: $FormattedCurrentTags"
                                $objStatus.TagsAssignmentDetails = "Missing tags: $FormattedmissingTags - Extra tags: $FormattedExtraTags"
                            }
                        }
                        else {
                            "OK" | Write-Host -f Green
                            "`t`t - Current: {0}" -f $FormattedCurrentTags | Write-Host
                            "`t`t - Missing: " | Write-Host -NoNewline
                            "None" | Write-Host -ForegroundColor Green
                            "`t`t - Extra: " | Write-Host -NoNewline
                            "None" | Write-Host -ForegroundColor Green
                            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tags configuration is not required as tags are already defined!" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                            $objStatus.TagsAssignmentStatus = "Tags configuration is not required as tags are already defined!"
                            $objStatus.TagsAssignmentDetails = $FormattedCurrentTags
                        }
                        
                    }
                    else {
                        "Warning" | Write-Host -f Yellow
                        "`t`t - Current: " | Write-Host -NoNewline
                        "None" | Write-Host -ForegroundColor Yellow
                        "`t`t - Missing: " | Write-Host -NoNewline
                        $Tags | Write-Host -f Yellow
                        "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tags configuration is required as no tags are currently defined!" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                        
                    }                               
                }
                catch {
                    "Failed" | Write-Host -f Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve tags details. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                    $objStatus.TagsAssignmentStatus = "Failed to retrieve tags details"
                    $objStatus.TagsAssignmentDetails = $_
                    $ErrorFound = $True
                }
            }
        }
    }
    #EndRegion

    #Region Add tags to the device (if any)

    if (-not $Check -and $Tags) {

        "`t - Tags: " | Write-Host -NoNewline

        Try {
            
            $DeviceTags = Get-HPEGLdevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty Tags
        }
        catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Error retrieving tags. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error retrieving tags. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.TagsAssignmentStatus = "Error retrieving tags."
            $objStatus.TagsAssignmentDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue            
        }

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
            }
            catch {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error adding tags. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error adding tags '{6}'. Error: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $Tags, $_ | Write-Verbose
                $objStatus.TagsAssignmentStatus = "Error adding tags to device."
                $objStatus.TagsAssignmentDetails = $_
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue
            }

            if ($DeviceTagsRemovalStatus.Status -eq "Complete") {
                "InProgress" | Write-Host -f Yellow
                "`t`t - Status: " | Write-Host -NoNewline
                "Existing tags removed successfully." | Write-Host -ForegroundColor Green
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Existing tags ({6}) removed successfully." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $ExistingtagsList | Write-Verbose
            }
            else {
                "Failed" | Write-Host -f Red
                "`t`t - Status: " | Write-Host -NoNewline
                "Error removing tags. Status: {0} - Details: {1}" -f $DeviceTagsRemovalStatus.Status, $DeviceTagsRemovalStatus.Details | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error removing tags '{6}'. Status: {7} - Details: {8}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $ExistingtagsList, $DeviceTagsRemovalStatus.Status, $DeviceTagsRemovalStatus.Details | Write-Verbose
                $objStatus.TagsAssignmentStatus = "Failed"
                $objStatus.TagsAssignmentDetails = "Error removing device from location '$($DeviceLocation)'. Status: $($LocationRemovalStatus.Status) - Details: $($LocationRemovalStatus.Details)"
                $objStatus.Status = "Failed"
                [void]$iLOPreparationStatus.Add($objStatus)
                continue                    
            }
        }
        else {
            "InProgress" | Write-Host -f Yellow            
        }

        try {
            $TagsAssignmentStatus = Add-HPEGLDeviceTagToDevice -Tags $Tags -SerialNumber $OnboardingStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
        }
        catch {
            "`t`t - Status: " | Write-Host -NoNewline
            "Error adding tags. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error adding tags '{6}'. Error: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $Tags, $_ | Write-Verbose
            $objStatus.TagsAssignmentStatus = "Error adding tags to device."
            $objStatus.TagsAssignmentDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }

        if ($TagsAssignmentStatus.Status -eq "Complete" -or $TagsAssignmentStatus.Status -eq "Warning") {
            "`t`t - Status: " | Write-Host -NoNewline
            "Tags '{0}' added successfully." -f $Tags | Write-Host -ForegroundColor Green
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Tags '{6}' added successfully." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $Tags | Write-Verbose
            $objStatus.TagsAssignmentStatus = $TagsAssignmentStatus.Status
            $objStatus.TagsAssignmentDetails = $TagsAssignmentStatus.Details
        }
        else {
            "`t`t - Status: " | Write-Host -NoNewline
            "Error adding tags. Status: {0} - Details: {1}" -f $TagsAssignmentStatus.Status, $TagsAssignmentStatus.Details | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error adding tags '{6}'. Status: {7} - Details: {8}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $Tags, $TagsAssignmentStatus.Status, $TagsAssignmentStatus.Details | Write-Verbose
            $objStatus.TagsAssignmentStatus = $TagsAssignmentStatus.Status
            $objStatus.TagsAssignmentDetails = $TagsAssignmentStatus.Details
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }
    }

    #EndRegion

    #Region Check defined location 

    if ($Check) {

        if ($LocationName) {

            "`t - Location: " | Write-Host -NoNewline

            $LocationFound = $Null
            $Devicefound = $Null

            # Check if the device exists in the workspace
            try {
                $Devicefound = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
            }
            catch {
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve location details. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                $objStatus.LocationAssignmentStatus = "Failed"
                $objStatus.LocationAssignmentDetails = $_
                $ErrorFound = $True
            }
                
            if (-not $Devicefound) {  
                "Warning" | Write-Host -f Yellow               
                "`t`t - Current: " | Write-Host -NoNewline
                "None" | Write-Host -ForegroundColor Yellow
                "`t`t - Required: " | Write-Host -NoNewline
                "{0}" -f $LocationName | Write-Host   
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location '{6}' will be configured after the device is connected to COM." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $LocationName | Write-Verbose
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
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location configuration is required as the location is not configured." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Warning"
                    $objStatus.LocationAssignmentDetails = "Location configuration is required as the location is not configured."
                }
                elseif ($DeviceLocation -eq $LocationName) {                        
                    "OK" | Write-Host -f Green               
                    "`t`t - Current: " | Write-Host -NoNewline
                    "{0}" -f $DeviceLocation | Write-Host -ForegroundColor Green
                    "`t`t - Required: " | Write-Host -NoNewline
                    "{0}" -f $LocationName | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location configuration is not required as the location is already configured." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Complete"
                    $objStatus.LocationAssignmentDetails = "Location configuration is not required as the location is already configured."                        
                }
                else {
                    "Warning" | Write-Host -f Yellow               
                    "`t`t - Current: " | Write-Host -NoNewline
                    "{0}" -f $DeviceLocation | Write-Host -ForegroundColor Yellow
                    "`t`t - Required: " | Write-Host -NoNewline
                    "{0}" -f $LocationName | Write-Host 
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location configuration is required as the location currently defined is incorrect." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Warning"
                    $objStatus.LocationAssignmentDetails = "ocation configuration is required as the location currently defined is incorrect."
                }
                               
            }   
        }             
       
    }
        
    #EndRegion

    #Region Assign device to location (if any)

    if (-not $Check -and $LocationName) {

        "`t - Location: " | Write-Host -NoNewline

        try {
            $DeviceLocation = Get-HPEGLDevice -SerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop | Select-Object -ExpandProperty location_name       
        }
        catch {
            "Failed" | Write-Host -f Red
            "`t`t - Status: " | Write-Host -NoNewline
            "Error retrieving device location details. Error: $_" | Write-Host -ForegroundColor Red
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to retrieve device location details. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
            $objStatus.LocationAssignmentStatus = "Failed to retrieve device location details."
            $objStatus.LocationAssignmentDetails = $_
            $objStatus.Status = "Failed"
            [void]$iLOPreparationStatus.Add($objStatus)
            continue
        }

        if ($LocationName -ne $DeviceLocation) {

            # Remove location if the device is assigned to a different location
            if ($DeviceLocation) {
    
                try {
                    $LocationRemovalStatus = Remove-HPEGLDeviceLocation -DeviceSerialNumber $objStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop
                }
                catch {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error removing device from location. Error: $_" | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Failed to remove device from location. Error: {6}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $_ | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Failed to remove device from location."
                    $objStatus.LocationAssignmentDetails = $_
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
    
                if ($LocationRemovalStatus.Status -eq "Complete") {
                    "InProgress" | Write-Host -f Yellow
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Device removed from location successfully." | Write-Host -ForegroundColor Green
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Device removed from location '{6}' successfully." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $DeviceLocation | Write-Verbose
                }
                else {
                    "Failed" | Write-Host -f Red
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error removing device from location. Status: {0} - Details: {1}" -f $LocationRemovalStatus.Status, $LocationRemovalStatus.Details | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error removing device from location '{6}'. Status: {7} - Details: {8}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $DeviceLocation, $LocationRemovalStatus.Status, $LocationRemovalStatus.Details | Write-Verbose
                    $objStatus.LocationAssignmentStatus = "Failed"
                    $objStatus.LocationAssignmentDetails = "Error removing device from location '$($DeviceLocation)'. Status: $($LocationRemovalStatus.Status) - Details: $($LocationRemovalStatus.Details)"
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
            }  
            else {   
                "InProgress" | Write-Host -f Yellow
            }
            
            
            # Assign the device to the defined location
            try {
                $LocationAssignmentStatus = Set-HPEGLDeviceLocation -LocationName $LocationName -DeviceSerialNumber $OnboardingStatus.SerialNumber -Verbose:$Verbose -ErrorAction Stop 

                if ($LocationAssignmentStatus.Status -eq "Complete") {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Location assigned successfully." | Write-Host -ForegroundColor Green
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location '{6}' successfully assigned." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $LocationName | Write-Verbose
                    $objStatus.LocationAssignmentStatus = $LocationAssignmentStatus.Status
                    $objStatus.LocationAssignmentDetails = $LocationAssignmentStatus.Details
                }
                else {
                    "`t`t - Status: " | Write-Host -NoNewline
                    "Error assigning location. Status: {0} - Details: {1}" -f $LocationAssignmentStatus.Status, $LocationAssignmentStatus.Details | Write-Host -ForegroundColor Red
                    "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error assigning location '{6}'. Status: {7} - Details: {8}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $LocationName, $LocationAssignmentStatus.Status, $LocationAssignmentStatus.Details | Write-Verbose
                    $objStatus.LocationAssignmentStatus = $LocationAssignmentStatus.Status
                    $objStatus.LocationAssignmentDetails = $LocationAssignmentStatus.Details
                    $objStatus.Status = "Failed"
                    [void]$iLOPreparationStatus.Add($objStatus)
                    continue
                }
            }
            catch {
                "`t`t - Status: " | Write-Host -NoNewline
                "Error assigning location. Error: $_" | Write-Host -ForegroundColor Red
                "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Error assigning location '{6}'. Error: {7}" -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $LocationName, $_ | Write-Verbose
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
            "[{0}] (v{1} {2} - Model:{3} {4} - SN:{5}) - Location '{6}' already defined. Skipping location assignment..." -f $iLO.IP, $iLOFirmwareVersion, $iLOGeneration, $ServerModel, $ServerGeneration, $objStatus.SerialNumber, $DeviceLocation | Write-Verbose
            $objStatus.LocationAssignmentStatus = "Location already defined."
            $objStatus.LocationAssignmentDetails = $DeviceLocation          
        }       
    }
    
    if ($Check -and $ErrorFound -eq $True) {
        $objStatus.status = "Failed"
    }
    
    # Add the status of the operation to the array
    [void]$iLOPreparationStatus.Add($objStatus)
    
    #EndRegion

}

#EndRegion

#Region -------------------------------------------------------- Generating output -------------------------------------------------------------------------------------

# Define the output file names with the date of creation
$Date = Get-Date -Format "yyyyMMdd_HHmm"
$OnboardingReportFile = "iLO_Onboarding_Status_$Date.csv"
$CheckReportFile = "iLO_Check_Status_$Date.csv"

# Define the messages based on the operation results  
if (-not $Check) {

    if ($iLOPreparationStatus | Where-Object { $_.Status -eq "Failed" }) {
  
        Write-Host "`nOne or more iLOs failed the onboarding process! Please resolve any issues and run the script again." -ForegroundColor Yellow

    }
    else {
        "`nOperation completed successfully! All servers have been configured and connected to the Compute Ops Management instance in the '{0}' region." -f $region | Write-Host -ForegroundColor Cyan
    }
   
    # Export the status of the operation to csv file
    # Check if the file is already open and loop until it is closed
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($OnboardingReportFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $fileStream.Close()
            $iLOPreparationStatus | Export-Csv -Path $OnboardingReportFile -NoTypeInformation -Force
            break
        }
        catch {
            Write-Host "The file '$OnboardingReportFile' is currently open. Please close the file..." -ForegroundColor Red
            Start-Sleep -Seconds 5
        }
    }

    Write-Host "The status of the operation has been exported to '$(Resolve-Path $OnboardingReportFile)'"


}
else {

    # Export the status of the operation to csv file
    # Check if the file is already open and loop until it is closed
    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($OnboardingReportFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $fileStream.Close()
            $iLOPreparationStatus | Export-Csv -Path $CheckReportFile -NoTypeInformation -Force
            break
        }
        catch {
            Write-Host "The file '$CheckReportFile' is currently open. Please close the file..." -ForegroundColor Red
            Start-Sleep -Seconds 5
        }
    }

    Write-Host "`nThe status of the check has been exported to '$(Resolve-Path $CheckReportFile)'" -ForegroundColor Cyan

}
    

    
        
#EndRegion
       
# Disconnect-OVMgmt
Read-Host -Prompt "Hit return to close" 


