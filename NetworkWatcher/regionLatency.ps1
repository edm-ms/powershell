$indianaISP = "Comcast Cable Communications, LLC - ASN 7922"
$country = "United States"
$state = "indiana"
$networkWatchRG = "Networks"


$dataReport = Get-AzNetworkWatcherReachabilityReport `
  -NetworkWatcherName NetworkWatcher_eastus `
  -ResourceGroupName $networkWatchRG `
  -Provider $indianaISP `
  -Country $country `
  -State $state `
  -StartTime "2019-06-01" `
  -EndTime "2019-06-02"