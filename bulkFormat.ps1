Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

$inputFile = Get-FileName

$allVMs = Import-Csv $inputFile
$myOutFile = 'C:\Users\ermoor\Desktop\vmChooser.csv'

If (Test-Path $myOutFile) {Remove-Item $myOutFile}

$vmName = 'unknown'
$azureLocation = 'us-east'
$vmCores = '1'
$vmMem = '2'
$vmDiskSize = '128'

$iops = '500'
$throughput = '25'

$ssd = 'yes'
$nics = '1'
$tempDiskSize = '10'
$peakCPU= '100'
$peakMem = '100'

$currency = 'USD'
$contract = 'ri1y' #options: payg, ri1y, ri3y
$burstable = 'no'

$os = 'windows'



#$myOutFile = 

# Bulk Uploader Tool: https://azurevmchooser.kvaes.be/bulkuploader

Add-Content -Path $myOutFile -Value '"VM Name","Region","Cores","Memory (GB)","SSD [Yes/No]","NICs","Max Disk Size (TB)","IOPS","Throughput (MB/s)","Min Temp Disk Size (GB)","Peak CPU Usage (%)","Peak Memory Usage (%)","Currency","Contract","Burstable","OS"'

foreach ($vm in $allVMs) {

    #$vmName = $vm.Name
    $vmCores = $vm.CPUs
    $vmMem = $vm.Memory
    $vmDiskSize = $vm.Provisioned

    $fileContent = $vmName + "," + $azureLocation + "," + $vmCores + "," + $vmMem + "," + $ssd + "," + $nics + "," + $vmDiskSize + "," + $iops + "," + $throughput + "," + $tempDiskSize + "," + $peakCPU+ "," + $peakMem + "," + $currency + "," + $contract + "," + $burstable + "," + $os
    Add-Content -Path $myOutFile -Value $fileContent
}