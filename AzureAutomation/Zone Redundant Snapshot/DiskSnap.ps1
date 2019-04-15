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

$tagToFind = 'DB2' # // Azure tag to match resources
$location = 'eastus2' # // Azure region to search for VM's
$snapRG = 'Backup' # // Resource group to hold snapshot
$snapDate = Get-Date -f MM-dd-yyyy # // Set snapshot date
$snapTime = Get-Date -f HH-mm # // Set snapshot time
$snapshotName = "$tagToFind-snap-time-$snapTime-date-$snapDate" # // Snapshot name
$vmList = @() # // Re-initialize variable

# //	Find all VM's in a region

$allVMs = Get-AzVM -Location $location

# // 	Loop through all VM's in a region to find matching tag

ForEach ($vm in $allVMs) {

	$tagTest = ($vm.Tags | where Values -eq $tagToFind) # // Find VM's with matching tag

	if ($tagTest -ne $null) { $vmList += $vm } # // If tag is found add to VM list

}

# //	Loop through all matching VM's and create a zone redundant OS snapshot

ForEach ($vm in $vmList) {

	$snapshot =  New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id `
		-Location $location `
		-SkuName Standard_ZRS `
		-CreateOption copy

	New-AzSnapshot -Snapshot $snapshot `
		-SnapshotName $snapshotName `
		-ResourceGroupName $snapRG

}