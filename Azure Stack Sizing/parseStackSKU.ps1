<#
.SYNOPSIS
    Script to grab existing Azure Stack SKU's and populate them as command line objects.
.DESCRIPTION
    This script will grab the existing published Azure Stack SKU's from a URL
.PARAMETER MatchFile
    Specify a CSV file to import and match against Azure Stack SKUs. The columns in the file
    need to follow this naming convention, but they do not need to be in a specific order:

    Name, CPU, RAM, SpaceGB, OS, PowerState

    Name = VM Name
    CPU = Count of vCPU's
    RAM = Memory in GB
    SpaceGB = Drive space assigned to VM in GB
    OS = OS Type/Name, i.e. Microsoft Windows Server 2008
    PowerState = poweredOn or poweredOff

.PARAMETER Match2008
    Switch to specify only matching Server 2008 VM instances.
.PARAMETER PreferCPU
    [Note: Not Currently Implemented]

    Switch to prefer matching SKU to CPU if there is no exact match. The default behavior is to
    match memory. Example, customer CPU count is 4 with 4GB RAM. Since there is no SKU of this
    type the default behavior would match a 2CPU system with 4GB RAM. With this switch the set
    the match would be a 4CPU w 8GB RAM.
.PARAMETER OnlyOn
    Switch to only match VM's that are powered on
.PARAMETER RoundUp
    Switch to round up CPU and Memory if there are no matching SKUs. The default behavior is to
    find the closest number match.
.EXAMPLE
    parseStackSKU.ps1 -MatchFile .\input.csv -Match2008 -MaxMem

    Finds all Azure Stack SKUs and then matches the data to an input file, only Server 2008, and
    sets matching for systems greater than 128GB RAM = 128GB RAM
.EXAMPLE
    parseStackSKU.ps1

    Run this to store the global variable $skuReport.
    Once this has been run use the examples below to retreive SKU data from the object.
    A full list of objects can be retrieved with the following command.

    PS C:\>$skuReport | Get-Member 
.EXAMPLE
    $skuReport | where vCPU -le 4 | where Memory -ge 32 | select SKU, vCPU, Memory

    Find SKUs less than or equal to 4 vCPU and greater than or equal to 32GB memory
.EXAMPLE
    $skuReport | where MaxIOPS -gt 20000 | select SKU, vCPU, Memory, MaxIOPS | sort MaxIOPS -Descending

    Search for all systems capable of over 20,000 IOPS, and sort by highest IO SKUs first
.NOTES
    Need to rebuild output object to show matched file original inputs vs. the Azure Stack SKU it maps to...
.OUTPUTS
    $skuReport
    $matchFile
.LINK
    https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-vm-sizes

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$MatchFile,

        [Parameter(Mandatory=$false, Position=1)]
        [switch]$Match2008,

        [Parameter(Mandatory=$false, Position=2)]
        [switch]$OnlyOn,

        [Parameter(Mandatory=$false, Position=3)]
        [switch]$RoundUp
)

# // Function to find closest number match
Function Get-Closest {

    param (
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        $numberList,

        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        $numberToMatch
    )

    $searchArray = $numberList
    $searchNumber = $numberToMatch
    $oldval = $searchNumber - $searchArray[0]
    $numMatch = $searchArray[0]

    if ($oldval -lt 0) {$oldval = $oldval * -1}

    foreach ($number in $searchArray){

        $val = $searchNumber - $number

        if($val -lt 0) {$val = $val * -1}

        if ($val -lt $oldval) { 

            $oldval = $val
            $numMatch = $number
        }
    }

    return $numMatch
}

# // Get-SKUMatch Function to match input file against Azure Stack SKUs
Function Get-SKUMatch {

    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [object]$MatchFile,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1)]
        [string]$Match2008,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=2)]
        [string]$OnlyOn,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=3)]
        [string]$RoundUp
        )

    $fileLocation = $MatchFile
    $MatchFile = Import-Csv $fileLocation
    $beforMatch = Import-Csv $fileLocation
    $matchedReport = @()
    $matchedVM = @()

    if ($Match2008 -eq $true) { 
        $MatchFile = $MatchFile | where 'OS' -like '*Server 2008*' 
        $beforMatch = $beforMatch | where 'OS' -like '*Server 2008*'
        }
    if ($OnlyOn -eq $true) { 
        $MatchFile = $MatchFile | where 'PowerState' -eq 'poweredOn' 
        $beforMatch = $beforMatch | where 'PowerState' -eq 'poweredOn' 
        }

    # // Convert imported fields for CPU, Memory, Space, and Drive count to integers
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        $MatchFile[$i].CPU = [int]$MatchFile[$i].CPU
        $MatchFile[$i].RAM = [int]$MatchFile[$i].RAM
        $MatchFile[$i].SpaceGB = [int]$MatchFile[$i].SpaceGB

        $beforMatch[$i].CPU = [int]$beforMatch[$i].CPU
        $beforMatch[$i].RAM = [int]$beforMatch[$i].RAM
        $beforMatch[$i].SpaceGB = [int]$beforMatch[$i].SpaceGB
        #$MatchFile[$i].Disks = [int]$MatchFile[$i].Disks
    }

    # // Select unique memory and vCPU SKUs in Azure Stack
    $skuMemTypes = ($skuReport | sort Memory -Unique | select Memory).Memory
    $skuCPUTypes = ($skuReport | sort vCPU -Unique | select vCPU).vCPU

    # // Normalize memory and vCPU values to match Stack SKUs
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        # // Loop through all memory SKUs looking for a match
        for ($m = 0; $m -lt $skuMemTypes.Count; $m ++) {

            # // If a match is found exit
            if ($MatchFile[$i].RAM -eq $skuMemTypes[$m]) { break }

            # // If RoundUp switch is set roundup memory to next largest SKU, otherwise find closest match
            if ($RoundUp -eq $true) { 

                # // If there is no exact match round up to the next memory value
                If (($MatchFile[$i].RAM - $skuMemTypes[$m]) -lt 0) { $MatchFile[$i].RAM = $skuMemTypes[$m] ; break }
            }
            else {

                $ramMatch = Get-Closest $skuMemTypes $MatchFile[$i].RAM
                $MatchFile[$i].RAM = $ramMatch ; break
            }
        }
        # // Loop through all vCPU SKUs looking for a match
        for ($c = 0; $c -lt $skuCPUTypes.Count; $c ++) {

            # // If a match is found exit
            if ($MatchFile[$i].CPU -eq $skuCPUTypes[$c]) { break }

            # // If RoundUp switch is set roundup CPU to next largest SKU, otherwise find closest match
            if ($RoundUp -eq $true) { 

                # // If there is no exact match round up to the next CPU value
                If (($MatchFile[$i].CPU - $skuCPUTypes[$c]) -lt 0) { $MatchFile[$i].CPU = $skuCPUTypes[$c] ; break }
            }
            else {

                $cpuMatch = Get-Closest $skuCPUTypes $MatchFile[$i].CPU
                $MatchFile[$i].CPU = $CPUMatch ; break
            }
        }
    }

    # // Match VM to SKU
    for ($counter = 0; $counter -lt $matchFile.count; $counter ++) {

        $foundCPU = $false
        # // Find Azure Stack SKU that matches VM Memory
        $memMatch = $skuReport | where Memory -eq $MatchFile[$counter].RAM

        #// Find Azure Stack SKU that matches both CPU and VM Memory
        $vmMatch = $memMatch | where vCPU -eq $MatchFile[$counter].CPU

        #// If there is no mem and CPU match determine next fit
        if ($vmMatch -eq $null) { 

            #// Find all CPU options with this memory type
            $availalbleCPUMatch = $memMatch | sort vCPU -Unique

            #// Loop through all CPU types with this memory match
            for ($i = 0; $i -lt $availalbleCPUMatch.Count; $i ++) {

                #// If we find a match with more CPU pick that (allow CPU overcommit)
                if ($availalbleCPUMatch[$i].vCPU -gt $MatchFile[$counter].CPU) {

                    $cpuChoice = $i
                    $foundCPU = $true
                    break
                }
            }
            # // Set CPU to next SKU size up if found, otherwise set the CPU to the next SKU with less CPU
            if ($foundCPU -eq $true) {

                $vmMatch = $memMatch | where vCPU -eq $availalbleCPUMatch[$cpuChoice].vCPU
                $MatchFile[$counter].CPU = $availalbleCPUMatch[$cpuChoice].vCPU
                $matchedVM += $MatchFile[$counter]
            }
            else {

                $vmMatch = $memMatch | where vCPU -eq $availalbleCPUMatch[($availalbleCPUMatch.Count - 1)].vCPU
                $MatchFile[$counter].CPU = $availalbleCPUMatch[$cpuChoice].vCPU
                $matchedVM += $MatchFile[$counter]
            }
        }
        else { 

            $matchedVM += $MatchFile[$counter]
        }
    }

    # // Build SKU matches
    $i = 0
    foreach ($vm in $matchedVM) {

        # Try to match v2 SKUs
        $skuMatches = $skuReport | where SKU -like '*_v2' | where vCPU -eq $vm.CPU | where Memory -eq $vm.RAM

        # If no v2 SKUs default to regular match
        if ($skuMatches -eq $null) { $skuMatches = $skuReport | where vCPU -eq $vm.CPU | where Memory -eq $vm.RAM }

        # If multiple matching SKUs just pick the middle one
        if ($skuMatches.Count -gt 1) { 

            $skuMatch = $skuMatches[($skuMatches.Count / 2)] 
        }
        else { $skuMatch = $skuMatches }

        $vmMatchObj = New-Object System.Object
        $vmMatchObj | Add-Member -NotePropertyName Name -NotePropertyValue $vm.Name
        $vmMatchObj | Add-Member -NotePropertyName CPU -NotePropertyValue $vm.CPU
        $vmMatchObj | Add-Member -NotePropertyName RAM -NotePropertyValue $vm.RAM
        $vmMatchObj | Add-Member -NotePropertyName OriginalCPU -NotePropertyValue $beforMatch[$i].CPU
        $vmMatchObj | Add-Member -NotePropertyName OriginalRam -NotePropertyValue $beforMatch[$i].RAM
        $vmMatchObj | Add-Member -NotePropertyName SpaceGB -NotePropertyValue $vm.SpaceGB
        $vmMatchObj | Add-Member -NotePropertyName SKU -NotePropertyValue $skuMatch.SKU

        $matchedReport += $vmMatchObj
        $i ++
    }
    return $matchedReport
}

# // Function to return standard HTML since ParsedHTML property in PowerShell is broken
Function ConvertTo-NormalHTML {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)]$HTML)

    $NormalHTML = New-Object -Com "HTMLFile"

    # // Try IHTMLDocument2_write if possible, fall back otherwise
    try {

        $NormalHTML.IHTMLDocument2_write($HTML.RawContent)
        return $NormalHTML
    }
    catch {

        $src = [System.Text.Encoding]::Unicode.GetBytes($HTML.RawContent)
        $NormalHTML.write($src)
        return $NormalHTML
    }
}
# // Allow PowerShell to use different TLS versions
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

$stackVMSizes = 'https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-vm-sizes'

$stackSKU = Invoke-WebRequest -Uri $stackVMSizes
$stackHTML = ConvertTo-NormalHTML $stackSKU
$tables = @($stackHTML.getElementsByTagName('TABLE'))

$titles = @()
$global:skuReport = @()

# // Loop through all tables in HTML
foreach ($table in $tables) {

    # // Grab all rows in current table
    $rows = @($table.Rows)

    # // Loop through all rows in current table
    foreach($row in $rows) {

        # // Grab all cells in current row
        $cells = @($row.Cells)

        # // If HTML tag is header loop through all cells to build field names
        if ($cells[0].tagName -eq "TH") { $titles = @($cells | % { ("" + $_.InnerText).Trim() }) }

        # // Move to next table in loop if retired SKU
        if ($titles[0] -eq 'Size - Size\Name') { break } 

        # // Move to next row in table if header row
        if ($titles[0] -eq $cells[0].InnerText) { continue } 

        $counter = 0
        $skuObj = New-Object System.Object

        # // Loop through all cells in current row
        foreach ($item in $cells) {

            $skuData = ($item.InnerText).Trim()

            # // Test if value can be an integer and cast as int if true
            if ( [bool]($skuData -as [int] -is [int]) -eq $true) { $skuData = [int]$skuData }

            # // Change some title names
            if ( $titles[$counter] -eq 'Size') { $titles[$counter] = 'SKU' }
            if ( $titles[$counter] -eq 'Memory (GiB)') { $titles[$counter] = 'Memory' }
            if ( $titles[$counter] -eq 'Max OS disk throughput (IOPS)') { $titles[$counter] = 'OsDriveIOPS' }
            if ( $titles[$counter] -eq 'Max temp storage throughput (IOPS)') { $titles[$counter] = 'TempDriveIOPS' }
            if ( $titles[$counter] -eq 'Max NICs') { $titles[$counter] = 'NICs' }

            # // Check if this is the combined data disk and IOPS field
            # // if yes then split them and create 3 fields (max drive count, max single drive IOPS, max total IOPS)
            if ( $titles[$counter] -eq 'Max data disks / throughput (IOPS)') { 

                # // Check if field doesn't follow the same formating and fix it
                if ( ($skuData.ToCharArray()) -notcontains '/' ) { $skuData = $skuData.split('x')[0] + ' / ' + $skuData }

                $driveSplit = $skuData.Split('/')
                $maxDrives = $driveSplit[0]
                $maxDrives = [int]$maxDrives
                $driveIOPS = $driveSplit[1].Trim()
                $driveIOPS = $driveIOPS.Split('x')[1]
                $driveIOPS = [int]$driveIOPS
                $maxIOPS = $maxDrives * $driveIOPS

                $skuObj | Add-Member -NotePropertyName 'MaxDrives' -NotePropertyValue $maxDrives -Force
                $skuObj | Add-Member -NotePropertyName 'DriveIOPS' -NotePropertyValue $driveIOPS -Force
                $skuObj | Add-Member -NotePropertyName 'MaxIOPS' -NotePropertyValue $maxIOPS -Force

                $counter ++
            }
            else {

                $skuObj | Add-Member -NotePropertyName $titles[$counter] -NotePropertyValue $skuData -Force
                $counter ++
            }
        }
        $global:skuReport += $skuObj
    }
}

# // If the matchfile switch is set call function to match VM to SKUs
if ($MatchFile -ne '') { 

    $global:matchedReport = Get-SkuMatch $MatchFile $Match2008 $OnlyOn $RoundUp 

    # // Display SKU matches and average drive space
    $matchedReport | group SKU | sort name | select Name, Count
    $averageDrive = [int]($matchedReport | Measure-Object SpaceGB -Average | select Average).Average
    Write-Host ' '
    Write-Host 'Average Drive Space/SKU: ' $averageDrive 'GB'
    Write-Host ' '
    Write-Host 'explore with the object $matchedReport and $skuReport'
    Write-Host ' '
}
else {
    
    Write-Host ' '
    Write-Host 'Success: To see what to do next type: help .\parseStackSKU.ps1 -ex'
    Write-Host ' '    
}