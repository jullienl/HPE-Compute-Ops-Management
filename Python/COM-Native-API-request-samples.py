
""" 
This Python script shows how to connect to the HPE Compute Ops Management API and how to create requests. 

Important note: To use the Compute Ops Management API, you must configure the API client credentials in the HPE GreenLake Cloud Platform.

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
from time import sleep
from oauthlib.oauth2 import BackendApplicationClient       
from requests_oauthlib import OAuth2Session       

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

#-------------------------------------------------------SERVERS requests samples--------------------------------------------------------------------------------


# Obtain the list of servers in your account
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers', headers=headers) 
ServersList = response.json()

print(f"{ServersList['count']} server(s) found")

if ServersList['count'] > 0 :
# Server items
   print(ServersList['items'][0]['name']) 
   print(ServersList['items'][0]['biosFamily']) 
   print(ServersList['items'][0]['displayName']) 
   print(ServersList['items'][0]['firmwareBundleUri']) 
   print(ServersList['items'][0]['generation']) 
   print(ServersList['items'][0]['lastFirmwareUpdate']) 
   print(ServersList['items'][0]['platformFamily']) 
   print(ServersList['items'][0]['processorVendor']) 
   print(ServersList['items'][0]['resourceType']) 
   print(ServersList['items'][0]['resourceUri']) 
   print(ServersList['items'][0]['selfUri']) 
   print(ServersList['items'][0]['tags']) 
   print(ServersList['items'][0]['updatedAt']) 

# Server items.hardware
   print(ServersList['items'][0]['hardware'])

## Serial Number
   print(ServersList['items'][0]['hardware']['serialNumber'])
## Model
   print(ServersList['items'][0]['hardware']['model'])
## Product ID
   print(ServersList['items'][0]['hardware']['productId'])
## Power State
   print(ServersList['items'][0]['hardware']['powerState'])
## Indicator LED
   print(ServersList['items'][0]['hardware']['indicatorLed'])
## iLO info
   print(ServersList['items'][0]['hardware']['bmc'])
## iLO IP
   iloIp = ServersList['items'][0]['hardware']['bmc']['ip']
   print(iloIp)


# Server health
   print(ServersList['items'][0]['hardware']['health'])


# Server state includes COM subscription information, COM managed / COM connected
   print(ServersList['items'][0]['state'])


# FW information with device name and versions
   print(ServersList['items'][0]['firmwareInventory'])


# Hostname / OS information
   print(ServersList['items'][0]['host'])

# Obtain the first 10 servers
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers?limit=10', headers=headers)
ServersList = response.json()


# List of servers from the 10th
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers?offset=9', headers=headers)
ServersList = response.json()

# Get a server by ID
serverId = [server for server in ServersList['items'] if server['name'] == 'HPE-HOL33'][0]['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers/' + serverId, headers=headers)
server = response.json()
print(server)

# List all alerts for a server
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers/' + serverId + '/alerts', headers=headers)
alerts = response.json()
print(alerts['items'])

# List all DL360 Gen10+ servers
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers', headers=headers) 
DL360Gen10Plus = [server for server in response.json()['items'] if server['hardware']['model'] == 'ProLiant DL360 Gen10 Plus']
print(DL360Gen10Plus)

#-------------------------------------------------------ACTIVITIES requests samples--------------------------------------------------------------------------------

# List all activities
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/activities', headers=headers) 
activities = response.json()
print(activities['items'])

# List last 10 server activities
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + "/activities?filter=source/type eq 'Server'&limit=10", headers=headers) 
activities = response.json()
print(activities['items'])
print(activities['count'])

# List last 10 firmware activities
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + "/activities?filter=source/type eq 'Firmware'&limit=10", headers=headers) 
firmware_activities = response.json()
print(firmware_activities['items'])
print(firmware_activities['count'])

# List required subscriptions activities
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + "/activities?filter=source/type eq 'Server' and contains(key,'SERVER_ASSIGNED')", headers=headers) 
subscription_activities = response.json()
print(subscription_activities['items'])
print(subscription_activities['count'])

#-------------------------------------------------------FIRMWARE-BUNDLES requests samples--------------------------------------------------------------------------------


# List all firmware bundles
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles', headers=headers) 
firmware_bundles = response.json()
print(firmware_bundles['items'])

# List a specific firmware bundle
firmwarebundleid = [fb for fb in firmware_bundles['items'] if fb['releaseVersion'] == '2022.03.0'][0]['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles/' + firmwarebundleid, headers=headers) 
firmware_bundle = response.json()
print(firmware_bundle)


#-------------------------------------------------------GROUPS requests samples--------------------------------------------------------------------------------

# List all groups
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers) 
groups = response.json()
print(groups['items'])


# List a group
groupid = [group for group in groups['items'] if group['name'] == 'Production']['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups/' + groupid, headers=headers) 
group = response.json()
print(group)


# Delete a group
#response = requests.delete(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups/' + groupid, headers=headers) 
print(response.json())


# Create a group
groupname = "Production-Group"
groupdescription = "My Production Group with DL360 Gen10 Plus servers"

body = {
    "name":  groupname,
    "description":  groupdescription,
    "firmwareBaseline": firmwarebundleid,
    "autoIloFwUpdateEnabled": "True",
    "autoFwUpdateOnAdd": "False",
    "deviceSettingsUris": [],
    "data": {},
    "tags": {
      "location": "Houston"
    }
  }

headers['Content-Type'] = "application/json"
#response = requests.post(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers, body=body) 
print (response.json())
newcreategroupid = response.json()['id']

# Add all DL360 Gen10 Plus to newly created group
devices = [ server[id] for server in DL360Gen10Plus]

body = {
    "devices":  devices
  }

response = requests.post(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups/' + newcreategroupid + "/devices", headers=headers, body=body)
print (response.json())

# Modify a group
newgroupname = "DL360Gen10plus-Production-Group"

body = {
    "name":  newgroupname
  }

headers['Content-Type'] = "application/merge-patch+json"
response = requests.patch(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups/' + newcreategroupid, headers=headers, body=body)
print (response.json())
headers.pop("Content-Type")

#-------------------------------------------------------JOB-TEMPLATES requests samples--------------------------------------------------------------------------------


# List all job templates
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/job-templates', headers=headers) 
jobtemplates = response.json()
print(jobtemplates['item'])


# Get a  job template
jobtemplateid = [jt for jt in jobtemplates['items'] if jt['name'] == 'GroupFirmwareUpdate']['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/job-templates/' + jobtemplateid, headers=headers) 
jobtemplate = response.json()
print(jobtemplate)


#-------------------------------------------------------JOBS requests samples--------------------------------------------------------------------------------

# List all jobs
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/jobs', headers=headers) 
jobs = response.json()
print(jobs['item'])


# Get a job
jobid = jobs['items'][0]['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/jobs/' + jobid, headers=headers) 
job = response.json()
print(job)

# Create a job to start a firmware update
## This job will update all servers in the group "DL360Gen10plus-Production-Group" with SPP 2022.03.0
## Warning: Any updates other than iLO FW require a server reboot!
## Note: To set schedule options during updates, you must create a schedule instead of a job
jobtemplates = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/job-templates', headers=headers).json() 
jobtemplateUri = [jt for jt in jobtemplates['items'] if jt['name'] == 'GroupFirmwareUpdate']['resourceUri']
groups = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers).json()
groupUri = [group for group in groups['items'] if group['name'] == 'DL360Gen10plus-Production-Group']['resourceUri']
bundles = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles', headers=headers).json()
firmwarebundleid = [fb for fb in bundles['items'] if fb['releaseVersion'] == '2022.03.0'][0]['id']
DL360Gen10Plus_group = [group for group in groups['items'] if group['name'] == 'DL360Gen10plus-Production-Group']
deviceids = [ server[id] for server in DL360Gen10Plus['devices']]

body = {
    "jobTemplateUri": jobtemplateUri,
    "resourceUri": groupUri,
    "data": {
      "bundle_id": firmwarebundleid,
      "devices": 
        deviceids
    }
  }

headers["Content-Type"] = "application/json"
response = requests.post(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/jobs', headers=headers, body=body) 
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


# Get the update report for the servers in the group after the update is complete.
for deviceid in deviceids:
   report = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers/' + deviceid, headers=headers)['content']['lastFirmwareUpdate']
   print(report)


#-------------------------------------------------------SCHEDULES requests samples--------------------------------------------------------------------------------


# List all schedules
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules', headers=headers) 
schedules = response.json()
print(schedules['item'])


# Get a schedule
scheduleid = schedules['items'][0]['id']
response = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules/' + scheduleid, headers=headers) 
schedule = response.json()
print(schedule)


# Delete a schedule
response = requests.delete(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules/' + scheduleid, headers=headers) 


# Update a schedule
newname = "Firmware update for group Production"
description = "This upgrade is going to rock!"
groups = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers).json()
associatedResourceUri = [group for group in groups['items'] if group['name'] == 'Production']['resourceUri']

body = {
    "name":  newname,
    "description":  description,
    "associatedResourceUri":  associatedResourceUri,
    "purpose": "GROUP_FW_UPDATE"
}

headers["Content-Type"] = "application/merge-patch+json"
response = requests.patch(url=ConnectivityEndpoint + "/compute-ops/" + APIversion + "/schedules/" + scheduleid,headers=headers, body=body)
print(response.json())


# Create a schedule
## Schedules allow you to run an update with scheduling options
## Warning: Any updates other than iLO FW require a server reboot!
schedulename = "Firmware upgrade for group DL360Gen10plus-Production-Group"
description = "Upgrade to SPP 2022.03.0"
## Start schedule on Sept 1, 2022 at 2am
startAt = "2022-10-01T02:00:00"
interval = "null" # Can be P7D for 7 days intervals, P15m, P1M, P1Y

jobtemplates = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/job-templates', headers=headers).json() 
jobTemplateid = [jt for jt in jobtemplates['items'] if jt['name'] == 'GroupFirmwareUpdate']['id']
groups = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/groups', headers=headers).json()
groupid = [group for group in groups['items'] if group['name'] == 'DL360Gen10plus-Production-Group']['id']
bundles = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/firmware-bundles', headers=headers).json()
bundleid = [fb for fb in bundles['items'] if fb['releaseVersion'] == '2022.03.0'][0]['id']
DL360Gen10Plus_group = [group for group in groups['items'] if group['name'] == 'DL360Gen10plus-Production-Group']
deviceids = [ server[id] for server in DL360Gen10Plus_group['devices']]


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

# Delete newly created schedule
response = requests.delete(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/schedules/' + scheduleid, headers=headers)

# Get the update report for the servers in the group after the update is complete.
for deviceid in deviceids:
   report = requests.get(url=ConnectivityEndpoint + '/compute-ops/' + APIversion + '/servers/' + serverId, headers=headers)['content']['lastFirmwareUpdate']
   print(report)
