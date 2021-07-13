param (
    [Parameter(Position=1, Mandatory=$true, HelpMessage="Enter full path of CSV file to process: ")]
    [string]$inputFile
)

$routeTables = @()
$uniqueRouteTables = @()

$routeTables = Import-Csv $inputFile

# // Remove blank entries
$routeTables = $routeTables | Where-Object "RouteTable" -ne ""

# // Find unique route tables
$uniqueRouteTables = $routeTables | Select-Object SubscriptionId, RouteTable, ResourceGroup, DisableBGPPropagation, Location | Get-Unique -AsString

foreach ($routeTable in $uniqueRouteTables) {

    Set-AzContext -SubscriptionId $routeTable.SubscriptionId

    # // Set variable equal to existing route table
    $currentRouteTable = Get-AzRouteTable -ResourceGroupName $routeTable.ResourceGroup -Name $routeTable.RouteTable

    # // Get current route table configuration
    $routeTableConfig = Get-AzRouteConfig -RouteTable $currentRouteTable

    # // If route table BGP propagation is different from file set it equal to value in file
    if ($routeTable.DisableBGPPropagation -notlike $currentRouteTable.DisableBgpRoutePropagation) { 
        $currentRouteTable.DisableBgpRoutePropagation = $routeTable.DisableBGPPropagation 
        Set-AzRouteTable -RouteTable $currentRouteTable
    }

    # // Loop through all routes in file where route table name matches current route table
    foreach ($route in $routeTables | Where-Object RouteTable -eq $routeTable.RouteTable) {

        # // If route name exists then modify route, else add the route
        if ($route.RouteName -in $routeTableConfig.Name) { 

            $currentRouteTable | Set-AzRouteConfig `
            -Name $route.RouteName `
            -AddressPrefix $route.addressPrefix `
            -NextHopType $route.nextHopType `
            -NextHopIpAddress $route.nextHopIpAddress

        }
        else {

            $currentRouteTable | Add-AzRouteConfig `
            -Name $route.RouteName `
            -AddressPrefix $route.addressPrefix `
            -NextHopType $route.nextHopType `
            -NextHopIpAddress $route.nextHopIpAddress
        }
    }

    $currentRouteTable | Set-AzRouteTable
}