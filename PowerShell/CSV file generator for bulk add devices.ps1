<# 

Adding compute devices to HPE GreenLake requires that the serial numbers and product numbers of each device with optional tags be provided.  
However, it is possible to use a csv file containing these values to add multiple compute devices to HPE GreenLake in a single step.

So this PowerShell script can be used to generate this csv file for bulk upload by retrieving the serial number and product number of each iLO listed in a csv file
containing the iLO IP addresses, the iLO credentials and optional tags.

The content of this iLOs csv file must respect the following format: 

  IP, Username, Password, tag:Location, tag:Departement
  192.168.3.191, Administrator,P@ssw0rd, California
  192.168.3.193, Administrator, P@ssw0rd, Texas, production
  192.168.3.194, Administrator, P@ssw0rd,  , development

Device tags can be used to categorize HPE GreenLake resources based on purpose, owner, environment, or other custom criteria, 
for more information, see https://support.hpe.com/hpesc/public/docDisplay?docId=sd00001293en_us&page=GUID-DE9AD407-FE9B-40E6-9DFB-024EFCB8CF85.html

Requirements: 
- A csv file with iLO IP addresses, credentials and optional tags
- Each iLO must be accessible for the script to retrieve the serial and product numbers

The example below shows the content of a csv file generated by the script that can be used in the HPE GreenLake interface:

  "Serial_No","Product_ID","tag:Departement","tag:Location"
  "CZ212406GJ","871940-B21","<blank>","California"
  "CZ212406GK","871940-B21","production","Texas"
  "CZ212406GG","871940-B21","development","<blank>"

Once generated, go to HPE GreenLake, select `Devices`, and then click `Add devices`. Select 'Compute Devices', and then click 'Next'. 
Select .csv File and provide the generated csv file.

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

# Tag categorization
$Nb_of_tags = ($iLO_collection | gm | ? name -match "tag").count

if ($Nb_of_tags -eq 0) {
  echo "Serial_No; Product_ID" > Devices_to_import_in_COM.txt 
}
elseif ($Nb_of_tags -eq 1) {
  $Tag_name1 = ($iLO_collection | gm | ? name -match "tag")[0].Name
  echo "Serial_No; Product_ID; $Tag_name1" > Devices_to_import_in_COM.txt 
}
else {
  $Tag_name1 = ($iLO_collection | gm | ? name -match "tag")[0].Name
  $Tag_name2 = ($iLO_collection | gm | ? name -match "tag")[1].Name
  echo "Serial_No; Product_ID; $Tag_name1; $Tag_name2" > Devices_to_import_in_COM.txt  
}

Import-Module HpeRedfishCmdlets

ForEach ($iLO in $iLO_Collection) {

  try {
    $session = Connect-HpeRedfish $iLO.IP -username $iLO.Username -password $iLO.Password -DisableCertificateAuthentication -ErrorAction Stop
    
  }
  catch {
    "iLO {0} cannot be added ! Check your IP or credentials !" -f $iLO.IP
    continue
  }
	
  $response = Get-HPERedfishDataRaw -Session $session -Odataid "/redfish/v1/Systems/1/" -DisableCertificateAuthentication

  $SerialNumber = $response.SerialNumber
  $sku = $response.sku


  if ($Nb_of_tags -eq 0) {
    "$SerialNumber;$sku" | Out-File Devices_to_import_in_COM.txt -Append
  }
  elseif ($Nb_of_tags -eq 1) {

    $tag1 = $iLO.$Tag_name1 
    
    if (-not $tag1) {
      $tag1 = "<blank>"
    }

    "$SerialNumber;$sku; $Tag1" | Out-File Devices_to_import_in_COM.txt -Append
  }
  else {

    $tag1 = $iLO.$Tag_name1 
    $tag2 = $iLO.$Tag_name2

    if (-not $tag1) {
      $tag1 = "<blank>"
    }
    if (-not $tag2) {
      $tag2 = "<blank>"
    }

    "$SerialNumber;$sku; $Tag1; $Tag2" | Out-File Devices_to_import_in_COM.txt -Append 

  }


  "iLO {0} added with {1} - {2}" -f $iLO.IP, $SerialNumber, $sku
 
  Disconnect-HpeRedfish -Session $session -DisableCertificateAuthentication

}

import-csv Devices_to_import_in_COM.txt -delimiter ";" | export-csv Devices_to_import_in_COM.csv -NoTypeInformation
remove-item Devices_to_import_in_COM.txt -Confirm:$false

  


