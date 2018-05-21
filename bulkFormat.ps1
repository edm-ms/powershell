param (
    [Parameter(Mandatory=$false)][string]$contract=$(throw "Specify contract type: payg, ri1y, ri3y"),
    [Parameter(Mandatory=$false)][string]$ssd=$(throw "Specify SSD: yes, no")
    )

Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Choose file to import"
    $OpenFileDialog.InitialDirectory = $initialDirectory
    $OpenFileDialog.Filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.Filename
}

Function Save-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
   
    $OpenFileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.SelectedPath

} 

$fileName = 'vmchooser.csv'

$inputFile = Get-FileName

$outputFile = Save-Filename
$outputFile = $outputFile + "\" + $fileName

$allVMs = Import-Csv $inputFile

If (Test-Path $outputFile) {Remove-Item $outputFile}

Start-Process microsoft-edge:https://azurevmchooser.kvaes.be/bulkuploader

$vmName = 'unknown'
$azureLocation = 'us-east'
$vmCores = '1'
$vmMem = '2'
$vmDiskSize = '128'

$iops = '500'
$throughput = '25'

$nics = '1'
$tempDiskSize = '10'
$peakCPU= '100'
$peakMem = '100'

$currency = 'USD'
$burstable = 'no'

$os = 'linux'

Add-Content -Path $outputFile -Value '"VM Name","Region","Cores","Memory (GB)","SSD [Yes/No]","NICs","Max Disk Size (TB)","IOPS","Throughput (MB/s)","Min Temp Disk Size (GB)","Peak CPU Usage (%)","Peak Memory Usage (%)","Currency","Contract","Burstable","OS"'

foreach ($vm in $allVMs) {

    $vmName = $vm.Name
    $vmCores = $vm.CPUs
    $vmMem = $vm.Memory
    $vmDiskSize = $vm.Provisioned

    $fileContent = $vmName + "," + $azureLocation + "," + $vmCores + "," + $vmMem + "," + $ssd + "," + $nics + "," + $vmDiskSize + "," + $iops + "," + $throughput + "," + $tempDiskSize + "," + $peakCPU+ "," + $peakMem + "," + $currency + "," + $contract + "," + $burstable + "," + $os
    Add-Content -Path $outputFile -Value $fileContent
}