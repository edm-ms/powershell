$filePrefix = "routeTableAttachBackup"
$fileSuffix = Get-Date (Get-Date).ToUniversalTime() -UFormat "%Y-%m-%d-%H%M%S"
$outputFile = "$filePrefix-$fileSuffix.csv"

$outputObject = @()

$resourceType = "microsoft.network/virtualNetworks"
$vnets = (Search-AzGraph -Query "Resources | where type =~ '$resourceType'").Data

foreach ($vnet in $vnets) {

    foreach ($subnet in $vnet.Properties.subnets) {

      $vnetObj = New-Object System.Object
      $vnetObj | Add-Member -NotePropertyName "SubscriptionID" $vnet.subscriptionId
      $vnetObj | Add-Member -NotePropertyName "VNetID" $vnet.id
      $vnetObj | Add-Member -NotePropertyName "VNetName" $vnet.name
      $vnetObj | Add-Member -NotePropertyName "Location" $vnet.Location
      $vnetObj | Add-Member -NotePropertyName "ResourceGroup" $vnet.resourceGroup
      $vnetObj | Add-Member -NotePropertyName "SubnetName" $subnet.Name
      $vnetObj | Add-Member -NotePropertyName "SubnetId" $subnet.id
      $vnetObj | Add-Member -NotePropertyName "SubnetAddress" $subnet.properties.addressPrefix
      $vnetObj | Add-Member -NotePropertyName "RouteTableId" $subnet.properties.routetable.id

      $outputObject += $vnetObj
      
    }
}

$outputObject | Export-Csv -Path $outputFile