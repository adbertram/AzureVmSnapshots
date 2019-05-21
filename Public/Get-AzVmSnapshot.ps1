function Get-AzVmSnapshot {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ResourceGroupName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$VmName
	)
 
	$ErrorActionPreference = 'Stop'

	$whereFilter = { $_.Name -match '^AzVmSnapshot' }
	if ($PSBoundParameters.ContainsKey('VmName')) {
		$whereFilter = 	{ $_.Name -match "^AzVmSnapshot-$VMName-" }
	}
 
	Get-AzSnapshot -ResourceGroupName $ResourceGroupName | Where-Object -FilterScript $whereFilter
}