# // Start Azure Automation Login Using Service Principal
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

# // Set script variables
$automationAccountName = "VMUpdateAutomation"
$automationAccountRG = "VMUpdateAutomation"
$automationAccountVariableName = "preUpdateVMStatus"

# // Retreive pre-update VM run status
$allVMs = Get-AzAutomationVariable -Name $automationAccountVariableName -ResourceGroupName $automationAccountRG -AutomationAccountName $automationAccountName
$allVMs = $allVMs.Value

# Loop through all VM's and power off all VMs that were off before update
ForEach ($vm in $allVMs) {

    If ($vm.PowerState -ne 'VM running') { Stop-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force }

}