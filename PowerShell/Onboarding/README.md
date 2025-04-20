# HPE Compute Ops Management Onboarding Script


> Ensure you are using the latest version of the script for optimal performance and compatibility: [**Prepare-and-Connect-iLOs-to-COM-v2.ps1**](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1).


This PowerShell script automates the process of connecting HPE Gen10 and later servers to HPE Compute Ops Management (COM). It also allows you to prepare and configure iLO settings, such as DNS, NTP, and firmware updates, before connecting the servers to COM.


This preparation is essential to ensure that iLOs are ready for COM and can effectively communicate and be managed by the platform. It includes:

- **Setting up DNS**: To ensure iLO can reach the cloud platform
- **Setting up NTP**: To ensure the date and time of iLO are correct, crucial for securing the mutual TLS (mTLS) connections between COM and iLO.
- **Updating iLO firmware**: To meet the COM minimum iLO firmware requirement to support adding servers with a COM activation key (iLO5 3.09 or later, or iLO6 1.64 or later).

The script requires a CSV file that contains the list of iLO IP addresses or resolvable hostnames to be connected to COM.

This CSV file must have the following format:

```cs
IP
192.168.0.100
192.168.0.101
192.168.0.102
```

**Note:** The first line is the header and must be "IP".


To see a demonstration of this script in action, watch the following video: 

[![Preparing and connecting HPE Servers to Compute Ops Management with PowerShell](https://img.youtube.com/vi/ZV0bmqmODmU/0.jpg)](https://youtu.be/ZV0bmqmODmU)

The script performs the following actions:

1. Connects to HPE GreenLake.
2. Checks the COM instance.
3. Checks the COM subscription.
4. Generates a COM activation key.
5. Prepares and configures iLO settings:
    - DNS: Sets DNS servers (if specified) to ensure iLOs can reach the cloud platform
    - SNTP: Sets SNTP servers (if specified) to ensure the date and time of iLOs are correct, crucial for securing the mutual TLS (mTLS) connections between COM and iLO.
    - Firmware: Updates iLO firmware (if needed) to ensure the iLO firmware meets the COM minimum requirement to support onboarding via COM activation key.
        - If the minimum firmware is not met, the script updates the firmware using the iLO firmware flash file specified.
6. Connects iLOs to COM with the following options:
    - Connects iLOs directly (if no proxy settings are specified).
    - Connects iLOs via a web proxy or secure gateway (if specified).
    - Connects iLOs via a web proxy and credentials (if specified).
7. Assigns tags and location to devices (if specified).
8. Generates and exports a CSV file with the status of the operation, including iLO and server details, and the results of each configuration step.

If location and tags are defined in the variables section, each server corresponding to the iLO defined in the CSV file is assigned to the same location in the HPE GreenLake workspace and with the same tags.

The script can be run with the following parameters:

- `Check`: Switch to check the COM instance, subscription, location, and iLO settings without making any changes to the iLO settings. Useful for pre-checking before onboarding.
- `SkipCertificateValidation`: Switch to bypass certificate validation when connecting to iLO. Use with caution. This switch is only intended to be used against known hosts using a self-signed certificate.
- `DisconnectiLOfromOneView`: Switch to disconnect the iLO from HPE OneView before onboarding to COM.
- `Verbose`: Switch to enable verbose output.

**Note:** The script requires the HPEiLOCmdlets and HPECOMCmdlets PowerShell modules to connect to iLOs and HPE GreenLake, respectively. The two modules are automatically installed if not already present.

**Requirements:**

- PowerShell 7 (versions lower than 7.5.0 due to a known issue with the HPEiLOCmdlets module with .NET SDK 9 used in versions 7.5.0 and later).
- PowerShell Modules:
  - HPEiLOCmdlets (https://www.powershellgallery.com/packages/HPEiLOCmdlets)
    - Used to connect to iLOs and perform iLO configuration tasks.
    - Automatically installed if not already present.
    - Authenticity and integrity of the module are verified before use.
  - HPECOMCmdlets (https://www.powershellgallery.com/packages/HPECOMCmdlets)
    - Used to connect to HPE GreenLake and COM and to perform configuration tasks.
    - Automatically installed if not already present.
    - Authenticity and integrity of the module are verified before use.
- Network access to both HPE GreenLake and the HPE iLOs.
- The servers you want to add and configure are not assigned to other COM service instances in the same workspace or a different workspace.
- HPE GreenLake user account:
  - With the HPE GreenLake Workspace Administrator or Workspace Operator role.
  - If you use custom HPE GreenLake roles, ensure that the user account has the HPE GreenLake Devices and Subscription Service Edit permission.
  - With the Compute Ops Management Administrator or Operator role.
- HPE GreenLake already set up with:
  - A workspace where a COM service instance is provisioned.
  - A COM subscription with enough licenses to support the number of iLOs defined in the CSV file.
  - A location to support automated HPE support case creation and services.
- iLO correctly set and accessible from the network with:
  - An IP address
  - An iLO account with Administrator privileges or at least the Configure iLO Settings privilege.
  - The password of the iLO account.

**How to use:**

1. Update the variables in the script as needed.
    - Path to the CSV file containing the list of iLO IP addresses or resolvable hostnames
    - Path to the iLO firmware flash files for iLO5 and iLO6.
    - Username of the iLO account.
    - DNS servers to configure in iLO (optional).
    - SNTP servers to configure in iLO (optional).
    - iLO Web Proxy or Secure Gateway settings (optional).
    - HPE GreenLake account with HPE GreenLake and Compute Ops Management administrative privileges.
    - HPE GreenLake workspace name where the COM instance is provisioned.
    - Region where the COM instance is provisioned.
    - Location name where the devices will be assigned (optional).
    - Tags to assign to devices (optional).
2. Run the script in a PowerShell 7 environment.
3. Review the output to ensure that the iLOs are successfully connected to COM.

**Note:** The script can be run multiple times with different CSV files to assign different tags or locations to servers.

**Example 1: Pre-checking before onboarding**

```
.\Prepare-and-Connect-iLOs-to-COM.ps1 -Check
```

**Output:**

```
Enter password for iLO account 'admin': ********
Enter password for your HPE GreenLake account 'email@domain.com': ********

[Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.

------------------------------
COM CONFIGURATION CHECK STATUS
------------------------------
- Provisionned instance: OK
- Subscription: OK                                                                                                    
        - Status: Sufficient licenses available (19) for the number of iLOs (3).
- Location: Failed
        - Status: Location 'Nice' not found in the HPE GreenLake workspace. Please create the location before running this script.

------------------------------
iLO CONFIGURATION CHECK STATUS
------------------------------

- [192.168.0.20] (v3.08 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004G)
        - DNS: Warning
                - Current: None
                - Missing: 192.168.2.1, 192.168.2.3
        - SNTP: Warning
                - Current: None
                - Missing: 1.1.1.1, 2.2.2.2
        - iLO firmware: Warning
                - Current: 3.08
                - Required: 3.09
        - iLO connection to COM: Disconnected
        - Tags: Warning
                - Current: None                                                                                        
                - Missing: Country=FR, App=AI, Department=IT
        - Location: Warning
                - Current: None                                                                                        
                - Required: Nice

- [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
        - DNS: Ok
                - Current: 192.168.2.1, 192.168.2.3
                - Missing: None
        - SNTP: Ok
                - Current: 1.1.1.1, 2.2.2.2
                - Missing: None
        - iLO firmware: OK
                - Current: 3.1
                - Required: 3.09
        - iLO connection to COM: Disconnected
        - Tags: Warning
                - Current: None                                                                                        
                - Missing: Country=FR, App=AI, Department=IT
        - Location: Warning
                - Current: None                                                                                        
                - Required: Nice

- [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
        - DNS: Ok
                - Current: 192.168.2.1, 192.168.2.3
                - Missing: None
        - SNTP: Warning
                - Current: None
                - Missing: 1.1.1.1, 2.2.2.2
        - iLO firmware: Warning
                - Current: 1.62
                - Required: 1.64
        - iLO connection to COM: Disconnected
        - Tags: Warning
                - Current: None                                                                                        
                - Missing: Country=FR, App=AI, Department=IT
        - Location: Warning
                - Current: None                                                                                        
                - Required: Nice

The status of the check has been exported to 'Z:\Onboarding\iLO_Check_Status_20250227_1011.csv'
Hit return to close:
```

**Example 2: Onboarding**

```
.\Prepare-and-Connect-iLOs-to-COM.ps1  
```

**Output:**

```
Enter password for iLO account 'admin': ********
Enter password for your HPE GreenLake account 'email@domain.com': ********

[Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.
[Workspace: HPE Mougins] - COM instance 'eu-central' successfully found.
[Workspace: HPE Mougins] - Sufficient licenses available (19) for the number of iLOs (3).                               
[Workspace: HPE Mougins] - Successfully generated COM activation key '3CJ7S2DH8' for region 'eu-central'.

- [192.168.0.20] (v3.08 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004G)
        - DNS: InProgress
                - Status: DNS settings set successfully!
        - SNTP: InProgress
                - Status: SNTP settings set successfully. Message: ResetRequired
                - Status: Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed...
                - Status: iLO reset has been detected. Waiting for iLO to be back online...
                - Status: iLO SNTP settings updated successfully and iLO is back online.
                - Status: Reconnecting to iLO...
        - iLO firmware: InProgress
                - Status: iLO5 firmware update in progress as firmware is lower than v3.09...
                - Status: iLO firmware must be activated. Waiting for the reset to be performed...
                - Status: iLO reset has been detected. Waiting for iLO to be back online...
                - Status: iLO firmware updated successfully and iLO is back online.
                - Status: Reconnecting to iLO...
                - Status: Waiting for iLO to be ready for COM connection...
                - Status: iLO is ready for COM connection.
        - iLO connection to COM: InProgress
                - Status: iLO successfully connected to COM.
        - Tags: InProgress                                                                                             
                - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
        - Location: InProgress
                - Status: Location assigned successfully.

- [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
        - DNS: Skipped
                - Status: DNS configuration is not required as the DNS servers are already defined.
        - SNTP: Skipped
                - Status: SNTP configuration is not required as the SNTP servers are already defined.
        - iLO firmware: Skipped
                - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
        - iLO connection to COM: InProgress
                - Status: iLO successfully connected to COM.
        - Tags: InProgress
                - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
        - Location: InProgress
                - Status: Location assigned successfully.

- [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
        - DNS: Skipped
                - Status: DNS configuration is not required as the DNS servers are already defined.
        - SNTP: Skipped
                - Status: SNTP configuration is not required as the SNTP servers are already defined.
        - iLO firmware: Skipped
                - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
        - iLO connection to COM: InProgress
                - Status: iLO successfully connected to COM.
        - Tags: InProgress
        - DNS: Skipped
                - Status: DNS configuration is not required as the DNS servers are already defined.
        - SNTP: Skipped
                - Status: SNTP configuration is not required as the SNTP servers are already defined.
        - iLO firmware: Skipped
                - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
        - iLO connection to COM: InProgress
                - Status: iLO successfully connected to COM.
        - Tags: InProgress
                - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
        - Location: InProgress
                - Status: Location assigned successfully.

- [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
        - DNS: Skipped
                - Status: DNS configuration is not required as the DNS servers are already defined.
        - SNTP: InProgress
                - Status: SNTP settings set successfully. Message: ResetRequired
                - Status: Changes to SNTP configuration requires an iLO reset in order to take effect. Waiting for the reset to be performed...
                - Status: iLO reset has been detected. Waiting for iLO to be back online...
                - Status: iLO SNTP settings updated successfully and iLO is back online.
                - Status: Reconnecting to iLO...
        - iLO firmware: InProgress
                - Status: iLO6 firmware update in progress as firmware is lower than v1.64...
                - Status: iLO firmware must be activated. Waiting for the reset to be performed...!
                - Status: iLO reset has been detected. Waiting for iLO to be back online...
                - Status: iLO is back online and iLO firmware updated successfully.
                - Status: Reconnecting to iLO...
                - Status: Waiting for iLO to be ready for COM connection...
                - Status: iLO is ready for COM connection.
        - iLO connection to COM: InProgress
                - Status: iLO successfully connected to COM.
        - Tags: InProgress
                - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
        - Location: InProgress
                - Status: Location assigned successfully.

Operation completed successfully! All servers have been configured and connected to the Compute Ops Management instance in the 'eu-central' region.
The status of the operation has been exported to 'Z:\Onboarding\iLO_Onboarding_Status_20250227_1046.csv'
Hit return to close:
```

**Note:** The script generates a CSV file with the status of the operation, including the iLO IP address, hostname, serial number, iLO generation, iLO firmware version, server model, and the status of the configuration and connection to COM.

**Disclaimer:** The script is provided as-is and is not officially supported by HPE. It is recommended to test the script in a non-production environment before running it in a production environment. 
