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

    $vmState = $inputFile[$startRead..$endRead] | Select-String $vmStateSearchString
    $vmState = $vmState.Line.Split('<')[8]
    $vmState = $vmState.Substring(3,$vmState.length-3)
    
    $cpuCount = $inputFile[$startRead..$endRead] | Select-String $cpuSearchString
    $cpuCount = $cpuCount.Line.Split('<')[8]
    $cpuCount = $cpuCount.Substring(3,$cpuCount.length-3)
    
    $vmMem = $inputFile[$startRead..$endRead] | Select-String $dMemSearchString

    if ($vmMem -eq $null) { $vmMem = $inputFile[$startRead..$endRead] | Select-String $sMemSearchString }
    
    $vmMem = $vmMem.Line.Split('<')[8]
    $vmMem = $vmMem.Substring(3,$vmMem.length-3)
    $vmMem = $vmMem.Split(' ')[0]
    $vmMem = [int]$vmMem

    $nicCount = $inputFile[$startRead..$endRead] | Select-String $nicSearchString
    $nicCount = $nicCount.Line.Split('<')[8]
    $nicCount = $nicCount.Substring(3,$nicCount.length-3)
    
    $driveCount = $inputFile[$startRead..$endRead] | Select-String $driveCountSearchString
    $driveCount = $driveCount.Line.Split('<')[8]
    $driveCount = $driveCount.Substring(3,$driveCount.length-3)
    $driveCount = [int]$driveCount

    $driveSpaceTotal = $inputFile[$startRead..$endRead] | Select-String $driveSpaceSearchString
    $driveSpaceUsed = $inputFile[$startRead..$endRead] | Select-String $driveSpaceUsedSearchString

    $drivesHash = @{}
    $largestDrive = 0

    do { # // Loop for the number of drives, create drive object(s), and add then total drives

        if ($driveSpaceTotal -eq $null) {

            $driveSpaceTotal =@('<tr class="r0"><td class="V">&nbsp;V&nbsp;</td><td><em>Maximum capacity</em></td><td>0 GB</td></tr>')
            $spaceTotal = $driveSpaceTotal[$driveLoop].Split('<')[8]

        }

        else {
        
            $spaceTotal = $driveSpaceTotal[$driveLoop].Line.Split('<')[8]

        }

        if ($driveSpaceUsed -eq $null) {

            $driveSpaceUsed =@('<tr class="r0"><td class="V">&nbsp;V&nbsp;</td><td><em>Used capacity (for dynamic VHD)</em></td><td>0 GB</td></tr>')
            $usedTotal = $driveSpaceUsed[$driveLoop].Split('<')[8]

        }

        else {
        
            $usedTotal = $driveSpaceUsed[$driveLoop].Line.Split('<')[8]

        }  

        $spaceTotal = $spaceTotal.Substring(3,$spaceTotal.length-3)
        $spaceTotal = $spaceTotal.Split(' ')[0]
        $spaceTotal = [int]$spaceTotal

        $usedTotal = $usedTotal.Substring(3,$usedTotal.length-3)
        $usedTotal = $usedTotal.Split(' ')[0]
        $usedTotal = [int]$usedTotal

        $driveName = 'Drive' + $driveLoop
        $drivesHash.add($driveName, $spaceTotal)

        if ( $spaceTotal -gt $largestDrive ) { $largestDrive = $spaceTotal }

        $driveLoop ++

        $totalSpace = $totalSpace + $spaceTotal
        $totalUsedSpace = $totalUsedSpace + $usedTotal

    }

    while ($driveCount -gt $driveLoop)
    
    $guestOS = $inputFile[$startRead..$endRead] | Select-String $guestOSString
    $guestOS = $guestOS.Line.Split('<')[8]
    $guestOS = $guestOS.Substring(3,$guestOS.length-3)

    $dcObj = New-Object System.Object
    $dcObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $vmList[$i].VMName
    $dcObj | Add-Member -NotePropertyName 'State' -NotePropertyValue $vmState
    $dcObj | Add-Member -NotePropertyName 'vCPU' -NotePropertyValue $cpuCount
    $dcObj | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $vmMem
    $dcObj | Add-Member -NotePropertyName 'NICs' -NotePropertyValue $nicCount
    $dcObj | Add-Member -NotePropertyName 'DriveCount' -NotePropertyValue $driveCount
    $dcObj | Add-Member -NotePropertyName "Drives" -NotePropertyValue $drivesHash
    $dcObj | Add-Member -NotePropertyName "LargestDrive" -NotePropertyValue $largestDrive
    $dcObj | Add-Member -NotePropertyName 'TotalSpace' -NotePropertyValue $totalSpace
    $dcObj | Add-Member -NotePropertyName 'UsedSpace' -NotePropertyValue $totalUsedSpace  
    $dcObj | Add-Member -NotePropertyName 'OS' -NotePropertyValue $guestOS

    $dcReport += $dcObj

    $i ++

} 

while ($i -lt $vmList.length)

Write-Host "Total VMs:" $dcReport.length
Write-Host "Total Space:" ($dcReport | Measure-Object 'TotalSpace' -sum).sum
Write-Host "Average vCPU:" ($dcReport | Measure-Object 'vCPU' -Average).Average
Write-Host "Average RAM:" ($dcReport | Measure-Object 'Memory' -Average).Average

# // $dcreport.drives | % { $_.Values -lt 128 }
# // $dcreport.drives | % { $allDrives += $_.Values }