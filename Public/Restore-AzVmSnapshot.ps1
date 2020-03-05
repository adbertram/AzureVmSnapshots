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
    
    begin {
        $ErrorActionPreference = 'Stop'
    }
 
    process {
	
        if (-not $PSBoundParameters.ContainsKey('Snapshot')) {
            ## Find the VM
            $vm = Get-AzVM -Name $VmName -ResourceGroupName $ResourceGroupName
            if (-not ($Snapshot = Get-AzVmSnapshot -ResourceGroupName $ResourceGroupName -VMName $vm.Name)) {
                throw "Could not find snapshot."
            }
        } else {
            $prefixLen = "AzVmSnapshot-".Length
            $vmName = $Snapshot.Name.substring($prefixLen, $Snapshot.Name.LastIndexOf('-') - $prefixLen)
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
}