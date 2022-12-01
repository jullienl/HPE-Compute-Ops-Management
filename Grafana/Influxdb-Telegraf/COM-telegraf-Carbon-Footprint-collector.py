"""
Python script to generate a Compute Ops Management carbon emissions report for Telegraf/influxdb with Exec input plugin.

The script generates a COM carbon footprint report based on the power consumption of all servers and then returns the sum of the carbon emissions of all servers (in kgCO2e).

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

Telegraf configuration (/etc/telegraf/telegraf.conf):

[[outputs.influxdb]]
  ## HTTP Basic Auth
   username = "telegraf"
   password = "xxxxxxxxxxxxxxx"

[[inputs.exec]]
  commands = ["/bin/python3 /tmp/COM-telegraf-Carbon-Footprint-collector.py"]
  interval = "24h" 
  timeout = "500s"
  data_format = "influx"


Note: This script uses the Compute Ops Management API, so the API client credentials in the HPE GreenLake Cloud Platform must be configured first.

To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 

Information about the HPE Greenlake for Compute Ops Management API can be found at:
https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops/public/openapi/compute-ops-latest/overview/

Requirements: 
- Compute Ops Management API Client Credentials with appropriate roles, this includes:
   - A Client ID
   - A Client Secret
   - A Connectivity Endpoint


Author: lionel.jullien@hpe.com
Date:   November 2022
"""

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

# MODULES TO INSTALL
import requests
import json
import warnings
from time import sleep
from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session


# API Client Credentials
ClientID = "5aaf115d-c5c4-4753-ba3c-cb5741c5a125"
ClientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# The connectivity endpoint can be found in the GreenLake platform / API client information
ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"
APIversion = "v1beta2"


# ClientSecret = getpass.getpass(prompt='Enter your HPE GreenLake Client Secret: ')

client = BackendApplicationClient(ClientID)

oauth = OAuth2Session(client=client)
auth = requests.auth.HTTPBasicAuth(ClientID, ClientSecret)


token = oauth.fetch_token(
    token_url='https://sso.common.cloud.hpe.com/as/token.oauth2', auth=auth)
AccessToken = token["access_token"]

headers = {"Authorization": "Bearer " + AccessToken}

# --------------------------------------------------Collect data-----------------------------------------------------------------------------

# Retrieve job template id of DataRoundupReportOrchestrator
jobtemplates = requests.get(url=ConnectivityEndpoint + '/compute-ops/' +
                            APIversion + '/job-templates', headers=headers).json()

jobtemplateId = [jt for jt in jobtemplates['items'] if jt['name']
                 == 'DataRoundupReportOrchestrator'][0]['id']

if jobtemplateId is None:
    warnings.warn(
        "Error, job template 'DataRoundupReportOrchestrator' not found!")
    exit()


# Retrieve 'all servers' filter
filters = requests.get(url=ConnectivityEndpoint + '/compute-ops/' +
                       'v1beta1' + '/filters', headers=headers).json()
allfilterUri = [fi for fi in filters['items']
                if fi['name'] == 'All Servers'][0]['resourceUri']

if allfilterUri is None:
    warnings.warn("Error, filter 'All Servers' not found!")
    exit()

# --------------------------------------------------Create a Carbon Footprint Report for all servers-----------------------------------------------------------------------------

# Run Carbon footprint report

# Creation of the payload
jobTemplateUri = "/api/compute/v1/job-templates/" + jobtemplateId

body = json.dumps({
    "jobTemplateUri": jobTemplateUri,
    "resourceUri": allfilterUri,
    "data": {
        "reportType": "CARBON_FOOTPRINT"
    }
})

# Creation of the request
headers["Content-Type"] = "application/json"

url = ConnectivityEndpoint + '/api/compute/v1/jobs'

response = requests.request("POST", url, headers=headers, data=body)
jobUri = response.json()['resourceUri']
jobId = response.json()['id']

# --------------------------------------------------Wait for the Carbon Footprint Report to complete-------------------------------------------------

# Wait for the task to complete
status = requests.request(
    "GET", url=ConnectivityEndpoint + jobUri, headers=headers).json()

if status['state'] == "error":
    print(f"Carbon footprint report creation failure! {status['status']}")
else:
    status = requests.request(
        "GET", url=ConnectivityEndpoint + jobUri, headers=headers).json()
    while status['state'] == "Running":
        sleep(5)
        status = requests.request(
            "GET", url=ConnectivityEndpoint + jobUri, headers=headers).json()
        if status['state'] == "Complete":
            activitystatus = requests.request("GET", url=ConnectivityEndpoint + "/compute-ops/" + APIversion +
                                              "/activities?filter=contains(source/resourceUri,'" + jobId + "')&limit=1", headers=headers).json()
            reportUri = requests.request(
                "GET", url=ConnectivityEndpoint + jobUri, headers=headers).json()['results']['location']
            # print(f"{activitystatus['items'][0]['message']}")
            break

# --------------------------------------------------Output All servers Carbon Emissions (kgCO2e)-----------------------------------------------------
        
reportData = requests.request(
    "GET", url=ConnectivityEndpoint + reportUri + "/data", headers=headers).json()

for x in reportData['series']:
    if x['subject']['type'] == 'TOTAL':
        Co2Emmissions = round(x['summary']['sum'], 2)

        print("Carbon_Report,name=Total emissions={0}" .format(
            Co2Emmissions))
        # output: Carbon_Report,name=Total emissions=707.0

        break
