function Remove-AzVmSnapshot {
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
		[Microsoft.Azure.Commands.Compute.Automation.Models.PSSnapshotList]$Snapshot
	)
	
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {	
		if (-not $PSBoundParameters.ContainsKey('Snapshot')) {
			if (-not ($Snapshot = Get-AzVmSnapshot -ResourceGroupName $ResourceGroupName -VMName $VMName)) {
				throw "Could not find snapshot."
			}
		}
		
		foreach ($snapshotDisk in $Snapshot) {
			if ($PSCmdlet.ShouldProcess("Snapshot", "Remove [$($snapshotDisk.Name)]")) {
				Remove-AzDisk -ResourceGroupName $snapshotDisk.ResourceGroupName -DiskName $snapshotDisk.Name -Force
			}
		}
	}
}