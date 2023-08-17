<#
PowerShell script to generate a Compute Ops Management carbon emissions report for Telegraf/influxdb with Exec input plugin.

The script generates a COM carbon footprint report based on the power consumption of all servers and then returns the sum of the carbon emissions of all servers (in kgCO2e).

Two measurements are available, TotalEmissionsPerWeek and TotalEmissionsPerDay.

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

Telegraf configuration (/etc/telegraf/telegraf.conf):

[[outputs.influxdb]]
  ## HTTP Basic Auth
   username = "telegraf"
   password = "xxxxxxxxxxxxxxx"

[[inputs.exec]]
  commands = ["pwsh /scripts/COM-telegraf-Carbon-Footprint-collector.ps1"] 
  interval = "24h" 
  timeout = "500s"
  data_format = "influx"


Note: This script uses the Compute Ops Management API, so the API client credentials in the HPE GreenLake Cloud Platform must be configured first.

To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 

Information about the HPE GreenLake for Compute Ops Management API can be found at:
https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/

Requirements: 
- Compute Ops Management API Client Credentials with appropriate roles, this includes:
   - A Client ID
   - A Client Secret
   - A Connectivity Endpoint


Author: lionel.jullien@hpe.com
Date:   August 2023
#>

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



# API Client Credentials
ClientID = "5aaf115d-c5c4-4753-ba3c-cb5741c5a125"
ClientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# The connectivity endpoint can be found in the GreenLake platform / API client information
$ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"


# InfluxDB 
$measurement = "COM_Carbon_Report"


#----------------------------------------------------------Retrieve COM resource API versions-------------------------------------------------------------------------
#region Retrieve resource API versions

#######################################################################################################################################################################################################
# Create variables to get the API version of COM resources using the API reference.
#   Generate a variable for each API resource ($servers_API_version, $jobs_API_version, etc.) 
#   Set each variable value with the resource API version ($servers_API_version = v1beta2, $filters_API_version = v1beta1, etc.)
#   $API_resources_variables contains the list of all variables that have been defined
#######################################################################################################################################################################################################

$response = Invoke-RestMethod -Uri "https://developer.greenlake.hpe.com/_auth/sidebar/__alternative-sidebar__-data-hpe-hcss-doc-portal-docs-greenlake-services-compute-ops-sidebars.yaml" -Method GET
$items = ($response.items | ? label -eq "API reference").items

$items = ($items | ? items -ne $Null | Sort-Object -Property label -Descending)

$API_resources_variables = @()

"COM API resources variables:" | Write-Verbose

for ($i = 0; $i -lt ($items.Count); $i++) {
  
  $APIversion = $items[$i].label.Substring($items[$i].label.length - 7)
#   $APIversion
  $APIresource = $items[$i].label.Substring(0, $items[$i].label.length - 10).replace('-', '_')
#   $APIresource

  if (-not (Get-Variable -Name ${APIresource}_API_version -ErrorAction SilentlyContinue)) {
    New-Variable -name ${APIresource}_API_version -Value $APIversion
    $variablename = "$" + (get-variable ${APIresource}_API_version).name
    $API_resources_variables += ($variablename)

    "`t{0} = {1}" -f $variablename, $APIversion | Write-verbose

  } 
}

#######################################################################################################################################################################################################
#endregion

#----------------------------------------------------------Connection to Compute Ops Management ----------------------------------------------------------------------
#region COM authentication

# Headers creation
$headers = @{} 
$headers["Content-Type"] = "application/x-www-form-urlencoded"

# Payload creation
$body = "grant_type=client_credentials&client_id=" + $ClientID + "&client_secret=" + $ClientSecret


try {
  $response = Invoke-RestMethod "https://sso.common.cloud.hpe.com/as/token.oauth2" -Method POST -Headers $headers -Body $body
}
catch {
  write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
}


# Capturing API Access Token
$AccessToken = $response.access_token

# Headers creation
$headers = @{} 
$headers["Authorization"] = "Bearer $AccessToken"

#endregion




# --------------------------------------------------Collect data-----------------------------------------------------------------------------

# Retrieve job template id of DataRoundupReportOrchestrator

try {
    $jobtemplates = Invoke-RestMethod "$ConnectivityEndpoint/compute-ops/$servers_API_version/job-templates" -Method GET -Headers $headers

}
catch {
  write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
}



$jobtemplateId = $jobtemplates.items  | ? name -eq 'DataRoundupReportOrchestrator' | % id

if (! $jobtemplateId) {
    Write-Error  "Error, job template 'DataRoundupReportOrchestrator' not found!"
    return
}


# Retrieve 'all servers' filter

try {
    $filters = Invoke-RestMethod "$ConnectivityEndpoint/compute-ops/$filters_API_version/filters" -Method GET -Headers $headers

}
catch {
  write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
}

$allfilterUri = $filters.items  | ? name -eq 'All Servers' | % resourceUri

if (! $allfilterUri) {
    Write-Error  "Error, filter 'All Servers' not found!"
    return
}


# --------------------------------------------------Create a Carbon Footprint Report for all servers-----------------------------------------------------------------------------

# Run Carbon footprint report

# Creation of the payload
$jobTemplateUri = "/api/compute/v1/job-templates/" + $jobtemplateId

$body = @{}
$body['jobTemplateUri'] = $jobTemplateUri
$body['resourceUri'] = $allfilterUri

$data = @{}
$data['reportType'] = "CARBON_FOOTPRINT"


$body['data'] = $data

$body = $body | ConvertTo-Json


# Creation of the request
# headers["Content-Type"] = "application/json"

$url = $ConnectivityEndpoint + '/api/compute/v1/jobs'

try {
    $response = Invoke-RestMethod $url -Method POST -Body $Body -ContentType "application/json" -Headers $headers
    $jobUri = $response.resourceUri
    $jobId = $response.id

}
catch {
  write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
}


# --------------------------------------------------Wait for the Carbon Footprint Report to complete-------------------------------------------------

# Wait for the task to complete

sleep 5

$url = $ConnectivityEndpoint + $jobUri

try {
    $status = Invoke-RestMethod $url -Method GET -Headers $headers

}
catch {
  write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
}

if ($status.state -eq "error") {
    "Carbon footprint report creation failure! Status: {0}" -f $status.status
    return
}
else {

    do {

    $status = Invoke-RestMethod $url -Method GET -Headers $headers

    sleep 5
        
    } while ($status.state -eq "Running" )
    
    if ($status.status -eq "Complete") {

        $url= $ConnectivityEndpoint + "/compute-ops/" + $activities_API_version + "/activities?filter=contains(source/resourceUri,'" + $jobId + "')&limit=1"

        try {
            $activitystatus = Invoke-RestMethod $url -Method GET -Headers $headers
        
        }
        catch {
          write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
        }

        $activitystatus.items.message | write-verbose


        $url= $ConnectivityEndpoint + $jobUri

        try {
            $reportUri = (Invoke-RestMethod $url -Method GET -Headers $headers).results.location
        
        }
        catch {
          write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
        }



    }
}


# --------------------------------------------------Output All servers Carbon Emissions (kgCO2e)-----------------------------------------------------
       
$url=$ConnectivityEndpoint + $reportUri + "/data"

try {
    $reportData = Invoke-RestMethod $url -Method GET -Headers $headers

}
catch {
  write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
}

foreach ($serie in $reportData.series ) {

    if ($serie.subject.type -eq 'TOTAL') {
        
        $TotalEmissionsPerDay = [Math]::Round($serie.buckets[0].value, 2)        
      
        "{0} TotalEmissionsPerDay={1}" -f $measurement, $TotalEmissionsPerDay

        # output: COM_Carbon_Report TotalEmissionsPerDay=109.0

        $TotalEmissionsPerWeek = [Math]::Round($serie.summary.sum, 2)

        "{0} TotalEmissionsPerWeek={1}" -f $measurement, $TotalEmissionsPerWeek

        # output: COM_Carbon_Report TotalEmissionsPerWeek=707.0
    }

}