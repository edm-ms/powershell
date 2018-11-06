param (
    [Parameter(Position=1, Mandatory=$false, HelpMessage="Specify SSD: yes or no")]
    [ValidateSet("yes","no", "all")]
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
$contractTypes = 'payg', 'ri1y', 'ri3y'

$inputFile = Get-FileName
$outputPath = Save-Filename

$allVMs = Import-Csv $inputFile

Start-Process microsoft-edge:https://azurevmchooser.kvaes.be/bulkuploader

$colName = "VM Name"
$colregion = "Region"
$colCores = "Cores"
$colMem = "Memory (GB)"
$colSSD = "SSD"
$colNics = "NICs"
$colDiskSize = "Max Disk Size (TB)"
$colIops = "IOPS"
$colThroughput = "Throughput (MB/s)"
$colMinTemp = "Min Temp Disk Size (GB)"
$colPeakCPU = "Peak CPU Usage (%)"
$colPeakMem = "Peak Memory Usage (%)"
$colCurrency = "Currency"
$colContract = "Contract"
$colBurst = "Burstable"
$colHANA = "SAPHANA"
$colSAP2 = "SAPS2T"
$colSAP3 = "SAPS3T"
$colSisla = "SISLA"
$colOverrideDisk = "OVERRIDEDISKTYPE"
$colOS = "OS"
$colOSDisk = "OSDISK"

$iops = '500'
$throughput = '25'
$tempDiskSize = '10'
$peakCPU= '100'
$peakMem = '100'
$currency = 'USD'
$burstable = 'No'
$azureLocation = 'brazil-south'
$vmHANA = 'No'
$vmSAP2 = ''
$vmSAP3 = ''
$vmSISLA = 'No'
$vmOverride = 'No'
$osDisk = ''
$i = 0

foreach ($actype in $contractTypes) {

    $contract = $contractTypes[$i]
    $outputFile = $outputPath + "\" + $contractTypes[$i] + "-" + $fileName

    If (Test-Path $outputFile) {Remove-Item $outputFile}

    Add-Content -Path $outputFile -Value "$colName,$colregion,$colCores,$colMem,$colSSD,$colNics,$colDiskSize,$colIops,$colThroughput,$colMinTemp,$colPeakCPU,$colPeakMem,$colCurrency,$colContract,$colBurst,$colHANA,$colSAP2,$colSAP3,$colSisla,$colOverrideDisk,$colOS,$colOSDisk"

    $i ++

    foreach ($vm in $allVMs) {

        $vmName = $vm.Name
        $vmCores = $vm.CPUs

        $vmMem = $vm.Memory / 1000
        $vmMem = [math]::Round($vmMem) 

        $vmDiskSize = $vm.Storage / 1000
        $vmDiskSize = [math]::Round($vmDiskSize, 3)
        
        $vmNics = $vm.NICs        
        $vmSSD = $vm.SSD
        $os = $vm.OS
        $region = $vm.Region

        If ($vm.Region -eq '') { $region = $azureLocation }
        If ($vm.SSD -eq '') { $vmSSD = $ssd }
        If ($vm.NICs -eq '') { $vmNics = 1}
        If ($vm.OS -like "*linux*") {$vm.OS = "linux"}
        If ($vm.OS -like "*cent*") {$vm.OS = "linux"}
        If ($vm.OS -like "*windows*") {$vm.OS = "windows"}
        If ($vm.OS -like "*other*") {$vm.OS = "windows"}

        $fileContent = $vmName + "," + $region + "," + $vmCores + "," + $vmMem + "," + $vmSSD + "," + $vmNics + "," + $vmDiskSize + "," + $iops + "," + $throughput + "," + $tempDiskSize + "," + $peakCPU+ "," + $peakMem + "," + $currency + "," + $contract + "," + $burstable + "," + $vmHANA + "," + $vmSAP2 + "," + $vmSAP3 + "," + $vmSISLA + "," + $vmOverride + "," + $os + "," + $osDisk
        Add-Content -Path $outputFile -Value $fileContent
    }
}