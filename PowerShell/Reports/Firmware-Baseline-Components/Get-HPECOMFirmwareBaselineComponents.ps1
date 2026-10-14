#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.26' }

<##
.SYNOPSIS
    Retrieves component details for an HPE Service Pack for ProLiant (SPP).

.DESCRIPTION
    This read-only reporting script:

        1. Connects to HPE GreenLake and validates the Compute Ops Management region.
        2. Retrieves an SPP baseline with Get-HPECOMFirmwareBaseline.
        3. Resolves the matching public HPE Contents Report online:
             a. Public https://support.hpe.com/docs/display/public/a00sppdocen_US/spp/assets/config.json confirms
                the release exists.
             b. Public https://support.hpe.com/docs/display/public/a00sppdocen_US/spp/assets/gen{generation}.{releaseVersion}.json
                returns QuickLinks.
             c. The Contents Report link gives the support document ID.
        4. Downloads the PDF from https://support.hpe.com/hpesc/public/api/document/{docId} and uses PdfPig to
           parse the component data.
        5. Prints a summary and optionally exports component data to CSV.

    PdfPig assemblies required for PDF extraction must be placed in the script's lib\PdfPig-1.7.0-custom-5 folder.

.PARAMETER Region
    COM region code, for example eu-central or us-west.

.PARAMETER Workspace
    HPE GreenLake workspace name.

.PARAMETER Generation
    ProLiant generation: 10, 11, or 12.

.PARAMETER ReleaseVersion
    Optional SPP release version. When omitted, the latest BASE SPP is used.

.PARAMETER GLCredential
    Optional HPE GreenLake credential.

.PARAMETER PasswordlessSSOEmail
    Optional passwordless SSO email address.

.PARAMETER ExportPath
    Optional CSV file or directory path.

.PARAMETER PassThru
    Emits component objects to the pipeline.

.EXAMPLE
    .\Get-HPECOMFirmwareBaselineComponents.ps1 -Region eu-central -Workspace Production -Generation 12

    Retrieve component details for the specified HPE Service Pack for ProLiant (SPP).

.EXAMPLE
    .\Get-HPECOMFirmwareBaselineComponents.ps1 -Region eu-central -Workspace Production -Generation 12 -ReleaseVersion 2026.07.00.00 -ExportPath .\spp.csv

    Retrieve component details for the specified HPE Service Pack for ProLiant (SPP) and export the data to a CSV file if the ExportPath parameter is provided.

.EXAMPLE

    .\Get-HPECOMFirmwareBaselineComponents.ps1 -Region eu-central -Workspace Production -Generation 12 -ReleaseVersion 2026.07.00.00 -PassThru | ConvertTo-Json -Depth 5

    Retrieve component details for the specified HPE Service Pack for ProLiant (SPP) and output the data as JSON.

.EXAMPLE
    $GLCredential = Get-Credential
    $components = .\Get-HPECOMFirmwareBaselineComponents.ps1 -Region eu-central -Workspace Production -GLCredential $GLCredential -Generation 12 -ReleaseVersion 2026.07.00.00 -PassThru 

    Retrieve component details for the specified HPE Service Pack for ProLiant (SPP) and store them in the $components variable.

    Count the number of components retrieved:
    $components.Count     
    288
    
    Get the first component from the $components array:
    $components[0]   
        Generation         : 12
        ReleaseVersion     : 2026.07.00.00
        Category           : Application - System Management
        Name               : Integrated Smart Update Tools for Ubuntu Linux x64
        Version            : 6.8.0.0
        Filename           : sut-6.8.0-7_amd64.deb
        UpgradeRequirement : Recommended
        ReleaseStatus      : new
        DocumentId         : dp00008215en_us
        SourceUrl          : https://support.hpe.com/hpesc/public/api/document/dp00008215en_us
        PageNumber         : 1

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Requires the HPECOMCmdlets module and the PdfPig assemblies in the script lib folder (https://github.com/UglyToad/pdfpig).
    Author  : Lionel Jullien (HPE)
    Module  : HPECOMCmdlets
    Version : 1.1.0

    Change log

    1.1.0 (2026-10-14)
        - Fixed filenames that wrap across two lines in the PDF, which were returned with a stray space
          (for example 'libbnxt_re-237.1.137.0- sles15sp7.x86_64.rpm').
        - Fixed rows that list two filenames (one per OS release): each filename is now returned in the
          Filename column, separated by '; ', instead of shifting values into the wrong columns.
        - Fixed rows split by a page break, which were returned as two partial rows (blank Category and
          Version) and could lose the end of the product name. They are now merged into one row.

    1.0.0
        - Initial release.

.LINK
    https://github.com/jullienl/HPE-COM-PowerShell-Library
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Region,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Workspace,

    [Parameter(Mandatory)]
    [ValidateSet('10', '11', '12')]
    [string]$Generation,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseVersion,

    [Parameter()]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$GLCredential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PasswordlessSSOEmail,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportPath,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

if ($GLCredential -and $PasswordlessSSOEmail) {
    Write-Error 'GLCredential and PasswordlessSSOEmail cannot be used together.' -ErrorAction Stop
}

# ---- Step 1 - Connect and validate the region ----
if (-not ($Global:HPEGreenLakeSession -and
        $Global:HPEGreenLakeSession.workspace -eq $Workspace -and
        $Global:HPEGreenLakeSession.IsValid)) {
    $connectParameters = @{ Workspace = $Workspace }
    if ($GLCredential) {
        $connectParameters.Credential = $GLCredential
    }
    elseif ($PasswordlessSSOEmail) {
        $connectParameters.PasswordlessSSOEmail = $PasswordlessSSOEmail
    }
    else {
        $connectParameters.Credential = Get-Credential
    }
    Connect-HPEGL @connectParameters | Out-Null
}

if ($Region -notin @($Global:HPECOMRegions.region)) {
    Write-Error "The COM region '$Region' is not provisioned in workspace '$Workspace'." -ErrorAction Stop
}

# ---- Step 2 - Retrieve the SPP baseline through HPECOMCmdlets ----
if ($ReleaseVersion) {
    $baseline = Get-HPECOMFirmwareBaseline -Region $Region -Generation $Generation -ReleaseVersion $ReleaseVersion -BundleType BASE | Select-Object -First 1
}
else {
    $baseline = Get-HPECOMFirmwareBaseline -Region $Region -Generation $Generation -LatestVersion -BundleType BASE | Select-Object -First 1
}

if (-not $baseline) {
    Write-Error "No BASE firmware baseline was found for generation '$Generation' and release '$ReleaseVersion'." -ErrorAction Stop
}

$resolvedVersion = [string]$baseline.releaseVersion
$generationKey = "gen$Generation"
$assetsBaseUri = 'https://support.hpe.com/docs/display/public/a00sppdocen_US/spp/assets'
$documentApiUri = 'https://support.hpe.com/hpesc/public/api/document'

# ---- Step 3 - Resolve the public Contents Report ----
$catalog = Invoke-RestMethod -Uri "$assetsBaseUri/config.json" -ErrorAction Stop
$generationTab = @($catalog.ListOfSPPTabs | Where-Object Generation -eq $generationKey) | Select-Object -First 1
$sppEntry = @($generationTab.SPPs | Where-Object BundleVersion -eq $resolvedVersion) | Select-Object -First 1
if (-not $sppEntry) {
    Write-Error "HPE has no public SPP catalog entry for $generationKey $resolvedVersion." -ErrorAction Stop
}

$releaseUri = "$assetsBaseUri/$generationKey.$resolvedVersion.json"
$releaseMetadata = Invoke-RestMethod -Uri $releaseUri -ErrorAction Stop
$contentsLink = @($releaseMetadata.QuickLinks | Where-Object LinkName -eq 'Contents Report') | Select-Object -First 1
if (-not $contentsLink) {
    Write-Error "The HPE SPP metadata does not contain a Contents Report link." -ErrorAction Stop
}

$contentsUri = [Uri]$contentsLink.Link
if ($contentsUri.Scheme -ne 'https' -or $contentsUri.Host -ne 'support.hpe.com') {
    Write-Error 'The Contents Report link does not point to support.hpe.com over HTTPS.' -ErrorAction Stop
}

$documentId = [System.Web.HttpUtility]::ParseQueryString($contentsUri.Query).Get('docId')
if ($documentId -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Error 'The Contents Report link does not contain a valid document ID.' -ErrorAction Stop
}

# ---- Step 4 - Download and parse the PDF ----
$sourceUrl = "$documentApiUri/$documentId"
$pdfPath = [System.IO.Path]::GetTempFileName()
try {
    Invoke-WebRequest -Uri $sourceUrl -OutFile $pdfPath -ErrorAction Stop
    $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
    if ($pdfBytes.Length -lt 5 -or [Text.Encoding]::ASCII.GetString($pdfBytes, 0, 5) -ne '%PDF-') {
        Write-Error 'The HPE Contents Report response was not a PDF.' -ErrorAction Stop
    }

    $libraryPath = Join-Path $PSScriptRoot 'lib\PdfPig-1.7.0-custom-5'
    foreach ($assemblyName in @('UglyToad.PdfPig.Core.dll', 'UglyToad.PdfPig.Fonts.dll', 'UglyToad.PdfPig.Tokenization.dll', 'UglyToad.PdfPig.Tokens.dll', 'UglyToad.PdfPig.dll')) {
        $assemblyPath = Join-Path $libraryPath $assemblyName
        if (-not (Test-Path -LiteralPath $assemblyPath)) {
            Write-Error "Missing PDF parser assembly: $assemblyPath" -ErrorAction Stop
        }
        Add-Type -Path $assemblyPath -ErrorAction Stop
    }

    $document = [UglyToad.PdfPig.PdfDocument]::Open($pdfPath)
    $components = [System.Collections.ArrayList]::new()

    # PDF line-wraps always break mid-token at a trailing hyphen (verified against real reports) - concatenate
    # those directly instead of inserting a space, so wrapped filenames/versions are reconstructed correctly.
    function Join-PdfWrappedText {
        param([string[]]$Tokens)
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $Tokens.Count; $i++) {
            if ($i -gt 0) {
                $previous = $Tokens[$i - 1]
                if (-not ($previous.Length -gt 1 -and $previous.EndsWith('-'))) {
                    [void]$sb.Append(' ')
                }
            }
            [void]$sb.Append($Tokens[$i])
        }
        return $sb.ToString()
    }

    function New-SppComponent {
        param($Row)
        $category = (Join-PdfWrappedText -Tokens @($Row.Category)).Trim()
        $name = (Join-PdfWrappedText -Tokens @($Row.Name)).Trim()
        # A remaining space after hyphen-aware joining means two distinct filenames were present in this row
        $filename = (Join-PdfWrappedText -Tokens @($Row.Filename)).Trim() -replace '\s+', '; '
        if (-not $filename -or $category -match 'Product Category' -or $name -eq 'Description') { return }

        [PSCustomObject]@{
            Generation         = $Generation
            ReleaseVersion     = $resolvedVersion
            Category           = $category
            Name               = $name
            Version            = (Join-PdfWrappedText -Tokens @($Row.Version)).Trim()
            Filename           = $filename
            UpgradeRequirement = (Join-PdfWrappedText -Tokens @($Row.UpgradeRequirement)).Trim()
            ReleaseStatus      = (Join-PdfWrappedText -Tokens @($Row.ReleaseStatus)).Trim()
            DocumentId         = $documentId
            SourceUrl          = $sourceUrl
            PageNumber         = $Row.PageNumber
        }
    }

    # The Upgrade Requirement / Filename / Release Status boundary is derived from the page's own header word
    # positions instead of the fixed 530/740 pixel values: a wrapped filename's continuation text can render a
    # few points left of the original fixed boundary, misclassifying it as Upgrade Requirement. The Category/Name/
    # Version boundaries are left untouched since they already match the real layout.
    $dynamicHeaderLabels = @{
        'Upgrade'     = 'UpgradeRequirement'
        'Requirement' = 'UpgradeRequirement'
        'Filename'    = 'Filename'
        'Release'     = 'ReleaseStatus'
        'Status'      = 'ReleaseStatus'
    }
    $upgradeRequirementUpper = 530.0
    $filenameUpper = 740.0
    $dynamicBoundsResolved = $false
    # The last row seen stays open until the next row starts, because a row split by a page break continues at the top of the next page
    $pendingRow = $null

    try {
        foreach ($page in $document.GetPages()) {
            $isFirstRowOnPage = $true
            $words = @($page.GetWords()) | Sort-Object { $_.BoundingBox.Bottom }, { $_.BoundingBox.Left } -Descending:$false
            $headerWords = @($words | Where-Object {
                    $_.Text -in @('Product', 'Category', 'Description', 'Version', 'Requirement', 'Filename', 'Release', 'Status')
                })
            $headerBottom = ($headerWords | Measure-Object -Property { $_.BoundingBox.Bottom } -Minimum).Minimum
            if ($null -eq $headerBottom) { $headerBottom = [double]::PositiveInfinity }

            if (-not $dynamicBoundsResolved) {
                $dynamicAnchors = @{}
                foreach ($headerWord in $headerWords) {
                    if ($dynamicHeaderLabels.ContainsKey($headerWord.Text)) {
                        $col = $dynamicHeaderLabels[$headerWord.Text]
                        $left = [double]$headerWord.BoundingBox.Left
                        if (-not $dynamicAnchors.ContainsKey($col) -or $left -lt $dynamicAnchors[$col]) {
                            $dynamicAnchors[$col] = $left
                        }
                    }
                }
                if ($dynamicAnchors.ContainsKey('UpgradeRequirement') -and $dynamicAnchors.ContainsKey('Filename') -and $dynamicAnchors.ContainsKey('ReleaseStatus')) {
                    $upgradeRequirementUpper = ($dynamicAnchors['UpgradeRequirement'] + $dynamicAnchors['Filename']) / 2
                    $filenameUpper = ($dynamicAnchors['Filename'] + $dynamicAnchors['ReleaseStatus']) / 2
                    $dynamicBoundsResolved = $true
                }
            }

            $lines = [System.Collections.ArrayList]::new()
            foreach ($word in $words) {
                $bottom = [double]$word.BoundingBox.Bottom
                if ($bottom -ge ($headerBottom - 2.5)) { continue }
                $line = $lines | Where-Object { [Math]::Abs($_.Bottom - $bottom) -le 2.5 } | Select-Object -First 1
                if (-not $line) {
                    $line = [PSCustomObject]@{ Bottom = $bottom; Words = [System.Collections.ArrayList]::new() }
                    [void]$lines.Add($line)
                }
                [void]$line.Words.Add($word)
            }

            # Group physical text lines that belong to the same wrapped table row (gap <= 20pt)
            $logicalRows = [System.Collections.ArrayList]::new()
            $currentRow = $null
            foreach ($line in ($lines | Sort-Object Bottom -Descending)) {
                $line.Words = @($line.Words | Sort-Object { $_.BoundingBox.Left })
                if (-not $currentRow -or ($currentRow.LastBottom - $line.Bottom) -gt 20) {
                    $currentRow = [PSCustomObject]@{ LastBottom = $line.Bottom; Lines = [System.Collections.ArrayList]::new() }
                    [void]$logicalRows.Add($currentRow)
                }
                $currentRow.LastBottom = $line.Bottom
                [void]$currentRow.Lines.Add($line)
            }

            foreach ($logicalRow in $logicalRows) {
                $orderedWords = @($logicalRow.Lines | ForEach-Object Words) | Sort-Object @{ Expression = { $_.BoundingBox.Bottom }; Descending = $true }, @{ Expression = { $_.BoundingBox.Left }; Descending = $false }

                $row = [PSCustomObject]@{
                    PageNumber         = $page.Number
                    Category           = @($orderedWords | Where-Object { $_.BoundingBox.Left -lt 100 } | ForEach-Object Text)
                    Name               = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge 100 -and $_.BoundingBox.Left -lt 250 } | ForEach-Object Text)
                    Version            = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge 300 -and $_.BoundingBox.Left -lt 380 } | ForEach-Object Text)
                    UpgradeRequirement = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge 380 -and $_.BoundingBox.Left -lt $upgradeRequirementUpper } | ForEach-Object Text)
                    Filename           = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $upgradeRequirementUpper -and $_.BoundingBox.Left -lt $filenameUpper } | ForEach-Object Text)
                    ReleaseStatus      = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $filenameUpper } | ForEach-Object Text)
                }

                $startsNewRow = $row.Category.Count -gt 0
                $isContinuation = $isFirstRowOnPage -and $pendingRow -and -not $startsNewRow -and $row.Version.Count -eq 0
                $isFirstRowOnPage = $false

                if ($isContinuation) {
                    foreach ($column in 'Name', 'Version', 'UpgradeRequirement', 'Filename', 'ReleaseStatus') {
                        $pendingRow.$column = @($pendingRow.$column) + @($row.$column)
                    }
                }
                elseif ($startsNewRow) {
                    if ($pendingRow) {
                        $component = New-SppComponent -Row $pendingRow
                        if ($component) { [void]$components.Add($component) }
                    }
                    $pendingRow = $row
                }
            }
        }

        if ($pendingRow) {
            $component = New-SppComponent -Row $pendingRow
            if ($component) { [void]$components.Add($component) }
        }
    }
    finally { $document.Dispose() }

    if ($components.Count -eq 0) { Write-Error 'No component rows were extracted from the Contents Report.' -ErrorAction Stop }

    if ($ExportPath) {
        $destination = $ExportPath
        if (Test-Path $ExportPath -PathType Container) {
            $destination = Join-Path $ExportPath "SPPComponents_${Generation}_${resolvedVersion}_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
        }
        $components | Export-Csv -Path $destination -NoTypeInformation -Encoding UTF8
        Write-Host "CSV exported to $destination" -ForegroundColor Green
    }

    Write-Host "SPP $generationKey ${resolvedVersion}: $($components.Count) components" -ForegroundColor Green
    if ($PassThru) { $components }
}
finally {
    Remove-Item -LiteralPath $pdfPath -Force -ErrorAction SilentlyContinue
}
