$filePrefix = "vnetPeerBackup"
$fileSuffix = Get-Date (Get-Date).ToUniversalTime() -UFormat "%Y-%m-%d-%H%M%S"
$outputFile = "$filePrefix-$fileSuffix.csv"

$outputObject = @()

$resourceType = "microsoft.network/virtualNetworks"
$vnets = (Search-AzGraph -Query "Resources | where type =~ '$resourceType'").Data

foreach ($vnet in $vnets) {

    foreach ($peer in $vnet.Properties.virtualNetworkPeerings) {

      $vnetObj = New-Object System.Object
      $vnetObj | Add-Member -NotePropertyName "SubscriptionID" $vnet.subscriptionId
      $vnetObj | Add-Member -NotePropertyName "VNetID" $vnet.id
      $vnetObj | Add-Member -NotePropertyName "VNetName" $vnet.name
      $vnetObj | Add-Member -NotePropertyName "Location" $vnet.Location
      $vnetObj | Add-Member -NotePropertyName "ResourceGroup" $vnet.resourceGroup
      $vnetObj | Add-Member -NotePropertyName "PeeringName" $peer.Name
      $vnetObj | Add-Member -NotePropertyName "AllowGWTransit" $peer.properties.allowGatewayTransit
      $vnetObj | Add-Member -NotePropertyName "AllowForwardedTraffic" $peer.properties.allowForwardedTraffic
      $vnetObj | Add-Member -NotePropertyName "UseRemoteGW" $peer.properties.useRemoteGateways
      $vnetObj | Add-Member -NotePropertyName "PeeringState" $peer.properties.peeringState
      $vnetObj | Add-Member -NotePropertyName "RemoteID" $peer.properties.remoteVirtualNetwork.id

      $outputObject += $vnetObj
      
    }
}

$outputObject | Export-Csv -Path $outputFile