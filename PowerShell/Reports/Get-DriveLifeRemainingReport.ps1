#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.26' }

<#
.SYNOPSIS
    Generates a Drive Life Remaining (SSD wear) report for every server managed by HPE
    Compute Ops Management (COM) in a given region, with an optional CSV export.

.DESCRIPTION
    HPE Compute Ops Management continuously tracks the remaining write endurance of the
    solid-state drives (SSDs) installed in your servers and buckets each drive into a
    "drive life remaining" range. This script surfaces that data from the COM "Server
    hardware inventory" report so you can proactively spot drives that are wearing out
    before they fail. It performs the following steps:

        1. Connects to HPE GreenLake (reusing an existing valid session when possible),
           then validates the target region.
        2. Locates the region's Server hardware inventory report.
        3. Retrieves the fleet-wide drive-life summary (how many drives and servers fall
           into each wear range: 0-15%, 15-25%, 25-50%, 50-100%, and Unknown).
        4. Drills into each range to list the individual servers that own drives in that
           range, enriched with server model and connection type.
        5. Prints a colour-coded summary and a per-server detail table, highlights the
           drives that need attention, and (optionally) exports the detail to CSV.

    This is a read-only reporting script: it never changes any server or drive setting.

    NOTE: The COM drive-life report groups results by wear range and by server; it does
    not expose the exact per-drive percentage or the drive serial number. Use
    -EnrichCriticalDrives to fetch the exact per-drive life %, model, serial and media
    type - but ONLY for the (small) set of servers the report already flagged below 50%,
    so the fleet scan stays fast even with thousands of servers.

.PARAMETER Region
    (Mandatory) The COM region code to report on (e.g. 'eu-central', 'us-west').
    Retrieve valid region codes with:
        Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned

.PARAMETER GLCredential
    (Optional) A PSCredential holding your HPE GreenLake account email and password, used
    to connect to HPE GreenLake at the start of the script. If omitted and no valid session
    already exists, the script prompts for it interactively. Ignored when a valid session
    for the requested workspace is already active.

    Use this for a native HPE account (single-factor or MFA) OR a password-based SAML SSO
    account - federation is auto-detected from your email domain, so no special handling is
    needed for SSO accounts that still use a password. For fully passwordless SSO
    (push / TOTP, no password), use -PasswordlessSSOEmail instead. Cannot be combined with
    -PasswordlessSSOEmail.

.PARAMETER PasswordlessSSOEmail
    (Optional) The email address to sign in with when your Identity Provider is configured
    for fully passwordless SSO (Okta / Entra ID / PingIdentity push notification or TOTP,
    no password). When supplied, the script connects with Connect-HPEGL -PasswordlessSSOEmail
    and you approve the sign-in on your device. Cannot be combined with -GLCredential. Only
    SAML 2.0 federation is supported; OIDC-federated workspaces must use -GLCredential.

.PARAMETER Workspace
    (Mandatory) The HPE GreenLake workspace that owns the servers. The script connects to
    (or switches to) this workspace with a fresh sign-in, and only reuses an existing
    session when it already targets this same workspace.

.PARAMETER ExportPath
    (Optional) Path to export the per-server detail as a CSV file. If a directory is
    supplied, a timestamped file name is generated inside it. If omitted, no CSV is written.

.PARAMETER CriticalOnly
    (Optional) Restricts the per-server detail (and CSV export) to drives with less than
    50% life remaining - the ranges that actually warrant action (0-15%, 15-25%, 25-50%).
    The fleet summary always shows every range regardless of this switch.

.PARAMETER IncludeUnknown
    (Optional) Also drills into the "Unknown" range in the per-server detail. Drives report
    Unknown when COM has no wear data for them (for example spinning HDDs, or SSDs whose
    inventory has not been collected yet). Off by default because these rows are rarely
    actionable and can be numerous.

.PARAMETER EnrichCriticalDrives
    (Optional) After the fleet report identifies which servers have drives below 50% life
    remaining, this switch collects the exact per-drive life percentage, drive model,
    serial, media type and physical location for that shortlist only - by calling
    Get-HPECOMServerInventory once per shortlisted server. Because the shortlist is
    naturally small, this stays fast even on very large fleets. It is NEVER run against the
    whole fleet.

.PARAMETER MaxEnrichServers
    (Optional) Safety cap on how many shortlisted servers -EnrichCriticalDrives will query.
    Defaults to 200. If the sub-50% shortlist is larger, only the worst-first first N are
    enriched and a warning is shown. Raise this to include more.

.PARAMETER PassThru
    (Optional) Emits the detail objects to the pipeline (in addition to the on-screen
    report) so they can be captured, filtered, or piped further. With -EnrichCriticalDrives
    the emitted objects are the per-drive detail; otherwise they are the per-server detail.

.EXAMPLE
    .\Get-DriveLifeRemainingReport.ps1 -Region eu-central -Workspace 'Production'

    Connects to the 'Production' workspace (reusing an active session, or prompting for
    credentials) and prints the fleet drive-life summary plus a per-server detail table
    for eu-central.

    Sample output:

        === HPE COM Drive Life Remaining report ('eu-central') ===

        HPE GreenLake   : connected ('Production')
        Report          : Server hardware inventory report
        Servers in fleet: 28

        === Fleet summary (by drive life remaining) ===

        Drive Life Range   Severity  DriveCount ServerCount
        ----------------   --------  ---------- -----------
        0-15% (Critical)   Critical           0           0
        15-25% (Warning)   Warning            0           0
        25-50% (Monitor)   Monitor            0           0
        50-100% (Healthy)  Healthy            6           3
        Unknown            Unknown           10           5

        Servers with drive-life data: 8 of 28 in fleet.

        === Servers with drives below 50% life remaining ===

        No drives are below 50% life remaining. Nothing to action.

        === Servers by drive life range ===

        ServerName        SerialNumber Model                 ConnectionType DriveLifeRange    DriveCount
        ----------        ------------ -----                 -------------- --------------    ----------
        localhost.lj.lab  CZ2311049Z   ProLiant DL360 Gen11  Direct         50-100% (Healthy)          2
        localhost.lj.lab  CZ231104B0   ProLiant DL360 Gen11  Direct         50-100% (Healthy)          2
        RHEL92-2.lj.lab   CZ2311004G   ProLiant DL360 Gen11  Direct         50-100% (Healthy)          2

.EXAMPLE
    $glCred = Get-Credential
    .\Get-DriveLifeRemainingReport.ps1 -Region eu-central -GLCredential $glCred -Workspace 'Production' -ExportPath 'C:\Reports\'

    Connects with the supplied account and writes the per-server detail to a timestamped
    CSV under C:\Reports\ (e.g. DriveLifeRemaining_eu-central_2026-07-29_1030.csv).

.EXAMPLE
    .\Get-DriveLifeRemainingReport.ps1 -Region us-west -Workspace 'Production' -CriticalOnly -ExportPath '.\worn-drives.csv'

    Reports only the servers whose drives have dropped below 50% life remaining in us-west
    and exports that shortlist to .\worn-drives.csv - ideal for a drive-replacement backlog.

.EXAMPLE
    $worn = .\Get-DriveLifeRemainingReport.ps1 -Region eu-central -Workspace 'Production' -CriticalOnly -PassThru
    $worn | Where-Object Severity -eq 'Critical' | Sort-Object ServerName

    Captures the detail objects and filters them in the pipeline for further processing.

.EXAMPLE
    .\Get-DriveLifeRemainingReport.ps1 -Region eu-central -Workspace 'Production' -EnrichCriticalDrives -ExportPath 'C:\Reports\'

    Runs the fast fleet scan, then - only for the servers flagged below 50% life remaining -
    collects the exact per-drive life %, model and serial via Get-HPECOMServerInventory, and
    writes both the range summary CSV and a per-drive CSV under C:\Reports\. The whole-fleet
    path stays at a handful of API calls; per-server calls are spent only on the shortlist.

.OUTPUTS
    System.Management.Automation.PSCustomObject

        When -PassThru is specified, one object per (server, drive-life range) pair is
        emitted, each containing:
        * ServerName     - Server name (or hostname) as reported by COM.
        * SerialNumber   - Server serial number.
        * Model          - Server hardware model (when known).
        * ConnectionType - Direct, Secure Gateway, or OneView managed.
        * DriveLifeRange - Human-readable wear range label.
        * Severity       - Critical / Warning / Monitor / Healthy / Unknown.
        * DriveCount     - Number of the server's drives that fall in this range.
        * NoValueReason  - COM-supplied reason when the wear value is unavailable.
        * Region         - The COM region the data came from.
        * ServerId       - COM server identifier (partNumber+serialNumber).

        When both -PassThru and -EnrichCriticalDrives are specified, per-drive objects are
        emitted instead, each containing: ServerName, SerialNumber, Model, ConnectionType,
        Controller, DriveName, DriveModel, DriveSerial, MediaType, Location,
        LifeLeftPercent, DriveSeverity, FailurePredicted, Health and Region.

.NOTES
    PREREQUISITES
    -------------
    - PowerShell 7.0 or later.
    - The HPECOMCmdlets module v1.0.26+ installed (Install-Module HPECOMCmdlets).
    - HPE GreenLake account credentials with access to the workspace that owns the servers.
    - Compute Ops Management provisioned in the target region.
    - Server inventory collected at least once so the hardware inventory report exists
      (New-HPECOMServerInventory), otherwise there is no drive-life data to report.

    Author : Lionel Jullien (HPE)
    Module : HPECOMCmdlets

.LINK
    https://github.com/jullienl/HPE-Compute-Ops-Management
    https://github.com/jullienl/HPE-COM-PowerShell-Library
    https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Region,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$GLCredential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PasswordlessSSOEmail,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Workspace,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$CriticalOnly,

    [Parameter()]
    [switch]$IncludeUnknown,

    [Parameter()]
    [switch]$EnrichCriticalDrives,

    [Parameter()]
    [ValidateRange(1, 10000)]
    [int]$MaxEnrichServers = 200,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------
# Drive-life range metadata: label, severity and display order for each COM wear bucket.
# --------------------------------------------------------------------------------------
$RangeMeta = [ordered]@{
    'RANGE_0_15'    = [PSCustomObject]@{ Label = '0-15% (Critical)'; Severity = 'Critical'; Order = 1; Color = 'Red' }
    'RANGE_15_25'   = [PSCustomObject]@{ Label = '15-25% (Warning)'; Severity = 'Warning'; Order = 2; Color = 'DarkYellow' }
    'RANGE_25_50'   = [PSCustomObject]@{ Label = '25-50% (Monitor)'; Severity = 'Monitor'; Order = 3; Color = 'Yellow' }
    'RANGE_50_100'  = [PSCustomObject]@{ Label = '50-100% (Healthy)'; Severity = 'Healthy'; Order = 4; Color = 'Green' }
    'RANGE_UNKNOWN' = [PSCustomObject]@{ Label = 'Unknown'; Severity = 'Unknown'; Order = 5; Color = 'Gray' }
}

# Maps a COM connectionType code to a friendly label.
function ConvertTo-FriendlyConnectionType {
    param([string]$ConnectionType)
    switch ($ConnectionType) {
        'GATEWAY' { 'Secure Gateway' }
        'ONEVIEW' { 'OneView managed' }
        'DIRECT' { 'Direct' }
        default { $ConnectionType }
    }
}

# Maps an exact drive life percentage to a severity bucket (matches the report ranges).
function Get-DriveSeverityFromPercent {
    param([Nullable[double]]$Percent)
    if ($null -eq $Percent) { return 'Unknown' }
    if ($Percent -lt 15) { 'Critical' }
    elseif ($Percent -lt 25) { 'Warning' }
    elseif ($Percent -lt 50) { 'Monitor' }
    else { 'Healthy' }
}

# Retrieves all rows of a drive-life report grouping, transparently paging through results.
function Get-DriveLifeReportRows {
    param(
        [Parameter(Mandatory)] [string]$ReportId,
        [Parameter(Mandatory)] [string]$GroupBy,
        [Parameter()]          [string]$Filter,
        [Parameter(Mandatory)] [string]$Region
    )

    $limit = 50
    $offset = 0
    $rows = [System.Collections.ArrayList]::new()

    do {
        $uri = "/ui-doorway/compute/v2/reports/$ReportId/data?group-by=$GroupBy&limit=$limit&offset=$offset"
        if ($Filter) {
            $uri += "&filter=$Filter"
        }

        $response = Invoke-HPECOMWebRequest -Region $Region -Uri $uri -Method GET

        $page = $response.data.rows
        $total = [int]$page.total

        if ($page.items) {
            foreach ($item in $page.items) {
                [void]$rows.Add($item)
            }
        }

        $offset += $limit

    } while ($offset -lt $total)

    return $rows
}

# --------------------------------------------------------------------------------------
# Step 0 - Connect to HPE GreenLake (reuse an existing valid session when possible)
# --------------------------------------------------------------------------------------
Write-Host "`n=== HPE COM Drive Life Remaining report ('$Region') ===`n" -ForegroundColor Cyan

# -Credential (native / password-based SSO) and -PasswordlessSSOEmail are mutually exclusive.
if ($GLCredential -and $PasswordlessSSOEmail) {
    Write-Error "Specify either -GLCredential (HPE account / password-based SSO) or -PasswordlessSSOEmail (passwordless SSO), not both."
    return
}

# Reuse the current session only when it already targets the requested workspace;
# otherwise establish a fresh session for that workspace.
$sessionValid = $Global:HPEGreenLakeSession -and $Global:HPEGreenLakeSession.workspace -eq $Workspace -and $Global:HPEGreenLakeSession.IsValid

if ($sessionValid) {
    Write-Host "HPE GreenLake   : reusing active session ('$($Global:HPEGreenLakeSession.workspace)')" -ForegroundColor Green
}
else {
    Write-Host "Connecting to HPE GreenLake..." -ForegroundColor Cyan

    $connectGLParams = @{
        Workspace                 = $Workspace
        RemoveExistingCredentials = $true
    }

    if ($PasswordlessSSOEmail) {
        # Passwordless SSO (push / TOTP): no password is used or prompted for. You approve
        # the sign-in on your authenticator device.
        $connectGLParams.PasswordlessSSOEmail = $PasswordlessSSOEmail
    }
    else {
        # HPE account or password-based SAML SSO. Federation is auto-detected from the email
        # domain, so the same -Credential path covers both non-SSO and password-based SSO.
        if (-not $GLCredential) {
            $GLCredential = Get-Credential -Message "HPE GreenLake account credentials"
        }
        $connectGLParams.Credential = $GLCredential
    }

    try {
        Connect-HPEGL @connectGLParams | Out-Null
    }
    catch {
        Write-Error "Failed to connect to HPE GreenLake: $($_.Exception.Message)"
        return
    }
    Write-Host "HPE GreenLake   : connected ('$($Global:HPEGreenLakeSession.workspace)')" -ForegroundColor Green
}

if (-not $Global:HPECOMRegions -or $Region -notin $Global:HPECOMRegions.region) {
    Write-Error "Region '$Region' is not provisioned in this workspace. Retrieve valid regions with: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned"
    return
}

# --------------------------------------------------------------------------------------
# Step 1 - Locate the Server hardware inventory report for the region
# --------------------------------------------------------------------------------------
try {
    $Report = Get-HPECOMReport -Region $Region -ServerHardwareInventoryReport
}
catch {
    Write-Error "Unable to locate the Server hardware inventory report in region '$Region'. Collect server inventory first with New-HPECOMServerInventory. ($($_.Exception.Message))"
    return
}

$ReportId = $Report.id

if (-not $ReportId) {
    Write-Error "No Server hardware inventory report is available in region '$Region'. Collect server inventory first with New-HPECOMServerInventory."
    return
}

Write-Host "Report          : $($Report.name)" -ForegroundColor Green

# --------------------------------------------------------------------------------------
# Retrieve every server in the region ONCE. This gives the true fleet total and doubles
# as the model / connection-type enrichment index used later. A single call keeps the
# scan efficient even for large fleets.
# --------------------------------------------------------------------------------------
$ServerIndex = @{}
$AllServers = @()
try {
    $AllServers = Get-HPECOMServer -Region $Region
    foreach ($srv in $AllServers) {
        if ($srv.serialNumber) {
            $ServerIndex[$srv.serialNumber] = $srv
        }
    }
}
catch {
    # Enrichment is best-effort; the report still works without it.
    Write-Verbose "Could not retrieve server list for enrichment: $($_.Exception.Message)"
}
$FleetTotal = @($AllServers).Count
Write-Host "Servers in fleet: $FleetTotal" -ForegroundColor Green

# --------------------------------------------------------------------------------------
# Step 2 - Fetch the fleet-wide drive-life summary (counts per wear range)
# --------------------------------------------------------------------------------------
try {
    $SummaryRows = Get-DriveLifeReportRows -ReportId $ReportId -GroupBy 'DRIVE_LIFE_PERCENTAGE' -Region $Region
}
catch {
    Write-Error "Failed to retrieve the drive-life summary: $($_.Exception.Message)"
    return
}

if (-not $SummaryRows) {
    Write-Host "`nNo drive-life data is available for region '$Region'. Nothing to report.`n" -ForegroundColor Yellow
    return
}

# Build the summary objects in wear-range order.
$Summary = foreach ($row in $SummaryRows) {
    $meta = $RangeMeta[$row.remainingDriveLifeRange]
    [PSCustomObject]@{
        DriveLifeRange = if ($meta) { $meta.Label } else { $row.remainingDriveLifeRange }
        Severity       = if ($meta) { $meta.Severity } else { 'Unknown' }
        DriveCount     = [int]$row.driveCount
        ServerCount    = [int]$row.serverCount
        Order          = if ($meta) { $meta.Order } else { 99 }
        RangeCode      = $row.remainingDriveLifeRange
    }
}
$Summary = $Summary | Sort-Object Order

Write-Host "`n=== Fleet summary (by drive life remaining) ===`n" -ForegroundColor Cyan
$Summary | Format-Table DriveLifeRange, Severity, DriveCount, ServerCount -AutoSize | Out-Host

# 'ServerCount' is reported per wear range, so a server whose drives span several ranges is
# counted in each of them - summing the column would over-count. Servers with no drive-life
# data at all (HDD-only, no drives, or inventory not yet collected) are absent from the report,
# which is why this figure is normally lower than the total fleet size shown above.
Write-Host ("Note: ServerCount is per wear range (a server can appear in several); servers with no drive-life data are not listed.") -ForegroundColor DarkGray

# --------------------------------------------------------------------------------------
# Step 3 - Decide which wear ranges to drill into for the per-server detail
# --------------------------------------------------------------------------------------
$KnownActionRanges = @('RANGE_0_15', 'RANGE_15_25', 'RANGE_25_50')

if ($CriticalOnly) {
    $TargetRanges = $KnownActionRanges
}
else {
    $TargetRanges = @('RANGE_0_15', 'RANGE_15_25', 'RANGE_25_50', 'RANGE_50_100')
    if ($IncludeUnknown) {
        $TargetRanges += 'RANGE_UNKNOWN'
    }
}

# Only query ranges that actually contain servers, to avoid empty round-trips.
$RangesWithServers = ($Summary | Where-Object { $_.ServerCount -gt 0 }).RangeCode
$TargetRanges = $TargetRanges | Where-Object { $_ -in $RangesWithServers }

# --------------------------------------------------------------------------------------
# Step 4 - Drill into each target range to build the per-server detail
#   (the fleet server list was already retrieved above and reused as $ServerIndex)
# --------------------------------------------------------------------------------------
$Detail = [System.Collections.ArrayList]::new()

foreach ($rangeCode in $TargetRanges) {
    $meta = $RangeMeta[$rangeCode]
    $filter = "data/rows/items/remainingDriveLifeRange eq '$rangeCode'"

    try {
        $rows = Get-DriveLifeReportRows -ReportId $ReportId -GroupBy 'DRIVE_LIFE_AND_SERVER' -Filter $filter -Region $Region
    }
    catch {
        Write-Warning "Failed to retrieve server detail for range '$($meta.Label)': $($_.Exception.Message)"
        continue
    }

    foreach ($row in $rows) {
        # serverId is formatted as '<partNumber>+<serialNumber>'.
        $serial = ($row.serverId -split '\+')[-1]
        $srv = if ($serial) { $ServerIndex[$serial] } else { $null }

        [void]$Detail.Add([PSCustomObject]@{
                ServerName     = if ($row.serverName) { $row.serverName } elseif ($srv) { $srv.name } else { $serial }
                SerialNumber   = $serial
                Model          = if ($srv -and $srv.hardware.model) { $srv.hardware.model } else { $null }
                ConnectionType = if ($srv) { ConvertTo-FriendlyConnectionType -ConnectionType $srv.connectionType } else { $null }
                DriveLifeRange = $meta.Label
                Severity       = $meta.Severity
                DriveCount     = [int]$row.driveCount
                NoValueReason  = $row.noValueReason
                Region         = $Region
                ServerId       = $row.serverId
                Order          = $meta.Order
            })
    }
}

# Sort worst-first, then by server name.
$Detail = $Detail | Sort-Object Order, ServerName

# --------------------------------------------------------------------------------------
# Step 5 - Highlight the drives that actually need attention (below 50% life remaining)
# --------------------------------------------------------------------------------------
$Actionable = $Detail | Where-Object { $_.Severity -in @('Critical', 'Warning', 'Monitor') }

Write-Host "`n=== Servers with drives below 50% life remaining ===`n" -ForegroundColor Cyan
if ($Actionable) {
    $Actionable | Format-Table ServerName, SerialNumber, Model, ConnectionType, DriveLifeRange, DriveCount -AutoSize | Out-Host
}
else {
    Write-Host "No drives are below 50% life remaining. Nothing to action.`n" -ForegroundColor Green
}

# --------------------------------------------------------------------------------------
# Step 6 - Full per-server detail table
# --------------------------------------------------------------------------------------
if ($Detail) {
    Write-Host "=== Servers by drive life range ===`n" -ForegroundColor Cyan
    $Detail | Format-Table ServerName, SerialNumber, Model, ConnectionType, DriveLifeRange, DriveCount -AutoSize | Out-Host

    $ServersWithData = @($Detail | Select-Object -ExpandProperty SerialNumber -Unique | Where-Object { $_ }).Count
    if ($CriticalOnly) {
        Write-Host ("Servers shown: $ServersWithData (drives below 50% life remaining) - of $FleetTotal in fleet.") -ForegroundColor Gray
    }
    else {
        Write-Host ("Servers with drive-life data: $ServersWithData of $FleetTotal in fleet.") -ForegroundColor Gray
    }
}

# --------------------------------------------------------------------------------------
# Step 6b - Explain the gap between the fleet and the drive-life report
#   A server is absent from the drive-life report when COM has no drive-life row for it.
#   That happens for one of two reasons, which we classify here so the gap is explicit:
#     - Inventory not yet collected  -> lastFullInventoryCollectionAt is empty
#     - No drive-life data           -> inventory exists, but no drive reports wear/life
#                                       (HDD-only, no drives, or drives without SSD wear data)
#   Only meaningful for the full (non -CriticalOnly) report, where every range is queried.
# --------------------------------------------------------------------------------------
if (-not $CriticalOnly -and $AllServers) {

    $ReportedSerials = @{}
    foreach ($serial in ($Detail | Select-Object -ExpandProperty SerialNumber -Unique | Where-Object { $_ })) {
        $ReportedSerials[$serial] = $true
    }

    $NoInventory = [System.Collections.ArrayList]::new()
    $NoDriveData = [System.Collections.ArrayList]::new()

    foreach ($srv in $AllServers) {
        if ($srv.serialNumber -and -not $ReportedSerials.ContainsKey($srv.serialNumber)) {
            if ($srv.lastFullInventoryCollectionAt) {
                [void]$NoDriveData.Add($srv)
            }
            else {
                [void]$NoInventory.Add($srv)
            }
        }
    }

    $MissingTotal = $NoInventory.Count + $NoDriveData.Count

    if ($MissingTotal -gt 0) {
        Write-Host "`n=== Fleet servers not in the drive-life report ($MissingTotal of $FleetTotal) ===`n" -ForegroundColor Cyan

        if ($NoInventory.Count -gt 0) {
            Write-Host ("Inventory not yet collected : {0} server(s) - run New-HPECOMServerInventory to include them." -f $NoInventory.Count) -ForegroundColor Yellow
        }
        if ($NoDriveData.Count -gt 0) {
            Write-Host ("No drive-life data          : {0} server(s) - HDD-only, no drives, or drives that do not report wear." -f $NoDriveData.Count) -ForegroundColor Gray
        }

        # Show the servers awaiting inventory (the actionable group); keep it concise.
        if ($NoInventory.Count -gt 0) {
            $NoInventory |
            Select-Object @{N = 'ServerName'; E = { $_.name } },
            @{N = 'SerialNumber'; E = { $_.serialNumber } },
            @{N = 'Model'; E = { $_.hardware.model } },
            @{N = 'ConnectionType'; E = { ConvertTo-FriendlyConnectionType -ConnectionType $_.connectionType } } |
            Sort-Object ServerName |
            Format-Table -AutoSize | Out-Host
        }
    }
}

# --------------------------------------------------------------------------------------
# Step 7 - Optional per-drive enrichment (exact life %) for the sub-50% shortlist ONLY
#   The report groups drives by wear range only. To get the exact PredictedMediaLifeLeft
#   percentage, drive model and serial, we call Get-HPECOMServerInventory per server - but
#   ONLY for the (small) set of servers the report already flagged below 50%. This keeps
#   the fleet scan at a handful of calls while still giving precise per-drive data, and
#   never issues one call per server across the whole fleet.
# --------------------------------------------------------------------------------------
$DriveDetail = [System.Collections.ArrayList]::new()

if ($EnrichCriticalDrives) {

    # Distinct servers from the sub-50% shortlist (worst-first order preserved).
    $EnrichTargets = $Actionable | Group-Object SerialNumber | ForEach-Object { $_.Group[0] }

    Write-Host "=== Per-drive enrichment ===`n" -ForegroundColor Cyan

    if (-not $EnrichTargets) {
        Write-Host " No servers below 50% life remaining - nothing to enrich.`n" -ForegroundColor Green
    }
    else {
        $targetCount = @($EnrichTargets).Count

        if ($targetCount -gt $MaxEnrichServers) {
            Write-Warning "The sub-50% shortlist has $targetCount server(s), above the -MaxEnrichServers cap ($MaxEnrichServers). Only the first $MaxEnrichServers (worst-first) will be enriched. Raise -MaxEnrichServers to include more."
            $EnrichTargets = $EnrichTargets | Select-Object -First $MaxEnrichServers
            $targetCount = $MaxEnrichServers
        }

        Write-Host " Collecting per-drive life data for $targetCount server(s)...`n" -ForegroundColor Cyan

        $i = 0
        foreach ($target in $EnrichTargets) {
            $i++
            Write-Progress -Activity "Collecting per-drive life data" -Status "$($target.ServerName) ($($target.SerialNumber))" -PercentComplete (($i / $targetCount) * 100)

            try {
                $controllers = Get-HPECOMServerInventory -Region $Region -Name $target.SerialNumber -ShowStorageController -Verbose:$false
            }
            catch {
                Write-Warning "Could not collect storage inventory for '$($target.ServerName)' ($($target.SerialNumber)): $($_.Exception.Message)"
                continue
            }

            foreach ($ctrl in $controllers) {
                foreach ($drive in $ctrl.Drives) {
                    $pct = if ($null -ne $drive.PredictedMediaLifeLeftPercent) { [double]$drive.PredictedMediaLifeLeftPercent } else { $null }

                    [void]$DriveDetail.Add([PSCustomObject]@{
                            ServerName       = $target.ServerName
                            SerialNumber     = $target.SerialNumber
                            Model            = $target.Model
                            ConnectionType   = $target.ConnectionType
                            Controller       = $ctrl.Controllers.Model
                            DriveName        = $drive.Name
                            DriveModel       = $drive.Model
                            DriveSerial      = $drive.SerialNumber
                            MediaType        = $drive.MediaType
                            Location         = $drive.PhysicalLocation.PartLocation.ServiceLabel
                            LifeLeftPercent  = $pct
                            DriveSeverity    = Get-DriveSeverityFromPercent -Percent $pct
                            FailurePredicted = [bool]$drive.FailurePredicted
                            Health           = $drive.Status.health
                            Region           = $Region
                        })
                }
            }
        }
        Write-Progress -Activity "Collecting per-drive life data" -Completed

        # Worst-worn drives first, then by server and physical location.
        $DriveDetail = $DriveDetail | Sort-Object `
        @{ Expression = { switch ($_.DriveSeverity) { 'Critical' { 1 } 'Warning' { 2 } 'Monitor' { 3 } 'Healthy' { 4 } default { 5 } } } }, `
            ServerName, Location

        if ($DriveDetail) {
            $DriveDetail |
            Format-Table ServerName, SerialNumber, DriveName, DriveSerial, MediaType, Location, LifeLeftPercent, DriveSeverity, FailurePredicted -AutoSize | Out-Host
        }
        else {
            Write-Host " No drive data returned for the shortlisted servers.`n" -ForegroundColor Yellow
        }
    }
}

# --------------------------------------------------------------------------------------
# Step 8 - Recommendations
# --------------------------------------------------------------------------------------
$critDrives = (($Summary | Where-Object RangeCode -eq 'RANGE_0_15').DriveCount) | ForEach-Object { [int]$_ }
$warnDrives = (($Summary | Where-Object RangeCode -eq 'RANGE_15_25').DriveCount) | ForEach-Object { [int]$_ }
$monDrives = (($Summary | Where-Object RangeCode -eq 'RANGE_25_50').DriveCount) | ForEach-Object { [int]$_ }

Write-Host "=== Recommendations ===`n" -ForegroundColor Cyan
if ($critDrives -gt 0) {
    Write-Host " [Critical] $critDrives drive(s) are below 15% life remaining - replace them as soon as possible." -ForegroundColor Red
}
if ($warnDrives -gt 0) {
    Write-Host " [Warning]  $warnDrives drive(s) are between 15% and 25% - order replacements and schedule maintenance." -ForegroundColor DarkYellow
}
if ($monDrives -gt 0) {
    Write-Host " [Monitor]  $monDrives drive(s) are between 25% and 50% - keep an eye on these over the coming months." -ForegroundColor Yellow
}
if (($critDrives + $warnDrives + $monDrives) -eq 0) {
    Write-Host " All drives with wear data are above 50% life remaining. No action required." -ForegroundColor Green
}
if (-not $EnrichCriticalDrives) {
    Write-Host " For the exact per-drive life %, model and serial of the worn drives, re-run with -EnrichCriticalDrives." -ForegroundColor Gray
}
Write-Host ""

# --------------------------------------------------------------------------------------
# Step 9 - Optional CSV export
# --------------------------------------------------------------------------------------
if ($ExportPath) {
    # If a directory was supplied, generate a timestamped file name inside it.
    if (Test-Path -LiteralPath $ExportPath -PathType Container) {
        $fileName = "DriveLifeRemaining_{0}_{1}.csv" -f $Region, (Get-Date -Format 'yyyy-MM-dd_HHmm')
        $ExportFile = Join-Path -Path $ExportPath -ChildPath $fileName
    }
    else {
        $ExportFile = $ExportPath
    }

    try {
        $Detail |
        Select-Object ServerName, SerialNumber, Model, ConnectionType, DriveLifeRange, Severity, DriveCount, NoValueReason, Region, ServerId |
        Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
        Write-Host "CSV exported    : $ExportFile" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to export CSV to '$ExportFile': $($_.Exception.Message)"
    }

    # When per-drive enrichment ran, export it to a sibling CSV alongside the summary.
    if ($EnrichCriticalDrives -and $DriveDetail) {
        if (Test-Path -LiteralPath $ExportPath -PathType Container) {
            $driveFile = Join-Path -Path $ExportPath -ChildPath ("DriveLifeRemaining_Drives_{0}_{1}.csv" -f $Region, (Get-Date -Format 'yyyy-MM-dd_HHmm'))
        }
        else {
            $driveFile = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($ExportFile),
                [System.IO.Path]::GetFileNameWithoutExtension($ExportFile) + '_drives.csv')
        }
        try {
            $DriveDetail |
            Select-Object ServerName, SerialNumber, Model, ConnectionType, Controller, DriveName, DriveModel, DriveSerial, MediaType, Location, LifeLeftPercent, DriveSeverity, FailurePredicted, Health, Region |
            Export-Csv -Path $driveFile -NoTypeInformation -Encoding UTF8
            Write-Host "Drive CSV       : $driveFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to export per-drive CSV to '$driveFile': $($_.Exception.Message)"
        }
    }
}

Write-Host ""

# --------------------------------------------------------------------------------------
# Step 10 - Emit detail objects to the pipeline when requested
# --------------------------------------------------------------------------------------
if ($PassThru) {
    if ($EnrichCriticalDrives -and $DriveDetail) {
        $DriveDetail | Select-Object ServerName, SerialNumber, Model, ConnectionType, Controller, DriveName, DriveModel, DriveSerial, MediaType, Location, LifeLeftPercent, DriveSeverity, FailurePredicted, Health, Region
    }
    else {
        $Detail | Select-Object ServerName, SerialNumber, Model, ConnectionType, DriveLifeRange, Severity, DriveCount, NoValueReason, Region, ServerId
    }
}
