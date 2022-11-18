<# 

This PowerShell script connect all iLOs defined in a CSV file to the HPE GreenLake Cloud Platform.
Actions performed:
  1/ Set iLO proxy parameters if defined in the proxy settings variable section
  2/ If iLO is under the control of a OneView instance, it override the existing manager 
  3/ Connect iLO to Compute Ops Management

CSV File content must follow the format: 

IP, Username, Password
192.168.2.1, Administrator,password
192.168.2.2, Administrator,password

Requirements: 
- HPE GreenLake company account ID (found in HPE GreenLake Cloud Platform interface in the Manage tab)
- All compute devices must first be added to HPE GreenLake, assigned to an application and to a subscription, 
  see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us (Managing Devices / Adding Devices)
- The servers must be prepared for management with:
         - iLO IP address set and accessible
         - A common local username and password
         

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


$iLO_collection = import-csv "path\to\iLOs.csv"


# iLO Proxy settings
# $ProxyServer = "web-proxy.lj.lab"
# $ProxyPort = "8088"
# $ProxyUserName = "demopaq"
# $ProxyPassword = "password"


# HPE GreenLake company account ID (found in HPE GreenLake Cloud Platform interface in the Manage tab)
$HPE_GreenLake_company_account_ID = "34652ff0317711ec9bc096872580fd6d"

Import-Module HpeRedfishCmdlets

$body = @"
{"ActivationKey":"$HPE_GreenLake_company_account_ID","OverrideManager":true}
"@

$url = "/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.EnableCloudConnect"

ForEach ($iLO in $iLO_Collection) {

  $session = Connect-HpeRedfish $iLO.IP -username $iLO.Username -password $iLO.Password -DisableCertificateAuthentication
	
  $task = Invoke-HPERedfishAction -odataid $url -Data $body -session $session -DisableCertificateAuthentication
	
  "`niLO {0} COM activation: `t {1}" -f $iLO.IP, $task.error.'@Message.ExtendedInfo'.MessageId

  if ($ProxyServer) {

    $body = @"
    {
      "Oem":
      {
          "Hpe":
              {"WebProxyConfiguration":
                  {
                      "ProxyServer":"$ProxyServer",
                      "ProxyPort":$ProxyPort,
                      "ProxyUserName":"$ProxyUserName",
                      "ProxyPassword":"$ProxyPassword"
                  }
              }
      }
  }
"@
    $url = "/redfish/v1/Managers/1/NetworkProtocol/"

    $task = Set-HPERedfishData  -odataid $url -DisableCertificateAuthentication -Setting $body -Session $session 

    "iLO {0} Proxy activation: `t {1}" -f $iLO.IP, $task.error.'@Message.ExtendedInfo'.MessageId
 
  }

  $task = Get-HPERedfishDataRaw -Session $session -Odataid "/redfish/v1/Managers/1/" -DisableCertificateAuthentication

  "iLO {0} COM connection status:  {1}" -f $iLO.IP, $task.Oem.Hpe.CloudConnect.CloudConnectStatus

  
  Disconnect-HpeRedfish -Session $session -DisableCertificateAuthentication

}
