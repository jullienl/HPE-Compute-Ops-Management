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
        5. Optionally (-IncludeReleaseDate), looks up the release date of every component file on
           support.hpe.com and adds it as a ReleaseDate column.
        6. Prints a summary and optionally exports component data to CSV.

    PdfPig assemblies required for PDF extraction must be placed in the script's lib\PdfPig-1.7.0-custom-5 folder.

    Internet access to support.hpe.com is required to retrieve the component details (Contents Report) and,
    with -IncludeReleaseDate, the component release dates.

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

.PARAMETER IncludeReleaseDate
    Adds a ReleaseDate column (yyyy-MM-dd) with the date each component version was released on support.hpe.com.
    The Contents Report PDF does not contain dates, so this looks up each filename on support.hpe.com and takes
    the date of the matching version. This takes several minutes because every component file is looked up.
    Rows that list two filenames get two dates in the same order, separated by '; '. The date is left empty when
    the filename is not listed on support.hpe.com or when the version is not found for it.

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

.EXAMPLE
    .\Get-HPECOMFirmwareBaselineComponents.ps1 -Region eu-central -Workspace Production -Generation 11 -IncludeReleaseDate -ExportPath .\spp.csv

    Retrieve the components of the latest Gen11 SPP, add the release date of each component, and export everything
    to a CSV file. A ReleaseDate column such as '2026-08-07' is included for each component.

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Requires the HPECOMCmdlets module and the PdfPig assemblies in the script lib folder (https://github.com/UglyToad/pdfpig).
    Author  : Lionel Jullien (HPE)
    Module  : HPECOMCmdlets
    Version : 1.2.0

    Contributors
        Zach Bitting : release date lookup (-IncludeReleaseDate), based on his Get-SPPDates.ps1 script, and
                       detailed testing and feedback on the Contents Report parsing.

    The release date lookup (-IncludeReleaseDate) relies on the search service behind the HPE support site,
    which HPE can change without notice.

    Change log

    1.2.0 (2026-10-14)
        - Added -IncludeReleaseDate to add the release date of each component (ReleaseDate column).
          Based on the date lookup in Get-SPPDates.ps1 by Zach Bitting. A date is only returned when the
          filename is listed on support.hpe.com, so a component is never given the date of a different product.
        - Fixed a filename that wraps in the middle of a word being split into two filenames
          (for example 'Toshiba_MG08Air_TAMG08ADAnG3.fwpk; g' is now 'Toshiba_MG08Air_TAMG08ADAnG3.fwpkg').
          Only rows that really list two filenames now contain a '; ' separator.
        - Fixed versions broken by a line wrap (for example '1016.38.0.10 03' is now '1016.38.0.1003'
          and '06.01.04.215 .0' is now '06.01.04.215.0').
        - Fixed words cut in the middle by a line wrap in the Category and Name columns (for example
          'Enhancement s' is now 'Enhancements' and 'D 3710' is now 'D3710').
        - Fixed truncated versions (for example '(b)', '3' or '.0011' instead of '14.4.624.1 (b)', '1016.38.0.1003'
          or '008.0016.0000.0011') and garbled names and versions, which happened when HPE shifted the columns
          of the Contents Report (seen in Gen12 and Gen10 reports). The columns are now located from the report header.
        - Fixed a row split by a page break losing the end of its Category and Name (for example 'Driver - Storage
          Fibre Channel and' instead of 'Driver - Storage Fibre Channel and Fibre Channel Over Ethernet').
        - Fixed the connection failing after several runs with 'You have reached the maximum of 7 personal API
          clients' by removing the API clients left by earlier runs when connecting.

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
    [switch]$PassThru,

    [Parameter()]
    [switch]$IncludeReleaseDate
)

$ErrorActionPreference = 'Stop'

if ($GLCredential -and $PasswordlessSSOEmail) {
    Write-Error 'GLCredential and PasswordlessSSOEmail cannot be used together.' -ErrorAction Stop
}

# ---- Step 1 - Connect and validate the region ----
if (-not ($Global:HPEGreenLakeSession -and
        $Global:HPEGreenLakeSession.workspace -eq $Workspace -and
        $Global:HPEGreenLakeSession.IsValid)) {
    # Clears API clients left by earlier runs, otherwise repeated runs hit the 7 personal API clients limit
    $connectParameters = @{ Workspace = $Workspace; RemoveExistingCredentials = $true }
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

    # A token ending with this marker was not followed by a space in the PDF, so the next line continues the same word.
    $noSpaceMarker = [string][char]0xE000

    # PDF line-wraps always break mid-token at a trailing hyphen (verified against real reports) - concatenate
    # those directly instead of inserting a space, so wrapped filenames/versions are reconstructed correctly.
    function Join-PdfWrappedText {
        param([string[]]$Tokens)
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $Tokens.Count; $i++) {
            if ($i -gt 0) {
                $previous = $Tokens[$i - 1]
                $wrapsInsideWord = $previous.EndsWith($noSpaceMarker) -and $previous.TrimEnd($noSpaceMarker) -ne '-'
                $endsWithHyphen = $previous.Length -gt 1 -and $previous.EndsWith('-')
                if (-not ($wrapsInsideWord -or $endsWithHyphen)) {
                    [void]$sb.Append(' ')
                }
            }
            [void]$sb.Append($Tokens[$i].TrimEnd($noSpaceMarker))
        }
        return $sb.ToString()
    }

    # The PDF writes a space glyph after every word that ends a line normally, but none when a long word is cut mid-word.
    function Add-PdfNoSpaceMarker {
        param($Words, $SpaceKeys)
        foreach ($word in $Words) {
            $y = [int][Math]::Round($word.BoundingBox.Bottom)
            $x = [int][Math]::Round($word.BoundingBox.Right)
            $followedBySpace = $false
            foreach ($dy in -1, 0, 1) {
                foreach ($dx in -1, 0, 1) {
                    if ($SpaceKeys.Contains(('{0}|{1}' -f ($y + $dy), ($x + $dx)))) { $followedBySpace = $true }
                }
            }
            if ($followedBySpace) { $word.Text } else { $word.Text + $noSpaceMarker }
        }
    }

    # A filename can wrap anywhere (at a hyphen, or in the middle of a word), so its pieces are joined directly
    # and a new filename only starts once the previous one ends with a file extension.
    function Join-PdfFilenames {
        param([string[]]$Tokens)
        $filenames = [System.Collections.ArrayList]::new()
        $current = ''
        foreach ($token in $Tokens) {
            $current += $token
            if ($current -match '\.(rpm|deb|exe|zip|fwpkg|vib|iso|bin|tgz|gz|msi|cab|sh)$') {
                [void]$filenames.Add($current)
                $current = ''
            }
        }
        if ($current) { [void]$filenames.Add($current) }
        return $filenames -join '; '
    }

    # A version never contains a space except before a suffix such as '(B)', so any other line wrap is a split
    # inside the version (for example '1016.38.0.10' + '03').
    function Join-PdfVersion {
        param([string[]]$Tokens)
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $Tokens.Count; $i++) {
            if ($i -gt 0 -and $Tokens[$i].StartsWith('(')) { [void]$sb.Append(' ') }
            [void]$sb.Append($Tokens[$i])
        }
        return $sb.ToString()
    }

    function New-SppComponent {
        param($Row)
        $category = (Join-PdfWrappedText -Tokens @($Row.Category)).Trim()
        $name = (Join-PdfWrappedText -Tokens @($Row.Name)).Trim()
        $filename = (Join-PdfFilenames -Tokens @($Row.Filename)).Trim()
        if (-not $filename -or $category -match 'Product Category' -or $name -eq 'Description') { return }

        [PSCustomObject]@{
            Generation         = $Generation
            ReleaseVersion     = $resolvedVersion
            Category           = $category
            Name               = $name
            Version            = (Join-PdfVersion -Tokens @($Row.Version)).Trim()
            Filename           = $filename
            UpgradeRequirement = (Join-PdfWrappedText -Tokens @($Row.UpgradeRequirement)).Trim()
            ReleaseStatus      = (Join-PdfWrappedText -Tokens @($Row.ReleaseStatus)).Trim()
            DocumentId         = $documentId
            SourceUrl          = $sourceUrl
            PageNumber         = $Row.PageNumber
        }
    }

    # Column boundaries are derived from the header row of the first page because HPE shifts the columns between
    # generations and releases (a wrapped filename can also render a few points left of a fixed boundary).
    # The fixed values are only fallbacks when the header cannot be read.
    $dynamicHeaderLabels = @{
        'Upgrade'     = 'UpgradeRequirement'
        'Requirement' = 'UpgradeRequirement'
        'Filename'    = 'Filename'
        'Release'     = 'ReleaseStatus'
        'Status'      = 'ReleaseStatus'
    }
    $categoryUpper = 100.0
    $nameUpper = 250.0
    $versionLower = 300.0
    $versionUpper = 380.0
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

            $spaceKeys = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($letter in $page.Letters) {
                if ($letter.Value -eq ' ') {
                    [void]$spaceKeys.Add(('{0}|{1}' -f [int][Math]::Round($letter.StartBaseLine.Y), [int][Math]::Round($letter.StartBaseLine.X)))
                }
            }

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
                    $versionUpper = $dynamicAnchors['UpgradeRequirement'] - 10
                    $upgradeRequirementUpper = ($dynamicAnchors['UpgradeRequirement'] + $dynamicAnchors['Filename']) / 2
                    $filenameUpper = ($dynamicAnchors['Filename'] + $dynamicAnchors['ReleaseStatus']) / 2

                    # The '#' header sits above the build number column, which lies between the Name and Version columns
                    $categoryHeader = $headerWords | Where-Object Text -eq 'Category' | Select-Object -First 1
                    $buildHeader = if ($categoryHeader) {
                        $words | Where-Object { $_.Text -eq '#' -and [Math]::Abs($_.BoundingBox.Bottom - $categoryHeader.BoundingBox.Bottom) -le 2.5 } | Select-Object -First 1
                    }
                    if ($categoryHeader -and $buildHeader) {
                        $categoryUpper = $categoryHeader.BoundingBox.Right + 15
                        $nameUpper = $buildHeader.BoundingBox.Left - 5
                        $versionLower = $buildHeader.BoundingBox.Right + 5
                    }
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
                    Category           = @(Add-PdfNoSpaceMarker -Words @($orderedWords | Where-Object { $_.BoundingBox.Left -lt $categoryUpper }) -SpaceKeys $spaceKeys)
                    Name               = @(Add-PdfNoSpaceMarker -Words @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $categoryUpper -and $_.BoundingBox.Left -lt $nameUpper }) -SpaceKeys $spaceKeys)
                    Version            = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $versionLower -and $_.BoundingBox.Left -lt $versionUpper } | ForEach-Object Text)
                    UpgradeRequirement = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $versionUpper -and $_.BoundingBox.Left -lt $upgradeRequirementUpper } | ForEach-Object Text)
                    Filename           = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $upgradeRequirementUpper -and $_.BoundingBox.Left -lt $filenameUpper } | ForEach-Object Text)
                    ReleaseStatus      = @($orderedWords | Where-Object { $_.BoundingBox.Left -ge $filenameUpper } | ForEach-Object Text)
                }

                $startsNewRow = $row.Category.Count -gt 0
                # Every real row has a version, so a first row on the page without one continues the previous page's row (its category can continue too)
                $isContinuation = $isFirstRowOnPage -and $pendingRow -and $row.Version.Count -eq 0
                $isFirstRowOnPage = $false

                if ($isContinuation) {
                    foreach ($column in 'Category', 'Name', 'Version', 'UpgradeRequirement', 'Filename', 'ReleaseStatus') {
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

    # ---- Step 5 - Add the release date of each component (optional) ----
    if ($IncludeReleaseDate) {
        $coveoTokenUri = 'https://support.hpe.com/km/api/generateCoveoSearchToken'
        $coveoSearchUri = 'https://hewlettpackardproductioniwmg9b9w.org.coveo.com/rest/search/v2?organizationId=hewlettpackardproductioniwmg9b9w'
        $collectionBaseUri = 'https://support.hpe.com/hpesc/public/api/software/swCollection'

        try {
            $coveoToken = (Invoke-RestMethod -Uri $coveoTokenUri -TimeoutSec 60 -ErrorAction Stop).token
        }
        catch {
            $coveoToken = $null
            Write-Warning "Release dates skipped: a search token could not be obtained from support.hpe.com. $($_.Exception.Message)"
        }

        if ($coveoToken) {
            $dateLookups = @(foreach ($component in $components) {
                    foreach ($file in ($component.Filename -split '; ')) {
                        [PSCustomObject]@{ Key = "$file|$($component.Version)"; Filename = $file; Version = $component.Version }
                    }
                }) | Sort-Object Key -Unique
            Write-Host "Looking up the release date of $($dateLookups.Count) component files on support.hpe.com (this can take several minutes)..." -ForegroundColor Cyan

            # Each product collection is fetched once and shared by all lookups
            $collectionCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

            $lookupResults = $dateLookups | ForEach-Object -ThrottleLimit 5 -Parallel {
                $lookup = $_
                $headers = @{ Authorization = "Bearer $($using:coveoToken)" }
                $cache = $using:collectionCache
                $result = [PSCustomObject]@{ Key = $lookup.Key; Date = $null; Reason = $null }

                try {
                    $searchBody = @{ q = $lookup.Filename; numberOfResults = 100 } | ConvertTo-Json
                    $search = $null
                    for ($attempt = 1; $attempt -le 3 -and -not $search; $attempt++) {
                        try {
                            # Hashtables are required: the search response has keys that differ only by case
                            $search = (Invoke-WebRequest -Method Post -Uri $using:coveoSearchUri -Headers $headers -ContentType 'application/json' -Body $searchBody -TimeoutSec 60).Content | ConvertFrom-Json -AsHashtable
                        }
                        catch {
                            if ($attempt -eq 3) { throw }
                            Start-Sleep -Seconds (2 * $attempt)
                        }
                    }

                    # Only a collection that lists this exact filename is trusted (the first search hit is often another product)
                    $hit = @($search['results'] | Where-Object {
                            $_['raw']['kmswcollectionid'] -and (("$($_['raw']['kmswitmfilenm'])" -split '\s+') -contains $lookup.Filename)
                        })[0]
                    if (-not $hit) {
                        $result.Reason = 'Filename is not listed on support.hpe.com'
                        return $result
                    }

                    $collectionId = [string]$hit['raw']['kmswcollectionid']
                    if ($collectionId -notmatch '^[A-Za-z0-9_-]+$') {
                        $result.Reason = 'Unexpected collection id'
                        return $result
                    }

                    $collection = $null
                    if (-not $cache.TryGetValue($collectionId, [ref]$collection)) {
                        for ($attempt = 1; $attempt -le 3 -and -not $collection; $attempt++) {
                            try {
                                $collection = (Invoke-WebRequest -Uri "$($using:collectionBaseUri)/$collectionId" -TimeoutSec 60).Content | ConvertFrom-Json -AsHashtable
                            }
                            catch {
                                if ($attempt -eq 3) { throw }
                                Start-Sleep -Seconds (2 * $attempt)
                            }
                        }
                        $cache[$collectionId] = $collection
                    }

                    $wantedVersion = $lookup.Version -replace '\s', ''
                    $revision = @($collection['revisions'] | Where-Object { ([string]$_['version'] -replace '\s', '') -eq $wantedVersion })[0]
                    if ($revision) { $result.Date = $revision['customer_available_date'] }
                    else { $result.Reason = 'Version not found for this product on support.hpe.com' }
                }
                catch {
                    $result.Reason = $_.Exception.Message
                }
                $result
            }

            $dateByKey = @{}
            foreach ($lookupResult in $lookupResults) { $dateByKey[$lookupResult.Key] = $lookupResult }

            $withDate = 0
            foreach ($component in $components) {
                $dates = foreach ($file in ($component.Filename -split '; ')) {
                    $lookupResult = $dateByKey["$file|$($component.Version)"]
                    $parsed = [datetime]::MinValue
                    if ($lookupResult.Date -and [datetime]::TryParseExact([string]$lookupResult.Date, 'd MMM yyyy', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                        $parsed.ToString('yyyy-MM-dd')
                    }
                    elseif ($lookupResult.Date) { [string]$lookupResult.Date }
                    else {
                        Write-Verbose "No release date for '$file' version '$($component.Version)': $($lookupResult.Reason)"
                        ''
                    }
                }
                $releaseDate = if (($dates -join '').Length -gt 0) { $dates -join '; ' } else { $null }
                if ($releaseDate) { $withDate++ }
                Add-Member -InputObject $component -NotePropertyName ReleaseDate -NotePropertyValue $releaseDate
            }

            $components = [System.Collections.ArrayList]@($components | Select-Object Generation, ReleaseVersion, Category, Name, Version, Filename, UpgradeRequirement, ReleaseStatus, ReleaseDate, DocumentId, SourceUrl, PageNumber)
            Write-Host "Release date found for $withDate of $($components.Count) components." -ForegroundColor Green
        }
    }

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
