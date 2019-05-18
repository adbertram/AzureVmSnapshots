function Get-AzVmSnapshot {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$VmName,
 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName
	)
 
	$ErrorActionPreference = 'Stop'
 
	## Find the VM
	$vm = Get-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
 
	## Find the OS disk on the VM to get the storage type
	$osDiskName = $vm.StorageProfile.OsDisk.name
	$oldOsDisk = Get-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName
	$storageType = $oldOsDisk.sku.name
 
	Get-AzSnapshot -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -match "^$VMName-" }
}