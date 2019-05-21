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
	
	$jobs = @()
	foreach ($name in $VMName) {
		$scriptBlock = {
			param($ResourceGroupName, $VmName)

			$ErrorActionPreference = 'Stop'

			$snapshotName = "AzVmSnapshot-$VMName-$(Get-Date -UFormat '%Y%m%d%H%M%S')"

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
		$jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList @($ResourceGroupName, $name)
	}
	Write-Verbose -Message 'Executed all snapshot operations. Waiting on jobs to finish...'
	$jobs | Wait-Job | Receive-Job
}