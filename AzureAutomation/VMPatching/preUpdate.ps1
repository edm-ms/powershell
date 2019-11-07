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
$automationAccountVariableName = "preUpdateVMStatus" # { This variable needs to be created in Azure Automation prior to first run
$pauseSeconds = 300

# // Find all VMs and include power state "status"
$allVMs = Get-AzVm -Status

# // Set Azure Automation variable with pre-update VM state
Set-AzAutomationVariable -Name $automationAccountVariableName -AutomationAccountName $automationAccountName -ResourceGroupName $automationAccountRG -Encrypted $false -Value $allVMs

# Loop through all VM's and power on all that are off
ForEach ($vm in $allVMs) {
    If ($vm.PowerState -ne 'VM running') { 
        "Starting VM: " + $vm.Name
        Start-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -NoWait
    }
}

# // Wait a set time before starting VM patch operation
Start-Sleep -Seconds $pauseSeconds