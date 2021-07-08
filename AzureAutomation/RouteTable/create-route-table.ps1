$routeTables = @()
$routeTableUniqueIds = @()

$routeTables = Import-Csv .\routeTableCopy.csv

# // Remove blank entries
$routeTables = $routeTables | Where-Object "Route Table" -ne ""

# // Find unique items
$routeTableUniqueIds = $routeTables | Select-Object 'Route Table', SubscriptionId, ResourceGroup, Location | Get-Unique -AsString

foreach ($uniqueRoute in $routeTableUniqueIds) {

    $currentRouteTable = $null
    Set-AzContext -SubscriptionId $uniqueRoute.SubscriptionId
    $rgName = $uniqueRoute.ResourceGroup
    $location = $uniqueRoute.Location
    $routeTableName = $uniqueRoute.'Route Table'

    # // If route table exists copy it with "backup-" in the name and create a new route table
    if ( ($currentRouteTable = Get-AzRouteTable -Name $routeTableName -ResourceGroupName $rgName) ) {

        # // Set newRouteTable variable equal to existing route table
        $newRouteTable = Get-AzRouteTable -ResourceGroupName $rgName -Name $routeTableName

        $routeConfig = Get-AzRouteConfig -RouteTable $currentRouteTable
        $backupRouteTableName = "backup-" + $routeTableName
        $routeTableBackup = New-AzRouteTable -Name $backupRouteTableName -ResourceGroupName $rgName -Location $location -Force

        foreach ($currentRoute in $routeConfig) {

            $routeTableBackup | Add-AzRouteConfig `
            -Name $currentRoute.Name `
            -AddressPrefix $currentRoute.AddressPrefix `
            -NextHopType $currentRoute.NextHopType `
            -NextHopIpAddress $currentRoute.NextHopIpAddress
        }

        $routeTableBackup | Set-AzRouteTable
        
    }
    else {$newRouteTable = New-AzRouteTable -Name $routeTableName -ResourceGroupName $rgName -location $location }

    # // Get current route table configuration
    $newRouteTableConfig = Get-AzRouteConfig -RouteTable $newRouteTable

    foreach ($route in $routeTables | Where-Object "Route Table" -eq $routeTableName) {

        if ($route.'Next Hop' -eq "Internet") { $route.'Next Hop IP Address' = ''  }
        if ($route.'Next Hop' -eq "Virtual Appliance") { $route.'Next Hop IP Address' = 'VirtualAppliance'  }

        # // If route name exists then modify route, else add the route
        if ($route.Name -in $newRouteTableConfig.Name) { 

            $newRouteTable | Set-AzRouteConfig `
            -Name $route.Name `
            -AddressPrefix $route.'Address prefix' `
            -NextHopType $route.'Next Hop' `
            -NextHopIpAddress $route.'Next Hop IP Address'

        }
        else {

            $newRouteTable | Add-AzRouteConfig `
            -Name $route.Name `
            -AddressPrefix $route.'Address prefix' `
            -NextHopType $route.'Next Hop' `
            -NextHopIpAddress $route.'Next Hop IP Address'
        }
    }

    $newRouteTable | Set-AzRouteTable
}