"""
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


Author: vincent.berger@hpe.com
Date:   September 2022
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
import getpass
import warnings
from time import sleep
from oauthlib.oauth2 import BackendApplicationClient       
from requests_oauthlib import OAuth2Session       

# Variables to perform the group firmware update 
GroupName = "Production-Group"
Baseline = "2022.03.0" 
## Start schedule on Sept 1, 2022 at 2am
startAt = "2022-10-01T02:00:00"

# API Client Credentials
#ClientID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ClientID = "a2acb3fd-5dd3-403f-b26f-4044c409f809"

# The connectivity endpoint can be found in the GreenLake platform / API client information
ConnectivityEndpoint = "https://us-west2-api.compute.cloud.hpe.com"
APIversion = "v1beta1"


ClientSecret = getpass.getpass(prompt='Enter your HPE GreenLake Client Secret: ')

client = BackendApplicationClient(ClientID)       
      
oauth = OAuth2Session(client=client)       
auth = requests.auth.HTTPBasicAuth(ClientID, ClientSecret)       

      
token = oauth.fetch_token(token_url='https://sso.common.cloud.hpe.com/as/token.oauth2', auth=auth)       
AccessToken = token["access_token"]

headers = {"Authorization": "Bearer " + AccessToken}

#-----------------------------------------------------------Modify the server group to set the defined baseline-----------------------------------------------------------------------------


# Retrieve firmware bundle id of the defined baseline
bundles = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles', headers=headers).json()
bundleid = [fb for fb in bundles['items'] if fb['releaseVersion'] == Baseline][0]['id']
if bundleid is None:
    warnings.warn("Error, firmware bundle '" + Baseline + "' not found!")
    exit()

# Retrieve group id of the defined group name
groups = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers).json()
group = [group for group in groups['items'] if group['name'] == GroupName]
groupid = group['id']
if groupid is None:
    warnings.warn("Error, group name '" + GroupName + "' not found!")
    exit()

body = {
    "firmwareBaseline": bundleid
  }

headers["Content-Type"] = "application/merge-patch+json"
response = requests.patch(url=ConnectivityEndpoint + "/compute-ops/" + APIversion + "/groups/" + groupid, headers=headers, body=body)
print(f"Group '{GroupName}' modification to use SPP '{Baseline}' - Status: {response['StatusDescription']}")


#-----------------------------------------------------------Schedule a firmware update-----------------------------------------------------------------------------

# Create a schedule to perform a firmware update
# This schedule will update all servers in the defined group with defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To perform an immediate update, you must create a job instead of a schedule
schedulename = "Firmware upgrade for group DL360Gen10plus-Production-Group"
description = "Upgrade to SPP 2022.03.0"
interval = "null" # Can be P7D for 7 days intervals, P15m, P1M, P1Y

jobtemplates = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/job-templates', headers=headers).json() 
jobTemplateid = [jt for jt in jobtemplates['items'] if jt['name'] == 'GroupFirmwareUpdate']['id']
if jobTemplateid is None:
    warnings.warn("Error, job template 'GroupFirmwareUpdate' not found!")
    exit()

groups = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers).json()
groupid = [group for group in groups['items'] if group['name'] == GroupName]['id']
bundles = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles', headers=headers).json()
bundleid = [fb for fb in bundles['items'] if fb['releaseVersion'] == '2022.03.0'][0]['id']
group = [group for group in groups['items'] if group['name'] == GroupName]
deviceids = [ server[id] for server in group['devices']]


body = {
    "name":  schedulename,
    "description":  description,
    "associatedResourceUri":  "/api/compute/v1/groups/" + groupid,
    "purpose":  "GROUP_FW_UPDATE",
    "schedule":  {
                     "interval": interval,
                     "startAt": startAt
                 },
    "operation":  {
                      "type":  "REST",
                      "method":  "POST",
                      "uri": "/api/compute/v1/jobs",
                      "body":  {
                        "resourceUri": "/api/compute/v1/groups/" + groupid,
                        "jobTemplateUri": "/api/compute/v1/job-templates/" + jobTemplateid,
                        "data": {
                          "devices": deviceids,
                          "parallel": "true",
                          "stopOnFailure": "false"
                        }
                      }                              
                  }
}

headers["Content-Type"] = "application/json"
response = requests.post(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules', headers=headers, body=body) 
scheduleid = response.json()['id']

# Get details about newly created schedule
print(requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules/' + scheduleid, headers=headers).json())
print(requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules/' + scheduleid, headers=headers).json()['operation']['body']['data'])
