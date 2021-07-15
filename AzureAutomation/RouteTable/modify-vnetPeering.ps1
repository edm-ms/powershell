param (
    [Parameter(Position=1, Mandatory=$true, HelpMessage="Enter full path of CSV file to process: ")]
    [string]$inputFile
)

# // Import CSV of peering relationships
$vnets = Import-Csv $inputFile

# // Loop through all items in file
foreach ($vnet in $vnets) {

    # // Set context to source subscription
    Set-AzContext -SubscriptionId $vnet.SubscriptionID

    # // Get source VNet
    $sourceVnet = Get-AzVirtualNetwork -ResourceGroupName $vnet.ResourceGroup -Name $vnet.VNetName

    # // Create hash table for switch parameters
    $params = @{
        AllowForwardedTraffic = $false
        AllowGatewayTransit = $false
        UseRemoteGateways = $false
    }

    # // Set switch parameters if true
    if ($vnet.AllowForwardedTraffic -like 'TRUE') {  $params.AllowForwardedTraffic = $true }
    if ($vnet.AllowGWTransit -like 'TRUE') { $params.AllowGatewayTransit = $true }
    if ($vnet.UseRemoteGW -like 'TRUE') { $params.UseRemoteGateways = $true } 

    # // Add VNet peering
    Add-AzVirtualNetworkPeering `
        -Name $vnet.PeeringName `
        -VirtualNetwork $sourceVnet `
        -RemoteVirtualNetworkId $vnet.RemoteID `
        @params
}