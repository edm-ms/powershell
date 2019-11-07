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

# // Find all VM's with power state
$allVMs = Get-AzVm -Status

# // Set Azure Automation variable with pre-update VM state
New-AzAutomationVariable –AutomationAccountName $automationAccountName –Name $automationAccountVariableName –Encrypted $false -ResourceGroupName $automationAccountRG –Value $allVMs

# Loop through all VM's and power on all that are off
ForEach ($vm in $allVMs) {

    If ($vm.PowerState -ne 'VM running') { 
        "Starting VM: $vm.Name"
        Start-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName 
    }

}