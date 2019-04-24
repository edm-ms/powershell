<#
.SYNOPSIS
    Script to grab existing Azure Stack SKU's and populate them as command line objects.
.DESCRIPTION
    This script will grab the existing published Azure Stack SKU's from the following URL.
.PARAMETER MatchFile
    Specify a CSV file to import and match against Azure Stack SKUs. The columns in the file
    need to follow this naming convention, but they do not need to be in a specific order:

    Name, vCPU, Memory, Space

    Name = VMNAme
    vCPU = Count of vCPU's
    Memory = Memory in GB
    Space = Drive space assigned to VM

.PARAMETER Match2008
    Switch to specify only matching Server 2008 VM instances.
.PARAMETER ForceMatch
    Switch to specify "force match" where VM's will be matched to a SKU regardless if they align
    or not. So as an example a VM with 256GB RAM (larger than anuy single Azure Stack SKU) will
    be matched to the next closest memory matched (128GB) SKU.
.EXAMPLE
    parseStackSKU.ps1

    Run this to store the global variable $skuReport.
    Once this has been run use the examples below to retreive SKU data from the object.
    A full list of objects can be retrieved with the following command.

    PS C:\>$skuReport | Get-Member 
.EXAMPLE
    $skuReport | where vCPU -gt 8 | select SKU, vCPU, Memory

    Find SKUs greater than 8 vCPU then select SKU Name, vCPU count, and Memory
.EXAMPLE
    $skuReport | where vCPU -le 4 | where Memory -ge 32 | select SKU, vCPU, Memory

    Find SKUs less than or equal to 4 vCPU and greater than or equal to 32GB memory
.EXAMPLE
    $skuReport | Measure-Object Memory -Maximum -Minimum -Average 

    Display maximum, minimum, and average memory values of all SKUs
.EXAMPLE
    $skuReport | where MaxIOPS -gt 20000 | select SKU, vCPU, Memory, MaxIOPS | sort MaxIOPS -Descending

    Search for all systems capable of over 20,000 IOPS, and sort by highest IO SKUs first
.OUTPUTS
    $skuReport
.NOTES
    Plan to add parameters for a few things like -MatchFile to match values in stack to a file.
.LINK
    https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-vm-sizes

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$MatchFile,

        [Parameter(Mandatory=$false)]
        [switch]$Match2008,

        [Parameter(Mandatory=$false)]
        [switch]$ForceMatch
)

# // Import CSV file to match against Azure Stack SKUs
#if ($MatchFile -ne $null) { $matchFile = Import-Csv $MatchFile }

# // Find only server 2008 instances


Function Get-SKUMatch {

    param(
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [object]$MatchFile,

        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string]$Match2008,

        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string]$ForceMatch

        )

    $MatchFile = Import-Csv $MatchFile
    $matchedReport = @()

    if ($Match2008 -eq $true) { $MatchFile = $MatchFile | where 'OS according to the VMware Tools' -like '*Server 2008*' }

    # // Convert imported fields for CPU, Memory, Space, and Drive count to integers
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        $MatchFile[$i].CPUs = [int]$MatchFile[$i].CPUs
        $MatchFile[$i].MemoryGB = [int]$MatchFile[$i].MemoryGB
        $MatchFile[$i].SpaceGB = [int]$MatchFile[$i].SpaceGB
        $MatchFile[$i].Disks = [int]$MatchFile[$i].Disks
        
    }

    # // Select unique memory and vCPU SKUs in Azure Stack
    $skuMemTypes = ($skuReport | sort Memory -Unique | select Memory).Memory
    $skuCPUTypes = ($skuReport | sort vCPU -Unique | select vCPU).vCPU

    for ($i = 0; $i -lt $skuMemTypes.Count; $i ++) { $skuMemTypes[$i] = [int]$skuMemTypes[$i] }
    for ($i = 0; $i -lt $skuCPUTypes.Count; $i ++) { $skuCPUTypes[$i] = [int]$skuCPUTypes[$i] }

    # // Normalize memory and vCPU values (round up if no exact match)
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        # // If force memory match switch is set configure maximum memory to be 128
        If ($ForceMatch -eq $true) { If ($MatchFile[$i].MemoryGB -gt 128) { $MatchFile[$i].MemoryGB -eq 128 }  } 

        # // Loop through all memory SKUs looking for a match
        for ($m = 0; $m -lt $skuMemTypes.Count; $m ++) {

            # // If a match is found exit
            if ($MatchFile[$i].MemoryGB -eq $skuMemTypes[$m]) { break }

            # // If there is no exact match round up to the next memory value
            If (($MatchFile[$i].MemoryGB - $skuMemTypes[$m]) -lt 0) { $MatchFile[$i].MemoryGB = $skuMemTypes[$m] ; break }

        }

        # // Loop through all vCPU SKUs looking for a match
        for ($c = 0; $c -lt $skuCPUTypes.Count; $c ++) {

            # // If a match is found exit
            if ($MatchFile[$i].CPUs -eq $skuCPUTypes[$c]) { break }

            # // If there is no exact match round up to the next vCPU value
            If (($MatchFile[$i].CPUs - $skuCPUTypes[$c]) -lt 0) { $MatchFile[$i].CPUs = $skuCPUTypes[$c] ; break }

        }
    }

    # // Match normalized vCPU and memory VM's to Azure Stack SKUs
    $customerMemTypes = ($MatchFile | Group-Object MemoryGB | Select-Object Name).Name | Sort-Object
    
    for ($i = 0; $i -lt $customerMemTypes.Count; $i ++) { $customerMemTypes[$i] = [int]$customerMemTypes[$i] }
    $customerMemTypes = $customerMemTypes | Sort-Object

    # // Loop through all memory types in customer environment
    foreach ($memType in $customerMemTypes) {

        # // Build a list of all CPU counts with this amount of memory
        $cpuMemList = $MatchFile | where MemoryGB -eq $memType | Group-Object CPUs  | sort Name | select Count, Name

        # // Loop through each CPU in the list matching CPU and memory count
        foreach ($cpu in $cpuMemList) {

            # // Match the current CPU + Memory to an Azure Stack SKU
            $skuMatches = $skuReport | where vCPU -eq $cpu.Name | where Memory -eq $memType

            # // Find current array position for Azure Stack CPU SKU
            $cpuTry = [array]::indexOf($skuCPUTypes, [int]$cpu.Name)

            do {

                # // Increment search position in array by until we find a matched vCPU + memory SKU
                $cpuTry ++

                $skuMatches = $skuReport | where vCPU -eq $skuCPUTypes[$cpuTry] | where Memory -eq $memType
                Write-Host "Current: $skuMatches"
                $cpuTry
    
            }
            while ($null -eq $skuMatches)
    
            # // If there is more than 1 SKU that matches pick the one in the middle
            if ($skuMatches.Count -gt 1) { 
                $skuMatch = $skuMatches[($skuMatches.Count / 2)] 
            }
            else { $skuMatch = $skuMatches }
    
            $vmMatchObj = New-Object System.Object
            $vmMatchObj | Add-Member -NotePropertyName Qty -NotePropertyValue $cpu.Count
            $vmMatchObj | Add-Member -NotePropertyName SKU -NotePropertyValue $skuMatch.SKU
    
            $matchedReport += $vmMatchObj

        }
    }

    return $matchedReport
    
}

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
$global:matchedReport = @()

# // Loop through all tables in HTML
foreach ($table in $tables) {

    # // Grab all rows in current table
    $rows = @($table.Rows)

    # // Loop through all rows in current table
    foreach($row in $rows)

    {

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

if ($MatchFile -ne '') { $global:matchedReport = Get-SkuMatch $MatchFile $ForceMatch $Match2008 }

Write-Host ' '
Write-Host 'Success: To see what to do next type: help .\parseStackSKU.ps1 -ex'
Write-Host ' '