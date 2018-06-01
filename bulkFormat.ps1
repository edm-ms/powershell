param (
    [Parameter(Position=0, Mandatory=$true, HelpMessage="Specify a contract type: payg, ri1y, or ri3y")]
    [ValidateSet("payg","ri1y","ri3y")]
    [string]$contract,

    [Parameter(Position=1, Mandatory=$true, HelpMessage="Specify SSD: yes or no")]
    [ValidateSet("yes","no")]
    [string]$ssd,

    [Parameter(Position=2, Mandatory=$false, HelpMessage="Specify default location: us-north-central, us-east, etc.")]
    [string]$azureLocation

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

if ($azureLocation -eq $null) {$azureLocation = 'us-north-central'}

$iops = '500'
$throughput = '25'
$nics = '1'
$tempDiskSize = '10'
$peakCPU= '100'
$peakMem = '100'
$currency = 'USD'
$burstable = 'no'

Add-Content -Path $outputFile -Value '"VM Name","Region","Cores","Memory (GB)","SSD [Yes/No]","NICs","Max Disk Size (TB)","IOPS","Throughput (MB/s)","Min Temp Disk Size (GB)","Peak CPU Usage (%)","Peak Memory Usage (%)","Currency","Contract","Burstable","OS"'

foreach ($vm in $allVMs) {

    $vmName = $vm.Name
    $vmCores = $vm.CPUs
    $vmMem = $vm.Memory
    $vmDiskSize = $vm.Provisioned
    $os = $vm.OS
    $region = $vm.Region

    If ($vm.Region -eq "") { $region = $azureLocation }

    $fileContent = $vmName + "," + $region + "," + $vmCores + "," + $vmMem + "," + $ssd + "," + $nics + "," + $vmDiskSize + "," + $iops + "," + $throughput + "," + $tempDiskSize + "," + $peakCPU+ "," + $peakMem + "," + $currency + "," + $contract + "," + $burstable + "," + $os
    Add-Content -Path $outputFile -Value $fileContent
}