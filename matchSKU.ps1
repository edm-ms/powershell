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
$vmToMove = @()
$memMatch = @()
$matchedSKUs = @()
$vmExclusions = @()
$matchedDrives = @()
    
# // Build Exclusions

foreach ($vm in $dcReport) {

     If ($vm.Drives.Values -gt $asrMaxDriveSize) { 
         
        #$vmExclusions += $vm.Name  
        
        $vmExcludeObj = New-Object System.Object
        $vmExcludeObj | Add-Member -NotePropertyName Name -NotePropertyValue $vm.Name
        $vmExcludeObj | Add-Member -NotePropertyName Reason -NotePropertyValue 'Drive(s) > 4TB not supported by ASR'
        $vmExcludeObj | Add-Member -NotePropertyName Value -NotePropertyValue $vm.Drives.Values

        $vmExclusions += $vmExcludeObj
    
    }
     
}
     
foreach ($vm in $dcReport) {

    # $vmExclusions += ($dcReport | where OS -Like $vm | select Name).Name

    foreach ($os in $osExclusions) {

        If (($vm | where OS -Like $os | select Name).Name -ne $null) {

            $vmExcludeObj = New-Object System.Object
            $vmExcludeObj | Add-Member -NotePropertyName Name -NotePropertyValue $vm.Name
            $vmExcludeObj | Add-Member -NotePropertyName Reason -NotePropertyValue 'Unsupported operating system'
            $vmExcludeObj | Add-Member -NotePropertyName Value -NotePropertyValue $vm.OS
    
            $vmExclusions += $vmExcludeObj

            }
        }

    }

$vmToMatch += ($dcReport | where Name -NotIn $vmExclusions.Name | select vCPU, Memory)
$vmToMove += ($dcReport | where Name -NotIn $vmExclusions.Name)

# // Normalize memory values, matching Azure SKU, and rounding up

foreach ($vm in $vmToMatch) {

    foreach ($azureVM in $allMemTypes) {

        If ($vm.Memory -eq $azureVM.MemoryInMB) { break } # // stop if RAM is a match
        If (($vm.Memory - $azureVM.MemoryInMB) -lt 0) { $vmToMatch[$mn].Memory = $azureVM.MemoryInMB ; break } # // round up to nearest available RAM SKU

        }

    $mn ++

    }

# // Logic for adjusting input values

foreach ($azureVM in $vmToMatch) {
        
    if ( $azureVM.vCPU -ge 6 -and $azureVM.Memory -ge 16384) { $vmToMatch[$ll].vCPU = 8  } # // Adjust CPU/Mem balance
    if ( $azureVM.vCPU -ge 6 -and $azureVM.Memory -lt 16384) { $vmToMatch[$ll].vCPU = 4  } # // Adjust CPU/Mem balance
    if ( $azureVM.Memory -le 4096 -and $azureVM.vCPU -ge 4) { $vmToMatch[$ll].vCPU = 2  } # // Adjust CPU/Mem balance

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



$i = 1

foreach ($drive in $driveSKUs) {

    if ($driveSKUs[$i] -eq $null) { break }

    $driveQTY = ($vmToMove.drives | % { ($_.Values -le $driveSKUs[$i]) -gt $drive } | measure | select Count).Count

    $driveObj = New-Object System.Object
    $driveObj | Add-Member -NotePropertyName Size -NotePropertyValue $driveSKUs[$i]
    $driveObj | Add-Member -NotePropertyName Qty -NotePropertyValue $driveQTY

    $matchedDrives += $driveObj

    $i ++

}

$matchedSKUs = $matchedSKUs | Sort-Object qty -Descending

$matchedSKUs | Select-Object Qty, SKU

