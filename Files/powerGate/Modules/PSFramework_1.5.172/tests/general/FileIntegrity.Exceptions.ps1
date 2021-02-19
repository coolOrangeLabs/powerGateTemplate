# List of forbidden commands
$global:BannedCommands = @(
	'Write-Host',
	'Write-Verbose',
	'Write-Warning',
	'Write-Error',
	'Write-Output',
	'Write-Information',
	'Write-Debug'
)

<#
	Contains list of exceptions for banned cmdlets.
	Insert the file names of files that may contain them.
	
	Example:
	"Write-Host"  = @('Write-PSFHostColor.ps1','Write-PSFMessage.ps1')
#>
$global:MayContainCommand = @{
	"Write-Host"  = @('Write-PSFHostColor.ps1')
	"Write-Verbose" = @()
	"Write-Warning" = @()
	"Write-Error"  = @('Invoke-PSFCommand.ps1','Stop-PSFFunction.ps1')
	"Write-Output" = @('filesystem.provider.ps1', 'gelf.provider.ps1', 'logfile.provider.ps1', 'input.ps1', 'teppCoreCode.ps1')
	"Write-Information" = @()
	"Write-Debug" = @()
}