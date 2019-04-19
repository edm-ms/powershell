Function ConvertTo-NormalHTML {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)]$HTML)

    $NormalHTML = New-Object -Com "HTMLFile"
    $NormalHTML.IHTMLDocument2_write($HTML.RawContent)
    return $NormalHTML
}

$stackVMSizes = 'https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-vm-sizes'

$stackSKU = Invoke-WebRequest -Uri $stackVMSizes
$stackHTML = ConvertTo-NormalHTML $stackSKU

$tables = @($stackHTML.getElementsByTagName('TABLE'))

# Disk IOP format --- need to break apart to new field |  8 / 8x500

$titles = @()
$skuReport = @()

foreach ($table in $tables) {

    $rows = @($table.Rows)

    foreach($row in $rows)

    {

        $cells = @($row.Cells)

        # // Find title header and build names

        if ($cells[0].tagName -eq "TH") { $titles = @($cells | % { ("" + $_.InnerText).Trim() }) }
        if ($titles[0] -eq 'Size - Size\Name') { break } # // Move to next table in loop if retired SKU
        if ($titles[0] -eq $cells[0].InnerText) { continue } # // Move to next row in table if header row

        $counter = 0
        $skuObj = New-Object System.Object

        foreach ($item in $cells) {

            $skuData = ($item.InnerText).Trim()
            $skuObj | Add-Member -NotePropertyName $titles[$counter] -NotePropertyValue $skuData -Force

            $counter ++

        }

        $skuReport += $skuObj

    }
}

Write-Host 'Type $skuReport to see available Azure Stack SKUs'
Write-Host 'Example find SKUs with greater than 4 vCPU: $skuReport | where vCPU -gt 4'
Write-Host 'Example find SKUs greater than or equal to 32GB RAM: $skuReport | where "Memory (GIB)" -ge 32'