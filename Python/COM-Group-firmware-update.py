"""
This script performs a firmware update of a server group managed by HPE Compute Ops Management using a defined SPP baseline.

Warning: Any updates other than iLO FW require a server reboot!

Note: To set schedule options during updates, you must create a schedule instead of a job, see COM-Schedule-group-firmware-update.py

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

#-----------------------------------------------------------Start the firmware update-----------------------------------------------------------------------------

# Create a job to start a firmware update
## This job will update all servers in the defined group with the defined SPP
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To set schedule options during updates, you must create a schedule instead of a job

# Retrieve job template id of GroupFirmwareUpdate
jobtemplates = requests.get(url=ConnectivityEndpoint + '/compute-ops-mgmt/' + APIversion + '/job-templates', headers=headers).json() 
jobtemplateUri = [jt for jt in jobtemplates['items'] if jt['name'] == 'GroupFirmwareUpdate']['resourceUri']
if jobtemplateUri is None:
    warnings.warn("Error, job template 'GroupFirmwareUpdate' not found!")
    exit()

# Retrieve group uri of the defined group name
groups = requests.get(url=ConnectivityEndpoint + '/compute-ops-mgmt/' + APIversion + '/groups', headers=headers).json()
group = [group for group in groups['items'] if group['name'] == GroupName]
resourceUri = group['resourceUri']
if resourceUri is None:
    warnings.warn("Error, group name '" + GroupName + "' not found!")
    exit()

# Retrieve firmware bundle id of the defined baseline
bundles = requests.get(url=ConnectivityEndpoint + '/compute-ops-mgmt/' + APIversion + '/firmware-bundles', headers=headers).json()
bundleid = [fb for fb in bundles['items'] if fb['releaseVersion'] == Baseline][0]['id']
if bundleid is None:
    warnings.warn("Error, firmware bundle '" + Baseline + "' not found!")
    exit()

# The list of devices must be provided even if they are already part of the group!
deviceids = [ server[id] for server in group['devices']]

# Creation of the payload
body = {
    "jobTemplateUri": jobtemplateUri,
    "resourceUri": resourceUri,
    "data": {
      "bundle_id": bundleid,
      "devices": 
        deviceids
    }
  }

# Creation of the request
headers["Content-Type"] = "application/json"
response = requests.post(url=ConnectivityEndpoint + '/compute-ops-mgmt/' + APIversion + '/jobs', headers=headers, body=body) 
jobUri = response.json()['resourceUri']

## Wait for the task to start or fail
status = requests.get(url=ConnectivityEndpoint + jobUri, headers=headers)['Content']
while status['state'] != "running" and status != "error":
   sleep(5)
   status = requests.get(url=ConnectivityEndpoint + jobUri, headers=headers)['Content']

## Wait for the task to complete
if status['state'] == "error" :
  print(f"Group firmware update failed! {status['status']}")

else :
  status = requests.get(url=ConnectivityEndpoint + jobUri, headers=headers)['Content']
  while status['state'] != "complete" and status != "error":
    sleep(20)
    status = requests.get(url=ConnectivityEndpoint + jobUri, headers=headers)['Content']
    FWUpgradeStatus = requests.get(url=ConnectivityEndpoint + "/ui-doorway/compute/v1/servers/counts/state", headers=headers)['content']
    print(FWUpgradeStatus)

  ## Display status
  print(f"State: {status['state']} - Status: {status['status']}")

  # Get the update report for the servers in the group after the update is complete if lastFirmwareUpdate is defined 
  for deviceid in deviceids:
   server = requests.get(url=ConnectivityEndpoint + '/compute-ops-mgmt/' + APIversion + '/servers/' + deviceid, headers=headers)['content']
   if server['lastFirmwareUpdate'] is not None:
    print(f"Server: {server['name']} - Report status: {server['lastFirmwareUpdate']['status']}")
   else:
    print(f"Server: {server['name']} - State: Firmware update successful - No update was required")
    
