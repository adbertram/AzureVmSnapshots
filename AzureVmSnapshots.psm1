function New-AzVmSnapshot {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$VmName,
 
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName
	)
 
	foreach ($name in $VMName) {
		$scriptBlock = {
			param($ResourceGroupName, $VmName)

			$ErrorActionPreference = 'Stop'

			$snapshotName = "$VMName-$(Get-Date -UFormat '%Y%m%d%H%M%S')"

			$vm = Get-AzVm -ResourceGroup $ResourceGroupName -Name $VmName
			$stopParams = @{
				ResourceGroupName = $ResourceGroupName
				Force             = $true
			}
			try {
				Write-Verbose -Message "Stopping Azure VM [$($VmName)]..."
				$null = $vm | Stop-AzVm -ResourceGroupName $ResourceGroupName -Force

				$diskName = $vm.StorageProfile.OSDisk.Name
				$osDisk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $diskname
				$snapConfig = New-AzSnapshotConfig -SourceUri $osDisk.Id -CreateOption Copy -Location $vm.Location 
				Write-Verbose -Message "Creating snapshot..."
				$null = New-AzSnapshot -Snapshot $snapConfig -SnapshotName $snapshotName -ResourceGroupName $ResourceGroupName
			} catch {
				throw $_.Exception.Message
			} finally {
				Write-Verbose -Message "Starting Azure VM back up..."
				$null = $vm | Start-AzVm
				[pscustomobject]@{
					'VMName'       = $VmName
					'SnapshotName' = $snapshotName
				}
			}
		}
		$jobs = @()
		$jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList @($ResourceGroupName, $name)
	}
	Write-Verbose -Message 'Executed all snapshot operations. Waiting on jobs to finish...'
	$jobs | Wait-Job | Receive-Job
}
 
function Restore-AzVmSnapshot {
	[CmdletBinding(DefaultParameterSetName = 'VM', SupportsShouldProcess, ConfirmImpact = 'High')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'VM')]
		[ValidateNotNullOrEmpty()]
		[string]$VmName,
 
		[Parameter(Mandatory, ParameterSetName = 'VM')]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,
 
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Snapshot')]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Azure.Commands.Compute.Automation.Models.PSSnapshotList]$Snapshot,
 
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$RemoveOriginalDisk
	)
 
	$ErrorActionPreference = 'Stop'
	
	if (-not $PSBoundParameters.ContainsKey('Snapshot')) {
		## Find the VM
		$vm = Get-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
		if (-not ($Snapshot = Get-AzVmSnapshot -ResourceGroupName $ResourceGroupName -VMName $vm.Name)) {
			throw "Could not find snapshot."
		}
	} else {
		$vmName = ($Snapshot.Name -split '-')[0]
		$ResourceGroupName = $Snapshot.ResourceGroupName
		$vm = Get-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
	}
 
	## Find the OS disk on the VM to get the storage type
	$osDiskName = $vm.StorageProfile.OsDisk.name
	$oldOsDisk = Get-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName
	
	if ($PSCmdlet.ShouldProcess("Snapshot", 'Restore')) {
		$diskconf = New-AzDiskConfig -AccountType $oldOsDisk.sku.name -Location $oldOsdisk.Location -SourceResourceId $Snapshot.Id -CreateOption Copy
		Write-Verbose -Message 'Creating new disk...'
		$newDisk = New-AzDisk -Disk $diskconf -ResourceGroupName $ResourceGroupName -DiskName "$($vm.Name)-$((New-Guid).ToString())"

		# Set the VM configuration to point to the new disk
		$null = Set-AzVMOSDisk -VM $vm -ManagedDiskId $newDisk.Id -Name $newDisk.Name

		# Update the VM with the new OS disk
		Write-Verbose -Message 'Updating VM...'
		$null = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm 

		# Start the VM 
		Write-Verbose -Message 'Starting VM...'
		$null = Start-AzVM -Name $vm.Name -ResourceGroupName $ResourceGroupName

		if ($RemoveOriginalDisk.IsPresent) {
			if ($PSCmdlet.ShouldProcess("Disk $($oldOsDisk.Name)", 'Remove')) {
				$null = Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $oldOsDisk.Name
			}
		}
	}
}

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