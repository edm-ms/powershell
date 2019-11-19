$rgName = ""
$vpnGwName = ""

$LocalGateway = Get-AzLocalNetworkGateway -Name "DefaultSiteHQ" -ResourceGroupName $rgName
$VirtualGateway = Get-AzVirtualNetworkGateway -Name $vpnGwName -ResourceGroupName $rgName
Set-AzVirtualNetworkGatewayDefaultSite -GatewayDefaultSite $LocalGateway -VirtualNetworkGateway $VirtualGateway