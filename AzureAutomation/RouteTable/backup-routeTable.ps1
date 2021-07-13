$filePrefix = "routeTableBackup"
$fileSuffix = Get-Date (Get-Date).ToUniversalTime() -UFormat "%Y-%m-%d-%H%M%S"
$outputFile = "$filePrefix-$fileSuffix.csv"
$outputObject = @()

$resourceType = "microsoft.network/routetables"
$routeTables = (Search-AzGraph -Query "Resources | where type =~ '$resourceType'").Data

foreach ($routeTable in $routeTables) {

  foreach ($route in $routeTable.Properties.Routes) {

    $routeObj = New-Object System.Object
    $routeObj | Add-Member -NotePropertyName "SubscriptionID" $routeTable.subscriptionId
    $routeObj | Add-Member -NotePropertyName "RouteTable" $routeTable.name
    $routeObj | Add-Member -NotePropertyName "ResourceGroup" $routeTable.resourceGroup
    $routeObj | Add-Member -NotePropertyName "Location" $routeTable.Location
    $routeObj | Add-Member -NotePropertyName "DisableBGPPropagation" $routeTable.Properties.disableBgpRoutePropagation
    $routeObj | Add-Member -NotePropertyName "RouteName" $route.name
    $routeObj | Add-Member -NotePropertyName "addressPrefix" $route.properties.addressPrefix
    $routeObj | Add-Member -NotePropertyName "nextHopIpAddress" $route.properties.nextHopIpAddress
    $routeObj | Add-Member -NotePropertyName "nextHopType" $route.properties.nextHopType

    $outputObject += $routeObj

  }
}

$outputObject | Export-Csv -Path $outputFile