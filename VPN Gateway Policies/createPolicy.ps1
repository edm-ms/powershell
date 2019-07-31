$ikeEncryption = 'AES256'
$ikeIntegrity = 'SHA384'
$dhGroup = 'DHGroup2'
$ipsecEncryption = 'AES256'
$ipsecIntegrity = 'SHA256'
$pfsGroup = 'None'
$saLifeTime = 28800
$saDataSizeKB = 102400000
$sharedKey = 'Azure12345Test'

$vpnGWName = 'us-west2-vpngw01'
$resourceGroupName = 'Network'
$lnGatewayName = 'BigCustomer1'
$location = 'westus2'
$connectionName = 'S2Sto' + $lnGatewayName

$ipPolicy = New-AzIpsecPolicy -IkeEncryption $ikeEncryption -IkeIntegrity $ikeIntegrity -DhGroup $dhGroup -IpsecEncryption $ipsecEncryption -IpsecIntegrity $ipsecIntegrity -PfsGroup $pfsGroup -SALifeTimeSeconds $saLifeTime -SADataSizeKilobytes $saDataSizeKB
$vnetgw = Get-AzVirtualNetworkGateway -Name $vpnGWName  -ResourceGroupName $resourceGroupName
$lng = Get-AzLocalNetworkGateway  -Name $lnGatewayName -ResourceGroupName $resourceGroupName
    
New-AzVirtualNetworkGatewayConnection -Name $connectionName -ResourceGroupName $resourceGroupName -VirtualNetworkGateway1 $vnetgw -LocalNetworkGateway2 $lng -Location $location -ConnectionType IPsec -IpsecPolicies $ipPolicy -SharedKey $sharedKey