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


Sample script output:
---------------------------------------------------------SUCCESSFUL UPDATE------------------------------------------------------------------------------------------------------------
Job state:      RUNNING
Job status:     Step 2 of 3  

Job state:      COMPLETE
Job status:     Complete  

Server:         HPE-HOL33 
Date:           11/14/2022 3:24:22 PM
Status:         Firmware update in progress
                Staging the firmware is complete. Server reboot initiated and in progress to activate the firmware.

Server:         HPE-HOL33 
Date:           11/14/2022 3:34:52 PM
Status:         Firmware update successful
      
Server:         HPE-HOL28
Date:           11/14/2022 3:34:51 PM
Status:         Firmware update successful
Note:           The server firmware is already up to date with specified baseline SPP 2022.03.1 (15 Sep 2022). The specified baseline has been set for the server.

Group:          Production
Date:           11/14/2022 3:35:09 PM
Status:         Group firmware update successful


------------------------------------------------------FAILED UPDATE-----------------------------------------------------------------------------------------------------------------
Job state:      RUNNING
Job status:     Step 2 of 3

Job state:      ERROR
Job status:     JobErrorException : 1 servers failed update

Server:         HPE-HOL06
Date:           11/15/2022 4:01:44 PM
Status:         Firmware update failed
Recommendation: Retry the firmware update. If the issue persists, create a Compute Ops Management support case (error code: FWE-115).

Group:          Production
Date:           11/15/2022 4:02:42 PM
Status:         Group firmware update failed
Recommendation: 1 out of 1 servers failed firmware update. Review the individual server firmware update activity, follow the recommendation to resolve the issue and retry group firmware update.


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

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
# $Baseline = "2022.03.1" 
$Baseline = "2022.09.01.00" 


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
  sleep 3  
}
catch {
  write-warning "Error, group $groupname server settings cannot be updated with SPP $Baseline !"
  break
}

#endregion


#region Run group firmware update
#-----------------------------------------------------------Start the firmware update-----------------------------------------------------------------------------

# Create a job to start a firmware update
## This job will update all servers in the defined group with the defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To set schedule options during updates, you must create a schedule instead of a job


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

# Update defined group firmware using defined SPP
## Creation of the payload
$body = @"
  {
    "jobTemplateUri": "$jobTemplateUri",
    "resourceUri": "$groupUri",
    "data": {
      "bundle_id": "$bundleid",
      "devices": 
        $devicesformatted
    }
  }
"@ 

## Creation of the request
$headers["Content-Type"] = "application/json"


try {
  $response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$jobs_API_version/jobs" -Method POST -Headers $headers -Body $body -ErrorAction Stop
  
}
catch {
  write-warning "Error, group $groupname upgrade failure !"
  break
}

$joburi = ($response.Content | ConvertFrom-Json).resourceUri

#endregion


clear-host


#region Display firmware update activity status
#-----------------------------------------------------------Display activities in console-----------------------------------------------------------------------------

## Wait for the task to start or fail
do {
  $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
  Start-Sleep 5
} until ($status.state -eq "RUNNING" -or $status.state -eq "error")

## Wait for the task to complete
if ($status.state -eq "error") {
  "Group firmware update failed! {0}" -f $status.status
}
else {
  
  # FW update job status 
  $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
  $updatetime = [datetime]$status.updatedAt

  "`nJob state: `t{0}`nJob status: `t{1}`n" -f $status.state, $status.status

  # FW update activity status for each device
  $i = 1

  foreach ($deviceid in $deviceids) {
    
    $FWupgradestatus = (((Invoke-webrequest "$ConnectivityEndpoint/api/compute/v1/activities?count=20&sort=createdAt:desc" -Method GET -Headers $headers).content | convertfrom-json).items | ? associatedServerId -eq $deviceid) 
    
    if ( $FWupgradestatus) { 
      
      $deviceFWupgradestatus = [datetime](($FWupgradestatus | ? key -eq "SERVER_JOB_FW_UPDATE_IN_PROGRESS")[0].updatedAt)
    
      set-variable FWupgradestatusupdatedAt_${i} -value $deviceFWupgradestatus
    }
    # "Time: {0}" -f (get-variable FWupgradestatusupdatedAt_${i} -ValueOnly)
    # Creates variables: $FWupgradestatusupdatedAt_1, FWupgradestatusupdatedAt_2, etc.
    $i += 1
  }

  do {   

    $status = (Invoke-webrequest "$ConnectivityEndpoint$joburi" -Method GET -Headers $headers).content | ConvertFrom-Json
    
    # "`nInitial Update Time: `t`t`t{0}" -f [datetime]$updatetime
    # "Job Update Time: `t`t`t{0}" -f [datetime]$status.updatedAt

    if ( [datetime]$status.updatedAt -gt $updatetime -and [datetime]$status.updatedAt -ne $updatetime ) {
      $updatetime = [datetime]$status.updatedAt
      "`nJob state: `t{0}`nJob status: `t{1} " -f $status.state, $status.status
    }    

    $i = 1

    foreach ($deviceid in $deviceids) {
   
      $FWupgradestatus = (((Invoke-webrequest "$ConnectivityEndpoint/api/compute/v1/activities?count=20&sort=createdAt:desc" -Method GET -Headers $headers).content | convertfrom-json).items | ? associatedServerId -eq $deviceid) 
      $server = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$servers_API_version/servers/$deviceid" -Method GET -Headers $headers).content | ConvertFrom-Json)
  
      if ( $FWupgradestatus[0].key -match "SERVER_JOB_FW_UPDATE_IN_PROGRESS" -and [datetime]$FWupgradestatus[0].updatedAt -gt $(get-variable FWupgradestatusupdatedAt_$i -ValueOnly) ) {
        
        set-variable FWupgradestatusupdatedAt_${i} -value ([datetime]$FWupgradestatus[0].updatedAt)
        
        if ($FWupgradestatus[0].message.Split("`r`n").count -gt 1) {
          "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nNote:`t`t{3}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message.split("`n")[0], $FWupgradestatus[0].message.split("`n")[2].substring(10)
        }
        else {
          "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message
        }
      }

      # "`nInitial Update Time for device {0} : `t{1}" -f $i, $(get-variable FWupgradestatusupdatedAt_$i -ValueOnly)
      # "Job Update Time for device {0} : `t`t{1}" -f $i, [datetime]$FWupgradestatus[0].updatedAt
          
      $i += 1
    }

    sleep 5

  } until ( $status.state -eq "Error" -or $status.state -eq "complete") 

  # Display Server firmware update status 
  
  foreach ($deviceid in $deviceids) {

    $FWupgradestatus = (((Invoke-webrequest "$ConnectivityEndpoint/api/compute/v1/activities?count=20&sort=createdAt:desc" -Method GET -Headers $headers).content | convertfrom-json).items | ? associatedServerId -eq $deviceid) 
    $server = ((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$servers_API_version/servers/$deviceid" -Method GET -Headers $headers).content | ConvertFrom-Json)
    
    if ( $FWupgradestatus[0].key -match "SERVER_JOB_FW_UPDATE_COMPLETED") {

      if ($FWupgradestatus[0].message.Split("`r`n").count -gt 1) {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nNote:`t`t{3}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message.split("`n")[0], $FWupgradestatus[0].message.split("`n")[2].substring(10)
      }
      else {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message
      }
    }

    if ( $FWupgradestatus[0].key -match "SERVER_JOB_FW_UPDATE_FAILED") {

      if ($FWupgradestatus[0].message.Split("`r`n").count -gt 1 -and $FWupgradestatus[0].recommendedAction) {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nRecommendation: {3}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message.split("`n")[0], $FWupgradestatus[0].recommendedAction
      }
      elseif ($FWupgradestatus[0].message.Split("`r`n").count -gt 1 -and -not $FWupgradestatus[0].recommendedAction) {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message.split("`n")[0]
      }
      elseif ($FWupgradestatus[0].message.Split("`r`n").count -eq 1 -and $FWupgradestatus[0].recommendedAction) {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nRecommendation: {3}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message, $FWupgradestatus[0].recommendedAction
      }
      elseif ($FWupgradestatus[0].message.Split("`r`n").count -eq 1 -and -not $FWupgradestatus[0].recommendedAction) {
        "`nServer: `t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $server.name, [datetime]$FWupgradestatus[0].updatedAt, $FWupgradestatus[0].message
      }
    }
  }

  # Display Group firmware update status 

  $GroupFWupgradestatus = ((((Invoke-webrequest "$ConnectivityEndpoint/api/compute/v1/activities?count=20&sort=createdAt:desc" -Method GET -Headers $headers).content | convertfrom-json).items) | ? groupDisplayName -eq $GroupName)

  if ( $GroupFWupgradestatus[0].key -match "GROUP_JOB_FW_UPDATE_COMPLETED") {

    if ($GroupFWupgradestatus[0].message.Split("`r`n").count -gt 1) {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nNote:`t`t{3}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message.split("`n")[0], $GroupFWupgradestatus[0].message.split("`n")[2].substring(10)
    }
    else {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message
    }
  }

  if ( $GroupFWupgradestatus[0].key -match "GROUP_JOB_FW_UPDATE_FAILED") {

    if ($GroupFWupgradestatus[0].message.Split("`r`n").count -gt 1 -and $GroupFWupgradestatus[0].recommendedAction) {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nRecommendation: {3}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message.split("`n")[0], $GroupFWupgradestatus[0].recommendedAction
    }
    elseif ($GroupFWupgradestatus[0].message.Split("`r`n").count -gt 1 -and -not $GroupFWupgradestatus[0].recommendedAction) {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message.split("`n")[0]
    }
    elseif ($GroupFWupgradestatus[0].message.Split("`r`n").count -eq 1 -and $GroupFWupgradestatus[0].recommendedAction) {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`nRecommendation: {3}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message, $GroupFWupgradestatus[0].recommendedAction
    }
    elseif ($GroupFWupgradestatus[0].message.Split("`r`n").count -eq 1 -and -not $GroupFWupgradestatus[0].recommendedAction) {
      "`nGroup: `t`t{0} `nDate: `t`t{1}`nStatus:`t`t{2}`n" -f $GroupName, [datetime]$GroupFWupgradestatus[0].updatedAt, $GroupFWupgradestatus[0].message
    }
  }


}
#endregion
