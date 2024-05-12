<#
PowerShell script to be run periodically by Telegraf/Exec for collecting sustainability data from HPE Compute Ops Management. 

First, the script generates an HPE Compute Ops Management sustainability report to collect the metrics data from the cloud platform. 
The script then converts this data into InfluxDB Line Protocol format, which is used by Telegraf to ingest the data into InfluxDB. 
Grafana can then utilizes the data in InfluxDB to create rich, interactive dashboards for visualizing the HPE Compute Ops Management metrics data.

Today, HPE COM provides for each server, as well as for all servers the following metrics data:
  - The carbon emissions (in kgCO2e)
  - The energy consumption (in kWh) 
  - The energy cost (in USD)
  
For each of these, two measurements are available, one for the total value per week and one for the total value per day.

Telegraf configuration (/etc/telegraf/HPE_COM.conf):

[[outputs.influxdb]]
  database = "telegraf"
  ## HTTP Basic Auth
  username = "telegraf"
  password = "xxxxxxxxxxxxxxx"

[[inputs.exec]]
  commands = ["pwsh <path>/COM-telegraf-Sustainability-collector.ps1"] 
  interval = "24h" 
  timeout = "500s"
  data_format = "influx"


Note: This script uses the HPE Compute Ops Management API, so the API client credentials on the HPE GreenLake cloud platform must be configured first.

To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 

Information about the HPE GreenLake for Compute Ops Management API can be found at:
https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/

Requirements: 
- Compute Ops Management API Client Credentials with appropriate roles, this includes:
   - A Client ID
   - A Client Secret
   - A Connectivity Endpoint

Example of output generated by the script:

    COM_Sustainability_Total_Report TotalCarbonEmissionsPerDay=145.89
    COM_Sustainability_Total_Report TotalCarbonEmissionsPerWeek=870.66
    COM_Sustainability_Total_Report TotalEnergyConsumptionPerDay=330.62
    COM_Sustainability_Total_Report TotalEnergyConsumptionPerWeek=1973.1
    COM_Sustainability_Total_Report TotalEnergyCostPerDay=52.9
    COM_Sustainability_Total_Report TotalEnergyCostPerWeek=315.7
    COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyConsumptionPerWeek=3.19
    COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyConsumptionPerDay=3.19
    COM_Sustainability_Individual_Report 2M282501KR_TotalCarbonEmissionsPerWeek=1.41
    COM_Sustainability_Individual_Report 2M282501KR_TotalCarbonEmissionsPerDay=1.41
    COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyCostPerWeek=0.51
    COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyCostPerDay=0.51
    COM_Sustainability_Individual_Report 2M293800KC_TotalCarbonEmissionsPerWeek=2.3
    COM_Sustainability_Individual_Report 2M293800KC_TotalCarbonEmissionsPerDay=0.41
    COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyConsumptionPerWeek=5.21
    COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyConsumptionPerDay=0.92
    COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyCostPerWeek=0.83
    COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyCostPerDay=0.15
    COM_Sustainability_Individual_Report 2M2946009Z_TotalCarbonEmissionsPerWeek=0.4
    COM_Sustainability_Individual_Report 2M2946009Z_TotalCarbonEmissionsPerDay=0.4
    COM_Sustainability_Individual_Report 2M2946009Z_TotalEnergyConsumptionPerWeek=0.9
    COM_Sustainability_Individual_Report 2M2946009Z_TotalEnergyConsumptionPerDay=0.9
    COM_Sustainability_Individual_Report 2M2946009Z_TotalEnergyCostPerWeek=0.14
    COM_Sustainability_Individual_Report 2M2946009Z_TotalEnergyCostPerDay=0.14

Author: lionel.jullien@hpe.com
Date:   October 2023

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

# HPE COM API Client Credentials
$ClientID = "5aaf115d-c5c4-4753-ba3c-cb5741c5a125"
$ClientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# The connectivity endpoint can be found in the GreenLake platform / API client information
$ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"

# InfluxDB measurements
$Total_measurement = "COM_Sustainability_Total_Report"
$Individual_measurement = "COM_Sustainability_Individual_Report"


#Region---------------------------------------------------Retrieve COM resource API versions-----------------------------------------------------------------------------------------

#######################################################################################################################################################################################################
#   Create variables to get the API version of COM resources using the API reference.
#   Generate a variable for each API resource ($servers_API_version, $jobs_API_version, etc.) 
#   Set each variable value with the resource API version ($servers_API_version = v1beta2, $filters_API_version = v1beta1, etc.)
#   $API_resources_variables contains the list of all variables that have been defined
#######################################################################################################################################################################################################

do {
    $response = Invoke-RestMethod -Uri "https://developer.greenlake.hpe.com/_auth/sidebar/__alternative-sidebar__-data-glcp-doc-portal-docs-greenlake-services-compute-ops-mgmt-sidebars.yaml" -Method GET
    Start-Sleep 2
}     
until ( $response.items )

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

#Region---------------------------------------------------Connection to Compute Ops Management---------------------------------------------------------------------------------------


# Headers creation
$headers = @{} 
$headers["Content-Type"] = "application/x-www-form-urlencoded"

# Payload creation
$body = "grant_type=client_credentials&client_id=" + $ClientID + "&client_secret=" + $ClientSecret

do {
    try {
        $response = Invoke-RestMethod "https://sso.common.cloud.hpe.com/as/token.oauth2" -Method POST -Headers $headers -Body $body
    }
    catch {
        write-host "Authentication error !" $error[0].Exception.Message -ForegroundColor Red
        return
    }
} until ($response.access_token)


# Capturing API Access Token
$AccessToken = $response.access_token

# Headers creation
$headers = @{} 
$headers["Authorization"] = "Bearer $AccessToken"

#endregion

#Region --------------------------------------------------Collect data---------------------------------------------------------------------------------------------------------------

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

#endRegion

#Region --------------------------------------------------Create a Sustainability Report for all servers-----------------------------------------------------------------------------

# Run Sustainability report

# Creation of the payload
$jobTemplateUri = "/api/compute/v1/job-templates/" + $jobtemplateId

$body = @{}
$body['jobTemplateUri'] = $jobTemplateUri
$body['resourceUri'] = $allfilterUri

$data = @{}
$data['reportType'] = "CARBON_FOOTPRINT"
$body['data'] = $data

$body = $body | ConvertTo-Json


$url = $ConnectivityEndpoint + '/api/compute/v1/jobs'

try {
    $response = Invoke-RestMethod $url -Method POST -Body $Body -ContentType "application/json" -Headers $headers
    $jobUri = $response.resourceUri
    $jobId = $response.id

}
catch {
    write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
}

#endRegion

#Region --------------------------------------------------Wait for the Sustainability Report to complete-----------------------------------------------------------------------------

# Wait for the task to complete

Start-Sleep 5

$url = $ConnectivityEndpoint + $jobUri

do {

    try {
        $status = Invoke-RestMethod $url -Method GET -Headers $headers
        Start-Sleep 5
  
    }
    catch {
        write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
    }
    
} until (  $status.state -eq "Complete" -or $status.state -eq "error" )

$reportUri = $status.results.location
$reportId = $reportUri.Substring($reportUri.Length - 36)


if ($status.state -eq "error") {
    "Sustainability report creation failure! Status: {0}" -f $status.status
    return
}

#endRegion

#Region --------------------------------------------------Capture Co2 emissions / energy consumption / energy cost for all + individual server---------------------------------------
      
$url = $ConnectivityEndpoint + "/ui-doorway/compute/v2/reports/" + $reportId + "/data"

try {
    $reportData = Invoke-RestMethod $url -Method GET -Headers $headers

}
catch {
    write-host "Error !" $error[0].Exception.Message -ForegroundColor Red
}

#endRegion

#Region --------------------------------------------------Output All servers Carbon Emissions (kgCO2e)-------------------------------------------------------------------------------

foreach ($serie in $reportData.data.series) {

    if ($serie.name -eq "Carbon Emissions" -AND $serie.subject.type -eq 'TOTAL' ) {
        
        $TotalCarbonEmissionsPerDay = [Math]::Round($serie.buckets[0].value, 2)        
      
        "{0} TotalCarbonEmissionsPerDay={1}" -f $Total_measurement, $TotalCarbonEmissionsPerDay

        # output: COM_Carbon_Report TotalEmissionsPerDay=109.0

        $TotalCarbonEmissionsPerWeek = [Math]::Round($serie.summary.sum, 2)

        "{0} TotalCarbonEmissionsPerWeek={1}" -f $Total_measurement, $TotalCarbonEmissionsPerWeek

        # Output: 
        # COM_Sustainability_Total_Report TotalCarbonEmissionsPerDay=145.89
        # COM_Sustainability_Total_Report TotalCarbonEmissionsPerWeek=870.66

    }

    # --------------------------------------------------Output All servers Energy Consumption (kWh)-----------------------------------------------------

    if ($serie.name -eq "Energy Consumption" -AND $serie.subject.type -eq 'TOTAL' ) {
        
        $TotalEnergyConsumptionPerDay = [Math]::Round($serie.buckets[0].value, 2)        
      
        "{0} TotalEnergyConsumptionPerDay={1}" -f $Total_measurement, $TotalEnergyConsumptionPerDay

        # output: COM_Carbon_Report TotalEmissionsPerDay=109.0

        $TotalEnergyConsumptionPerWeek = [Math]::Round($serie.summary.sum, 2)

        "{0} TotalEnergyConsumptionPerWeek={1}" -f $Total_measurement, $TotalEnergyConsumptionPerWeek

        # Output: 
        # COM_Sustainability_Total_Report TotalEnergyConsumptionPerDay=330.62
        # COM_Sustainability_Total_Report TotalEnergyConsumptionPerWeek=1973.1
    }

    # --------------------------------------------------Output All servers Energy Cost (USD)-----------------------------------------------------

  
    if ($serie.name -eq "Energy Cost" -AND $serie.subject.type -eq 'TOTAL' ) {
        
        $TotalEnergyCostPerDay = [Math]::Round($serie.buckets[0].value, 2)        
      
        "{0} TotalEnergyCostPerDay={1}" -f $Total_measurement, $TotalEnergyCostPerDay

        # output: COM_Carbon_Report TotalEmissionsPerDay=109.0

        $TotalEnergyCostPerWeek = [Math]::Round($serie.summary.sum, 2)

        "{0} TotalEnergyCostPerWeek={1}" -f $Total_measurement, $TotalEnergyCostPerWeek

        # Output: 
        # COM_Sustainability_Total_Report TotalEnergyCostPerDay=52.9
        # COM_Sustainability_Total_Report TotalEnergyCostPerWeek=315.7
    }
}

# --------------------------------------------------Output each servers-----------------------------------------------------

foreach ($serie in ($reportData.data.series | Sort-Object { $_.subject.displayName } )) {

    if ($serie.subject.type -eq 'SERVER' ) {

        $telemetry = $serie.name.Replace(" ", "")
           
        if ($serie.subject.displayName) {
            $ServerName = $serie.subject.displayName
        }
        else {
            $ServerName = $serie.subject.id
        }
    
        $totalPerWeek = [Math]::Round($serie.summary.sum, 2)    

        $field = $ServerName + "_Total" + $telemetry + "PerWeek"

        "{0} {1}={2}" -f $Individual_measurement, $field , $totalPerWeek

        $totalPerDay = [Math]::Round($serie.buckets[0].value, 2)    

        $field = $ServerName + "_Total" + $telemetry + "PerDay"
          
        "{0} {1}={2}" -f $Individual_measurement, $field , $totalPerDay
    

        # Output: 
        # COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyConsumptionPerWeek=3.19
        # COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyConsumptionPerDay=3.19
        # COM_Sustainability_Individual_Report 2M282501KR_TotalCarbonEmissionsPerWeek=1.41
        # COM_Sustainability_Individual_Report 2M282501KR_TotalCarbonEmissionsPerDay=1.41
        # COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyCostPerWeek=0.51
        # COM_Sustainability_Individual_Report 2M282501KR_TotalEnergyCostPerDay=0.51
        # COM_Sustainability_Individual_Report 2M293800KC_TotalCarbonEmissionsPerWeek=2.3
        # COM_Sustainability_Individual_Report 2M293800KC_TotalCarbonEmissionsPerDay=0.41
        # COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyConsumptionPerWeek=5.21
        # COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyConsumptionPerDay=0.92
        # COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyCostPerWeek=0.83
        # COM_Sustainability_Individual_Report 2M293800KC_TotalEnergyCostPerDay=0.15
    }

}

#endRegion
