<# 

This PowerShell script is designed to migrate all servers managed by an HPE OneView appliance to a Compute Ops Management (COM) workspace. 

The script encompasses the following processes:
- Onboarding to HPE GreenLake.
- Assigning devices to a COM instance.
- Applying a COM subscription.
- Establishing an iLO connection to COM with or without proxy settings.
- Removing the device from HPE OneView after a successful migration.

Requirements:

To use this script, the following prerequisites must be fulfilled:
- PowerShell: Version 5 or 7 installed on the system where the script will be executed.
- HPE OneView PowerShell Library: Required for interacting with the HPE OneView appliance.
- HPE OneView Administrator Account: Necessary credentials to manage and initiate the migration of servers.
- HPE GreenLake Administrator Account: Credentials for accessing and managing resources within HPE GreenLake.
- HPE GreenLake PowerShell Library: Needed for invoking HPE GreenLake specific commands.
- HPE iLO Administrator Account: A uniform administrator account credentials for all iLO interfaces being migrated.

Ensure that each requirement is in place before executing the script to avoid any interruptions during the migration process.

-------------------------------------------------------------------------------------------------------
Output sample:

oneview.lj.lab: 2 servers found for the migration to COM
Running migration, please wait...
192.168.0.21 - server successfully removed from OneView and added to COM
192.168.0.20 - server successfully removed from OneView and added to COM

-------------------------------------------------------------------------------------------------------
Upon successful execution, the script will output a CSV file to the local directory. 
The CSV file will include the following details:

iLO IP	        SerialNumber	PartNumber	    Migration Status
192.168.0.21	CZ2311004H	    P28948-B21	    Complete
192.168.0.20	CZ2311004G	    P28948-B21	    Complete

#>

# Tags are optional, they can be used to add tags to the device you import in COM.
# Tags must meet the following string format <Name>=<Value> <Name>=<Value> such as "Country=US" or "Country=US State=TX App=Grafana" 
$Tags = "Country=FR"
$COM_Region = "EU-Central"  # US-West
$workspaceName = "HPE Mougins"

# iLO proxy settings (optional)
$IloProxyServer = ""
$IloProxyPort = ""
$IloProxyUserName = ""
$IloProxyPassword = ""

# Generate a CSV file to report migration status
$CSV_File_Name_For_Migration_Status_Report = "Device_Migration_Result.csv"

#Region Credentials
################## iLO credentials ################################################################################################################################################
# $iLO_Password = "******"
# ConvertTo-SecureString -String $iLO_Password -AsPlainText -Force |  ConvertFrom-SecureString   

$iLO_Username = "Administrator"
$Encrypted_iLO_Password = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000ea1f94d2f2dc2b40af7a0adaeeae84b100000000020000000000106600000001000020000000f67696f4c188acb6b3df7e8ba832fae4412d8a6d5296277e74f84f79f9740f97000000000e800000000200002000000040d097f33072526d2f9609b46aa8613134b9f7a3d72400537b74359f6fb8b6b720000000bbceea287d34290bde51874baaa98f3553b29b74c26d1d63acf738323286868c40000000b0f995892e4c4fa10c1122cbca5aa5336137d6586edf84d342b46c4520ddfb038e9813c2d4524b2df2daafeafefe744fe7d3c6aa22b95dd017bbe4db8f1f6e22"


################## COM credentials ################################################################################################################################################
# $COM_ClientSecret = "**************************"
# ConvertTo-SecureString -String $COM_ClientSecret -AsPlainText -Force |  ConvertFrom-SecureString   

# $COM_ClientID = "019f9bc4-f985-4aa0-a4b2-78ce9f2043c3"
# $Encrypted_COM_ClientSecret = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000ea1f94d2f2dc2b40af7a0adaeeae84b1000000000200000000001066000000010000200000009915259be52f663fbbbd240dd9d9e4367d4e8913edbadfefabd4ea3b95ced759000000000e8000000002000020000000ce6ae6845c1d7b6750eedbe4a3efa0c9506ffe0bcd49ad9b4e167ca9c79d824950000000623a5a4c4d0160ce943818f336d0f6e1ac8bf70cadb07ded0bc278778806f49fcbc49957fc84c941ea207b1d10e9f44493f7d132c462098ea9c635e10697cef4e0679ed203c52099739edd1cbe7effe940000000e1b87fd0f76f730021ca338e425bdffc63f967df0625ddcbdc8b92942144b6180996d52af2354c1c4ce7f803469d4c7b23c08767649567144e8d89d6b133f445"
# # The connectivity endpoint can be found in the GreenLake platform / API client information
# $ConnectivityEndpoint = "https://eu-central1-api.compute.cloud.hpe.com"


################## GLP credentials ################################################################################################################################################
$GLP_userName = "lio@ik.me"
# $GLP_password = "******************"
# ConvertTo-SecureString -String $GLP_password -AsPlainText -Force |  ConvertFrom-SecureString   
$Encrypted_GLP_Password = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000ea1f94d2f2dc2b40af7a0adaeeae84b100000000020000000000106600000001000020000000870132eb67cac7ee3d9144659d55fa4683bb44aebf45a9b419bdfb3f46879b3b000000000e8000000002000020000000542b21a0cd0bd8989a06e6d225f02456b680e41ba1913bb28af4123ddb15f1e630000000cd2fe90c323301b95f3e86cb1e582a63cc3d8f802dcc0f87a6508dc480b91464e164c92f4721b70548b0113dbf5db5f54000000052c2bbaacbfdd4d2dd3c6ab8ef42617852735ae6445141a1cdd42a758aedaa3a924c1c03af1998427931e725e57b60bbffccc331bdf9fa63f0bed89403d8251b"
$GLP_secpasswd = ConvertTo-SecureString $Encrypted_GLP_Password
$GLP_credentials = New-Object System.Management.Automation.PSCredential ($GLP_userName, $GLP_secpasswd)

################## OneView credentials ################################################################################################################################################
# $OV_password = "************"
# ConvertTo-SecureString -String $OV_password -AsPlainText -Force |  ConvertFrom-SecureString   
$OV_userName = "Administrator"
$OV_IP = "oneview.lj.lab"

$Encrypted_OV_password = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000ea1f94d2f2dc2b40af7a0adaeeae84b100000000020000000000106600000001000020000000913a31eb27339428a49798641e0359cbe2c23673613b8945d00e89ba38ba792b000000000e80000000020000200000005727612bce5ee261f06e7356dfc7923bb8a39aff0884d88b451348a031c266fa20000000807557644c43810ddd64734ee319b7b4cf4c2019ec76c41d215810542ac5bfe540000000909ad3abfdbb4478290d3e4aec00a07ff60750116ea1ce51376e2474b33f7a0a3fa032aefe90730978ed9fb8734c1623e5c761a5a5968af530be7732267d7cdc"
$OV_secpasswd = ConvertTo-SecureString $Encrypted_OV_password
$OV_credentials = New-Object System.Management.Automation.PSCredential ($OV_userName, $OV_secpasswd)

#endRegion

################## HPE GreenLake Module ################################################################################################################################################
import-module "C:\Users\jullienl\OneDrive - Hewlett Packard Enterprise\Projects\HPEGreenLake\HPEGreenLake.psd1" -force 


# #----------------------------------------------------------Set environment variables for all COM resource API versions (from the API reference)-------------------------------------------------------------------------
# #region Retrieve resource API versions

# #######################################################################################################################################################################################################
# # Create variables to get the API version of COM resources using the API reference.
# #   Generate a variable for each API resource ($servers_API_version, $jobs_API_version, etc.) 
# #   Set each variable value with the resource API version ($servers_API_version = v1beta2, $filters_API_version = v1beta1, etc.)
# #   $API_resources_variables contains the list of all variables that have been defined
# #######################################################################################################################################################################################################

# $response = Invoke-RestMethod -Uri "https://developer.greenlake.hpe.com/_auth/sidebar/__alternative-sidebar__-data-glcp-doc-portal-docs-greenlake-services-compute-ops-mgmt-sidebars.yaml" -Method GET
# $items = ($response.items | ? label -eq "API reference").items

# $items = ($items | ? items -ne $Null | Sort-Object -Property label -Descending)

# $API_resources_variables = @()

# "COM API resources variables:" | Write-Verbose

# for ($i = 0; $i -lt ($items.Count); $i++) {
  
#     $APIversion = $items[$i].label.Substring($items[$i].label.length - 7)
#     # $APIversion
#     $APIresource = $items[$i].label.Substring(0, $items[$i].label.length - 10).replace('-', '_')
#     # $APIresource

#     #  Create $API_resources_variables variable

#     if (-not (Get-Variable -Name ${APIresource}_API_version -ErrorAction SilentlyContinue)) {
#         New-Variable -name ${APIresource}_API_version -Value $APIversion
#         $variablename = "$" + (get-variable ${APIresource}_API_version).name
#         $API_resources_variables += ($variablename)

#         "`t{0} = {1}" -f $variablename, $APIversion | Write-Verbose

#     } 
# }

# write-host 'API versions are saved in $API_resources_variables'
# #endregion


# #----------------------------------------------------------Connection to Compute Ops Management ----------------------------------------------------------------------
# #region COM authentication

# $COM_ClientSecret_SecureString = ConvertTo-SecureString $Encrypted_COM_ClientSecret
# $COM_ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($COM_ClientSecret_SecureString))


# # Headers creation
# $headers = @{} 
# $headers["Content-Type"] = "application/x-www-form-urlencoded"

# # Payload creation
# $body = "grant_type=client_credentials&client_id=" + $COM_ClientID + "&client_secret=" + $COM_ClientSecret


# try {
#     $response = Invoke-webrequest "https://sso.common.cloud.hpe.com/as/token.oauth2" -Method POST -Headers $headers -Body $body
# }
# catch {
#     write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
# }


# # Capturing API Access Token
# $AccessToken = ($response.Content  | Convertfrom-Json).access_token

# # Headers creation
# $headers = @{} 
# $headers["Authorization"] = "Bearer $AccessToken"

# #endregion


# #----------------------------------------------------------Set environment variables for all COM job templates-------------------------------------------------------------------------
# #region Retrieve job template resources


# $items = (Invoke-RestMethod "$ConnectivityEndpoint/compute-ops/$job_templates_API_version/job-templates" -Method GET -Headers $headers).items


# $Job_Template_variables = @()

# "COM API resources variables:" | Write-Verbose

# for ($i = 0; $i -lt ($items.Count); $i++) {

#     $jobtemplatetname = $items[$i].name.replace('-', '_').replace('.', '_')
#     $jobtemplateUri = $items[$i].resourceUri
  
  
#     #  Create $Job_Template_variables variable

#     if (-not (Get-Variable -Name ${jobtemplatetname}_jobtemplate_uri -ErrorAction SilentlyContinue)) {
#         New-Variable -name ${jobtemplatetname}_jobtemplate_uri -Value $jobtemplateUri
#         $variablename = "$" + (get-variable ${jobtemplatetname}_jobtemplate_uri).name
#         $Job_Template_variables += ($variablename)

#         "`t{0} = {1}" -f $variablename, $APIversion | Write-Verbose

#     } 
# }

# Write-host 'Job templates are saved in $Job_Template_variables'


# #######################################################################################################################################################################################################
# #endregion


# #----------------------------------------------------------Connection to HPE GreenLake ----------------------------------------------------------------------
# #region COM authentication
# if (-not $HPEGreenLakeSession ) {
#     Connect-HPEGL -Credential $GLP_credentials -Workspace $workspaceName | Out-Null
# }
# #endregion


#----------------------------------------------------------Connection to HPE OneView ----------------------------------------------------------------------
#region OneView authentication
if (-not $ConnectedSessions ) {
    Connect-OVMgmt -Hostname $OV_IP -Credential $OV_credentials -ErrorAction stop | Out-Null    

}
#endregion

#----------------------------------------------------------Migrate OneView Servers to COM -------------------------------------------------------------------------
#region Migrate OneView Servers to COM

$DeviceMigrationStatusList = @()

# Obtain the list of servers in HPE OneView to be migrated to COM

$serverListToBeMigrated = Search-OVIndex -Category server-hardware -Count 1024 | ? { $_.Attributes.mpModel -eq "iLO5" -or $_.Attributes.mpModel -eq "iLO6" }

# Filters can be used here to define which type of device to migrate
# Example: To migrate only the servers that are powered off:
$serverListToBeMigrated = $serverListToBeMigrated | ? { $_.Attributes.powerState -eq "Off" }
Clear-Host
"{0}: {1} servers found for the migration to COM" -f $OV_IP, $serverListToBeMigrated.Count

Write-Host "Running migration, please wait..."

$iLO_Password_SecureString = ConvertTo-SecureString $Encrypted_iLO_Password
$iLO_Password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($iLO_Password_SecureString))

$serveriLOListToBeMigrated = @()

foreach ($server in $serverListToBeMigrated) {
    
    $serverSerialNumber = $server.attributes.serialNumber
    
    $SH = Get-OVServer -SerialNumber $serverSerialNumber
    $serveriLO = $SH.mpHostInfo.mpIpAddresses | ? address -notmatch "fe80" | % address
        
    $serveriLOListToBeMigrated += $serveriLO
    
}

foreach ($serveriLO in $serveriLOListToBeMigrated) {

    if ($IloProxyServer -and -not $IloProxyUserName) {

        $DeviceMigrationStatus = Add-HPEGLDeviceComputeFullService -IloProxyServer $IloProxyServer -IloProxyPort $IloProxyPort -IloIP $serveriLO -GLCredential $GLP_credentials -Region $COM_Region -GLWorkspace $workspaceName -IloUserName $iLO_Username -IloPassword $iLO_Password -Tags $Tags -Application "Compute Ops Management" -DisconnectiLOfromOneView -ComputeSubscriptionTier ENHANCED #-Verbose
    }
    elseif ($IloProxyServer -and $IloProxyUserName) {

        $DeviceMigrationStatus = Add-HPEGLDeviceComputeFullService -IloProxyServer $IloProxyServer -IloProxyPort $IloProxyPort -IloProxyUserName $IloProxyUserName -IloProxyPassword $IloProxyPassword -IloIP $serveriLO -GLCredential $GLP_credentials -Region $COM_Region -GLWorkspace $workspaceName -IloUserName $iLO_Username -IloPassword $iLO_Password -Tags $Tags -Application "Compute Ops Management" -DisconnectiLOfromOneView -ComputeSubscriptionTier ENHANCED #-Verbose

    }
    else {

        $DeviceMigrationStatus = Add-HPEGLDeviceComputeFullService -IloIP $serveriLO -GLCredential $GLP_credentials -Region $COM_Region -GLWorkspace $workspaceName -IloUserName $iLO_Username -IloPassword $iLO_Password -Tags $Tags -Application "Compute Ops Management" -DisconnectiLOfromOneView -ComputeSubscriptionTier ENHANCED #-Verbose
        
    }

    $DeviceMigrationStatusList += $DeviceMigrationStatus
}

# Export to CSV for reporting purposes in local folder

# for ($i = 0; $i -lt $DeviceMigrationStatusList.Count; $i++) {
#     $exportdata = ((($DeviceMigrationStatusList[$i].SubTasksStatus  -split '\];').TrimStart('[').TrimEnd(']')) -split ';').replace(',', ':')
#     $DeviceMigrationStatusList[$i].SubTasksStatus =  $exportdata
# }

# $DeviceMigrationStatusList | Select-Object Name, serialnumber, status, @{Name = 'SubTasksStatus'; Expression = { $_.SubTasksStatus -join ';' } } | Export-Csv $CSV_File_Name_For_Migration_Status_Report -Force
$DeviceMigrationStatusList | Select-Object @{Name = 'iLO IP'; Expression = { $_.Name } }, serialnumber, PartNumber, @{Name = 'Migration Status'; Expression = { $_.status } } | Export-Csv $CSV_File_Name_For_Migration_Status_Report -Force

#EndRegion


#----------------------------------------------------------Remove OneView Servers from COM if migration successful -------------------------------------------------------------------------
#region Remove OneView Servers from COM

foreach ($server in $DeviceMigrationStatusList) {

    if ($server.status -eq "Complete" ) {
        try {
            get-ovserver -SerialNumber $server.SerialNumber | Remove-OVServer -Confirm:$false -Force -ErrorAction Stop | Out-Null
            "{0} - server successfully removed from OneView and added to COM" -f $server.Name
        }
        catch {
            "{0} - server cannot be removed from OneView but was successfully added to COM" -f $server.Name
            continue

        }

    }

    if ($server.status -eq "Failed" ) {

        "{0} - Error ! Server cannot be added to COM !" -f $server.Name

    }
}

#EndRegion