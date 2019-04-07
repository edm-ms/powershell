[CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory)]
        [Object]$dcReport
)

If ((Get-AzContext).Account -eq $null) { Connect-AzAccount -Subscription $env:subid }

$allVMs = Get-AzVMSize -Location 'East-US2'
$allMemTypes =  $allvms | sort MemoryInMB | Select-Object MemoryInMB -Unique

$cml = 0 # // CPU Match Loop
$mml = 0 # // Memory Match Loop
$mn = 0 # // Memory Normalization Loop
$ll = 0 # Logic Loop

$driveSKUs = @(1, 32, 64, 128, 256, 512, 1024, 2048, 4096)

$asrMaxDriveSize = 4096
$osExclusions = @('', '*Router*', '*BSD*', '*Windows XP*', '*Windows 7*', '*Windows 8*', '*Windows 10*')

$vmToMatch = @()
$memMatch = @()
$matchedSKUs = @()
$vmExclusions = @()
    
# // Build Exclusions

foreach ($vm in $dcReport) {

     If ($vm.Drives.Values -gt $asrMaxDriveSize) { $vmExclusions += $vm.Name  }
     
}
     
foreach ($vm in $osExclusions) {

    $vmExclusions += ($dcReport | where OS -Like $vm | select Name).Name

}

$vmToMatch += ($dcReport | where Name -NotIn $vmExclusions | select vCPU, Memory)
$vmToMove += ($dcReport | where Name -NotIn $vmExclusions)

# // Normalize memory values, matching Azure SKU, and rounding up

foreach ($vm in $vmToMatch) {

    foreach ($item in $allMemTypes) {

        If ($vm.Memory -eq $item.MemoryInMB) { break } # // stop if RAM is a match
        If (($vm.Memory - $item.MemoryInMB) -lt 0) { $vmToMatch[$mn].Memory = $item.MemoryInMB ;break } # // round up to nearest available RAM SKU

    }

    $mn ++

    }

# // Logic for adjusting input values

foreach ($item in $vmToMatch) {
        
    if ( $item.vCPU -ge 6 -and $item.Memory -ge 16384) { $vmToMatch[$ll].vCPU = 8  } # // Adjust CPU/Mem balance
    if ( $item.vCPU -ge 6 -and $item.Memory -lt 16384) { $vmToMatch[$ll].vCPU = 4  } # // Adjust CPU/Mem balance
    if ( $item.Memory -le 4096 -and $item.vCPU -ge 4) { $vmToMatch[$ll].vCPU = 2  } # // Adjust CPU/Mem balance

    $ll ++

    }

$cpuCountType = $vmToMatch | Group-Object vCPU | Select Name 

foreach ($cpuMatch in $cpuCountType) {

    $cpuMatch = $cpuMatch.Name

    $memCountType = $vmToMatch | where vCPU -eq $cpuMatch | Group-Object Memory

    foreach ($memMatch in $memCountType) {
        
        $possibleMatch = $allVMs | where NumberOfCores -eq $cpuMatch | where MemoryInMB -eq $memMatch.Name | `
        where Name -notlike "*_N*" | where Name -notlike "*Promo*" | where Name -like "*_*s*"

        $qty = $memCountType[$mml].Count
            
        if ( $possibleMatch -eq $null ) { 

            $vmMatchObj = New-Object System.Object
            $vmMatchObj | Add-Member -NotePropertyName Qty -NotePropertyValue $qty
            $vmMatchObj | Add-Member -NotePropertyName Match -NotePropertyValue 'No'
            $vmMatchObj | Add-Member -NotePropertyName CPU -NotePropertyValue $cpuMatch
            $vmMatchObj | Add-Member -NotePropertyName Memory -NotePropertyValue $memMatch.Name
            $vmMatchObj | Add-Member -NotePropertyName SKU -NotePropertyValue 'N/A'

        }

        else { 
                
            $vmMatchObj = New-Object System.Object
            $vmMatchObj | Add-Member -NotePropertyName Qty -NotePropertyValue $qty
            $vmMatchObj | Add-Member -NotePropertyName Match -NotePropertyValue 'Yes'
            $vmMatchObj | Add-Member -NotePropertyName CPU -NotePropertyValue $cpuMatch
            $vmMatchObj | Add-Member -NotePropertyName Memory -NotePropertyValue $memMatch.Name
            $vmMatchObj | Add-Member -NotePropertyName SKU -NotePropertyValue $possibleMatch.Name
            
        }
 
        $matchedSKUs += $vmMatchObj
        $mml ++
    
    }

    $mml = 0
    $cml ++

}

$matchedSKUs = $matchedSKUs | Sort-Object qty -Descending
$unMatched = $matchedSKUs | where Match -eq "No" 
$matchedSKUs | where SKU -ne 'N/A' | Select-Object Qty, SKU
$unMatched


$i = 1

foreach ($drive in $driveSKUs) {

    if ($driveSKUs[$i] -eq $null) { break }
    write-host  $driveSKUs[$i] "|" ($vmToMove.drives | % { ($_.Values -le $driveSKUs[$i]) -gt $drive } | measure | select Count).Count
    $i ++

}