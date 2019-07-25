$indianaISP = "Comcast Cable Communications, LLC - ASN 7922"
$country = "United States"
$state = "indiana"
$netWatcherName = "NetworkWatcher_eastus"
$networkWatchRG = "Networks"
$latencyReport = @()

$providers = Get-AzNetworkWatcherReachabilityProvidersList -NetworkWatcherName NetworkWatcher_eastus -ResourceGroupName Networks
($providers | select Countries).Countries[15].States.Providers | select -Unique
($providers | select Countries).Countries[15].States


$dataReport = Get-AzNetworkWatcherReachabilityReport `
  -NetworkWatcherName $netWatcherName `
  -ResourceGroupName $networkWatchRG `
  -Provider $indianaISP `
  -Country $country `
  -State $state `
  -StartTime "2019-06-01" `
  -EndTime "2019-06-02"

  for ($i = 0; $i -lt $dataReport.ReachabilityReport.Count ; $i ++) {

    $latencyData = New-Object System.Object
    $latencyData | Add-Member -NotePropertyName AzureRegion -NotePropertyValue $dataReport.ReachabilityReport[$i].AzureLocation
    $latencyData | Add-Member -NotePropertyName LatencyScore -NotePropertyValue $dataReport.ReachabilityReport[$i].Latencies.Score

    $latencyReport += $latencyData

  }


  Get-AzNetworkWatcherReachabilityProvidersList `
  -NetworkWatcherName NetworkWatcher_eastus `
  -ResourceGroupName Network `
  -City Seattle `
  -Country "United States" `
  -State washington