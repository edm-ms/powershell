<#

.SYNOPSIS
    Script to grab existing Azure Stack SKU's and populate them as command line objects.

.DESCRIPTION
    This script will grab the existing published Azure Stack SKU's from the following URL.

.PARAMETER MatchFile
    Eventually will ask for input file to match against Azure Stack SKUs

.EXAMPLE
    ./parseStackSKU.ps1 

.NOTES
    Plan to add parameters for a few things like -MatchFile to match values in stack to a file.

.LINK
    Azure Stack SKUs: https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-vm-sizes

#>

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

# Disk IOP format --- need to break apart to new field |  8 / 8x500

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

        # // Find title header and build names
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

            $skuObj | Add-Member -NotePropertyName $titles[$counter] -NotePropertyValue $skuData -Force

            $counter ++

        }

        $global:skuReport += $skuObj

    }
}

Write-Host 'Type $skuReport to see available Azure Stack SKUs'
Write-Host 'Example find SKUs with greater than 4 vCPU: $skuReport | where vCPU -gt 4'
Write-Host 'Example find SKUs greater than or equal to 32GB RAM: $skuReport | where "Memory (GIB)" -ge 32'