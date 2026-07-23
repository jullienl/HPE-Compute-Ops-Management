#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.26' }

<#
.SYNOPSIS
    Migrates HPE servers connected to Compute Ops Management (COM) from a Direct iLO
    connection to a Secure Gateway connection, in bulk, for a given region.

.DESCRIPTION
    This script automates the migration of every Direct-connected server in a Compute Ops
    Management region to a Secure Gateway connection. It performs the following steps:

        1. Connects to HPE GreenLake (reusing an existing valid session when possible),
           then validates the target region.
        2. Selects the Secure Gateway appliance to route through (either the name you
           provide, or the first available Secure Gateway found in the region).
        3. Generates a short-lived COM activation key tied to that Secure Gateway.
        4. Retrieves all servers currently using a Direct connection in the region.
        5. Reconnects each server's iLO through the Secure Gateway in a single pipeline
           operation, using -Force to disconnect the existing Direct connection first.

    Because the device-to-service assignment is never removed during the migration, all
    COM group memberships, server settings, policies and subscriptions are fully preserved.

    Run the script with -Check first to preview every action (a read-only per-iLO report)
    without making any change to the iLOs.

.PARAMETER GLCredential
    (Optional) A PSCredential holding your HPE GreenLake account email and password, used
    to connect to HPE GreenLake at the start of the script. If omitted and no valid session
    already exists, the script prompts for it interactively. Ignored when a valid session
    for the requested workspace is already active.

.PARAMETER Workspace
    (Mandatory) The HPE GreenLake workspace that owns the servers. The script connects to
    (or switches to) this workspace with a fresh sign-in, and only reuses an existing
    session when it already targets this same workspace.

.PARAMETER Region
    The COM region code where the servers are connected (e.g. 'eu-central', 'us-west').
    Retrieve valid region codes with:
        Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned

.PARAMETER IloCredential
    A PSCredential object holding the iLO username and password. All target iLOs must
    share these credentials. If omitted (and -CredentialCsvPath is not used), the script
    prompts for them interactively. Belongs to the 'SharedCredential' parameter set.

.PARAMETER CredentialCsvPath
    Path to a CSV file providing per-iLO credentials, for estates where each iLO has its
    own username/password. The CSV must have the columns: IP, Username, Password - for
    example:
        IP,Username,Password
        192.168.0.1,admin,password1
        192.168.0.2,Administrator,password2
    Each Direct-connected server is matched to its CSV row by iLO IP address; servers with
    no matching row are skipped with a warning. Belongs to the 'CsvCredential' parameter
    set and cannot be combined with -IloCredential.

.PARAMETER SecureGatewayName
    (Optional) The name of the Secure Gateway appliance to route the iLO connections
    through. If not provided, the first available Secure Gateway in the region is used.

.PARAMETER IloProxyPort
    (Optional) The iLO proxy port used to reach the Secure Gateway. Defaults to 8080,
    which is the standard Secure Gateway port.

.PARAMETER ActivationKeyExpirationInHours
    (Optional) Lifetime of the generated COM activation key, in hours. Defaults to 24.
    Valid range is 0.5 (30 minutes) to 168 (7 days).

.PARAMETER SkipCertificateValidation
    (Optional) Skips iLO TLS certificate validation. Use only against trusted iLOs that
    present self-signed certificates. Not recommended for production over untrusted paths.

.PARAMETER Check
    (Optional) Preview mode. Runs the connection cmdlet with -WhatIf so each iLO is
    contacted read-only and a step-by-step report is produced, without changing anything.

.EXAMPLE
    .\Migrate-DirectToSecureGateway.ps1 -Region eu-central -Workspace 'Production' -Check

    Previews the migration of every Direct-connected server in eu-central. Connects to HPE
    GreenLake 'Production' workspace (reusing an active session, or prompting for credentials), 
    prompts for iLO credentials, auto-selects the first Secure Gateway, and prints a per-iLO 
    WhatIf report without making any change.

    Sample output:

        === HPE COM migration: Direct -> Secure Gateway ('eu-central') ===

        Connecting to HPE GreenLake...
        HPE GreenLake   : connected ('Production')

        Secure Gateway  : sg01.lj.lab (port 8080)

        Servers to move : 4 Direct-connected server(s)

        name          serialNumber iLOIPAddress  connectionType
        ----          ------------ ------------  --------------
        fdz365g11-1   CZJ3100GDB   10.228.75.111 DIRECT
        HVM-1         CZ2311004G   192.168.0.20  DIRECT
        RHEL-1.lj.lab CZ2311004H   192.168.0.21  DIRECT
        RHEL-2.lj.lab CZJ3100GD9   192.168.1.56  DIRECT

        Generating a COM activation key tied to Secure Gateway 'sg01.lj.lab'...
        Activation key  : generated (valid for 24 h)

        PREVIEW MODE (-Check): no change will be made to the iLOs.

        WARNING: iLO '10.228.75.111': iLO is not reachable. Please ensure you are connected to the iLO network. Cannot display the planned operations.
        WARNING: iLO '192.168.0.20' [iLO 5 v3.20 - SN: CZ2311004G] - WhatIf report:                                             
        Validation
            - iLO network connectivity (ping) : Reachable
            - iLO authentication / session    : Succeeded
            - iLO identity                    : iLO 5 v3.20 (SN: CZ2311004G)
            - Current iLO proxy               : Disabled
            - Managed by HPE OneView          : No
            - iLO firmware vs activation key  : Compatible (v3.20 meets the minimum required version)

        Planned operations
            - COM disconnect (-Force)         : Disconnect the iLO from its current COM connection before reconnecting
            - Proxy configuration             : Configure web proxy 'sg01.lj.lab:8080'
            - HPE OneView                     : Leave unchanged (not managed by HPE OneView)
            - Activation key                  : 'xxxxxxxx'
            - COM connection                  : Connect using the provided activation key
        WARNING: iLO '192.168.0.21' [iLO 5 v3.20 - SN: CZ2311004H] - WhatIf report:                                             
        Validation
            - iLO network connectivity (ping) : Reachable
            - iLO authentication / session    : Succeeded
            - iLO identity                    : iLO 5 v3.20 (SN: CZ2311004H)
            - Current iLO proxy               : Disabled
            - Managed by HPE OneView          : No
            - iLO firmware vs activation key  : Compatible (v3.20 meets the minimum required version)

        Planned operations
            - COM disconnect (-Force)         : Disconnect the iLO from its current COM connection before reconnecting
            - Proxy configuration             : Configure web proxy 'sg01.lj.lab:8080'
            - HPE OneView                     : Leave unchanged (not managed by HPE OneView)
            - Activation key                  : 'xxxxxxxx'
            - COM connection                  : Connect using the provided activation key
        WARNING: iLO '192.168.1.56' [iLO 6 v1.77 - SN: CZJ3100GD9] - WhatIf report:                                             
        Validation
            - iLO network connectivity (ping) : Reachable
            - iLO authentication / session    : Succeeded
            - iLO identity                    : iLO 6 v1.77 (SN: CZJ3100GD9)
            - Current iLO proxy               : Disabled
            - Managed by HPE OneView          : No
            - iLO firmware vs activation key  : Compatible (v1.77 meets the minimum required version)

        Planned operations
            - COM disconnect (-Force)         : Disconnect the iLO from its current COM connection before reconnecting
            - Proxy configuration             : Configure web proxy 'sg01.lj.lab:8080'
            - HPE OneView                     : Leave unchanged (not managed by HPE OneView)
            - Activation key                  : 'xxxxxxxx'
            - COM connection                  : Connect using the provided activation key

.EXAMPLE
    $glCred  = Get-Credential   # HPE GreenLake account
    $iloCred = Get-Credential   # iLO account shared by all servers
    .\Migrate-DirectToSecureGateway.ps1 -Region eu-central -GLCredential $glCred -Workspace 'Production' -IloCredential $iloCred -SkipCertificateValidation

    Connects to HPE GreenLake using the supplied account and 'Production' workspace, then
    migrates all Direct-connected servers in eu-central to the first available Secure
    Gateway, skipping iLO certificate validation. Fully unattended - no interactive prompts.

    Sample output:

        === HPE COM migration: Direct -> Secure Gateway ('eu-central') ===

        Connecting to HPE GreenLake...
        HPE GreenLake   : connected ('Production')

        Secure Gateway  : sg01.lj.lab (port 8080)

        Servers to move : 4 Direct-connected server(s)

        name          serialNumber iLOIPAddress  connectionType
        ----          ------------ ------------  --------------
        fdz365g11-1   CZJ3100GDB   10.228.75.111 DIRECT
        HVM-1         CZ2311004G   192.168.0.20  DIRECT
        RHEL-1.lj.lab CZ2311004H   192.168.0.21  DIRECT
        RHEL-2.lj.lab CZJ3100GD9   192.168.1.56  DIRECT

        Generating a COM activation key tied to Secure Gateway 'sg01.lj.lab'...
        Activation key  : generated (valid for 24 h)

        Migrating 4 server(s) to the Secure Gateway connection...

        === Migration results ===

        iLO           SerialNumber Status   Details
        ---           ------------ ------   -------
        10.228.75.111              Warning  iLO is not reachable. Please ensure you are connected to the iLO network.
        192.168.0.20  CZ2311004G   Complete
        192.168.0.21  CZ2311004H   Complete
        192.168.1.56  CZJ3100GD9   Complete

        1 server(s) did not complete the migration. Review the Details column above.

.EXAMPLE
    $iloCred = Get-Credential
    .\Migrate-DirectToSecureGateway.ps1 -Region us-west -Workspace 'Production' -IloCredential $iloCred -SecureGatewayName 'sg01.lab' -IloProxyPort 8080

    Reuses the current HPE GreenLake session when it already targets 'Production' (otherwise
    connects for you), and migrates all Direct-connected servers in us-west through the
    specific Secure Gateway 'sg01.lab' on port 8080.

.EXAMPLE
    $glCred = Get-Credential
    .\Migrate-DirectToSecureGateway.ps1 -Region eu-central -GLCredential $glCred -Workspace 'Production' -CredentialCsvPath .\iLO-credentials.csv -SkipCertificateValidation

    Connects to HPE GreenLake, then migrates all Direct-connected servers in eu-central using
    per-iLO credentials read from the CSV file. Each iLO is matched to its row by IP address,
    so servers with different usernames/passwords are all handled in a single run.

.OUTPUTS
    System.Management.Automation.PSCustomObject

        In normal (non -Check) mode, the script returns one status object per migrated server,
        as produced by Connect-HPEGLDeviceComputeiLOtoCOM. Each object contains:
        * iLO                  - iLO IP address of the migrated server.
        * SerialNumber         - Serial number of the server.
        * Status               - Overall result (Complete on success; Failed on error;
                                 Warning if no action was needed or another condition occurred).
        * Details              - More information about the status.
        * iLOConnectionStatus  - Result of the iLO connection attempt to Compute Ops Management.
        * iLOConnectionDetails - More information about the iLO connection attempt.
        * ProxySettingsStatus  - Result of the Secure Gateway (iLO proxy) configuration attempt.
        * ProxySettingsDetails - More information about the proxy configuration attempt.
        * Exception            - Any exception generated during the operation.

        In preview mode (-Check), no object is returned; a per-iLO WhatIf report is written to
        the host instead.

.NOTES
    PREREQUISITES
    -------------
    - PowerShell 7.0 or later.
    - The HPECOMCmdlets module v1.0.26+ installed (Install-Module HPECOMCmdlets).
    - HPE GreenLake account credentials with access to the workspace that owns the servers.
      The script connects for you (reusing an existing session only when it already targets
      the requested -Workspace); pass credentials with -GLCredential or let it prompt.
    - Compute Ops Management provisioned in the target region.
    - At least one Secure Gateway appliance deployed and online in the target region.
    - Network access from the machine running this script to every target iLO.
    - iLO firmware meeting the COM activation-key minimums:
          iLO 5: v3.09 or later     iLO 6: v1.64 or later
    - A valid COM subscription with available quantity, or auto-subscription enabled
      (Set-HPEGLDeviceAutoSubscription), so the generated activation key can subscribe
      the servers.

    Author : Lionel Jullien (HPE)
    Module : HPECOMCmdlets

.LINK
    https://github.com/jullienl/HPE-Compute-Ops-Management
    https://github.com/jullienl/HPE-COM-PowerShell-Library
    https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake
#>

[CmdletBinding(DefaultParameterSetName = 'SharedCredential')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Region,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$GLCredential,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Workspace,

    [Parameter(ParameterSetName = 'SharedCredential')]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$IloCredential,

    [Parameter(Mandatory, ParameterSetName = 'CsvCredential')]
    [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { $true }
            else { throw "CSV file not found: $_" }
        })]
    [string]$CredentialCsvPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SecureGatewayName,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$IloProxyPort = 8080,

    [Parameter()]
    [ValidateRange(0.5, 168)]
    [double]$ActivationKeyExpirationInHours = 24,

    [Parameter()]
    [switch]$SkipCertificateValidation,

    [Parameter()]
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------
# Step 0 - Connect to HPE GreenLake (reuse an existing valid session when possible)
# --------------------------------------------------------------------------------------
Write-Host "`n=== HPE COM migration: Direct -> Secure Gateway ('$Region') ===`n" -ForegroundColor Cyan

# Reuse the current session only when it already targets the requested workspace;
# otherwise establish a fresh session for that workspace.
$sessionValid = $Global:HPEGreenLakeSession -and $Global:HPEGreenLakeSession.workspaceName -eq $Workspace

if ($sessionValid) {
    Write-Host "HPE GreenLake   : reusing active session ('$($Global:HPEGreenLakeSession.workspaceName)')" -ForegroundColor Green
}
else {
    Write-Host "Connecting to HPE GreenLake..." -ForegroundColor Cyan
    if (-not $GLCredential) {
        $GLCredential = Get-Credential -Message "HPE GreenLake account credentials"
    }

    $connectGLParams = @{
        Credential                = $GLCredential
        Workspace                 = $Workspace
        RemoveExistingCredentials = $true
    }

    try {
        Connect-HPEGL @connectGLParams | Out-Null
    }
    catch {
        Write-Error "Failed to connect to HPE GreenLake: $($_.Exception.Message)"
        return
    }
    Write-Host "HPE GreenLake   : connected ('$($Global:HPEGreenLakeSession.workspaceName)')" -ForegroundColor Green
}

if (-not $Global:HPECOMRegions -or $Region -notin $Global:HPECOMRegions.region) {
    Write-Error "Region '$Region' is not provisioned in this workspace. Retrieve valid regions with: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned"
    return
}

# --------------------------------------------------------------------------------------
# Step 1 - Obtain iLO credentials
#   SharedCredential set : one PSCredential for every iLO (prompt if not supplied)
#   CsvCredential set    : per-iLO credentials read from a CSV keyed by IP address
# --------------------------------------------------------------------------------------
$csvCredentials = @{}

if ($PSCmdlet.ParameterSetName -eq 'CsvCredential') {
    Write-Host "Loading per-iLO credentials from '$CredentialCsvPath'..." -ForegroundColor Yellow
    $csvRows = Import-Csv -Path $CredentialCsvPath

    foreach ($row in $csvRows) {
        if (-not $row.IP -or -not $row.Username -or -not $row.Password) {
            Write-Error "CSV row is missing a value. Required columns: IP, Username, Password."
            return
        }
        $sec = ConvertTo-SecureString $row.Password -AsPlainText -Force
        $csvCredentials[$row.IP.Trim()] = [System.Management.Automation.PSCredential]::new($row.Username.Trim(), $sec)
    }

    Write-Host "Loaded credentials for $($csvCredentials.Count) iLO(s).`n" -ForegroundColor Green
}
else {
    if (-not $IloCredential) {
        Write-Host "Enter the iLO credentials shared by all target servers:" -ForegroundColor Yellow
        $IloCredential = Get-Credential -Message "iLO credentials for the servers to migrate"
    }
}

# --------------------------------------------------------------------------------------
# Step 2 - Resolve the Secure Gateway to route through
# --------------------------------------------------------------------------------------
if ($SecureGatewayName) {
    $SecureGateway = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGatewayName
    if (-not $SecureGateway) {
        Write-Error "Secure Gateway '$SecureGatewayName' was not found in region '$Region'."
        return
    }
}
else {
    $SecureGateway = Get-HPECOMAppliance -Region $Region -Type SecureGateway | Select-Object -First 1
    if (-not $SecureGateway) {
        Write-Error "No Secure Gateway appliance found in region '$Region'. Deploy and connect a Secure Gateway before migrating."
        return
    }
    $SecureGatewayName = $SecureGateway.name
}

Write-Host "`nSecure Gateway  : $SecureGatewayName (port $IloProxyPort)" -ForegroundColor Green

# --------------------------------------------------------------------------------------
# Step 3 - Retrieve the Direct-connected servers to migrate
# --------------------------------------------------------------------------------------
$DirectServers = Get-HPECOMServer -Region $Region -ConnectionType Direct 

if (-not $DirectServers) {
    Write-Host "`nNo Direct-connected servers found in region '$Region'. Nothing to migrate.`n" -ForegroundColor Yellow
    return
}

$serverCount = @($DirectServers).Count
Write-Host "`nServers to move : $serverCount Direct-connected server(s)`n" -ForegroundColor Green
$DirectServers | Select-Object name, serialNumber, iLOIPAddress, connectionType | Format-Table -AutoSize

# --------------------------------------------------------------------------------------
# Step 4 - Generate a COM activation key tied to the Secure Gateway
# --------------------------------------------------------------------------------------
Write-Host "`nGenerating a COM activation key tied to Secure Gateway '$SecureGatewayName'..." -ForegroundColor Cyan
$ActivationKey = New-HPECOMServerActivationKey -Region $Region -SecureGateway $SecureGatewayName -ExpirationInHours $ActivationKeyExpirationInHours

if (-not $ActivationKey) {
    Write-Error "Failed to generate a COM activation key for Secure Gateway '$SecureGatewayName'."
    return
}
Write-Host "Activation key  : generated (valid for $ActivationKeyExpirationInHours h)`n" -ForegroundColor Green

# --------------------------------------------------------------------------------------
# Step 5 - Reconnect every Direct-connected iLO through the Secure Gateway
#   -Force ............... disconnects the current Direct connection, then reconnects
#   -IloProxyServer/Port . configures the Secure Gateway as the iLO proxy
#   -Check ............... maps to -WhatIf for a read-only per-iLO preview
# --------------------------------------------------------------------------------------
$connectParams = @{
    ActivationKeyFromCOM = $ActivationKey
    IloProxyServer       = $SecureGatewayName
    IloProxyPort         = $IloProxyPort
    Force                = $true
}
if ($SkipCertificateValidation) { $connectParams.SkipCertificateValidation = $true }
if ($Check) { $connectParams.WhatIf = $true }

if ($Check) {
    Write-Host "`nPREVIEW MODE (-Check): no change will be made to the iLOs.`n" -ForegroundColor Yellow
}
else {
    Write-Host "`nMigrating $serverCount server(s) to the Secure Gateway connection...`n" -ForegroundColor Cyan
}

if ($PSCmdlet.ParameterSetName -eq 'CsvCredential') {
    # Per-iLO credentials: match each Direct server to its CSV row by iLO IP, then migrate
    # one server at a time so each connection uses its own credential.
    $results = [System.Collections.ArrayList]::new()

    foreach ($server in $DirectServers) {
        $iloIp = $server.iLOIPAddress
        $cred = $csvCredentials[$iloIp]

        if (-not $cred) {
            Write-Warning "iLO '$iloIp' (server '$($server.name)') has no matching row in the CSV. Skipping."
            continue
        }

        $perServerParams = $connectParams.Clone()
        $perServerParams.IloCredential = $cred

        $r = $server | Connect-HPEGLDeviceComputeiLOtoCOM @perServerParams
        if ($r) { [void]$results.Add($r) }
    }
}
else {
    # Shared credential: migrate every server in a single pipeline operation.
    $connectParams.IloCredential = $IloCredential
    $results = $DirectServers | Connect-HPEGLDeviceComputeiLOtoCOM @connectParams
}

# --------------------------------------------------------------------------------------
# Step 6 - Report
# --------------------------------------------------------------------------------------
if (-not $Check -and $results) {
    Write-Host "`n=== Migration results ===`n" -ForegroundColor Cyan
    $results | Format-Table iLO, SerialNumber, Status, Details -AutoSize

    # Only 'Complete' counts as a successful migration. 'Failed' and 'Warning'
    # (e.g. iLO unreachable, no action taken) both mean the server was NOT migrated.
    $notMigrated = @($results | Where-Object Status -ne 'Complete')
    if ($notMigrated.Count -gt 0) {
        Write-Host "$($notMigrated.Count) server(s) did not complete the migration. Review the Details column above." -ForegroundColor Red
    }
    else {
        Write-Host "All servers migrated successfully to the Secure Gateway connection." -ForegroundColor Green
    }
}

Write-Host ""



