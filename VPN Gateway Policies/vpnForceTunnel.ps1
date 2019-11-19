$rgName = ""
$vpnGwName = ""
$localGwName = ""

$LocalGateway = Get-AzLocalNetworkGateway -Name $localGwName -ResourceGroupName $rgName
$VirtualGateway = Get-AzVirtualNetworkGateway -Name $vpnGwName -ResourceGroupName $rgName

Set-AzVirtualNetworkGatewayDefaultSite -GatewayDefaultSite $LocalGateway -VirtualNetworkGateway $VirtualGateway