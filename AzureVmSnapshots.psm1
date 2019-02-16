function New-AzureRmVmSnapshot {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$VmName,
 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroup,
 
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$SnapshotName = "$VMName-$(Get-Date -UFormat '%Y%m%d%H%M%S')"
	)
 
	$ErrorActionPreference = 'Stop'
	foreach ($name in $VMName) {
		$scriptBlock = {
			param($ResourceGroup, $VmName, $SnapshotName, $VerbosePreference)

			$vm = Get-AzureRmVm -ResourceGroup $ResourceGroup -Name $VmName
			$stopParams = @{
				ResourceGroupName = $ResourceGroup
				Force             = $true
			}
			try {
				Write-Verbose -Message "Stopping Azure VM [$($VmName)]..."
				$null = $vm | Stop-AzureRmVm -ResourceGroupName $ResourceGroup -Force

				$diskName = $vm.StorageProfile.OSDisk.Name
				$osDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroup -DiskName $diskname
				$snapConfig = New-AzureRmSnapshotConfig -SourceUri $osDisk.Id -CreateOption Copy -Location $vm.Location 
				Write-Verbose -Message "Creating snapshot..."
				$null = New-AzureRmSnapshot -Snapshot $snapConfig -SnapshotName $SnapshotName -ResourceGroupName $ResourceGroup
			} catch {
				throw $_.Exception.Message
			} finally {
				Write-Verbose -Message "Starting Azure VM back up..."
				$null = $vm | Start-AzureRmVm
				[pscustomobject]@{
					'VMName'       = $VmName
					'SnapshotName' = $SnapshotName
				}
			}
		}
		$jobs = @()
		$jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList @($ResourceGroup, $name, $SnapshotName, $VerbosePreference)
	}
	Write-Verbose -Message 'Executed all snapshot operations. Waiting on jobs to finish...'
	$jobs | Wait-Job | Receive-Job
}
 
function Restore-AzureRmVmSnapshot {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$VmName,
 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroup,
 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SnapshotName,
 
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$RemoveOriginalDisk
	)
 
	$ErrorActionPreference = 'Stop'
 
	## Find the VM
	$vm = Get-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroup
 
	## Find the OS disk on the VM to get the storage type
	$osDiskName = $vm.StorageProfile.OsDisk.name
	$oldOsDisk = Get-AzureRmDisk -Name $osDiskName -ResourceGroupName $ResourceGroup
	$storageType = $oldOsDisk.sku.name
 
	## Create the new disk from the snapshot
	if (-not ($snapshot = Get-AzureRmSnapshot -ResourceGroupName $ResourceGroup | Where-Object { $_.Name -eq $SnapshotName })) {
		throw "Could not find snapshot [$($SnapshotName)]."
	}
	if ($PSCmdlet.ShouldProcess("Snapshot", 'Restore')) {
		$diskconf = New-AzureRmDiskConfig -AccountType $storagetype -Location $oldOsdisk.Location -SourceResourceId $snapshot.Id -CreateOption Copy
		Write-Verbose -Message 'Creating new disk...'
		$newDisk = New-AzureRmDisk -Disk $diskconf -ResourceGroupName $resourceGroup -DiskName "$($vm.Name)-$((New-Guid).ToString())"

		# Set the VM configuration to point to the new disk
		$null = Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $newDisk.Id -Name $newDisk.Name

		# Update the VM with the new OS disk
		Write-Verbose -Message 'Updating VM...'
		$null = Update-AzureRmVM -ResourceGroupName $resourceGroup -VM $vm 

		# Start the VM 
		Write-Verbose -Message 'Starting VM...'
		$null = Start-AzureRmVM -Name $vm.Name -ResourceGroupName $resourceGroup

		if ($RemoveOriginalDisk.IsPresent) {
			if ($PSCmdlet.ShouldProcess("Disk $($oldOsDisk.Name)", 'Remove')) {
				$null = Remove-AzureRmDisk -ResourceGroupName $ResourceGroup -DiskName $oldOsDisk.Name
			}
		}
	}
}