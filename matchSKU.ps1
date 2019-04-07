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

$cpuMemory = @()
$memMatch = @()
$matchedSKUs = @()
    
$cpuMemory += ($dcReport | select vCPU, Memory)

# // Normalize memory values, matching Azure SKU, and rounding up

foreach ($vm in $cpuMemory) {

    foreach ($item in $allMemTypes) {

        If ($vm.Memory -eq $item.MemoryInMB) { break } # // stop if RAM is a match
        If (($vm.Memory - $item.MemoryInMB) -lt 0) { $cpuMemory[$mn].Memory = $item.MemoryInMB ;break }

    }

    $mn ++

    }

# // Logic for adjusting input values

foreach ($item in $cpuMemory) {
        
    if ( $item.vCPU -ge 6 -and $item.Memory -ge 16384) { $cpuMemory[$ll].vCPU = 8  } # // Adjust CPU/Mem balance
    if ( $item.vCPU -ge 6 -and $item.Memory -lt 16384) { $cpuMemory[$ll].vCPU = 4  } # // Adjust CPU/Mem balance
    if ( $item.Memory -le 4096 -and $item.vCPU -ge 4) { $cpuMemory[$ll].vCPU = 2  } # // Adjust CPU/Mem balance

    $ll ++

    }

$cpuCountType = $cpuMemory | Group-Object vCPU | Select Name

foreach ($cpuMatch in $cpuCountType) {

    $cpuMatch = $cpuMatch.Name

    $memCountType = $cpuMemory | where vCPU -eq $cpuMatch | Group-Object Memory

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

$matchedSKUs | where SKU -ne 'N/A' | Select-Object Qty, SKU
write-host "Unmatched VMs:" ($matchedSKUs | where Match -eq "No" | measure qty -sum).sum