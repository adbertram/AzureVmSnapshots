@{
	RootModule        = 'AzureVmSnapshots.psm1'
	ModuleVersion     = '*'
	GUID              = 'a331209b-755a-4109-8f43-7849ab9e71d1'
	Author            = 'Adam Bertram'
	CompanyName       = 'TechSnips, LLC'
	Copyright         = '(c) 2019 TechSnips, LLC. All rights reserved.'
	Description       = 'A small PowerShell module to create and restore Azure VMs.'
	RequiredModules   = 'Az'
	FunctionsToExport = '*'
	CmdletsToExport   = '*'
	VariablesToExport = '*'
	AliasesToExport   = '*'
	PrivateData       = @{
		PSData = @{
			Tags       = @('AzureVirtualMachines')
			ProjectUri = 'https://github.com/adbertram/AzureVmSnapshots'
		}
	}
}