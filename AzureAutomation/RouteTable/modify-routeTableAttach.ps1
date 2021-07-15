param (
    [Parameter(Position=1, Mandatory=$true, HelpMessage="Enter full path of CSV file to process: ")]
    [string]$inputFile
)

# // Import CSV of peering relationships
$vnets = Import-Csv $inputFile

# // Find unique vnets
$uniqueVnets = $vnets | Select-Object SubscriptionId, VNetID, ResourceGroup, VNetName | Get-Unique -AsString

# // Loop through all unique VNets
foreach ($vnet in $uniqueVnets) {

    # // Set context to source subscription
    Set-AzContext -SubscriptionId $vnet.SubscriptionID 

    # // Get source VNet
    $sourceVnet = Get-AzVirtualNetwork -ResourceGroupName $vnet.ResourceGroup -Name $vnet.VNetName

    # // Loop through all routes in file where route table name matches current route table
    foreach ($subnet in $vnets | Where-Object VNetID -eq $vnet.VNetID) {

        # // Set subnet route table
        Set-AzVirtualNetworkSubnetConfig `
            -Name $subnet.SubnetName `
            -VirtualNetwork $sourceVnet `
            -AddressPrefix $subnet.SubnetAddress `
            -RouteTableId $subnet.RouteTableId
    
        # // Set subnet config on VNet
        $sourceVnet | Set-AzVirtualNetwork
    
    }
}