<# 

This PowerShell script shows how to connect to the HPE Compute Ops Management API and how to create requests. 

Important note: To use the Compute Ops Management API, you must configure the API client credentials in the HPE GreenLake Cloud Platform.

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


# API Client Credentials
$ClientID = "e419b0b6-ef7c-4049-8045-f50bed11b4e6"

# The connectivity endpoint can be found in the GreenLake platform / API client information
$ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"



#----------------------------------------------------------Retrieve COM resource API versions-------------------------------------------------------------------------
#region Retrieve resource API versions

#######################################################################################################################################################################################################
# Create variables to get the API version of COM resources using the API reference.
#   Generate a variable for each API resource ($servers_API_version, $jobs_API_version, etc.) 
#   Set each variable value with the resource API version ($servers_API_version = v1beta2, $filters_API_version = v1beta1, etc.)
#   $API_resources_variables contains the list of all variables that have been defined
#######################################################################################################################################################################################################

$response = Invoke-RestMethod -Uri "https://developer.greenlake.hpe.com/_auth/sidebar/__alternative-sidebar__-data-glcp-doc-portal-docs-greenlake-services-compute-ops-mgmt-sidebars.yaml" -Method GET
$items = ($response.items | ? label -eq "API reference").items

$items = ($items | ? items -ne $Null | Sort-Object -Property label -Descending)

$API_resources_variables = @()

"COM API resources variables:" | Write-Verbose

for ($i = 0; $i -lt ($items.Count); $i++) {
  
  $APIversion = $items[$i].label.Substring($items[$i].label.length - 7)
  # $APIversion
  $APIresource = $items[$i].label.Substring(0, $items[$i].label.length - 10).replace('-', '_')
  # $APIresource

  if (-not (Get-Variable -Name ${APIresource}_API_version -ErrorAction SilentlyContinue)) {
    New-Variable -name ${APIresource}_API_version -Value $APIversion
    $variablename = "$" + (get-variable ${APIresource}_API_version).name
    $API_resources_variables += ($variablename)

    "`t{0} = {1}" -f $variablename, $APIversion | Write-Verbose

  } 
}

#######################################################################################################################################################################################################
#endregion

#----------------------------------------------------------Connection to Compute Ops Management ----------------------------------------------------------------------
#region COM authentication

$secClientSecret = read-host  "Enter your HPE GreenLake Client Secret" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secClientSecret)
$ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) 


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
$AccessToken = ($response.Content | Convertfrom-Json).access_token

# Headers creation
$headers = @{} 
$headers["Authorization"] = "Bearer $AccessToken"

#endregion


#-------------------------------------------------------SERVERS requests samples--------------------------------------------------------------------------------
#region servers


# Obtain the list of servers in your account
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers" -Method GET -Headers $headers
$ServersList = $response.Content | ConvertFrom-Json

"{0} server(s) found" -f $ServersList.count

# Server items
$ServersList.items[0].name 
$ServersList.items[0].biosFamily
$ServersList.items[0].displayName
$ServersList.items[0].firmwareBundleUri
$ServersList.items[0].generation
$ServersList.items[0].lastFirmwareUpdate
$ServersList.items[0].platformFamily
$ServersList.items[0].processorVendor
$ServersList.items[0].resourceType
$ServersList.items[0].resourceUri
$ServersList.items[0].selfUri
$ServersList.items[0].tags
$ServersList.items[0].updatedAt


# Server items.hardware
$ServersList.items[0].hardware

## Serial Number
$ServersList.items[0].hardware.serialnumber
## Model
$ServersList.items[0].hardware.model
## Product ID
$ServersList.items[0].hardware.productId
## Power State
$ServersList.items[0].hardware.powerState
## Indicator LED
$ServersList.items[0].hardware.indicatorLed
## iLO info
$ServersList.items[0].hardware.bmc
## iLO IP
$iloIP = $ServersList.items[0].hardware.bmc.ip


# Server health
$ServersList.items[0].hardware.health 


# Server state includes COM subscription information, COM managed / COM connected
$ServersList.items[0].state


# FW information with device name and versions
$ServersList.items[0].firmwareInventory


# Hostname / OS information
$ServersList.items[0].host


# Obtain the first 10 servers
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers?limit=10" -Method GET -Headers $headers
$ServersList = $response.Content | ConvertFrom-Json


# List of servers from the 10th
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers?offset=9" -Method GET -Headers $headers
$ServersList = $response.Content | ConvertFrom-Json


# Get a server by ID
$serverid = $ServersList.items | where name -eq "HPE-HOL17" | % id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers/$serverid" -Method GET -Headers $headers
$Server = $response.Content | ConvertFrom-Json
$server


# List all alerts for a server
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers/$serverid/alerts" -Method GET -Headers $headers
$alerts = $response.Content | ConvertFrom-Json
$alerts.items


# List all DL360 Gen10+ servers
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers" -Method GET -Headers $headers
$DL360Gen10Plus = ($response.Content | ConvertFrom-Json).items | Where-Object { $_.hardware.model -match "ProLiant DL360 Gen10 Plus" } 
$DL360Gen10Plus

#endregion


#-------------------------------------------------------ACTIVITIES requests samples--------------------------------------------------------------------------------
#region activities


# List all activities
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$activities_API_version/activities" -Method GET -Headers $headers
$activities = $response.Content | ConvertFrom-Json
$activities.items


# List last 10 server activities
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$activities_API_version/activities?filter=source/type eq 'Server'&limit=10" -Method GET -Headers $headers
$activities = $response.Content | ConvertFrom-Json
$activities.items
$activities.count


# List last 10 firmware activities
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$activities_API_version/activities?filter=source/type eq 'Firmware'&limit=10" -Method GET -Headers $headers
$firmwareactivities = $response.Content | ConvertFrom-Json
$firmwareactivities.items
$firmwareactivities.count


# List required subscriptions activities
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$activities_API_version/activities?filter=source/type eq 'Server' and contains(key,'SERVER_ASSIGNED')" -Method GET -Headers $headers
$subscriptionsactivities = $response.Content | ConvertFrom-Json
$subscriptionsactivities.items
$subscriptionsactivities.count

#endregion


#-------------------------------------------------------FIRMWARE-BUNDLES requests samples--------------------------------------------------------------------------------
#region firmware-bundles


# List all firmware bundles
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$firmware_bundles_API_version/firmware-bundles" -Method GET -Headers $headers
$firmwarebundles = $response.Content | ConvertFrom-Json
$firmwarebundles.items


# List a group
$firmwarebundlesid = $firmwarebundles.items | Where-Object releaseVersion -eq 2022.03.0 | ForEach-Object id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$firmware_bundles_API_version/firmware-bundles/$firmwarebundlesid" -Method GET -Headers $headers
$firmwarebundle = $response.Content | ConvertFrom-Json
$firmwarebundle

#endregion


#-------------------------------------------------------GROUPS requests samples--------------------------------------------------------------------------------
#region groups


# List all groups
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers
$groups = $response.Content | ConvertFrom-Json
$groups.items


# List a group
$groupid = $groups.items | Where-Object name -eq Production | ForEach-Object id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups/$groupid" -Method GET -Headers $headers
$group = $response.Content | ConvertFrom-Json
$group


# Delete a group
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups/$groupid" -Method DELETE -Headers $headers
$response.Content | ConvertFrom-Json


# Create a group
$groupname = "Production-Group"
$groupdescription = "My Production Group with DL360 Gen10 Plus servers"
$firmwarebundleid = $firmwarebundle.id

$body = @"
  {
    "name":  "$groupname",
    "description":  "$groupdescription",
    "firmwareBaseline": "$firmwarebundleid",
    "autoIloFwUpdateEnabled": "False",
    "autoFwUpdateOnAdd": "False",
    "deviceSettingsUris": [],
    "data": {},
    "tags": {
      "location": "Houston"
    }
  }
"@ 

$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method POST -Headers $headers -Body $body
$response.Content | ConvertFrom-Json
$newcreategroupid = ($response.Content | ConvertFrom-Json).id


# Add all DL360 Gen10 Plus to newly created group
$devices = ($DL360Gen10Plus | Select-Object @{Name = "serverId"; Expression = { $_.id } }) | convertto-json

$body = @"
  {
    "devices":  $devices
  }
"@ 

$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups/$newcreategroupid/devices" -Method POST -Headers $headers -Body $body
$response.Content | ConvertFrom-Json


# Modify a group
$newgroupname = "DL360Gen10plus-Production-Group"

$body = @"
  {
    "name":  "$newgroupname"
  }
"@ 

$headers["Content-Type"] = "application/merge-patch+json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups/$newcreategroupid" -Method PATCH -Headers $headers -Body $body
$response.Content | ConvertFrom-Json

#endregion


#-------------------------------------------------------JOB-TEMPLATES requests samples--------------------------------------------------------------------------------
#region job-templates


# List all job templates
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$job_templates_API_version/job-templates" -Method GET -Headers $headers
$jobtemplates = $response.Content | ConvertFrom-Json
$jobtemplates.items


# Get a  job template
$jobtemplateid = ($jobtemplates.items | ? name -eq "GroupFirmwareUpdate").id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$job_templates_API_version/job-templates/$jobtemplateid" -Method GET -Headers $headers
$jobtemplate = $response.Content | ConvertFrom-Json
$jobtemplate

#endregion


#-------------------------------------------------------JOBS requests samples--------------------------------------------------------------------------------
#region jobs


# List all jobs
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$jobs_API_version/jobs" -Method GET -Headers $headers
$jobs = $response.Content | ConvertFrom-Json
$jobs.items


# Get a job
$jobid = $jobs.items[0].id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$jobs_API_version/jobs/$jobid" -Method GET -Headers $headers
$job = $response.Content | ConvertFrom-Json
$job


# Create a job to start a firmware update
## This job will update all servers in the group "DL360Gen10plus-Production-Group" with SPP 2022.03.0
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To set schedule options during updates, you must create a schedule instead of a job
$jobTemplateUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$job_templates_API_version/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "GroupFirmwareUpdate").resourceUri
$resourceUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "Production").resourceUri
$bundleid = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$firmware_bundles_API_version/firmware-bundles" -Method GET -Headers $headers).content | ConvertFrom-Json).items | Where-Object releaseVersion -eq 2022.03.0 | ForEach-Object id
# The list of devices must be provided even if they are already part of the group!
$deviceids = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "Production").devices.id 

if ($deviceids.count -eq 1) {
  $devicesformatted = ConvertTo-Json  @("$deviceids")
}
else {
  $devicesformatted = $deviceids | ConvertTo-Json 
}


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

$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$jobs_API_version/jobs" -Method POST -Headers $headers -Body $body
$joburi = ($response.Content | ConvertFrom-Json).resourceUri

## Wait for the task to start or fail
do {
  $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
  Start-Sleep 5
} until ($status.state -eq "running" -or $status.state -eq "error")

## Wait for the task to complete
if ($status.state -eq "error") {
  "Group firmware update failed! {0} " -f $status.status
  $status.data.state_reason_message.message_args
}
else {
  do {
    $FWupgradestatus = (((Invoke-webrequest "$ConnectivityEndpoint/ui-doorway/compute/v1/servers/counts/state" -Method GET -Headers $headers).content | convertfrom-json).counts | gm ) | ? name -match "in progress" | % name
    $FWupgradestatus
    $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
    Start-Sleep 20
  } until ( $status.state -eq "Error" -or $status.state -eq "complete") 

  ## Display status
  "State: {0} - Status: {1}" -f $status.state, $status.status


  # Get the update report for the servers in the group after the update is complete.
  foreach ($deviceid in $deviceids) {
    $report = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers/$deviceid" -Method GET -Headers $headers).content | ConvertFrom-Json).lastFirmwareUpdate 
    $report
  }



}


#endregion


#-------------------------------------------------------SCHEDULES requests samples--------------------------------------------------------------------------------
#region schedules


# List all schedules
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules" -Method GET -Headers $headers
$schedules = $response.Content | ConvertFrom-Json
$schedules.items


# Get a schedule
$scheduleid = $schedules.items[0].id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method GET -Headers $headers
$schedule = $response.Content | ConvertFrom-Json
$schedule


# Delete a schedule
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method DELETE -Headers $headers
$response.Content | ConvertFrom-Json


# Update a schedule
$newname = "Firmware update for group Production"
$description = "This upgrade is going to rock!"
$associatedResourceUri = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).groups | ? name -eq "Production").resourceUri

$body = @"
{
    "name":  "$newname",
    "description":  "$description",
    "associatedResourceUri":  "$associatedResourceUri",
    "purpose":  "GROUP_FW_UPDATE"
}
"@ 

$headers["Content-Type"] = "application/merge-patch+json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method PATCH -Headers $headers -Body $body
$response.Content | ConvertFrom-Json


# Create a schedule
## Schedules allow you to run an update with scheduling options
## Warning: Any updates other than iLO FW require a server reboot!
$schedulename = "Firmware upgrade for group Production"
$description = "Upgrade to SPP 2022.03.1"
## Start schedule on Sept 1, 2022 at 2am
$startAt = get-date -year 2022 -Month 12 -Day 1 -Hour 2 -Minute 0  -Format o
$interval = "null" # Can be P7D for 7 days intervals, P15m, P1M, P1Y


$jobTemplateid = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$job_templates_API_version/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "GroupFirmwareUpdate").id
$groupid = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "Production").id
$bundleid = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$firmware_bundles_API_version/firmware-bundles" -Method GET -Headers $headers).content | ConvertFrom-Json).items | Where-Object releaseVersion -eq 2022.03.1 | ForEach-Object id
$deviceids = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$groups_API_version/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "Production").devices.id 

if ($deviceids.count -eq 1) {
  $devicesformatted = ConvertTo-Json  @("$deviceids")
}
else {
  $devicesformatted = $deviceids | ConvertTo-Json 
}


$body = @"
{
    "name":  "$schedulename",
    "description":  "$description",
    "associatedResourceUri":  "/api/compute/v1/groups/$groupid",
    "purpose":  "GROUP_FW_UPDATE",
    "schedule":  {
                     "interval":  $interval,
                     "startAt": "$startAt"
                 },
    "operation":  {
                      "type":  "REST",
                      "method":  "POST",
                      "uri": "/api/compute/v1/jobs",
                      "body":  {
                        "resourceUri": "/api/compute/v1/groups/$groupid",
                        "jobTemplateUri": "/api/compute/v1/job-templates/$jobTemplateid",
                        "data": {
                          "devices": $devicesformatted,
                          "parallel": true,
                          "stopOnFailure": false
                        }
                      }                              
                  }
}
"@ 

$headers["Content-Type"] = "application/json"
# $idempotencyKey = (1..64|%{[byte](Get-Random -Max 128)}|foreach ToString X2) -join ''
# $headers["Idempotency-Key"] = $idempotencyKey 
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules" -Method POST -Headers $headers -Body $body
$response.Content | ConvertFrom-Json
$scheduleid = ($response.Content | ConvertFrom-Json).id

# Get details about newly created schedule
((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method GET -Headers $headers).Content | ConvertFrom-Json)
((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method GET -Headers $headers).Content | ConvertFrom-Json).operation.body.data

# Delete newly created schedule
$response = (Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$schedules_API_version/schedules/$scheduleid" -Method DELETE -Headers $headers) | ConvertFrom-Json

# Get the update report for the servers in the group after the update is complete.
foreach ($deviceid in $deviceids) {
  $report = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$servers_API_version/servers/$deviceid" -Method GET -Headers $headers).content | ConvertFrom-Json).lastFirmwareUpdate 
  $report

}


#endregion


#-------------------------------------------------------FILTERS requests samples--------------------------------------------------------------------------------
#region filters


# List all filters
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters" -Method GET -Headers $headers
$filters = $response.Content | ConvertFrom-Json
$filters.items


# Get filterable properties
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters/properties" -Method GET -Headers $headers
$filtersproperties = $response.Content | ConvertFrom-Json
$filtersproperties | format-list 


# Get a filter
$filterid = ($filters.items | where-object name -eq "Warnings").id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters/$filterid" -Method GET -Headers $headers
$filter = $response.Content | ConvertFrom-Json
$filter


# Delete a saved filter
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters/$filterid" -Method DELETE -Headers $headers
$response.Content | ConvertFrom-Json


# Update a saved filter
$newname = "Warnings for powered ON servers"

$body = @"
{
  "name": "$newname",
  "description": "",
  "filterResourceType": "compute-ops/server",
  "filter": "(hardware/powerState in ('On')) and (hardware/health/summary in ('Warning'))",
  "filterTags": null
}
"@ 

$headers["Content-Type"] = "application/merge-patch+json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters/$filterid" -Method PATCH -Headers $headers -Body $body
$response.Content | ConvertFrom-Json


# Create a filter
$body = @"
{
  "name": "DL360 Linux servers",
  "description": "My filter for DL360 Gen10 and Gen10 Plus Linux server",
  "filterResourceType": "compute-ops/server",
  "filter": "(hardware/model in ('ProLiant DL360 Gen10','ProLiant DL360 Gen10 Plus'))",
  "filterTags": null
}
"@ 

$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters" -Method POST -Headers $headers -Body $body
$response.Content | ConvertFrom-Json

#endregion


#-------------------------------------------------------SERVER SETTINGS requests samples--------------------------------------------------------------------------------
#region server-settings


# List all server-settings
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$server_settings_API_version/server-settings" -Method GET -Headers $headers
$serversettings = $response.Content | ConvertFrom-Json
$serversettings.items


# Get a server-settings
$serversettingsid = ($serversettings.items | where-object name -eq "Production Firmware Settings").id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$server_settings_API_version/server-settings/$serversettingsid" -Method GET -Headers $headers
$serversetting = $response.Content | ConvertFrom-Json
$serversetting


# Delete a server-settings item
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$server_settings_API_version/server-settings/$serversettingsid" -Method DELETE -Headers $headers
$response.Content | ConvertFrom-Json


# Update a server-settings item
$newname = "Webfarm Firmware Settings"
$id = $serversetting.settings.GEN10.id

$body = @"
{
  "name": "$newname",
  "description": "Firmware settings for group Production",
  "settings": {
    "GEN10": {
      "id": "$id"
    }
  }
}
"@ 

$headers["Content-Type"] = "application/merge-patch+json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$server_settings_API_version/server-settings/$serversettingsid" -Method PATCH -Headers $headers -Body $body
$response.Content | ConvertFrom-Json


# Create a server-settings
## Get a firmware bundle ID
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$firmware_bundles_API_version/firmware-bundles" -Method GET -Headers $headers
$firmwarebundlesid = ($response.Content | ConvertFrom-Json).items | Where-Object releaseVersion -eq 2022.03.1 | ForEach-Object id

$body = @"
{
  "name": "LJ server settings",
  "description": "My server settings with SPP 2022.03.1",
  "platformFamily": "PROLIANT",
  "category": "FIRMWARE",
  "settings": {
    "GEN10": {
      "id": "$firmwarebundlesid"
    }
  }
}
"@ 

$headers["Content-Type"] = "application/json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$server_settings_API_version/server-settings" -Method POST -Headers $headers -Body $body
$response.Content | ConvertFrom-Json

#endregion


#-------------------------------------------------------REPORTS requests samples--------------------------------------------------------------------------------
#region reports


# List all reports
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$reports_API_version/reports" -Method GET -Headers $headers
$reports = $response.Content | ConvertFrom-Json
$reports.items


# Get a report metadata
$reportid = $reports.items.id
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$reports_API_version/reports/$reportid"  -Method GET -Headers $headers
$reportmetadata = $response.Content | ConvertFrom-Json
$reportmetadata


# Get a report data
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$reports_API_version/reports/$reportid/data"  -Method GET -Headers $headers
$reportdata = $response.Content | ConvertFrom-Json
$reportdata


# Run a report
## Get job template DataRoundupReportOrchestrator
$jobtemplates = (Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$job_templates_API_version/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json
$jobtemplateid = ($jobtemplates.items | ? name -eq "DataRoundupReportOrchestrator").id
## Get all servers filter
$filters = (Invoke-webrequest "$ConnectivityEndpoint/compute-ops-mgmt/$filters_API_version/filters" -Method GET -Headers $headers).Content | ConvertFrom-Json
$filterresourceUri = ($filters.items | where-object name -eq "All Servers").resourceUri

$body = @"
{
  "jobTemplateUri":"/api/compute/v1/job-templates/$jobtemplateid",
  
  "resourceUri":"$filterresourceUri",
  
  "data":{
      "reportType":"CARBON_FOOTPRINT"
      }
}
"@ 

$headers["Content-Type"] = "application/json"

$response = Invoke-webrequest "$ConnectivityEndpoint/api/compute/v1/jobs"  -Method POST -Headers $headers -Body $body

$joburi = ($response.Content | ConvertFrom-Json).resourceUri

## Wait for the task to start or fail
do {
  $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
  Start-Sleep 5
} until ($status.state -eq "Complete" -or $status.state -eq "error")

## Wait for the task to complete
if ($status.state -eq "error") {
  "Carbon footprint creation failure {0} " -f $status.status
  $status.data.state_reason_message.message_args
}
else {
  "Carbon Footprint Report was created successfully at {0}" -f [DateTime]($status.createdAt)
}


#endregion
