function bulkImportFormat () {
    
$bulkImportObj = New-Object System.Object

$bulkImportObj | Add-Member -NotePropertyName "VM Name" -NotePropertyValue $vmName
$bulkImportObj | Add-Member -NotePropertyName "Region" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Cores" -NotePropertyValue $cpuCount
$bulkImportObj | Add-Member -NotePropertyName "Memory (GB)" -NotePropertyValue $vmMem
$bulkImportObj | Add-Member -NotePropertyName "SSD" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "NICs" -NotePropertyValue $nicCount
$bulkImportObj | Add-Member -NotePropertyName "Max Disk Size (TB)" -NotePropertyValue $driveSpaceTotal
$bulkImportObj | Add-Member -NotePropertyName "IOPS" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Throughput (MB/s)" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Min Temp Disk Size (GB)" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Peak CPU Usage (%)" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Peak Memory Usage (%)" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Currency" -NotePropertyValue 'USD'
$bulkImportObj | Add-Member -NotePropertyName "Contract" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "Burstable" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "SAPHANA" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "SAPS2T" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "SAPS3T" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "SISLA" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "OVERRIDEDISKTYPE" -NotePropertyValue
$bulkImportObj | Add-Member -NotePropertyName "OS" -NotePropertyValue $guestOS
$bulkImportObj | Add-Member -NotePropertyName "OSDISK" -NotePropertyValue

}

$inputFile = Get-Content $env:myfile

$vmString = '<tr><td colspan="3"><h3> VM:'
$guestOSString = '</td><td><em>Guest OS</em></td><td>'
$cpuSearchString = '</td><td><em>Number of CPUs</em></td><td>'
$nicSearchString = '</td><td><em>Number of network adapters</em></td><td>'
$dMemSearchString = '</td><td><em>Start RAM</em></td><td>'
$sMemSearchString = '</td><td><em>RAM</em></td><td>'
$driveCountSearchString = '</td><td><em>Number of drives</em></td><td>'
$driveSpaceSearchString = 'Maximum capacity'
$vmStateSearchString = '</td><td><em>State</em></td><td>'
$driveSpaceUsedSearchString = 'Used capacity'

$vmList = @()
$dcReport = @()
$i = 0

foreach ($line in $inputFile) {
    
    If ($line.length -lt 28) { continue }
    
    If ($line.Substring(0,28) -eq $vmString) {

        $vmName = $line.split(':')
        $vmName = $vmName.split(' ')[4]

        $vmNameSearch = '<tr><td colspan="3"><h3> VM: ' + $vmName + ' </h3></td></tr>'
        $arrayPosition = [array]::indexof($inputFile,$vmNameSearch)

        $vmObj = New-Object System.Object
        $vmObj | Add-Member -NotePropertyName VMName -NotePropertyValue $vmName
        $vmObj | Add-Member -NotePropertyName ArrayPos -NotePropertyValue $arrayPosition

        $vmList += $vmObj

    }
}

do {

    $startRead = $vmList[$i].ArrayPos
    $endRead = $vmList[$i+1].ArrayPos - 1

    # // If this is the last part of the array to read get the endpoint as the count of items in the array
    if ($i -eq $vmlist.length-1) { $endRead = $inputFile.Length }

    $driveLoop = 0
    $totalSpace = 0
    $totalUsedSpace = 0

        $dcObj = New-Object System.Object
        $dcObj | Add-Member -NotePropertyName 'VM Name' -NotePropertyValue $vmList[$i].VMName

    $vmState = $inputFile[$startRead..$endRead] | Select-String $vmStateSearchString
    $vmState = $vmState.Line.Split('<')[8]
    $vmState = $vmState.Substring(3,$vmState.length-3)
    
        $dcObj | Add-Member -NotePropertyName 'VM State' -NotePropertyValue $vmState

    $cpuCount = $inputFile[$startRead..$endRead] | Select-String $cpuSearchString
    $cpuCount = $cpuCount.Line.Split('<')[8]
    $cpuCount = $cpuCount.Substring(3,$cpuCount.length-3)
    
        $dcObj | Add-Member -NotePropertyName 'vCPU' -NotePropertyValue $cpuCount

    $vmMem = $inputFile[$startRead..$endRead] | Select-String $dMemSearchString

    if ($vmMem -eq $null) { $vmMem = $inputFile[$startRead..$endRead] | Select-String $sMemSearchString }
    
    $vmMem = $vmMem.Line.Split('<')[8]
    $vmMem = $vmMem.Substring(3,$vmMem.length-3)
    $vmMem = $vmMem.Split(' ')[0]
    $vmMem = [int]$vmMem
    
        $dcObj | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $vmMem

    $nicCount = $inputFile[$startRead..$endRead] | Select-String $nicSearchString
    $nicCount = $nicCount.Line.Split('<')[8]
    $nicCount = $nicCount.Substring(3,$nicCount.length-3)

        $dcObj | Add-Member -NotePropertyName 'NICs' -NotePropertyValue $nicCount
    
    $driveCount = $inputFile[$startRead..$endRead] | Select-String $driveCountSearchString
    $driveCount = $driveCount.Line.Split('<')[8]
    $driveCount = $driveCount.Substring(3,$driveCount.length-3)
    $driveCount = [int]$driveCount

        $dcObj | Add-Member -NotePropertyName 'Drive Count' -NotePropertyValue $driveCount

    $driveSpaceTotal = $inputFile[$startRead..$endRead] | Select-String $driveSpaceSearchString
    $driveSpaceUsed = $inputFile[$startRead..$endRead] | Select-String $driveSpaceUsedSearchString

    do { # // Loop for the number of drives, create drive object(s), and add then total drives

        if ($driveSpaceTotal -eq $null) {

            $driveSpaceTotal =@('<tr class="r0"><td class="V">&nbsp;V&nbsp;</td><td><em>Maximum capacity</em></td><td>0 GB</td></tr>')
            $driveSpaceTotalLoop = $driveSpaceTotal[$driveLoop].Split('<')[8]

        }

        else {
        
            $driveSpaceTotalLoop = $driveSpaceTotal[$driveLoop].Line.Split('<')[8]

        }

        if ($driveSpaceUsed -eq $null) {

            $driveSpaceUsed =@('<tr class="r0"><td class="V">&nbsp;V&nbsp;</td><td><em>Used capacity (for dynamic VHD)</em></td><td>0 GB</td></tr>')
            $driveSpaceUsedLoop = $driveSpaceUsed[$driveLoop].Split('<')[8]

        }

        else {
        
            $driveSpaceUsedLoop = $driveSpaceUsed[$driveLoop].Line.Split('<')[8]

        }  

        $driveSpaceTotalLoop = $driveSpaceTotalLoop.Substring(3,$driveSpaceTotalLoop.length-3)
        $driveSpaceTotalLoop = $driveSpaceTotalLoop.Split(' ')[0]
        $driveSpaceTotalLoop = [int]$driveSpaceTotalLoop

        $driveSpaceUsedLoop = $driveSpaceUsedLoop.Substring(3,$driveSpaceUsedLoop.length-3)
        $driveSpaceUsedLoop = $driveSpaceUsedLoop.Split(' ')[0]
        $driveSpaceUsedLoop = [int]$driveSpaceUsedLoop

        $dcObj | Add-Member -NotePropertyName "Drive $driveLoop" -NotePropertyValue $driveSpaceUsedLoop

        $driveLoop ++

        $totalSpace = $totalSpace + $driveSpaceTotalLoop
        $totalUsedSpace = $totalUsedSpace + $driveSpaceUsedLoop

    }

    while ($driveCount -gt $driveLoop)
    
        $dcObj | Add-Member -NotePropertyName 'Total Assigned Space' -NotePropertyValue $totalSpace
        $dcObj | Add-Member -NotePropertyName 'Total Used Space' -NotePropertyValue $totalUsedSpace
    
    $guestOS = $inputFile[$startRead..$endRead] | Select-String $guestOSString
    $guestOS = $guestOS.Line.Split('<')[8]
    $guestOS = $guestOS.Substring(3,$guestOS.length-3)
    
        $dcObj | Add-Member -NotePropertyName 'OS' -NotePropertyValue $guestOS

    $dcReport += $dcObj

    $i ++

} 

while ($i -lt $vmList.length)

Write-Host "Total VMs:" $dcReport.length
Write-Host "Total Space:" ($dcReport | Measure-Object 'Total Assigned Space' -sum).sum
Write-Host "OS Drive Space:" ($dcReport | Measure-Object 'Drive 0' -sum).sum
Write-Host "Average vCPU:" ($dcReport | Measure-Object 'vCPU' -Average).Average
Write-Host "Average RAM:" ($dcReport | Measure-Object 'Memory' -Average).Average