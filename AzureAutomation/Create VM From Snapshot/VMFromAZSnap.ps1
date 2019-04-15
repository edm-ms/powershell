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

#Provide the name of your resource group
$resourceGroupName ='Backup'
$vmResourceGroup = 'WinVM'
$networkResourceGroup = 'Networks'
$availabilityZone = 3
$osDiskSize = 128
$osType = 'Windows'


#Provide the name of the snapshot that will be used to create OS disk
$snapshotName = 'DB2-snap-time-'

#Provide the name of the OS disk that will be created using the snapshot
$osDiskName = 'recoveredOS'

#Provide the name of an existing virtual network where virtual machine will be created
$virtualNetworkName = 'vnet-prod-useast2-spoke01'

#Provide the name of the virtual machine
$virtualMachineName = 'vm-db2-bc'
$virtualMachineSize = 'Standard_B2ms'

$snapshot = Get-AzSnapshot | where Name -like "*$snapshotName*" | Sort-Object TimeCreated -Descending
$snapshot = $snapshot[0]

$diskConfig = New-AzDiskConfig -Location $snapshot.Location `
        -SourceResourceId $snapshot.Id `
        -DiskSizeGB $osDiskSize `
        -OsType $osType `
        -Zone $availabilityZone `
        -SkuName Standard_LRS `
        -CreateOption Copy
 
$disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $vmResourceGroup -DiskName $osDiskName

#Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize -Zone $availabilityZone

#Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows

#Get the virtual network where virtual machine will be hosted
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $networkResourceGroup

# Create NIC in the fourth subnet of the virtual network
$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic') -ResourceGroupName $vmResourceGroup -Location $snapshot.Location -SubnetId $vnet.Subnets[4].Id

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id

#Create the virtual machine with Managed Disk
New-AzVM -VM $VirtualMachine -ResourceGroupName $vmResourceGroup -Location $snapshot.Location