<#
.SYNOPSIS
    Script to grab existing Azure Stack SKU's and populate them as command line objects.
.DESCRIPTION
    This script will grab the existing published Azure Stack SKU's from the following URL.
.PARAMETER MatchFile
    Specify a CSV file to import and match against Azure Stack SKUs. The columns in the file
    need to follow this naming convention, but they do not need to be in a specific order:

    Name, vCPU, Memory, Space

    Name = VM Name
    CPU = Count of vCPU's
    RAM = Memory in GB
    Space = Drive space assigned to VM

.PARAMETER Match2008
    Switch to specify only matching Server 2008 VM instances.
.PARAMETER PreferCPU
    Switch to prefer matching SKU to CPU if there is no exact match. The default behavior is to
    match memory. Example, customer CPU count is 4 with 4GB RAM. Since there is no SKU of this
    type the default behavior would match a 2CPU system with 4GB RAM. With this switch the set
    the match would be a 4CPU w 8GB RAM.
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
    $matchedVM = @()

    if ($Match2008 -eq $true) { $MatchFile = $MatchFile | where 'OS according to the VMware Tools' -like '*Server 2008*' }

    # // Convert imported fields for CPU, Memory, Space, and Drive count to integers
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        $MatchFile[$i].CPU = [int]$MatchFile[$i].CPU
        $MatchFile[$i].RAM = [int]$MatchFile[$i].RAM
        $MatchFile[$i].SpaceGB = [int]$MatchFile[$i].SpaceGB
        $MatchFile[$i].Disks = [int]$MatchFile[$i].Disks
        
    }

    # // Select unique memory and vCPU SKUs in Azure Stack
    $skuMemTypes = ($skuReport | sort Memory -Unique | select Memory).Memory
    $skuCPUTypes = ($skuReport | sort vCPU -Unique | select vCPU).vCPU

    # // Normalize memory and vCPU values to match Stack SKUs (round up if no exact match)
    for ($i = 0; $i -lt $MatchFile.Count; $i ++) {

        # // If force memory match switch is set configure any VM with greater than 128GB memory to = 128GB
        If ($ForceMatch -eq $true) { If ($MatchFile[$i].RAM -gt 128) { $MatchFile[$i].RAM -eq 128 }  } 

        # // Loop through all memory SKUs looking for a match
        for ($m = 0; $m -lt $skuMemTypes.Count; $m ++) {

            # // If a match is found exit
            if ($MatchFile[$i].RAM -eq $skuMemTypes[$m]) { break }

            # // If there is no exact match round up to the next memory value
            If (($MatchFile[$i].RAM - $skuMemTypes[$m]) -lt 0) { $MatchFile[$i].RAM = $skuMemTypes[$m] ; break }
        }

        # // Loop through all vCPU SKUs looking for a match
        for ($c = 0; $c -lt $skuCPUTypes.Count; $c ++) {

            # // If a match is found exit
            if ($MatchFile[$i].CPU -eq $skuCPUTypes[$c]) { break }

            # // If there is no exact match round up to the next vCPU value
            If (($MatchFile[$i].CPU - $skuCPUTypes[$c]) -lt 0) { $MatchFile[$i].CPU = $skuCPUTypes[$c] ; break }
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

    # // Build SKU matches!
    foreach ($vm in $matchedVM) {

        $skuMatches = $skuReport | where vCPU -eq $vm.CPU | where Memory -eq $vm.RAM

        if ($skuMatches.Count -gt 1) { 
            $skuMatch = $skuMatches[($skuMatches.Count / 2)] 
        }
        else { $skuMatch = $skuMatches }

        $vmMatchObj = New-Object System.Object
        $vmMatchObj | Add-Member -NotePropertyName Name -NotePropertyValue $vm.Name
        $vmMatchObj | Add-Member -NotePropertyName CPU -NotePropertyValue $vm.CPU
        $vmMatchObj | Add-Member -NotePropertyName RAM -NotePropertyValue $vm.RAM
        $vmMatchObj | Add-Member -NotePropertyName SKU -NotePropertyValue $skuMatch.SKU

        $matchedReport += $vmMatchObj

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
#$global:matchedReport = @()

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