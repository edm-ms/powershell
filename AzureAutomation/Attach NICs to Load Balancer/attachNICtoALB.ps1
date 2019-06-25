# // ####################################################
# // ####################################################
# // Start Azure Automation Login Using Service Principal
# // ####################################################
# // ####################################################
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
# // ####################################################
# // ####################################################
# // End Azure Automation Login Using Service Principal
# // ####################################################
# // ####################################################

# //	Set script variables
$allRGNics = @()
$rgNameSearch = 'citrix-xd*'
$albName = 'LB-US-Central-01'
$albRG = 'citrix-xd-sdsds'
$albBackEndName = 'Default-Outbound'

# // Grab load balancer information
$myALB = Get-AzLoadBalancer -Name $albName -ResourceGroupName $albRG
$backend = Get-AzLoadBalancerBackendAddressPoolConfig -name $albBackEndName -LoadBalancer $myALB

# // Grab all resource groups starting with 'citrix-xd'
$allRGs = Get-AzResourceGroup | Where-Object ResourceGroupName -Like $rgNameSearch

# // Loop through all matched resource groups and find all NIC's
foreach ($rg in $allRGs) {
    
    $allRGNics += Get-AzNetworkInterface -ResourceGroupName $rg.ResourceGroupName
}

# // Loop through all matched NICs and add them to the load balancer back-end
foreach ($nic in $allRGNICs) {

    $nic.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend
    Set-AzNetworkInterface -NetworkInterface $nic
}