<#

This script creates a firmware update schedule for a server group managed by HPE Compute Ops Management using a defined SPP baseline and schedule date.

Warning: Any updates other than iLO FW require a server reboot!

Note: To perform an immediate update, you must create a job instead of a schedule, see COM-Group-firmware-update.ps1. 

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
Date:   Nov 2022

    
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
$GroupName = "Production"
$Baseline = "2022.03.1" 
# Start schedule on Dec 1, 2022 at 2am
[datetime]$StartSchedule = "12-01-2022 2:00:00"


# API Client Credentials
$ClientID = "e419b0b6-ef7c-4049-8045-f50bed11b4e6"

# The connectivity endpoint can be found in the GreenLake platform / API client information
$ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#region Retrieve resource API versions

#######################################################################################################################################################################################################
# Create variables to get the API version of COM resources using the API reference.
#   Generate a variable for each API resource ($servers_API_version, $jobs_API_version, etc.) 
#   Set each variable value with the resource API version ($servers_API_version = v1beta2, $filters_API_version = v1beta1, etc.)
#   $API_resources_variables contains the list of all variables that have been defined
#######################################################################################################################################################################################################
$response = Invoke-RestMethod -Uri "https://developer.greenlake.hpe.com/_auth/sidebar/__alternative-sidebar__-data-hpe-hcss-doc-portal-docs-greenlake-services-compute-ops-sidebars.yaml" -Method GET
$items = ($response.items | ? label -eq "API reference").items

$API_resources_variables = @()
for ($i = 1; $i -lt ($items.Count - 1); $i++) {
  
  $APIversion = $items[$i].label.Substring($items[$i].label.length - 7)
  # $APIversion
  $APIresource = $items[$i].label.Substring(0, $items[$i].label.length - 10).replace('-', '_')
  # $APIresource

  if (-not (Get-Variable -Name ${APIresource}_API_version -ErrorAction SilentlyContinue)) {
    New-Variable -name ${APIresource}_API_version -Value $APIversion
  }
  $variablename = "$" + (get-variable ${APIresource}_API_version).name
  $API_resources_variables += ($variablename)
}
#######################################################################################################################################################################################################
#endregion


#region GreenLake authentication
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


#region Set group server settings with defined SPP
#-----------------------------------------------------------Modify the group server settings to set the defined baseline-----------------------------------------------------------------------------

# Retrieve firmware bundle id of the defined baseline
$bundleid = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$firmware_bundles_API_version/firmware-bundles" -Method GET -Headers $headers).content | ConvertFrom-Json).items | Where-Object releaseVersion -eq $Baseline | ForEach-Object id

if (-not $bundleid ) {
  write-warning "Error, firmware bundle '$baseline' not found!"
  break
}
# Retrieve group Server settings 
$serverSettingsUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq $GroupName).serverSettingsUris 

# Set group server settings to use defined SPP
## Creation of the payload
$body = @"
{
  "settings": {
    "GEN10": {
      "id": "$bundleid"
    }
  }
}
"@ 
## Creation of the header
$headers["Content-Type"] = "application/merge-patch+json"

try {
  $response = Invoke-webrequest "$ConnectivityEndpoint$serverSettingsUri" -Method PATCH -Headers $headers -Body $body -ErrorAction Stop

  "Server settings for group $groupname has been set with SPP $Baseline" -f $response

}
catch {
  write-warning "Error, group $groupname server settings cannot be updated with SPP $Baseline !"
  break
}

#endregion


#region Schedule group firmware update
#-----------------------------------------------------------Schedule a firmware update-----------------------------------------------------------------------------

# Create a schedule to perform a firmware update
# This schedule will update all servers in the defined group with defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To perform an immediate update, you must create a job instead of a schedule

$startAt = get-date $StartSchedule  -Format o

#Schedule interval
$interval = "null" # Can be P7D for 7 days intervals, P15m, P1M, P1Y

# Retrieve job template resourceUri of GroupFirmwareUpdate
$jobTemplateUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$job_templates_API_version/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "GroupFirmwareUpdate").resourceUri

if (-not  $jobTemplateUri) {
  write-warning "Error, job template 'GroupFirmwareUpdate' not found!"
  break
}

# Retrieve group Uri of the defined group name
$groupUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq $GroupName).resourceUri

if (-not  $groupUri) {
  write-warning "Error, group name '$groupname' not found!"
  break
}


# Retrieve group device IDs 
## The list of devices must be provided even if they are already part of the group!
$deviceids = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq $GroupName).devices.id 

if ($deviceids.count -eq 1) {
  $devicesformatted = ConvertTo-Json  @("$deviceids")
}
else {
  $devicesformatted = $deviceids | ConvertTo-Json 
}

if ($deviceids.count -eq 0) {
  write-warning "Error, no server found in group $groupname !"
  break
}


# Creation of the payload
$body = @"
{
  "name": "Schedule for $GroupName",
  "description": "Firmware update for $GroupName with baseline $Baseline",
  "associatedResourceUri": "/api/compute/v1/groups/$Groupid",
  "purpose": "GROUP_FW_UPDATE",
  "schedule": {
                "interval": $interval,
                "startAt": "$startAt"
              },
  "operation": {
                "type": "REST",
                "method": "POST",
                "uri": "/api/compute/v1/jobs",
                "body": {
                          "resourceUri": "$groupUri",
                          "jobTemplateUri": "$jobTemplateUri",
                          "data": {
                                    "devices": $devicesformatted,
                                    "parallel": true,
                                    "stopOnFailure": false
                                  }
                        }
                }
}
"@ 

# Creation of the request
$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$schedules_API_version/schedules" -Method POST -Headers $headers -Body $body


"{0} - Status: {1} for {2}" -f (($response.Content | ConvertFrom-Json).name), $response.StatusDescription, [datetime]$StartSchedule


#endregion
