<# 

This script performs a firmware update of a server group managed by HPE Compute Ops Management using a defined SPP baseline.

Warning: Any updates other than iLO FW require a server reboot!

Note: To set schedule options during updates, you must create a schedule instead of a job, see COM-Schedule-group-firmware-update.ps1

Note: To use the Compute Ops Management API, you must configure the API client credentials in the HPE GreenLake Cloud Platform.

To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 

Information about the HPE Greenlake for Compute Ops Management API can be found at:
https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/

Requirements: 
- Compute Ops Management API Client Credentials with appropriate roles, this includes:
   - A Client ID
   - A Client Secret
   - A Connectivity Endpoint


Author: lionel.jullien@hpe.com
Date:   August 2022

    
#################################################################################
#        (C) Copyright 2022 Hewlett Packard Enterprise Development LP           #
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

# Variables to perform the group firmware update 
$GroupName = "Production-Group"
$Baseline = "2022.03.0" 


# API Client Credentials
$ClientID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# The connectivity endpoint can be found in the GreenLake platform / API client information
$ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"
$APIversion = "v1beta1"

# MODULES TO INSTALL
# None


#region authentication
#----------------------------------------------------------Connection to HPE GreenLake -----------------------------------------------------------------------------

$secClientSecret = read-host  "Enter your HPE GreenLake Client Secret" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secClientSecret)
$ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) 
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)


# Headers creation
$headers = @{} 
$headers["Content-Type"] = "application/x-www-form-urlencoded"

# Payload creation
$body = "grant_type=client_credentials&client_id=" + $ClientID + "&client_secret=" + $ClientSecret


try {
  $response = Invoke-webrequest "https://sso.common.cloud.hpe.com/as/token.oauth2" -Method POST -Headers $headers -Body $body
}
catch {
  write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
}


# Capturing API Access Token
$AccessToken = ($response.Content  | Convertfrom-Json).access_token

# Headers creation
$headers = @{} 
$headers["Authorization"] = "Bearer $AccessToken"

#endregion


#region Firmware-update
#-----------------------------------------------------------Start the firmware update-----------------------------------------------------------------------------

# Create a job to start a firmware update
## This job will update all servers in the defined group with the defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To set schedule options during updates, you must create a schedule instead of a job

# Retrieve job template id of GroupFirmwareUpdate
$jobTemplateUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "GroupFirmwareUpdate").resourceUri

if (-not  $jobTemplateUri) {
  write-warning "Error, job template 'GroupFirmwareUpdate' not found!"
  break
}

# Retrieve group uri of the defined group name
$resourceUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).groups | ? name -eq $GroupName).resourceUri

if (-not  $resourceUri) {
  write-warning "Error, group name '$groupname' not found!"
  break
}

# Retrieve firmware bundle id of the defined baseline
$bundleid = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/firmware-bundles" -Method GET -Headers $headers).content | ConvertFrom-Json).items | Where-Object releaseVersion -eq $Baseline | ForEach-Object id

if (-not $bundleid ) {
  write-warning "Error, firmware bundle '$baseline' not found!"
  break
}

# The list of devices must be provided even if they are already part of the group!
$deviceids = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).groups | ? name -eq $GroupName).devices.id 

if ($deviceids.count -eq 1) {
  $devicesformatted = ConvertTo-Json  @("$deviceids")
}
else {
  $devicesformatted = $deviceids | ConvertTo-Json 
}

# Creation of the payload
$body = @"
  {
    "jobTemplateUri": "$jobTemplateUri",
    "resourceUri": "$resourceUri",
    "data": {
      "bundle_id": "$bundleid",
      "devices": 
        $devicesformatted
    }
  }
"@ 

# Creation of the request
$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/jobs" -Method POST -Headers $headers -Body $body
$joburi = ($response.Content | ConvertFrom-Json).resourceUri

## Wait for the task to start or fail
do {
  $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
  Start-Sleep 5
} until ($status.state -eq "running" -or $status.state -eq "error")

## Wait for the task to complete
if ($status.state -eq "error") {
  "Group firmware update failed! {0}" -f $status.status
}
else {
  do {
    $FWupgradestatus = (((Invoke-webrequest "$ConnectivityEndpoint/ui-doorway/compute/v1/servers/counts/state" -Method GET -Headers $headers).content | convertfrom-json).counts | gm ) | ? name -match "in progress"  | % name
    $FWupgradestatus
    $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
    Start-Sleep 20
  } until ( $status.state -eq "Error" -or $status.state -eq "complete") 

  ## Display status
  "State: {0} - Status: {1}" -f $status.state, $status.status


  $response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/servers/$serverid" -Method GET -Headers $headers
  $Server = $response.Content | ConvertFrom-Json
  $server


  # Get the update report for the servers in the group after the update is complete if lastFirmwareUpdate is defined 
  foreach ($deviceid in $deviceids) {

    $server = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/servers/$deviceid" -Method GET -Headers $headers).content | ConvertFrom-Json)
    # $server 
    
    if ( (Get-Member -inputobject $server -name "lastFirmwareUpdate" -Membertype Properties) -and $null -ne $server.lastFirmwareUpdate) {
      "Server: {0} - Report status: {1}" -f $server.name, $server.lastFirmwareUpdate.status
       ($server.lastFirmwareUpdate.firmwareInventoryUpdates | fl *)
    }
    elseif ((Get-Member -inputobject $server -name "lastFirmwareUpdate" -Membertype Properties) -and $null -eq $server.lastFirmwareUpdate) {
      "Server: {0} - State: {1}" -f $server.name, "Firmware update successful - No update was required"
    }
    else {
      "Server: {0} - State: {1}" -f $server.name, (($status.data.state_reason_message.message_args -split '\r?\n').Trim() | ? { $_ -match ($server.id.Substring($server.id.Length - 10, 10)) })
    }
  }
}


#endregion
