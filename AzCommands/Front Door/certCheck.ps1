$afdName = "yourFrontDoorName"
$certCheckValue = "Disabled" #// Set to Enabled or Disabled

$afdResource = Get-AzResource -Name $afdName
$myFD = Get-AzFrontDoor -Name $afdName -ResourceGroupName $afdResource.ResourceGroupName

$certCheck = New-AzFrontDoorBackendPoolsSettingObject -EnforceCertificateNameCheck $certCheckValue
Set-AzFrontDoor -ResourceGroupName $afdResource.ResourceGroupName -Name $myFD.FriendlyName -BackendPoolsSetting $certCheck