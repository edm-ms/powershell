# // Set script variables
$storageAccountName = "nsgflowwestus2" # // Storage account name where flow logs will be collected
$workspaceName = "Workspace-Name" # // Log Analytics workspace name for Traffic Analytics
$workspaceGUID = "dd862626-11bd-4d27-8743-3434da6b8b89" # // GUID (workspace ID) of the workspace above
    
$storageResource = Get-AzResource -Name $storageAccountName
$workspace = Get-AzResource -Name $workspaceName -ResourceType Microsoft.OperationalInsights/workspaces
$storageAccount = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $storageResource.ResourceGroupName
$networkWatchers = Get-AzNetworkWatcher
$nsgs = Get-AzNetworkSecurityGroup
    
    # // Loop through all NSGs
    foreach ($nsg in $nsgs) {
        # // Loop through all network watcher instances
        foreach ($nw in $networkWatchers) {
            # // If network watcher location and NSG location match continue
            if ($nw.Location -eq $nsg.Location) {
                # // If flow logs are not enabled for matched NSG enable them
                if ((Get-AzNetworkWatcherFlowLogStatus -NetworkWatcher $nw -TargetResourceId $nsg.id).Enabled -eq 0 ) {
                    Write-Host "Enabling flow logs for NSG:" $nsg.Name
                    Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $nw -TargetResourceId $nsg.Id `
                    -StorageAccountId $storageAccount.Id -EnableFlowLog $true -FormatType Json -FormatVersion 2 `
                    -EnableTrafficAnalytics -WorkspaceResourceId $workspace.Id -WorkspaceGUID $workspaceGUID -WorkspaceLocation $workspace.Location
                }
            }
        }
    }