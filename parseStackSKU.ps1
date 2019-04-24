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
        [Parameter(Mandatory=$false, HelpMessage="Specify file name to match SKUs against")]
        [ValidateNotNullOrEmpty()]
        [string]$MatchFile,

        [Parameter(Mandatory=$false)]
        [switch]$Match2008,

        [Parameter(Mandatory=$false)]
        [switch]$ForceMatch
)

# // Import CSV file to match against Azure Stack SKUs
if ($MatchFile -eq $true) { 
    
    $matchFile = Import-Csv $MatchFile

    }

if ($Match2008 -eq $true) { 

    $MatchFile = $MatchFile | where 'OS according to the VMware Tools' -like '*Server 2008*' | where PowerState -eq 'poweredOn'

}


Function MatchSKUs {

    # // Normalize Values based on switches
    # // maybe count the matches, if > 2 divide by 2 and pick that sku?

    # // Convert imported fields for CPU, Memory, Space, and Drive count to integers
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        $MatchFile[$i].CPUs = [int]$MatchFile[$i].CPUs
        $MatchFile[$i].MemoryGB = [int]$MatchFile[$i].MemoryGB
        $MatchFile[$i].SpaceGB = [int]$MatchFile[$i].SpaceGB
        $MatchFile[$i].Disks = [int]$MatchFile[$i].Disks
        
    }

    # // Select unique memory and vCPU SKUs in Azure Stack
    $skuMemTypes = $skuReport | sort Memory -Unique | select Memory
    $skuCPUTypes = $skuReport | sort vCPU -Unique | select vCPU

    # // Normalize memory values (round up if no exact match)
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        # // If force memory match switch is set configure maximum memory to be 128
        If ($ForceMatch -eq $true) { If ($MatchFile[$i].MemoryGB -gt 128) { $MatchFile[$i].MemoryGB -eq 128 }  } 

        # // Loop through all memory SKUs looking for a match
        for ($m = 0; $m -lt $skuMemTypes.Count; $m ++) {

            # // If a match is found exit
            if ($MatchFile[$i].MemoryGB -eq $skuMemTypes[$m].Memory) { break }

            # // If there is no exact match round up to the next memory value
            If (($MatchFile[$i].MemoryGB - $skuMemTypes[$m].Memory) -lt 0) { $MatchFile[$i].MemoryGB = $skuMemTypes[$m].Memory ; break }

        
        }
        # // Loop through all memory SKUs looking for a match
        for ($m = 0; $m -lt $skuMemTypes.Count; $m ++) {

            # // If a match is found exit
            if ($MatchFile[$i].MemoryGB -eq $skuMemTypes[$m].Memory) { break }

            # // If there is no exact match round up to the next memory value
            If (($MatchFile[$i].MemoryGB - $skuMemTypes[$m].Memory) -lt 0) { $MatchFile[$i].MemoryGB = $skuMemTypes[$m].Memory ; break }

        }

        # // Loop through all vCPU SKUs looking for a match
        for ($c = 0; $c -lt $skuCPUTypes.Count; $c ++) {

            # // If a match is found exit
            if ($MatchFile[$i].CPUs -eq $skuCPUTypes[$c].vCPU) { break }

            # // If there is no exact match round up to the next vCPU value
            If (($MatchFile[$i].CPUs - $skuCPUTypes[$c].vCPU) -lt 0) { $MatchFile[$i].CPUs = $skuCPUTypes[$c].vCPU ; break }

        }

    }
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

Write-Host ' '
Write-Host 'Success: To see what to do next type: help .\parseStackSKU.ps1 -ex'
Write-Host ' '