$ErrorActionPreference = 'Stop'

try {
	## Don't upload the build scripts and appveyor.yml to PowerShell Gallery
	$tempmoduleFolderPath = "$env:Temp\AzVmSnapShots"
	$null = mkdir $tempmoduleFolderPath

	## Remove all of the files/folders to exclude out of the main folder
	$excludeFromPublish = @(
		'AzVmSnapShots\\buildscripts'
		'AzVmSnapShots\\appveyor\.yml'
		'AzVmSnapShots\\\.git'
		'AzVmSnapShots\\\.nuspec'
		'AzVmSnapShots\\README\.md'

	)
	$exclude = $excludeFromPublish -join '|'
	Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER -Recurse | where { $_.FullName -match $exclude } | Remove-Item -Force -Recurse

	## Publish module to PowerShell Gallery
	$publishParams = @{
		Path        = $env:APPVEYOR_BUILD_FOLDER
		NuGetApiKey = $env:nuget_apikey
	}
	Publish-PMModule @publishParams

} catch {
	Write-Error -Message $_.Exception.Message
	$host.SetShouldExit($LastExitCode)
}