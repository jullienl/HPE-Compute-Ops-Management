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
# Start schedule on Sept 1, 2022 at 2am
[datetime]$StartSchedule = "09-01-2022 2:00:00"


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
$ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 


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


#region Schedule-Firmware-update
#-----------------------------------------------------------Modify the server group to set the defined baseline-----------------------------------------------------------------------------


# Retrieve firmware bundle id of the defined baseline
$firmwarebundleID = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/firmware-bundles" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? releaseVersion -eq $baseline).id
  
if (-not   $firmwarebundleID ) {
  write-warning "Error, firmware bundle '$baseline' not found!"
  break
}

# Retrieve group id of the defined group name
$Groupid = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/groups" -Method GET -Headers $headers).Content | ConvertFrom-Json).groups | ? name -eq $GroupName).id

if (-not $GroupID) {
  write-warning "Error, group name '$groupname' not found!"
  break
}

$body = @"
  {
    "firmwareBaseline": "$firmwarebundleID"
  }
"@ 

$headers["Content-Type"] = "application/merge-patch+json"
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/groups/$Groupid" -Method PATCH -Headers $headers -Body $body
"Group '{0}' modification to use SPP '{1}' - Status: {2}" -f $groupname, $baseline, $response.StatusDescription

#endregion


#region Schedule-Firmware-update
#-----------------------------------------------------------Schedule a firmware update-----------------------------------------------------------------------------

# Create a schedule to perform a firmware update
# This schedule will update all servers in the defined group with defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To perform an immediate update, you must create a job instead of a schedule

$startAt = get-date $StartSchedule  -Format o

#Schedule interval
$interval = "null" # Can be P7D for 7 days intervals, P15m, P1M, P1Y

$Jobtemplateid = (((Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/job-templates" -Method GET -Headers $headers).Content | ConvertFrom-Json).items | ? name -eq "GroupFirmwareUpdate").id

if (-not  $Jobtemplateid) {
  write-warning "Error, job template 'GroupFirmwareUpdate' not found !"
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
                          "resourceUri": "/api/compute/v1/groups/$Groupid",
                          "jobTemplateUri": "/api/compute/v1/job-templates/$Jobtemplateid",
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
$response = Invoke-webrequest "$ConnectivityEndpoint/compute-ops/$APIversion/schedules" -Method POST -Headers $headers -Body $body


"{0} - Status: {1} for {2}" -f (($response.Content | ConvertFrom-Json).name), $response.StatusDescription, [datetime]$StartSchedule


#endregion
