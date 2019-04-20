<#

.SYNOPSIS
    Script to grab existing Azure Stack SKU's and populate them as command line objects.

.DESCRIPTION
    This script will grab the existing published Azure Stack SKU's from the following URL.

.PARAMETER MatchFile
    Eventually will ask for input file to match against Azure Stack SKUs

.EXAMPLE
    parseStackSKU.ps1

    Run this to store the global variable $skuReport.
    Once this has been run use the examples below to retreive SKU data from the object.

.EXAMPLE
    $skuReport | where vCPU -gt 8 | select Size, vCPU, 'Memory (GiB)'

    Find SKUs greater than 8 vCPU then select SKU Name, vCPU count, and Memory

.EXAMPLE
    $skuReport | where vCPU -le 4 | where 'Memory (GiB)' -ge 32 | select Size, vCPU, 'Memory (GiB)'

    Find SKUs less than or equal to 4 vCPU and greater than or equal to 32GB memory, select SKU Name, vCPU count, and Memory

.EXAMPLE
    $skuReport | Measure-Object 'Memory (GiB)' -Average -Maximum -Minimum

    Find maximum, minimum, and average memory values of all SKUs

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
        [switch]$MatchFile
)
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

            # // Reduce length of long title names
            if ( $titles[$counter] -eq 'Memory (GiB)') { $titles[$counter] = 'Memory' }
            if ( $titles[$counter] -eq 'Max OS disk throughput (IOPS)') { $titles[$counter] = 'MaxOsDriveIOPS' }
            if ( $titles[$counter] -eq 'Max temp storage throughput (IOPS)') { $titles[$counter] = 'MaxTempDriveIOPS' }
            if ( $titles[$counter] -eq 'Max NICs') { $titles[$counter] = 'NICs' }

            # // Check if this is the combined data disk and IOPS field
            # // if yes then split them and create 3 fields (max drive count, max single drive IOPS, max total IOPS)
            if ( $titles[$counter] -eq 'Max data disks / throughput (IOPS)') { 

                # // Check if field doesn't follow the same formating and fix it
                if ( ($skuData.ToCharArray()) -notcontains '/' ) { $skuData = $skuData.split('x')[0] + ' / ' + $skuData }

                $driveSplit = $skuData.Split('/')
                $maxDrives = $driveSplit[0]
                $maxDrives = [int]$maxDrives
                $maxIOPS = $driveSplit[1].Trim()
                $maxIOPS = $maxIOPS.Split('x')[1]
                $maxIOPS = [int]$maxIOPS
                $maxTotalIOPS = $maxDrives * $maxIOPS

                $skuObj | Add-Member -NotePropertyName 'MaxDrives' -NotePropertyValue $maxDrives -Force
                $skuObj | Add-Member -NotePropertyName 'MaxSingleDriveIOPS' -NotePropertyValue $maxIOPS -Force
                $skuObj | Add-Member -NotePropertyName 'MaxTotalIOPS' -NotePropertyValue $maxTotalIOPS -Force

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