$inputFile = Get-Content $env:myfile

$vmString = '<tr><td colspan="3"><h3> VM:'
$guestOSString = '</td><td><em>Guest OS</em></td><td>'
$cpuSearchString = '</td><td><em>Number of CPUs</em></td><td>'
$dMemSearchString = '</td><td><em>Start RAM</em></td><td>'
$sMemSearchString = '</td><td><em>RAM</em></td><td>'
$driveCountSearchString = '</td><td><em>Number of drives</em></td><td>'
$driveSpaceSearchString = '</td><td><em>Maximum capacity</em></td><td>'
$vmStateSearchString = '</td><td><em>State</em></td><td>'

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

    $driveLoop = 0
    $totalSpace = 0

    $guestOS = $inputFile[$startRead..$endRead] | Select-String $guestOSString
    $guestOS = $guestOS.Line.Split('<')[8]
    $guestOS = $guestOS.Substring(3,$guestOS.length-3)

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

    $driveCount = $inputFile[$startRead..$endRead] | Select-String $driveCountSearchString
    $driveCount = $driveCount.Line.Split('<')[8]
    $driveCount = $driveCount.Substring(3,$driveCount.length-3)

    $driveSpace = $inputFile[$startRead..$endRead] | Select-String $driveSpaceSearchString
    
    do { # // Loop for the number of drives and add them together

        $driveSpaceLoop = $driveSpace[$driveLoop].Line.Split('<')[8]
        $driveSpaceLoop = $driveSpaceLoop.Substring(3,$driveSpaceLoop.length-3)
        $driveSpaceLoop = $driveSpaceLoop.Split(' ')[0]
        $driveSpaceLoop = [int]$driveSpaceLoop

        $driveLoop ++

        $totalSpace = $totalSpace + $driveSpaceLoop

    }

    while ($driveLoop+1 -lt $driveCount)

    $dcObj = New-Object System.Object
    $dcObj | Add-Member -NotePropertyName 'VM Name' -NotePropertyValue $vmList[$i].VMName
    $dcObj | Add-Member -NotePropertyName 'VM State' -NotePropertyValue $vmState
    $dcObj | Add-Member -NotePropertyName 'vCPU Count' -NotePropertyValue $cpuCount
    $dcObj | Add-Member -NotePropertyName 'Memory MB' -NotePropertyValue $vmMem
    $dcObj | Add-Member -NotePropertyName 'Drive Count' -NotePropertyValue $driveCount
    $dcObj | Add-Member -NotePropertyName 'Total Space GB' -NotePropertyValue $totalSpace
    $dcObj | Add-Member -NotePropertyName 'Guest OS' -NotePropertyValue $guestOS

    $dcReport += $dcObj

    $i ++
    

} 

while ($i -lt $vmList.length-1)