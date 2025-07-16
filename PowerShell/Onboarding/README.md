# HPE Compute Ops Management Onboarding Script


> Ensure you are using the latest version of the script for optimal performance and compatibility: [**Prepare-and-Connect-iLOs-to-COM-v2.ps1**](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1).


This PowerShell script is designed to streamline the onboarding process of HPE Gen10 and later servers to HPE Compute Ops Management (COM) by automating the necessary preparations and configurations required for successful integration.

This preparation is essential to ensure that iLOs are ready for COM and can effectively communicate and be managed by the platform. It includes:

- **Setting up DNS**: To ensure iLO can reach the cloud platform
- **Setting up NTP**: To ensure the date and time of iLO are correct, crucial for securing the mutual TLS (mTLS) connections between COM and iLO.
- **Updating iLO firmware**: To meet the COM minimum iLO firmware requirement to support adding servers with a COM activation key (iLO5 3.09 or later, or iLO6 1.64 or later).

This script is designed to be idempotent, meaning you can safely run it multiple times without causing issues or duplicating actions. Here’s how it works:

- **Parameter Skipping**: The script checks each parameter or configuration before making changes. If a parameter is already set or a step has already been completed, the script skips that step. This prevents unnecessary updates or reconfiguration.
- **iLO Connection Check**: Before attempting to connect an iLO to COM, the script verifies if the iLO is already connected. If it is, the script skips the reconnection process for that iLO, avoiding redundant operations.
- **Status Reporting**: The script generates a detailed status report at the end of its execution, indicating which iLOs were successfully connected, which were skipped, and any warnings or issues encountered. This report helps you track the state of each iLO without needing to re-run the script unnecessarily.

This approach ensures that running the script repeatedly will not disrupt existing configurations or connections. It only applies changes where needed, making it safe and efficient for ongoing management or troubleshooting.

The script requires a CSV file and supports two options for iLO credentials:

1. All iLOs use the same account username and password. In this case, provide a CSV file with a header "IP" and a list of iLO IP addresses or resolvable hostnames to be connected to COM:

   ```cs
   IP
   192.168.0.100
   192.168.0.101
   192.168.0.102
   ```
   > The first line is the header and must be "IP".

2. Each iLO uses a different username and/or password. In this case, provide a CSV file with headers "IP,UserName,Password" and specify the iLO IP address or hostname, username, and password for each entry:

   ```cs
   IP, UserName, Password
   192.168.0.100, admin1, password1
   192.168.0.101, admin2, password2
   192.168.1.102, admin3, password3
   ```
   > The specified accounts must have Administrator privileges, or at minimum, the "Configure iLO Settings" privilege.

Choose the CSV format that matches your environment.

To see a demonstration of this script in action, watch the video:

[![Preparing and connecting HPE Servers to Compute Ops Management with PowerShell](https://img.youtube.com/vi/ZV0bmqmODmU/0.jpg)](https://youtu.be/ZV0bmqmODmU)

**Note:** This video was recorded during the early development phase of the script. The script has since been significantly enhanced, and some features or outputs shown in the video may differ from the current version.

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

## What's New

The script includes a comprehensive "What's New" section in the header that documents all recent updates and improvements. Key highlights include:

- **July 16, 2025**: Extended the logic for A55 or A56 ROM family servers to handle compatibility with iLO firmware versions. Now if iLO 1.62 or earlier is detected with any ROM version, the script will use the workspace ID onboarding method.
- **July 15, 2025**: Fixed activation key collection issues when multiple keys were available and ensured proper iLO disconnection from COM after device removal when no valid subscription key was found, preventing future onboarding failures.
- **July 11, 2025**: Enhanced script reliability and validation by adding retry logic for iLO chassis information retrieval, implementing comprehensive post-onboarding verification of server presence and subscription status, optimizing DNS configuration handling for DHCP-managed settings, and improving tagging efficiency to prevent redundant updates.
- **July 9, 2025**: Enhanced script reliability by adding connection retry logic and activation key compatibility validation for server onboarding.
- **July 8, 2025**: Added a new feature to the script that allows users to specify the subscription tier and whether to include evaluation subscriptions. This provides more flexibility in selecting the appropriate COM subscription for onboarding.
- **July 2, 2025**: Added many improvements to the entire script. Enhanced the summary output to display the number of successful, failed, warning, and skipped servers at the end of the script. Improved on-screen reporting for "Unsupported/Skipped" servers.
- **July 1, 2025**: General improvements, bug fixes, and enhanced compatibility for A55/A56 server hardware platforms (Gen11)
- **June 10, 2025**: Fixed COM activation key assignment and subscription validation issues
- **June 4, 2025**: Improved session reliability, enhanced documentation, and security enhancements

For detailed information about all changes and improvements, refer to the `.WHATSNEW` section in the script header.

## Requirements

- PowerShell 7.
- PowerShell Modules:
    - HPEiLOCmdlets (https://www.powershellgallery.com/packages/HPEiLOCmdlets)
        - Required for connecting to HPE iLOs and performing all iLO configuration and management tasks.
        - The script automatically installs and uses the latest available version to ensure compatibility and access to the newest features and bug fixes.
        - Minimum supported version: 5.1.0.0 (earlier versions are not supported due to known issues).
        - On Windows systems, the script verifies the authenticity and integrity of the module before use to ensure only trusted code is executed.
    - HPECOMCmdlets (https://www.powershellgallery.com/packages/HPECOMCmdlets)
        - Required for connecting to HPE GreenLake and Compute Ops Management, and for performing all related configuration and management tasks.
        - The script automatically installs and uses the latest available version to ensure compatibility and access to the newest features and bug fixes.
        - On Windows systems, the script verifies the authenticity and integrity of the module before use to ensure only trusted code is executed.
- Ensure network access to both HPE GreenLake and all target HPE iLOs.
- Verify that the servers to be onboarded are not already assigned to another COM service instance in any workspace.
- HPE GreenLake user account requirements:
    - Must have the Workspace Administrator or Workspace Operator role.
    - If using custom roles, the account must have "Devices and Subscription Service Edit" permission.
    - Must also have the COM Administrator or Operator role.
- HPE GreenLake environment must have:
    - A workspace with a provisioned COM service instance.
    - An active COM subscription with sufficient licenses for all iLOs listed in the CSV file.
    - A defined location (required for automated HPE support case creation and services).
    - A Secure Gateway added to the COM instance (if applicable).
- iLO requirements:
    - Each iLO must have a reachable IP address.
    - An iLO account with Administrator privileges, or at minimum, the "Configure iLO Settings" privilege.
    - The password for the iLO account.

## How to use 

1. Create a CSV file:
    - Example1: For a single iLO username/password, the CSV file should look like this:

        ```cs
        IP
        192.168.0.100
        192.168.0.101
        192.168.0.102
        ```   
        > The first line is the header and must be "IP".

    - Example2: For different iLO credentials per device, the CSV file should look like this:

        ```cs
        IP, UserName, Password
        192.168.0.20, admin1, password1
        192.168.0.21, admin2, password2
        192.168.1.56, admin3, password3
        ```   
        > The first line is the header and must be "IP, UserName, Password".

2. Review and update the variables in the "Variables definition" section of the script as needed.
    
   All configuration variables are defined near the top of the script, in the section labeled:

   `#Region --------------------------- Variables definition -------------------------------------------`
    
   Update the following variables according to your environment:

   **Required configuration**:

   `$iLOcsvPath` - Path to your CSV file containing the iLO details   
   `$iLO5binFile` and `$iLO6binFile` - Path to the iLO firmware flash files for iLO5 and iLO6   
   `$iLOUserName` - iLO administrator account username (only needed if missing from the CSV file)    
   `$WorkspaceName` - Your HPE GreenLake workspace name where the COM instance is provisioned  
   `$Region` - Your COM instance region  
   `$HPEAccount` - Your HPE GreenLake account email with HPE GreenLake and COM administrative privileges  
   `$OktaSSOEmail` - Set to $true if using @HPE.com email. Note that SSO is available for users with an hpe.com email address only   
   `$SubscriptionTier` - Set to 'PROLIANT' or 'ALLETRA' based on your device type  
   `$UseEval `- Set to $true to include evaluation subscriptions  

   **Optional configuration**:

   `$DNSservers` and `$DNStypes` - DNS server configuration to configure in iLO
   `$SNTPservers` - Time synchronization servers to configure in iLO
   `$WebProxyServer`, `$WebProxyPort`, `$WebProxyUsername`, `$WebProxyPassword` - Web proxy settings to configure in iLO  
   `$SecureGateway `- Secure Gateway FQDN (alternative to web proxy)  
   - The Secure Gateway must be pre-configured in your COM instance before running this script.  
   - You cannot use both web proxy variables and Secure Gateway variables simultaneously.    

   `$LocationName` - Location assignment for devices  
   - The location must be created in the HPE GreenLake workspace before running this script.
   
   `$Tags` - Custom tags to assign to devices   

   All these variables are clearly marked and documented in the "Variables definition" section for easy customization.

3. Run the script in a PowerShell 7 environment.

4. Review the output to ensure that the iLOs are successfully connected to COM.

## Important Note: 
- To accelerate onboarding through parallel processing, consider splitting your list of iLOs into multiple CSV files and running several instances of the script simultaneously, each with a different CSV file. Note that a maximum of 7 instances can be run concurrently due to the current limit of 7 Personal API clients per user in a workspace.

- To assign different tags or locations to servers, create separate CSV files for each group with the desired tags or location values, and run the script multiple times using those files. This approach allows you to customize tags and location assignments for each set of servers during onboarding.

- Firmware updates can take significantly longer when the iLO firmware binary is not located on the local network, due to slower file transfer speeds. To optimize the process, make sure the iLO firmware binary is accessible on the same local network as your iLOs. This typically allows updates to complete more quickly and significantly reduces overall delays.



## Examples

**Example 1: Pre-checking before onboarding**

```
.\Prepare-and-Connect-iLOs-to-COM.ps1 -Check
```

**Output:**

```
    Enter password for iLO account 'administrator': ********

    Verifying the authenticity and integrity of the HPEiLOCmdlets module...
    Verifying file: HPEiLOCmdlets.resources.dll
    Verifying file: HPEiLOCmdlets.resources.dll
    Verifying file: AutoMapper.dll
    Verifying file: DeepCloner.dll
    Verifying file: HPEiLOCmdlets.dll
    Verifying file: HPEiLOCmdlets.psd1
    Verifying file: log4net.dll (third-party library)
    Verifying file: Newtonsoft.Json.dll
    Verifying file: System.Reflection.TypeExtensions.dll
    HPEiLOCmdlets module verification successful. All signatures, certificates, and metadata are valid.
    Proceeding to import module...

    Verifying the authenticity and integrity of the HPECOMCmdlets module...
    Verifying file: HPECOMCmdlets.Format.ps1xml
    Verifying file: HPECOMCmdlets.psd1
    Verifying file: HPECOMCmdlets.psm1
    HPECOMCmdlets module verification successful. All signatures, certificates, and metadata are valid.
    Proceeding to import module...

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
            - Onboarding method selected: Activation Key
            - DNS: Warning
                    - Current: None
                    - Missing: 192.168.2.1, 192.168.2.3
            - SNTP: Warning
                    - Current: None
                    - Missing: 1.1.1.1, 2.2.2.2
            - iLO firmware: Warning
                    - Current: 3.08
                    - Required: 3.09 or later
            - iLO connection to COM: Disconnected
                - Status: iLO not connected to COM. Current status: NotEnabled  
            - Tags: Warning
                    - Current: None                                                                                        
                    - Missing: Country=FR, App=AI, Department=IT
                    - Extra: None
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    - [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
            - Onboarding method selected: Activation Key
            - DNS: Ok
                    - Current: 192.168.2.1, 192.168.2.3
                    - Missing: None
            - SNTP: Ok
                    - Current: 1.1.1.1, 2.2.2.2
                    - Missing: None
            - iLO firmware: OK
                    - Current: 3.1
                    - Required: 3.09 or later
            - iLO connection to COM: Connected
                    - Status: iLO already connected to COM.
            - Tags: Warning
                    - Current: None                                                                                        
                    - Missing: Country=FR, App=AI, Department=IT
                    - Extra: None
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    - [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
            - Onboarding method selected: Activation Key
            - DNS: Ok
                    - Current: 192.168.2.1, 192.168.2.3
                    - Missing: None
            - SNTP: Warning
                    - Current: None
                    - Missing: 1.1.1.1, 2.2.2.2
            - iLO firmware: Warning
                    - Current: 1.62
                    - Required: 1.64 or later
            - iLO connection to COM: Disconnected
            - Tags: Warning
                    - Current: Country=FR                                                                                        
                    - Missing: Department=IT, App=AI
                    - Extra: None
            - Location: Warning
                    - Current: None                                                                                        
                    - Required: Nice

    
    Check summary: 0 succeeded, 0 failed, 3 warnings, 0 skipped (Total: 3)

    ⚠️ Status check completed with issues!
        Please review the detailed status report and resolve any issues before proceeding to onboarding.
    
    📄 Status report exported to: Z:\Onboarding\iLO_Check_Status_20250227_1011.csv

    email@domain.com session disconnected!
    Hit return to close:
```

**Example 2: Onboarding**

```
.\Prepare-and-Connect-iLOs-to-COM.ps1  
```

**Output:**

```
    Enter password for iLO account 'administrator': ********

    Verifying the authenticity and integrity of the HPEiLOCmdlets module...
    Verifying file: HPEiLOCmdlets.resources.dll
    Verifying file: HPEiLOCmdlets.resources.dll
    Verifying file: AutoMapper.dll
    Verifying file: DeepCloner.dll
    Verifying file: HPEiLOCmdlets.dll
    Verifying file: HPEiLOCmdlets.psd1
    Verifying file: log4net.dll (third-party library)
    Verifying file: Newtonsoft.Json.dll
    Verifying file: System.Reflection.TypeExtensions.dll
    HPEiLOCmdlets module verification successful. All signatures, certificates, and metadata are valid.
    Proceeding to import module...

    Verifying the authenticity and integrity of the HPECOMCmdlets module...
    Verifying file: HPECOMCmdlets.Format.ps1xml
    Verifying file: HPECOMCmdlets.psd1
    Verifying file: HPECOMCmdlets.psm1
    HPECOMCmdlets module verification successful. All signatures, certificates, and metadata are valid.
    Proceeding to import module...

    Enter password for your HPE GreenLake account 'email@domain.com': ********

    [Workspace: HPE Mougins] - Successfully connected to the HPE GreenLake workspace.
    [Workspace: HPE Mougins] - COM instance 'eu-central' successfully found.
    [Workspace: HPE Mougins] - Sufficient licenses available (19) for the number of iLOs (3).                               

    - [192.168.0.20] (v3.08 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004G)
            - Onboarding method selected: Activation Key
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
            - COM activation key: InProgress
                 - Status: Successfully generated COM standard activation key 'VCC7G2A64' for region 'eu-central'.    
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress                                                                                             
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: No current location assigned. Proceeding to assign new location.
                    - Status: Location assigned successfully.

    - [192.168.0.21] (v3.1 iLO5 - Model:DL360 Gen10Plus - SN:CZ2311004H)
            - Onboarding method selected: Activation Key
            - DNS: Skipped
                    - Status: DNS configuration is not required as the DNS servers are already defined.
            - SNTP: Skipped
                    - Status: SNTP configuration is not required as the SNTP servers are already defined.
            - iLO firmware: Skipped
                    - Status: iLO5 firmware update is not needed as firmware is v3.09 or higher.
            - COM activation key: InProgress
                 - Status: Successfully generated COM standard activation key 'VCC7G2A64' for region 'eu-central'. 
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: No current location assigned. Proceeding to assign new location.
                    - Status: Location assigned successfully.

    - [192.168.1.56] (v1.62 iLO6 - Model:DL365 Gen11 - SN:CZJ3100GD9)
            - Onboarding method selected: Activation Key
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
            - COM activation key: InProgress
                 - Status: Successfully generated COM standard activation key 'VCC7G2A64' for region 'eu-central'.                    
            - iLO connection to COM: InProgress
                    - Status: iLO successfully connected to COM.
            - Tags: InProgress
                    - Status: Existing tags removed successfully.
                    - Status: Tags 'Country=FR, App=AI, Department=IT' added successfully.
            - Location: InProgress
                    - Status: No current location assigned. Proceeding to assign new location.
                    - Status: Location assigned successfully.

    Onboarding summary: 3 succeeded, 0 failed, 0 warnings, 0 skipped (Total: 3)
    
    ✅ Onboarding completed successfully for all servers!
        All servers have been configured and connected to Compute Ops Management in the 'eu-central' region.

    📄 Status report exported to: Z:\Onboarding\iLO_Onboarding_Status_20250227_1046.csv'

    email@domain.com session disconnected!
    Hit return to close:
```

**Note:** The script generates a CSV file with the status of the operation, including the iLO IP address, hostname, serial number, iLO generation, iLO firmware version, server model, and the status of the configuration and connection to COM.

**Disclaimer:** The script is provided as-is and is not officially supported by HPE. It is recommended to test the script in a non-production environment before running it in a production environment. 
