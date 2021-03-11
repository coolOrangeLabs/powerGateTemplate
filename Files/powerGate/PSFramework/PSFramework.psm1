$script:ModuleRoot = $PSScriptRoot

if ($PSFramework_DebugMode) { [PSFramework.PSFCore.PSFCoreHost]::DebugMode = $true }
if ($PSFramework_DebugVerbose) { [PSFramework.PSFCore.PSFCoreHost]::VerboseDebug = $true }

[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("Starting Import","")

if (($ExecutionContext.Host.Runspace.InitialSessionState.LanguageMode -eq 'NoLanguage') -or ($PSVersionTable.PSVersion.Major -lt 5))
{
	# This is considered safe, as you should not be using unsafe localization resources in a constrained endpoint
	$script:ModuleVersion = (Invoke-Expression (Get-Content -Path "$($script:ModuleRoot)\PSFramework.psd1" -Raw)).ModuleVersion
}
else
{
	$script:ModuleVersion = (Import-PowerShellDataFile -Path "$($script:ModuleRoot)\PSFramework.psd1").ModuleVersion
}

# Detect whether at some level dotsourcing was enforced
$script:doDotSource = $false
if ($psframework_dotsourcemodule) { $script:doDotSource = $true }
if (($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.OS -like "*Windows*"))
{
	if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }
	if ((Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }
}

<#
Note on Resolve-Path:
All paths are sent through Resolve-Path in order to convert them to the correct path separator.
This allows ignoring path separators throughout the import sequence, which could otherwise cause trouble depending on OS.
#>

# Detect whether at some level loading individual module files, rather than the compiled module was enforced
$importIndividualFiles = $false
if ($PSFramework_importIndividualFiles) { $importIndividualFiles = $true }
if (($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.OS -like "*Windows*"))
{
	if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "ImportIndividualFiles" -ErrorAction Ignore).ImportIndividualFiles) { $script:doDotSource = $true }
	if ((Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\System" -Name "ImportIndividualFiles" -ErrorAction Ignore).ImportIndividualFiles) { $script:doDotSource = $true }
}
if (Test-Path (Join-Path (Resolve-Path -Path "$($script:ModuleRoot)\..") '.git')) { $importIndividualFiles = $true }
if ("<was compiled>" -eq '<was not compiled>') { $importIndividualFiles = $true }

[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("Finished Pre-Import Config", "DotSource: $script:doDotSource | Individual Files: $importIndividualFiles")

function Import-ModuleFile
{
	<#
		.SYNOPSIS
			Loads files into the module on module import.
		
		.DESCRIPTION
			This helper function is used during module initialization.
			It should always be dotsourced itself, in order to proper function.
			
			This provides a central location to react to files being imported, if later desired
		
		.PARAMETER Path
			The path to the file to load
		
		.EXAMPLE
			PS C:\> . Import-ModuleFile -File $function.FullName
	
			Imports the file stored in $function according to import policy
	#>
	[CmdletBinding()]
	Param (
		[string]
		$Path
	)
	
	try
	{
		if ($doDotSource) { . (Resolve-Path $Path) }
		else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText((Resolve-Path $Path).ProviderPath))), $null, $null) }
	}
	catch { throw (New-Object System.Exception("Failed to import $(Resolve-Path $Path) : $_", $_.Exception)) }
}

#region Load individual files
if ($importIndividualFiles)
{
	# Execute Preimport actions
	[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("PreImport", "")
	foreach ($path in (& "$ModuleRoot\internal\scripts\preimport.ps1")) {
		[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("  $path", "")
		. Import-ModuleFile -Path $path
	}
	
	# Import all internal functions
	[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("InternalFunctions", "")
	foreach ($function in (Get-ChildItem "$($script:ModuleRoot)\internal\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore))
	{
		. Import-ModuleFile -Path $function.FullName
	}
	
	# Import all public functions
	[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("Functions", "")
	foreach ($function in (Get-ChildItem "$($script:ModuleRoot)\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore))
	{
		. Import-ModuleFile -Path $function.FullName
	}
	
	# Execute Postimport actions
	[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("PostImport", "")
	foreach ($path in (& "$ModuleRoot\internal\scripts\postimport.ps1")) {
		[PSFramework.PSFCore.PSFCoreHost]::WriteDebug("  $path", "")
		. Import-ModuleFile -Path $path
	}
	
	# End it here, do not load compiled code below
	return
}
#endregion Load individual files

#region Load compiled code
#region Paths
$script:path_RegistryUserDefault = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default"
$script:path_RegistryUserEnforced = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Enforced"
$script:path_RegistryMachineDefault = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default"
$script:path_RegistryMachineEnforced = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Enforced"
$psVersionName = "WindowsPowerShell"
if ($PSVersionTable.PSVersion.Major -ge 6) { $psVersionName = "PowerShell" }

#region User Local
if ($IsLinux -or $IsMacOs)
{
	# Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
	$script:path_LocalAppData = $Env:XDG_CONFIG_HOME
	if (-not $script:path_LocalAppData) { $script:path_LocalAppData = Join-Path $HOME .config/ }
	
	$script:path_FileUserLocal = Join-Path (Join-Path $script:path_LocalAppData $psVersionName) "PSFramework/"
}
else
{
	# Defaults to $Env:LocalAppData on Windows
	$script:path_FileUserLocal = Join-Path $Env:LocalAppData "$psVersionName\PSFramework\Config"
	$script:path_LocalAppData = $Env:LocalAppData
	if (-not $script:path_FileUserLocal)
	{
		$script:path_FileUserLocal = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "$psVersionName\PSFramework\Config"
		$script:path_LocalAppData = [Environment]::GetFolderPath("LocalApplicationData")
	}
}
#endregion User Local

#region User Shared
if ($IsLinux -or $IsMacOs)
{
	# Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
	$script:path_AppData = @($Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0]
	if (-not $script:path_AppData) { $script:path_AppData = Join-Path $HOME .local/share/ }
	
	$script:path_FileUserShared = Join-Path (Join-Path $script:path_AppData $psVersionName) "PSFramework/"
}
else
{
	# Defaults to $Env:AppData on Windows
	$script:path_FileUserShared = Join-Path $Env:AppData "$psVersionName\PSFramework\Config"
	$script:path_AppData = $env:APPDATA
	if (-not $Env:AppData)
	{
		$script:path_AppData = [Environment]::GetFolderPath("ApplicationData")
		$script:path_FileUserShared = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "$psVersionName\PSFramework\Config"
	}
}
#endregion User Shared

#region System
if ($IsLinux -or $IsMacOs)
{
	# Defaults to /etc/xdg elsewhere
	$XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator) | Where-Object { $_ -and (Test-Path $_) }
	if ($XdgConfigDirs.Count -gt 1) { $script:path_ProgramData = $XdgConfigDirs[1] }
	else { $script:path_ProgramData = "/etc/xdg/" }
	$script:path_FileSystem = Join-Path $script:path_ProgramData "$psVersionName/PSFramework/"
}
else
{
	# Defaults to $Env:ProgramData on Windows
	$script:path_FileSystem = Join-Path $Env:ProgramData "$psVersionName\PSFramework\Config"
	$script:path_ProgramData = $env:ProgramData
	if (-not $script:path_FileSystem)
	{
		$script:path_ProgramData = [Environment]::GetFolderPath("CommonApplicationData")
		$script:path_FileSystem = Join-Path ([Environment]::GetFolderPath("CommonApplicationData")) "$psVersionName\PSFramework\Config"
	}
}
#endregion System

#region Special Paths
if ($IsLinux -or $IsMacOs)
{
	$script:path_Logging = Join-Path (Split-Path $script:path_FileUserShared) "Logs/"
	$script:path_typedata = Join-Path $script:path_FileUserShared "TypeData/"
}
else
{
	# Defaults to $Env:AppData on Windows
	$script:path_Logging = Join-Path $Env:AppData "$psVersionName\PSFramework\Logs"
	$script:path_typedata = Join-Path $Env:AppData "$psVersionName\PSFramework\TypeData"
	if (-not $Env:AppData)
	{
		$script:path_Logging = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "$psVersionName\PSFramework\Logs"
		$script:path_typedata = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "$psVersionName\PSFramework\TypeData"
	}
}

#endregion Special Paths
#endregion Paths

# Determine Registry Availability
$script:NoRegistry = $false
if (($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -notlike "*Windows*"))
{
	$script:NoRegistry = $true
}

if (-not ([PSFramework.Message.LogHost]::LoggingPath)) { [PSFramework.Message.LogHost]::LoggingPath = $script:path_Logging }

[PSFramework.PSFCore.PSFCoreHost]::ModuleRoot = $script:ModuleRoot
# Run the library initialization logic
# Needed before the configuration system loads
[PSFramework.PSFCore.PSFCoreHost]::Initialize()

if (($PSVersionTable.PSVersion.Major -lt 5) -and -not (Get-Module TabExpansionPlusPlus))
{
<#
Copyright (c) 2013, Jason Shirk
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#>
	#region Exported utility functions for completers
	
	#############################################################################
	#
	# Helper function to create a new completion results
	#
	function global:New-CompletionResult
	{
		param ([Parameter(Position = 0, ValueFromPipelineByPropertyName, Mandatory, ValueFromPipeline)]
			[ValidateNotNullOrEmpty()]
			[string]
			$CompletionText,
			
			[Parameter(Position = 1, ValueFromPipelineByPropertyName)]
			[string]
			$ToolTip,
			
			[Parameter(Position = 2, ValueFromPipelineByPropertyName)]
			[string]
			$ListItemText,
			
			[System.Management.Automation.CompletionResultType]
			$CompletionResultType = [System.Management.Automation.CompletionResultType]::ParameterValue,
			
			[Parameter(Mandatory = $false)]
			[switch]
			$NoQuotes = $false
		)
		
		process
		{
			$toolTipToUse = if ($ToolTip -eq '') { $CompletionText }
			else { $ToolTip }
			$listItemToUse = if ($ListItemText -eq '') { $CompletionText }
			else { $ListItemText }
			
			# If the caller explicitly requests that quotes
			# not be included, via the -NoQuotes parameter,
			# then skip adding quotes.
			
			if ($CompletionResultType -eq [System.Management.Automation.CompletionResultType]::ParameterValue -and -not $NoQuotes)
			{
				# Add single quotes for the caller in case they are needed.
				# We use the parser to robustly determine how it will treat
				# the argument.  If we end up with too many tokens, or if
				# the parser found something expandable in the results, we
				# know quotes are needed.
				
				$tokens = $null
				$null = [System.Management.Automation.Language.Parser]::ParseInput("echo $CompletionText", [ref]$tokens, [ref]$null)
				if ($tokens.Length -ne 3 -or
					($tokens[1] -is [System.Management.Automation.Language.StringExpandableToken] -and
						$tokens[1].Kind -eq [System.Management.Automation.Language.TokenKind]::Generic))
				{
					$CompletionText = "'$CompletionText'"
				}
			}
			return New-Object System.Management.Automation.CompletionResult `
			($CompletionText, $listItemToUse, $CompletionResultType, $toolTipToUse.Trim())
		}
		
	}
	
	#############################################################################
	#
	# .SYNOPSIS
	#
	#     This is a simple wrapper of Get-Command gets commands with a given
	#     parameter ignoring commands that use the parameter name as an alias.
	#
	function global:Get-CommandWithParameter
	{
		[CmdletBinding(DefaultParameterSetName = 'AllCommandSet')]
		param (
			[Parameter(ParameterSetName = 'AllCommandSet', Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
			[ValidateNotNullOrEmpty()]
			[string[]]
			${Name},
			
			[Parameter(ParameterSetName = 'CmdletSet', ValueFromPipelineByPropertyName)]
			[string[]]
			${Verb},
			
			[Parameter(ParameterSetName = 'CmdletSet', ValueFromPipelineByPropertyName)]
			[string[]]
			${Noun},
			
			[Parameter(ValueFromPipelineByPropertyName)]
			[string[]]
			${Module},
			
			[ValidateNotNullOrEmpty()]
			[Parameter(Mandatory)]
			[string]
			${ParameterName})
		
		begin
		{
			$wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Command', [System.Management.Automation.CommandTypes]::Cmdlet)
			$scriptCmd = { & $wrappedCmd @PSBoundParameters | Where-Object { $_.Parameters[$ParameterName] -ne $null } }
			$steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
			$steppablePipeline.Begin($PSCmdlet)
		}
		process
		{
			$steppablePipeline.Process($_)
		}
		end
		{
			$steppablePipeline.End()
		}
	}
	
	#############################################################################
	#
	function global:Set-CompletionPrivateData
	{
		param (
			[ValidateNotNullOrEmpty()]
			[string]
			$Key,
			
			[object]
			$Value,
			
			[ValidateNotNullOrEmpty()]
			[int]
			$ExpirationSeconds = 604800
		)
		
		$Cache = [PSCustomObject]@{
			Value		   = $Value
			ExpirationTime = (Get-Date).AddSeconds($ExpirationSeconds)
		}
		$completionPrivateData[$key] = $Cache
	}
	
	#############################################################################
	#
	function global:Get-CompletionPrivateData
	{
		param (
			[ValidateNotNullOrEmpty()]
			[string]
			$Key)
		
		if (!$Key)
		{ return $completionPrivateData }
		
		$cacheValue = $completionPrivateData[$key]
		if ((Get-Date) -lt $cacheValue.ExpirationTime)
		{
			return $cacheValue.Value
		}
	}
	
	#############################################################################
	#
	function global:Get-CompletionWithExtension
	{
		param ([string]
			$lastWord,
			
			[string[]]
			$extensions)
		
		[System.Management.Automation.CompletionCompleters]::CompleteFilename($lastWord) |
		Where-Object {
			# Use ListItemText because it won't be quoted, CompletionText might be
			[System.IO.Path]::GetExtension($_.ListItemText) -in $extensions
		}
	}
	
	#############################################################################
	#
	function global:New-CommandTree
	{
		[CmdletBinding(DefaultParameterSetName = 'Default')]
		param (
			[Parameter(Position = 0, Mandatory, ParameterSetName = 'Default')]
			[Parameter(Position = 0, Mandatory, ParameterSetName = 'Argument')]
			[ValidateNotNullOrEmpty()]
			[string]
			$Completion,
			
			[Parameter(Position = 1, Mandatory, ParameterSetName = 'Default')]
			[Parameter(Position = 1, Mandatory, ParameterSetName = 'Argument')]
			[string]
			$Tooltip,
			
			[Parameter(ParameterSetName = 'Argument')]
			[switch]
			$Argument,
			
			[Parameter(Position = 2, ParameterSetName = 'Default')]
			[Parameter(Position = 1, ParameterSetName = 'ScriptBlockSet')]
			[scriptblock]
			$SubCommands,
			
			[Parameter(Position = 0, Mandatory, ParameterSetName = 'ScriptBlockSet')]
			[scriptblock]
			$CompletionGenerator
		)
		
		$actualSubCommands = $null
		if ($null -ne $SubCommands)
		{
			$actualSubCommands = [NativeCommandTreeNode[]](& $SubCommands)
		}
		
		switch ($PSCmdlet.ParameterSetName)
		{
			'Default' {
				New-Object NativeCommandTreeNode $Completion, $Tooltip, $actualSubCommands
				break
			}
			'Argument' {
				New-Object NativeCommandTreeNode $Completion, $Tooltip, $true
			}
			'ScriptBlockSet' {
				New-Object NativeCommandTreeNode $CompletionGenerator, $actualSubCommands
				break
			}
		}
	}
	
	#############################################################################
	#
	function global:Get-CommandTreeCompletion
	{
		param ($wordToComplete,
			
			$commandAst,
			
			[NativeCommandTreeNode[]]
			$CommandTree)
		
		$commandElements = $commandAst.CommandElements
		
		# Skip the first command element - it's the command name
		# Iterate through the remaining elements, stopping early
		# if we find the element that matches $wordToComplete.
		for ($i = 1; $i -lt $commandElements.Count; $i++)
		{
			if (!($commandElements[$i] -is [System.Management.Automation.Language.StringConstantExpressionAst]))
			{
				# Ignore arguments that are expressions.  In some rare cases this
				# could cause strange completions because the context is incorrect, e.g.:
				#    $c = 'advfirewall'
				#    netsh $c firewall
				# Here we would be in advfirewall firewall context, but we'd complete as
				# though we were in firewall context.
				continue
			}
			
			if ($commandElements[$i].Value -eq $wordToComplete)
			{
				$CommandTree = $CommandTree |
				Where-Object { $_.Command -like "$wordToComplete*" -or $_.CompletionGenerator -ne $null }
				break
			}
			
			foreach ($subCommand in $CommandTree)
			{
				if ($subCommand.Command -eq $commandElements[$i].Value)
				{
					if (!$subCommand.Argument)
					{
						$CommandTree = $subCommand.SubCommands
					}
					break
				}
			}
		}
		
		if ($null -ne $CommandTree)
		{
			$CommandTree | ForEach-Object {
				if ($_.Command)
				{
					$toolTip = if ($_.Tooltip) { $_.Tooltip }
					else { $_.Command }
					New-CompletionResult -CompletionText $_.Command -ToolTip $toolTip
				}
				else
				{
					& $_.CompletionGenerator $wordToComplete $commandAst
				}
			}
		}
	}
	
	#endregion Exported utility functions for completers
	
	#region Exported functions
	
	#############################################################################
	#
	# .SYNOPSIS
	#     Register a ScriptBlock to perform argument completion for a
	#     given command or parameter.
	#
	# .DESCRIPTION
	#     Argument completion can be extended without needing to do any
	#     parsing in many cases. By registering a handler for specific
	#     commands and/or parameters, PowerShell will call the handler
	#     when appropriate.
	#
	#     There are 2 kinds of extensions - native and PowerShell. Native
	#     refers to commands external to PowerShell, e.g. net.exe. PowerShell
	#     completion covers any functions, scripts, or cmdlets where PowerShell
	#     can determine the correct parameter being completed.
	#
	#     When registering a native handler, you must specify the CommandName
	#     parameter. The CommandName is typically specified without any path
	#     or extension. If specifying a path and/or an extension, completion
	#     will only work when the command is specified that way when requesting
	#     completion.
	#
	#     When registering a PowerShell handler, you must specify the
	#     ParameterName parameter. The CommandName is optional - PowerShell will
	#     first try to find a handler based on the command and parameter, but
	#     if none is found, then it will try just the parameter name. This way,
	#     you could specify a handler for all commands that have a specific
	#     parameter.
	#
	#     A handler needs to return instances of
	#     System.Management.Automation.CompletionResult.
	#
	#     A native handler is passed 2 parameters:
	#
	#         param($wordToComplete, $commandAst)
	#
	#     $wordToComplete  - The argument being completed, possibly an empty string
	#     $commandAst      - The ast of the command being completed.
	#
	#     A PowerShell handler is passed 5 parameters:
	#
	#         param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
	#
	#     $commandName        - The command name
	#     $parameterName      - The parameter name
	#     $wordToComplete     - The argument being completed, possibly an empty string
	#     $commandAst         - The parsed representation of the command being completed.
	#     $fakeBoundParameter - Like $PSBoundParameters, contains values for some of the parameters.
	#                           Certain values are not included, this does not mean a parameter was
	#                           not specified, just that getting the value could have had unintended
	#                           side effects, so no value was computed.
	#
	# .PARAMETER ParameterName
	#     The name of the parameter that the Completion parameter supports.
	#     This parameter is not supported for native completion and is
	#     mandatory for script completion.
	#
	# .PARAMETER CommandName
	#     The name of the command that the Completion parameter supports.
	#     This parameter is mandatory for native completion and is optional
	#     for script completion.
	#
	# .PARAMETER Completion
	#     A ScriptBlock that returns instances of CompletionResult. For
	#     native completion, the script block parameters are
	#
	#         param($wordToComplete, $commandAst)
	#
	#     For script completion, the parameters are:
	#
	#         param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
	#
	# .PARAMETER Description
	#     A description of how the completion can be used.
	#
	function global:Register-ArgumentCompleter
	{
		[CmdletBinding(DefaultParameterSetName = "PowerShellSet")]
		param (
			[Parameter(ParameterSetName = "NativeSet", Mandatory)]
			[Parameter(ParameterSetName = "PowerShellSet")]
			[string[]]
			$CommandName = "",
			
			[Parameter(ParameterSetName = "PowerShellSet", Mandatory)]
			[string]
			$ParameterName = "",
			
			[Parameter(Mandatory)]
			[scriptblock]
			$ScriptBlock,
			
			[string]
			$Description,
			
			[Parameter(ParameterSetName = "NativeSet")]
			[switch]
			$Native)
		
		$fnDefn = $ScriptBlock.Ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
		if (!$Description)
		{
			# See if the script block is really a function, if so, use the function name.
			$Description = if ($fnDefn -ne $null) { $fnDefn.Name }
			else { "" }
		}
		
		if ($MyInvocation.ScriptName -ne (& { $MyInvocation.ScriptName }))
		{
			# Make an unbound copy of the script block so it has access to TabExpansionPlusPlus when invoked.
			# We can skip this step if we created the script block (Register-ArgumentCompleter was
			# called internally).
			if ($fnDefn -ne $null)
			{
				$ScriptBlock = $ScriptBlock.Ast.Body.GetScriptBlock() # Don't reparse, just get a new ScriptBlock.
			}
			else
			{
				$ScriptBlock = $ScriptBlock.Ast.GetScriptBlock() # Don't reparse, just get a new ScriptBlock.
			}
		}
		
		foreach ($command in $CommandName)
		{
			if ($command -and $ParameterName)
			{
				$command += ":"
			}
			
			$key = if ($Native) { 'NativeArgumentCompleters' }
			else { 'CustomArgumentCompleters' }
			$tabExpansionOptions[$key]["${command}${ParameterName}"] = $ScriptBlock
			
			$tabExpansionDescriptions["${command}${ParameterName}$Native"] = $Description
		}
	}
	
	#############################################################################
	#
	# .SYNOPSIS
	#     Tests the registered argument completer
	#
	# .DESCRIPTION
	#     Invokes the registered parameteter completer for a specified command to make it easier to test
	#     a completer
	#
	# .EXAMPLE
	#  Test-ArgumentCompleter -CommandName Get-Verb -ParameterName Verb -WordToComplete Sta
	#
	# Test what would be completed if Get-Verb -Verb Sta<Tab> was typed at the prompt
	#
	# .EXAMPLE
	#  Test-ArgumentCompleter -NativeCommand Robocopy -WordToComplete /
	#
	# Test what would be completed if Robocopy /<Tab> was typed at the prompt
	#
	function global:Test-ArgumentCompleter
	{
		[CmdletBinding(DefaultParametersetName = 'PS')]
		param
		(
			[Parameter(Mandatory, Position = 1, ParameterSetName = 'PS')]
			[string]
			$CommandName
			 ,
			
			[Parameter(Mandatory, Position = 2, ParameterSetName = 'PS')]
			[string]
			$ParameterName
			 ,
			
			[Parameter(ParameterSetName = 'PS')]
			[System.Management.Automation.Language.CommandAst]
			$commandAst
			 ,
			
			[Parameter(ParameterSetName = 'PS')]
			[Hashtable]
			$FakeBoundParameters = @{ }
			 ,
			
			[Parameter(Mandatory, Position = 1, ParameterSetName = 'NativeCommand')]
			[string]
			$NativeCommand
			 ,
			
			[Parameter(Position = 2, ParameterSetName = 'NativeCommand')]
			[Parameter(Position = 3, ParameterSetName = 'PS')]
			[string]
			$WordToComplete = ''
			
		)
		
		if ($PSCmdlet.ParameterSetName -eq 'NativeCommand')
		{
			$Tokens = $null
			$Errors = $null
			$ast = [System.Management.Automation.Language.Parser]::ParseInput($NativeCommand, [ref]$Tokens, [ref]$Errors)
			$commandAst = $ast.EndBlock.Statements[0].PipelineElements[0]
			$command = $commandAst.GetCommandName()
			$completer = $tabExpansionOptions.NativeArgumentCompleters[$command]
			if (-not $Completer)
			{
				throw "No argument completer registered for command '$Command' (from $NativeCommand)"
			}
			& $completer $WordToComplete $commandAst
		}
		else
		{
			$completer = $tabExpansionOptions.CustomArgumentCompleters["${CommandName}:$ParameterName"]
			if (-not $Completer)
			{
				throw "No argument completer registered for '${CommandName}:$ParameterName'"
			}
			& $completer $CommandName $ParameterName $WordToComplete $commandAst $FakeBoundParameters
		}
	}
	
	#############################################################################
	#
	# .SYNOPSIS
	# Retrieves a list of argument completers that have been loaded into the
	# PowerShell session.
	#
	# .PARAMETER Name
	# The name of the argument complete to retrieve. This parameter supports
	# wildcards (asterisk).
	#
	# .EXAMPLE
	# Get-ArgumentCompleter -Name *Azure*;
	function global:Get-ArgumentCompleter
	{
		[CmdletBinding()]
		param ([string[]]
			$Name = '*')
		
		if (!$updatedTypeData)
		{
			# Define the default display properties for the objects returned by Get-ArgumentCompleter
			[string[]]$properties = "Command", "Parameter"
			Update-TypeData -TypeName 'TabExpansionPlusPlus.ArgumentCompleter' -DefaultDisplayPropertySet $properties -Force
			$updatedTypeData = $true
		}
		
		function WriteCompleters
		{
			function WriteCompleter($command, $parameter, $native, $scriptblock)
			{
				foreach ($n in $Name)
				{
					if ($command -like $n)
					{
						$c = $command
						if ($command -and $parameter) { $c += ':' }
						$description = $tabExpansionDescriptions["${c}${parameter}${native}"]
						$completer = [pscustomobject]@{
							Command															     = $command
							Parameter														     = $parameter
							Native															     = $native
							Description														     = $description
							ScriptBlock														     = $scriptblock
							File																 = if ($scriptblock.File) { Split-Path -Leaf -Path $scriptblock.File }
						}
						
						$completer.PSTypeNames.Add('TabExpansionPlusPlus.ArgumentCompleter')
						Write-Output $completer
						
						break
					}
				}
			}
			
			foreach ($pair in $tabExpansionOptions.CustomArgumentCompleters.GetEnumerator())
			{
				if ($pair.Key -match '^(.*):(.*)$')
				{
					$command = $matches[1]
					$parameter = $matches[2]
				}
				else
				{
					$parameter = $pair.Key
					$command = ""
				}
				
				WriteCompleter $command $parameter $false $pair.Value
			}
			
			foreach ($pair in $tabExpansionOptions.NativeArgumentCompleters.GetEnumerator())
			{
				WriteCompleter $pair.Key '' $true $pair.Value
			}
		}
		
		WriteCompleters | Sort-Object -Property Native, Command, Parameter
	}
	
	#############################################################################
	#
	# .SYNOPSIS
	#     Register a ScriptBlock to perform argument completion for a
	#     given command or parameter.
	#
	# .DESCRIPTION
	#
	# .PARAMETER Option
	#
	#     The name of the option.
	#
	# .PARAMETER Value
	#
	#     The value to set for Option. Typically this will be $true.
	#
	function global:Set-TabExpansionOption
	{
		param (
			[ValidateSet('ExcludeHiddenFiles',
						 'RelativePaths',
						 'LiteralPaths',
						 'IgnoreHiddenShares',
						 'AppendBackslash')]
			[string]
			$Option,
			
			[object]
			$Value = $true)
		
		$tabExpansionOptions[$option] = $value
	}
	
	#endregion Exported functions
	
	#region Internal utility functions
	
	#############################################################################
	#
	# This function checks if an attribute argument's name can be completed.
	# For example:
	#     [Parameter(<TAB>
	#     [Parameter(Po<TAB>
	#     [CmdletBinding(DefaultPa<TAB>
	#
	function TryAttributeArgumentCompletion
	{
		param (
			[System.Management.Automation.Language.Ast]
			$ast,
			
			[int]
			$offset
		)
		
		$results = @()
		$matchIndex = -1
		
		try
		{
			# We want to find any NamedAttributeArgumentAst objects where the Ast extent includes $offset
			$offsetInExtentPredicate = {
				param ($ast)
				return $offset -gt $ast.Extent.StartOffset -and
				$offset -le $ast.Extent.EndOffset
			}
			$asts = $ast.FindAll($offsetInExtentPredicate, $true)
			
			$attributeType = $null
			$attributeArgumentName = ""
			$replacementIndex = $offset
			$replacementLength = 0
			
			$attributeArg = $asts | Where-Object { $_ -is [System.Management.Automation.Language.NamedAttributeArgumentAst] } | Select-Object -First 1
			if ($null -ne $attributeArg)
			{
				$attributeAst = [System.Management.Automation.Language.AttributeAst]$attributeArg.Parent
				$attributeType = $attributeAst.TypeName.GetReflectionAttributeType()
				$attributeArgumentName = $attributeArg.ArgumentName
				$replacementIndex = $attributeArg.Extent.StartOffset
				$replacementLength = $attributeArg.ArgumentName.Length
			}
			else
			{
				$attributeAst = $asts | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] } | Select-Object -First 1
				if ($null -ne $attributeAst)
				{
					$attributeType = $attributeAst.TypeName.GetReflectionAttributeType()
				}
			}
			
			if ($null -ne $attributeType)
			{
				$results = $attributeType.GetProperties('Public,Instance') |
				Where-Object {
					# Ignore TypeId (all attributes inherit it)
					$_.Name -like "$attributeArgumentName*" -and $_.Name -ne 'TypeId'
				} |
				Sort-Object -Property Name |
				ForEach-Object {
					$propType = [Microsoft.PowerShell.ToStringCodeMethods]::Type($_.PropertyType)
					$propName = $_.Name
					New-CompletionResult $propName -ToolTip "$propType $propName" -CompletionResultType Property
				}
				
				return [PSCustomObject]@{
					Results		      = $results
					ReplacementIndex  = $replacementIndex
					ReplacementLength = $replacementLength
				}
			}
		}
		catch { }
	}
	
	#############################################################################
	#
	# This function completes native commands options starting with - or --
	# works around a bug in PowerShell that causes it to not complete
	# native command options starting with - or --
	#
	function TryNativeCommandOptionCompletion
	{
		param (
			[System.Management.Automation.Language.Ast]
			$ast,
			
			[int]
			$offset
		)
		
		$results = @()
		$replacementIndex = $offset
		$replacementLength = 0
		try
		{
			# We want to find any Command element objects where the Ast extent includes $offset
			$offsetInOptionExtentPredicate = {
				param ($ast)
				return $offset -gt $ast.Extent.StartOffset -and
				$offset -le $ast.Extent.EndOffset -and
				$ast.Extent.Text.StartsWith('-')
			}
			$option = $ast.Find($offsetInOptionExtentPredicate, $true)
			if ($option -ne $null)
			{
				$command = $option.Parent -as [System.Management.Automation.Language.CommandAst]
				if ($command -ne $null)
				{
					$nativeCommand = [System.IO.Path]::GetFileNameWithoutExtension($command.CommandElements[0].Value)
					$nativeCompleter = $tabExpansionOptions.NativeArgumentCompleters[$nativeCommand]
					
					if ($nativeCompleter)
					{
						$results = @(& $nativeCompleter $option.ToString() $command)
						if ($results.Count -gt 0)
						{
							$replacementIndex = $option.Extent.StartOffset
							$replacementLength = $option.Extent.Text.Length
						}
					}
				}
			}
		}
		catch { }
		
		return [PSCustomObject]@{
			Results		      = $results
			ReplacementIndex  = $replacementIndex
			ReplacementLength = $replacementLength
		}
	}
	
	
	#endregion Internal utility functions
	
	#############################################################################
	#
	# This function is partly a copy of the V3 TabExpansion2, adding a few
	# capabilities such as completing attribute arguments and excluding hidden
	# files from results.
	#
	function global:TabExpansion2
	{
		[CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
		param (
			[Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 0)]
			[string]
			$inputScript,
			
			[Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 1)]
			[int]
			$cursorColumn,
			
			[Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 0)]
			[System.Management.Automation.Language.Ast]
			$ast,
			
			[Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 1)]
			[System.Management.Automation.Language.Token[]]
			$tokens,
			
			[Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 2)]
			[System.Management.Automation.Language.IScriptPosition]
			$positionOfCursor,
			
			[Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
			[Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
			[Hashtable]
			$options = $null
		)
		
		if ($null -ne $options)
		{
			$options += $tabExpansionOptions
		}
		else
		{
			$options = $tabExpansionOptions
		}
		
		if ($psCmdlet.ParameterSetName -eq 'ScriptInputSet')
		{
			$results = [System.Management.Automation.CommandCompletion]::CompleteInput(
            <#inputScript#>				$inputScript,
            <#cursorColumn#>				$cursorColumn,
            <#options#>				$options)
		}
		else
		{
			$results = [System.Management.Automation.CommandCompletion]::CompleteInput(
            <#ast#>				$ast,
            <#tokens#>				$tokens,
            <#positionOfCursor#>				$positionOfCursor,
            <#options#>				$options)
		}
		
		if ($results.CompletionMatches.Count -eq 0)
		{
			# Built-in didn't succeed, try our own completions here.
			if ($psCmdlet.ParameterSetName -eq 'ScriptInputSet')
			{
				$ast = [System.Management.Automation.Language.Parser]::ParseInput($inputScript, [ref]$tokens, [ref]$null)
			}
			else
			{
				$cursorColumn = $positionOfCursor.Offset
			}
			
			# workaround PowerShell bug that case it to not invoking native completers for - or --
			# making it hard to complete options for many commands
			$nativeCommandResults = TryNativeCommandOptionCompletion -ast $ast -offset $cursorColumn
			if ($null -ne $nativeCommandResults)
			{
				$results.ReplacementIndex = $nativeCommandResults.ReplacementIndex
				$results.ReplacementLength = $nativeCommandResults.ReplacementLength
				if ($results.CompletionMatches.IsReadOnly)
				{
					# Workaround where PowerShell returns a readonly collection that we need to add to.
					$collection = new-object System.Collections.ObjectModel.Collection[System.Management.Automation.CompletionResult]
					$results.GetType().GetProperty('CompletionMatches').SetValue($results, $collection)
				}
				$nativeCommandResults.Results | ForEach-Object {
					$results.CompletionMatches.Add($_)
				}
			}
			
			$attributeResults = TryAttributeArgumentCompletion $ast $cursorColumn
			if ($null -ne $attributeResults)
			{
				$results.ReplacementIndex = $attributeResults.ReplacementIndex
				$results.ReplacementLength = $attributeResults.ReplacementLength
				if ($results.CompletionMatches.IsReadOnly)
				{
					# Workaround where PowerShell returns a readonly collection that we need to add to.
					$collection = new-object System.Collections.ObjectModel.Collection[System.Management.Automation.CompletionResult]
					$results.GetType().GetProperty('CompletionMatches').SetValue($results, $collection)
				}
				$attributeResults.Results | ForEach-Object {
					$results.CompletionMatches.Add($_)
				}
			}
		}
		
		if ($options.ExcludeHiddenFiles)
		{
			foreach ($result in @($results.CompletionMatches))
			{
				if ($result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderItem -or
					$result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderContainer)
				{
					try
					{
						$item = Get-Item -LiteralPath $result.CompletionText -ErrorAction Stop
					}
					catch
					{
						# If Get-Item w/o -Force fails, it is probably hidden, so exclude the result
						$null = $results.CompletionMatches.Remove($result)
					}
				}
			}
		}
		if ($options.AppendBackslash -and
			$results.CompletionMatches.ResultType -contains [System.Management.Automation.CompletionResultType]::ProviderContainer)
		{
			foreach ($result in @($results.CompletionMatches))
			{
				if ($result.ResultType -eq [System.Management.Automation.CompletionResultType]::ProviderContainer)
				{
					$completionText = $result.CompletionText
					$lastChar = $completionText[-1]
					$lastIsQuote = ($lastChar -eq '"' -or $lastChar -eq "'")
					if ($lastIsQuote)
					{
						$lastChar = $completionText[-2]
					}
					
					if ($lastChar -ne '\')
					{
						$null = $results.CompletionMatches.Remove($result)
						
						if ($lastIsQuote)
						{
							$completionText =
							$completionText.Substring(0, $completionText.Length - 1) +
							'\' + $completionText[-1]
						}
						else
						{
							$completionText = $completionText + '\'
						}
						
						$updatedResult = New-Object System.Management.Automation.CompletionResult `
						($completionText, $result.ListItemText, $result.ResultType, $result.ToolTip)
						$results.CompletionMatches.Add($updatedResult)
					}
				}
			}
		}
		
		if ($results.CompletionMatches.Count -eq 0)
		{
			# No results, if this module has overridden another TabExpansion2 function, call it
			# but only if it's not the built-in function (which we assume if function isn't
			# defined in a file.
			if ($oldTabExpansion2 -ne $null -and $oldTabExpansion2.File -ne $null)
			{
				return (& $oldTabExpansion2 @PSBoundParameters)
			}
		}
		
		return $results
	}
	
	
	#############################################################################
	#
	# Main
	#
	
	Add-Type @"
using System;
using System.Management.Automation;

public class NativeCommandTreeNode
{
    private NativeCommandTreeNode(NativeCommandTreeNode[] subCommands)
    {
        SubCommands = subCommands;
    }

    public NativeCommandTreeNode(string command, NativeCommandTreeNode[] subCommands)
        : this(command, null, subCommands)
    {
    }

    public NativeCommandTreeNode(string command, string tooltip, NativeCommandTreeNode[] subCommands)
        : this(subCommands)
    {
        this.Command = command;
        this.Tooltip = tooltip;
    }

    public NativeCommandTreeNode(string command, string tooltip, bool argument)
        : this(null)
    {
        this.Command = command;
        this.Tooltip = tooltip;
        this.Argument = true;
    }

    public NativeCommandTreeNode(ScriptBlock completionGenerator, NativeCommandTreeNode[] subCommands)
        : this(subCommands)
    {
        this.CompletionGenerator = completionGenerator;
    }

    public string Command { get; private set; }
    public string Tooltip { get; private set; }
    public bool Argument { get; private set; }
    public ScriptBlock CompletionGenerator { get; private set; }
    public NativeCommandTreeNode[] SubCommands { get; private set; }
}
"@
	
	# Custom completions are saved in this hashtable
	$tabExpansionOptions = @{
		CustomArgumentCompleters = @{ }
		NativeArgumentCompleters = @{ }
	}
	# Descriptions for the above completions saved in this hashtable
	$tabExpansionDescriptions = @{ }
	# And private data for the above completions cached in this hashtable
	$completionPrivateData = @{ }
}

function Convert-PsfConfigValue
{
<#
	.SYNOPSIS
		Converts a persisted configuration's value back to its data type.
	
	.DESCRIPTION
		Converts a persisted configuration's value back to its data type.
		Can be used for either registry-based or json-file-based items.
	
	.PARAMETER Value
		The full value item to decode (must include the original type identifier).
		Example:
		  "bool:true"
	
	.EXAMPLE
		PS C:\> Convert-PsfConfigValue -Value "bool:true"
	
		Will return a boolean $true
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
	[CmdletBinding()]
	Param (
		[string]
		$Value
	)
	
	begin
	{
		
	}
	process
	{
		$index = $Value.IndexOf(":")
		if ($index -lt 1) { throw "No type identifier found!" }
		$type = $Value.Substring(0, $index)
		$content = $Value.Substring($index + 1)
		
		switch ($type)
		{
			"bool"
			{
				if ($content -eq "true") { return $true }
				if ($content -eq "1") { return $true }
				if ($content -eq "false") { return $false }
				if ($content -eq "0") { return $false }
				throw "Failed to interpret as bool: $content"
			}
			"int" { return ([int]$content) }
			"double" { return [double]$content }
			"long" { return [long]$content }
			"string" { return $content }
			"timespan" { return (New-Object System.TimeSpan($content)) }
			"datetime" { return (New-Object System.DateTime($content)) }
			"consolecolor" { return ([System.ConsoleColor]$content) }
			"array"
			{
				if ($content -eq "") { return, @() }
				$tempArray = @()
				foreach ($item in ($content -split "þþþ"))
				{
					$tempArray += Convert-PsfConfigValue -Value $item
				}
				return, $tempArray
			}
			
			default { throw "Unknown type identifier" }
		}
	}
	end
	{
	
	}
}

function Read-PsfConfigEnvironment {
<#
	.SYNOPSIS
		Reads configuration settings from environment variables.
	
	.DESCRIPTION
		Reads configuration settings from environment variables.
		Returns objects with two properties: Name & Value
	
	.PARAMETER Prefix
		The prefix by which to filter environment variables.
		Only variables that start with the prefix, followeb by an underscore are processed.
	
	.PARAMETER Simple
		Whether to perform simple data processing.
		By default, the full configuration data format is expected.
	
	.EXAMPLE
		PS C:\> Read-PsfConfigEnvironment -Prefix PSFramework
	
		Loads all configuration settings provided by environment starting with PSFramework_.
		Will apply full configuration object parsing.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Prefix,
		
		[switch]
		$Simple
	)
	
	begin {
		function ConvertFrom-EnvironmentSetting {
			[CmdletBinding()]
			param (
				[Parameter(ValueFromPipelineByPropertyName = $true)]
				[string]
				$Name,
				
				[Parameter(ValueFromPipelineByPropertyName = $true)]
				[string]
				$Value,
				
				[bool]
				$Simple,
				
				[string]
				$Prefix
			)
			
			process {
				#region Common Mode
				if (-not $Simple) {
					try {
						[pscustomobject]@{
							FullName = $Name.SubString(($Prefix.Length + 1))
							Value = [PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($Value)
						}
					}
					catch {
						Write-PSFMessage -Level Warning -String 'Read-PsfConfigEnvironment.BadData' -StringValues $Name, $Value
					}
				}
				#endregion Common Mode
				#region Simple Mode
				else {
					$fullName = $Name.SubString(($Prefix.Length + 1))
					if ($Value -eq '') { return [PSCustomObject]@{ FullName = $fullName; Value = $null } }
					if ($Value -eq 'true') { return [PSCustomObject]@{ FullName = $fullName; Value = $true } }
					if ($Value -eq 'false') { return [PSCustomObject]@{ FullName = $fullName; Value = $false } }
					$tempVal = $null
					if ([int32]::TryParse($Value, [ref]$tempVal)) {
						return [PSCustomObject]@{ FullName = $fullName; Value = $tempVal }
					}
					$tempVal = $null
					if ([int64]::TryParse($Value, [ref]$tempVal)) {
						return [PSCustomObject]@{ FullName = $fullName; Value = $tempVal }
					}
					$tempVal = $null
					if ([double]::TryParse($Value, 'Any', [System.Globalization.NumberFormatInfo]::InvariantInfo, [ref]$tempVal)) {
						return [PSCustomObject]@{ FullName = $fullName; Value = $tempVal }
					}
					$tempVal = $null
					if ([datetime]::TryParse($Value, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, 'AssumeUniversal', [ref]$tempVal)) {
						return [PSCustomObject]@{ FullName = $fullName; Value = $tempVal }
					}
					if ($Value -match "^.|*") {
						return [PSCustomObject]@{ FullName = $fullName; Value = $Value.SubString(2).Split($Value.Substring(0, 1)) }
					}
					return [PSCustomObject]@{ FullName = $fullName; Value = $Value }
				}
				#endregion Simple Mode
			}
		}
	}
	process {
		Get-ChildItem "env:$($Prefix)_*" | ConvertFrom-EnvironmentSetting -Simple $Simple -Prefix $Prefix
	}
}

function Read-PsfConfigFile
{
<#
	.SYNOPSIS
		Reads a configuration file and parses it.
	
	.DESCRIPTION
		Reads a configuration file and parses it.
	
	.PARAMETER Path
		The path to the file to parse.
	
	.PARAMETER WebLink
		The link to a website to download straight as raw json.
	
	.PARAMETER RawJson
		Raw json data to interpret.
	
	.EXAMPLE
		PS C:\> Read-PsfConfigFile -Path config.json
	
		Reads the config.json file and returns interpreted configuration objects.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Path')]
		[string]
		$Path,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Weblink')]
		[string]
		$Weblink,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'RawJson')]
		[string]
		$RawJson
	)
	
	#region Utility Function
	function New-ConfigItem
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
		[CmdletBinding()]
		param (
			$FullName,
			
			$Value,
			
			$Type,
			
			[switch]
			$KeepPersisted,
			
			[switch]
			$Enforced,
			
			[switch]
			$Policy
		)
		
		[pscustomobject]@{
			FullName	    = $FullName
			Value		    = $Value
			Type		    = $Type
			KeepPersisted   = $KeepPersisted
			Enforced	    = $Enforced
			Policy		    = $Policy
		}
	}
	
	function Get-WebContent
	{
		[CmdletBinding()]
		param (
			[string]
			$WebLink
		)
		
		$webClient = New-Object System.Net.WebClient
		$webClient.Encoding = [System.Text.Encoding]::UTF8
		$webClient.DownloadString($WebLink)
	}
	#endregion Utility Function
	
	if ($Path)
	{
		if (-not (Test-Path $Path)) { return }
		$data = Get-Content -Path $Path -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
	}
	if ($Weblink)
	{
		$data = Get-WebContent -WebLink $Weblink | ConvertFrom-Json -ErrorAction Stop
	}
	if ($RawJson)
	{
		$data = $RawJson | ConvertFrom-Json -ErrorAction Stop
	}
	
	foreach ($item in $data)
	{
		#region No Version
		if (-not $item.Version)
		{
			New-ConfigItem -FullName $item.FullName -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($item.Value, $item.Type))
		}
		#endregion No Version
		
		#region Version One
		if ($item.Version -eq 1)
		{
			if ((-not $item.Style) -or ($item.Style -eq "Simple")) { New-ConfigItem -FullName $item.FullName -Value $item.Data }
			else
			{
				if (($item.Type -eq "Object") -or ($item.Type -eq 12))
				{
					New-ConfigItem -FullName $item.FullName -Value $item.Value -Type "Object" -KeepPersisted
				}
				else
				{
					New-ConfigItem -FullName $item.FullName -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($item.Value, $item.Type))
				}
			}
		}
		#endregion Version One
	}
}

function Read-PsfConfigPersisted {
<#
	.SYNOPSIS
		Reads configurations from persisted file / registry.
	
	.DESCRIPTION
		Reads configurations from persisted file / registry.
	
	.PARAMETER Scope
		Where to read from.
	
	.PARAMETER Module
		Load module specific data.
		Use this to load on-demand configuration only when the module is imported.
		Useful when using the config system as cache.
	
	.PARAMETER ModuleVersion
		The configuration version of the module-settings to load.
	
	.PARAMETER Hashtable
		Rather than returning results, insert them into this hashtable.
	
	.PARAMETER Default
		When inserting into a hashtable, existing values are overwritten by default.
		Enabling this setting will cause it to only insert values if the key does not exist yet.
	
	.EXAMPLE
		Read-PsfConfigPersisted -Scope 127
	
		Read all persisted default configuration items in the default mandated order.
#>
	[OutputType([System.Collections.Hashtable])]
	[CmdletBinding()]
	param (
		[PSFramework.Configuration.ConfigScope]
		$Scope,
		
		[string]
		$Module,
		
		[int]
		$ModuleVersion = 1,
		
		[System.Collections.Hashtable]
		$Hashtable,
		
		[switch]
		$Default
	)
	
	begin {
		#region Helper Functions
		function New-ConfigItem {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				$FullName,
				
				$Value,
				
				$Type,
				
				[switch]
				$KeepPersisted,
				
				[switch]
				$Enforced,
				
				[switch]
				$Policy
			)
			
			[pscustomobject]@{
				FullName	  = $FullName
				Value		  = $Value
				Type		  = $Type
				KeepPersisted = $KeepPersisted
				Enforced	  = $Enforced
				Policy	      = $Policy
			}
		}
		
		function Read-Registry {
			[CmdletBinding()]
			param (
				$Path,
				
				[switch]
				$Enforced
			)
			
			if (-not (Test-Path $Path)) { return }
			
			$common = 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider'
			
			foreach ($item in ((Get-ItemProperty -Path $Path -ErrorAction Ignore).PSObject.Properties | Where-Object Name -NotIn $common)) {
				if ($item.Value -like "Object:*") {
					$data = $item.Value.Split(":", 2)
					New-ConfigItem -FullName $item.Name -Type $data[0] -Value $data[1] -KeepPersisted -Enforced:$Enforced -Policy
				}
				else {
					try { New-ConfigItem -FullName $item.Name -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($item.Value)) -Policy }
					catch {
						Write-PSFMessage -Level Warning -Message "Failed to load configuration from Registry: $($item.Name)" -ErrorRecord $_ -Target "$Path : $($item.Name)"
					}
				}
			}
		}
		#endregion Helper Functions
		
		if (-not $Hashtable) { $results = @{ } }
		else { $results = $Hashtable }
		
		if ($Module) { $filename = "$($Module.ToLower())-$($ModuleVersion).json" }
		else { $filename = "psf_config.json" }
	}
	process {
		#region Environment - Simple
		if ($Scope -band 256) {
			foreach ($item in Read-PsfConfigEnvironment -Prefix PSF -Simple) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Environment - Simple
		
		#region Environment - Full
		if ($Scope -band 128) {
			foreach ($item in Read-PsfConfigEnvironment -Prefix PSFramework) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Environment - Full
		
		#region File - Computer Wide
		if ($Scope -band 64) {
			if (-not $Module) {
				foreach ($file in Get-ChildItem -Path $script:path_FileSystem -Filter "psf_config_*.json" -ErrorAction Ignore) {
					foreach ($item in Read-PsfConfigFile -Path $file.FullName) {
						if (-not $Default) { $results[$item.FullName] = $item }
						elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
					}
				}
			}
			foreach ($item in (Read-PsfConfigFile -Path (Join-Path $script:path_FileSystem $filename))) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion File - Computer Wide
		
		#region Registry - Computer Wide
		if (($Scope -band 4) -and (-not $script:NoRegistry)) {
			foreach ($item in (Read-Registry -Path $script:path_RegistryMachineDefault)) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Registry - Computer Wide
		
		#region File - User Shared
		if ($Scope -band 32) {
			if (-not $Module) {
				foreach ($file in Get-ChildItem -Path $script:path_FileUserShared -Filter "psf_config_*.json" -ErrorAction Ignore) {
					foreach ($item in Read-PsfConfigFile -Path $file.FullName) {
						if (-not $Default) { $results[$item.FullName] = $item }
						elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
					}
				}
			}
			foreach ($item in (Read-PsfConfigFile -Path (Join-Path $script:path_FileUserShared $filename))) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion File - User Shared
		
		#region Registry - User Shared
		if (($Scope -band 1) -and (-not $script:NoRegistry)) {
			foreach ($item in (Read-Registry -Path $script:path_RegistryUserDefault)) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Registry - User Shared
		
		#region File - User Local
		if ($Scope -band 16) {
			if (-not $Module) {
				foreach ($file in Get-ChildItem -Path $script:path_FileUserLocal -Filter "psf_config_*.json" -ErrorAction Ignore) {
					foreach ($item in Read-PsfConfigFile -Path $file.FullName) {
						if (-not $Default) { $results[$item.FullName] = $item }
						elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
					}
				}
			}
			foreach ($item in (Read-PsfConfigFile -Path (Join-Path $script:path_FileUserLocal $filename))) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion File - User Local
		
		#region Registry - User Enforced
		if (($Scope -band 2) -and (-not $script:NoRegistry)) {
			foreach ($item in (Read-Registry -Path $script:path_RegistryUserEnforced -Enforced)) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Registry - User Enforced
		
		#region Registry - System Enforced
		if (($Scope -band 8) -and (-not $script:NoRegistry)) {
			foreach ($item in (Read-Registry -Path $script:path_RegistryMachineEnforced -Enforced)) {
				if (-not $Default) { $results[$item.FullName] = $item }
				elseif (-not $results.ContainsKey($item.FullName)) { $results[$item.FullName] = $item }
			}
		}
		#endregion Registry - System Enforced
	}
	end {
		$results
	}
}

function Write-PsfConfigFile
{
<#
	.SYNOPSIS
		Handles config export to file.
	
	.DESCRIPTION
		Handles config export to file.
	
	.PARAMETER Config
		The configuration items to export.
	
	.PARAMETER Path
		The path to export to.
		Needs to point to the specific file to export to.
		Will create the folder structure if needed.
	
	.PARAMETER Replace
		Completely replaces previous file contents.
		By default, it will integrate settings into one coherent configuration file.
	
	.EXAMPLE
		PS C:\> Write-PsfConfigFile -Config $items -Path .\file.json
	
		Exports all settings stored in $items to .\file.json.
		If the file already exists, the new settings will be merged into the existing file.
#>
	[CmdletBinding()]
	Param (
		[PSFramework.Configuration.Config[]]
		$Config,
		
		[string]
		$Path,
		
		[switch]
		$Replace
	)
	
	begin
	{
		$parent = Split-Path -Path $Path
		if (-not (Test-Path $parent))
		{
			$null = New-Item $parent -ItemType Directory -Force
		}
		
		$data = @{ }
		if ((Test-Path $Path) -and (-not $Replace))
		{
			foreach ($item in (Get-Content -Path $Path -Encoding UTF8 | ConvertFrom-Json))
			{
				$data[$item.FullName] = $item
			}
		}
	}
	process
	{
		foreach ($item in $Config)
		{
			$datum = @{
				Version  = 1
				FullName = $item.FullName
			}
			if ($item.SimpleExport)
			{
				$datum["Data"] = $item.Value
			}
			else
			{
				$persisted = [PSFramework.Configuration.ConfigurationHost]::ConvertToPersistedValue($item.Value)
				$datum["Value"] = $persisted.PersistedValue
				$datum["Type"] = $persisted.PersistedType
				$datum["Style"] = "default"
			}
			
			$data[$item.FullName] = [pscustomobject]$datum
		}
	}
	end
	{
		$data.Values | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
	}
}

function Convert-PsfMessageException
{
	<#
		.SYNOPSIS
			Transforms the Exception input to the message system.
		
		.DESCRIPTION
			Transforms the Exception input to the message system.
		
			If there is an exception running a transformation scriptblock, it will log the error in the transform error queue and return the original object instead.
		
		.PARAMETER Exception
			The input Exception object, that might have to be transformed (may not either)
		
		.PARAMETER FunctionName
			The function writing the message
		
		.PARAMETER ModuleName
			The module, that the function writing the message is part of
		
		.EXAMPLE
			PS C:\> Convert-PsfMessageException -Exception $Exception -FunctionName 'Get-Test' -ModuleName 'MyModule'
		
			Checks internal storage for definitions that require a Exception transform, and either returns the original object or the transformed object.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		$Exception,
		
		[Parameter(Mandatory = $true)]
		[string]
		$FunctionName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName
	)
	
	if ($null -eq $Exception) { return }
	
	$typeName = $Exception.GetType().FullName
	
	if ([PSFramework.Message.MessageHost]::ExceptionTransforms.ContainsKey($typeName))
	{
		$scriptBlock = [PSFramework.Message.MessageHost]::ExceptionTransforms[$typeName]
		try
		{
			$tempException = $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create($scriptBlock.ToString())), $null, $Exception)
			return $tempException
		}
		catch
		{
			[PSFramework.Message.MessageHost]::WriteTransformError($_, $FunctionName, $ModuleName, $Exception, "Exception", ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId))
			return $Exception
		}
	}
	
	if ($transform = [PSFramework.Message.MessageHost]::ExceptionTransformList.Get($typeName, $ModuleName, $FunctionName))
	{
		try
		{
			$tempException = $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create($transform.ScriptBlock.ToString())), $null, $Exception)
			return $tempException
		}
		catch
		{
			[PSFramework.Message.MessageHost]::WriteTransformError($_, $FunctionName, $ModuleName, $Exception, "Target", ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId))
			return $Exception
		}
	}
	
	return $Exception
}

function Convert-PsfMessageLevel
{
	<#
		.SYNOPSIS
			Processes the effective message level of a message
		
		.DESCRIPTION
			Processes the effective message level of a message
			- Applies level decrements
			- Applies message level modifiers
		
		.PARAMETER OriginalLevel
			The level the message was originally written to
		
		.PARAMETER FromStopFunction
			Whether the message was passed through Stop-PSFFunction first.
			This is used to increment the automatic message level decrement counter by 1 (so it ignores the fact, that it was passed through Stop-PSFFunction).
			The automatic message level decrement functionality allows users to make nested commands' messages be less verbose.
		
		.PARAMETER Tags
			The tags that were added to the message
		
		.PARAMETER FunctionName
			The function that wrote the message.
		
		.PARAMETER ModuleName
			The module the function writing the message comes from.
	
		.EXAMPLE
			Convert-PsfMessageLevel -OriginalLevel $Level -FromStopFunction $fromStopFunction -Tags $Tag -FunctionName $FunctionName -ModuleName $ModuleName
	
			This will convert the original level of $Level based on the transformation rules for levels.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[PSFramework.Message.MessageLevel]
		$OriginalLevel,
		
		[Parameter(Mandatory = $true)]
		[bool]
		$FromStopFunction,
		
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		[string[]]
		$Tags,
		
		[Parameter(Mandatory = $true)]
		[string]
		$FunctionName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName
	)
	
	$number = $OriginalLevel.value__
	
	if ([PSFramework.Message.MessageHost]::NestedLevelDecrement -gt 0)
	{
		$depth = (Get-PSCallStack).Count - 3
		if ($FromStopFunction) { $depth = $depth - 1 }
		$number = $number + $depth * ([PSFramework.Message.MessageHost]::NestedLevelDecrement)
	}
	
	foreach ($modifier in [PSFramework.Message.MessageHost]::MessageLevelModifiers.Values)
	{
		if ($modifier.AppliesTo($FunctionName, $ModuleName, $Tags))
		{
			$number = $number + $modifier.Modifier
		}
	}
	
	# Finalize number and return
	if ($number -lt 1) { $number = 1 }
	if ($number -gt 9) { $number = 9 }
	return ([PSFramework.Message.MessageLevel]$number)
}

function Convert-PsfMessageTarget
{
	<#
		.SYNOPSIS
			Transforms the target input to the message system.
		
		.DESCRIPTION
			Transforms the target input to the message system.
		
			If there is an exception running a transformation scriptblock, it will log the error in the transform error queue and return the original object instead.
		
		.PARAMETER Target
			The input target object, that might have to be transformed (may not either)
		
		.PARAMETER FunctionName
			The function writing the message
		
		.PARAMETER ModuleName
			The module, that the function writing the message is part of
		
		.EXAMPLE
			PS C:\> Convert-PsfMessageTarget -Target $Target -FunctionName 'Get-Test' -ModuleName 'MyModule'
		
			Checks internal storage for definitions that require a target transform, and either returns the original object or the transformed object.
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		$Target,
		
		[Parameter(Mandatory = $true)]
		[string]
		$FunctionName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$ModuleName
	)
	
	if ($null -eq $Target) { return }
	
	$typeName = $Target.GetType().FullName
	
	if ([PSFramework.Message.MessageHost]::TargetTransforms.ContainsKey($typeName))
	{
		$scriptBlock = [PSFramework.Message.MessageHost]::TargetTransforms[$typeName]
		try
		{
			$tempTarget = $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create($scriptBlock.ToString())), $null, $Target)
			return $tempTarget
		}
		catch
		{
			[PSFramework.Message.MessageHost]::WriteTransformError($_, $FunctionName, $ModuleName, $Target, "Target", ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId))
			return $Target
		}
	}
	
	if ($transform = [PSFramework.Message.MessageHost]::TargetTransformlist.Get($typeName, $ModuleName, $FunctionName))
	{
		try
		{
			$tempTarget = $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create($transform.ScriptBlock.ToString())), $null, $Target)
			return $tempTarget
		}
		catch
		{
			[PSFramework.Message.MessageHost]::WriteTransformError($_, $FunctionName, $ModuleName, $Target, "Target", ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId))
			return $Target
		}
	}
	
	return $Target
}

function global:New-PSFTeppCompletionResult
{
    <#
        .SYNOPSIS
            Generates a completion result for dbatools internal tab completion.
        
        .DESCRIPTION
            Generates a completion result for dbatools internal tab completion.
        
        .PARAMETER CompletionText
            The text to propose.
        
        .PARAMETER ToolTip
            The tooltip to show in tooltip-aware hosts (ISE, mostly)
        
        .PARAMETER ListItemText
            ???
        
        .PARAMETER CompletionResultType
            The type of object that is being completed.
            By default it generates one of type paramter value.
        
        .PARAMETER NoQuotes
            Whether to put the result in quotes or not.
        
        .EXAMPLE
            New-PSFTeppCompletionResult -CompletionText 'master' -ToolTip 'master'
    
            Returns a CompletionResult with the text and tooltip 'master'
    #>
	param (
		[Parameter(Position = 0, ValueFromPipelineByPropertyName = $true, Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$CompletionText,
		
		[Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
		[string]
		$ToolTip,
		
		[Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
		[string]
		$ListItemText,
		
		[System.Management.Automation.CompletionResultType]
		$CompletionResultType = [System.Management.Automation.CompletionResultType]::ParameterValue,
		
		[switch]
		$NoQuotes
	)
	
	process
	{
		$toolTipToUse = if ($ToolTip -eq '') { $CompletionText }
		else { $ToolTip }
		$listItemToUse = if ($ListItemText -eq '') { $CompletionText }
		else { $ListItemText }
		
		# If the caller explicitly requests that quotes
		# not be included, via the -NoQuotes parameter,
		# then skip adding quotes.
		
		if ($CompletionResultType -eq [System.Management.Automation.CompletionResultType]::ParameterValue -and -not $NoQuotes)
		{
			# Add single quotes for the caller in case they are needed.
			# We use the parser to robustly determine how it will treat
			# the argument.  If we end up with too many tokens, or if
			# the parser found something expandable in the results, we
			# know quotes are needed.
			
			$tokens = $null
			$null = [System.Management.Automation.Language.Parser]::ParseInput("echo $CompletionText", [ref]$tokens, [ref]$null)
			if ($tokens.Length -ne 3 -or ($tokens[1] -is [System.Management.Automation.Language.StringExpandableToken] -and $tokens[1].Kind -eq [System.Management.Automation.Language.TokenKind]::Generic))
			{
				$CompletionText = "'$CompletionText'"
			}
		}
		return New-Object System.Management.Automation.CompletionResult($CompletionText, $listItemToUse, $CompletionResultType, $toolTipToUse.Trim())
	}
}

(Get-Item Function:\New-PSFTeppCompletionResult).Visibility = "Private"

function Invoke-PSFCommand
{
<#
	.SYNOPSIS
		An Invoke-Command wrapper with integrated session management.
	
	.DESCRIPTION
		This wrapper command around Invoke-Command allows conveniently calling remote calls.
	
		- It uses the PSFComputer parameter class, and is thus a lot more flexible in accepted input
		- It automatically reuses sessions specified for input
		- It automatically establishes new sessions, tracks usage and retires sessions that have timed out.
	
		Using this command, it is no longer necessary to first establish a connection and then manually handle the session object.
		Just point the command at the computer and it will remember.
		It also reuses sessions across multiple commands that call it.
	
		Note:
		Special connection conditions (like a custom application name, alternative authentication schemes, etc.) are not supported and require using New-PSSession to establish the connection.
		Once that session has been established, the session object can be used with this command and will be used for command invocation.
	
	.PARAMETER ComputerName
		The computer(s) to invoke the command on.
		Accepts all kinds of things that legally point at a computer, including DNS names, ADComputer objects, IP Addresses, SQL Server connection strings, CimSessions or PowerShell Sessions.
		It will reuse PSSession objects if specified (and not include them in its session management).
	
	.PARAMETER ScriptBlock
		The code to execute.
	
	.PARAMETER ArgumentList
		The arguments to pass into the scriptblock.
	
	.PARAMETER Credential
		Credentials to use when establishing connections.
		Note: These will be ignored if there already exists an established connection.
	
	.PARAMETER HideComputerName
		Indicates that this cmdlet omits the computer name of each object from the output display. By default, the name of the computer that generated the object appears in the display.
	
	.PARAMETER ThrottleLimit
		Specifies the maximum number of concurrent connections that can be established to run this command. If you omit this parameter or enter a value of 0, the default value, 32, is used.
	
	.EXAMPLE
		PS C:\> Invoke-PSFCommand -ScriptBlock $ScriptBlock
	
		Runs the $scriptblock against the local computer.
	
	.EXAMPLE
		PS C:\> Invoke-PSFCommand -ScriptBlock $ScriptBlock (Get-ADComputer -Filter "name -like 'srv-db*'")
	
		Runs the $scriptblock against all computers in AD with a name that starts with "srv-db".
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectUsageOfAssignmentOperator", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Invoke-PSFCommand')]
	param (
		[PSFComputer[]]
		[Alias('Session')]
		$ComputerName = $env:COMPUTERNAME,
		
		[Parameter(Mandatory = $true)]
		[scriptblock]
		$ScriptBlock,
		
		[object[]]
		$ArgumentList,
		
		[System.Management.Automation.CredentialAttribute()]
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[switch]
		$HideComputerName,
		
		[int]
		$ThrottleLimit = 32
	)
	
	begin
	{
		Write-PSFMessage -Level InternalComment -Message "Bound parameters: $($PSBoundParameters.Keys -join ", ")" -Tag 'debug', 'start', 'param'
		
		#region Clean up broken sessions
		[array]$broken = $psframework_pssessions.GetBroken()
		foreach ($sessionInfo in $broken)
		{
			Write-PSFMessage -Level Debug -Message "Removing broken session to $($sessionInfo.ComputerName)"
			Remove-PSSession -Session $sessionInfo.Session -ErrorAction Ignore
			$null = $psframework_pssessions.Remove($sessionInfo.ComputerName)
		}
		#endregion Clean up broken sessions
		
		#region Invoke Command Splats
		$paramInvokeCommand = @{
			ScriptBlock	       = $ScriptBlock
			ArgumentList	   = $ArgumentList
			HideComputerName   = $HideComputerName
			ThrottleLimit	   = $ThrottleLimit
		}
		
		$paramInvokeCommandLocal = @{
			ScriptBlock		    = $ScriptBlock
			ArgumentList	    = $ArgumentList
		}
		#endregion Invoke Command Splats
	}
	process
	{
		#region Collect list of sessions to process
		$sessionsToInvoke = @()
		$managedSessions = @()
		
		foreach ($computer in $ComputerName)
		{
			if ($computer.Type -eq "PSSession") { $sessionsToInvoke += $computer.InputObject }
			elseif ($sessionObject = $computer.InputObject -as [System.Management.Automation.Runspaces.PSSession]) { $sessionsToInvoke += $sessionObject }
			else
			{
				#region Handle localhost
				if ($computer.IsLocalHost)
				{
					Write-PSFMessage -Level Verbose -Message "Executing command against localhost" -Target $computer
					Invoke-Command @paramInvokeCommandLocal
					continue
				}
				#endregion Handle localhost
				
				#region Already have a cached session
				if ($session = $psframework_pssessions[$computer.ComputerName])
				{
					$sessionsToInvoke += $session.Session
					$managedSessions += $session
					$session.ResetTimestamp()
				}
				#endregion Already have a cached session
				
				#region Establish new session and add to management
				else
				{
					Write-PSFMessage -Level Verbose -Message "Establishing connection to $computer" -Target $computer
					try
					{
						if ($Credential) { $pSSession = New-PSSession -ComputerName $computer -Credential $Credential -ErrorAction Stop }
						else { $pSSession = New-PSSession -ComputerName $computer -ErrorAction Stop }
					}
					catch
					{
						Write-PSFMessage -Level Warning -Message "Failed to connect to $computer" -ErrorRecord $_ -Target $computer 3>$null
						Write-Error -ErrorRecord $_
						continue
					}
					
					$session = New-Object PSFramework.ComputerManagement.PSSessioninfo($pSSession)
					$psframework_pssessions[$session.ComputerName] = $session
					$sessionsToInvoke += $session.Session
					$managedSessions += $session
				}
				#endregion Establish new session and add to management
			}
		}
		#endregion Collect list of sessions to process
		
		if ($sessionsToInvoke)
		{
			Write-PSFMessage -Level VeryVerbose -Message "Invoking command against $($sessionsToInvoke.ComputerName -join ', ' )"
			Invoke-Command -Session $sessionsToInvoke @paramInvokeCommand
		}
		
		#region Refresh timestamp
		foreach ($session in $managedSessions)
		{
			$session.ResetTimestamp()
		}
		#endregion Refresh timestamp
	}
	end
	{
		#region Cleanup expired sessions
		[array]$expired = $psframework_pssessions.GetExpired()
		foreach ($sessionInfo in $expired)
		{
			Write-PSFMessage -Level Debug -Message "Removing expired session to $($sessionInfo.ComputerName)"
			Remove-PSSession -Session $sessionInfo.Session -ErrorAction Ignore
			$null = $psframework_pssessions.Remove($sessionInfo.ComputerName)
		}
		#endregion Cleanup expired sessions
	}
}

function New-PSFSessionContainer
{
<#
	.SYNOPSIS
		Creates an object containing multiple session objects to the same computer.
	
	.DESCRIPTION
		Creates an object containing multiple session objects to the same computer.
		Using this, a single object can be used to point at a computer while containing session objects for multiple protocols inside.
	
		Only session types registered via Reigster-PSSessionObjectType are supported.
	
	.PARAMETER ComputerName
		The name of the computer to connect to
	
	.PARAMETER Session
		The session objects that are a live connection to the host.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> New-PSFSessionContainer -ComputerName "server1" -Session $pssession, $cimsession, $smosession
	
		Create a session container containing three different kinds of session objects
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectUsageOfAssignmentOperator", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PSFComputer]
		$ComputerName,
		
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[object[]]
		$Session,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		$container = New-Object PSFramework.ComputerManagement.SessionContainer
		$container.ComputerName = $ComputerName
	}
	process
	{
		foreach ($sessionItem in $Session)
		{
			if ($null -eq $sessionItem) { continue }
			
			if (-not ($sessionName = [PSFramework.ComputerManagement.ComputerManagementHost]::KnownSessionTypes[$sessionItem.GetType()]))
			{
				Stop-PSFFunction -String 'New-PSFSessionContainer.UnknownSessionType' -StringValues $sessionItem.GetType().Name, $sessionItem -Continue -EnableException $EnableException
			}
			
			$container.Connections[$sessionName] = $sessionItem
		}
	}
	end
	{
		$container
	}
}

function Register-PSFSessionObjectType
{
<#
	.SYNOPSIS
		Registers a new type as a live session object.
	
	.DESCRIPTION
		Registers a new type as a live session object.
		This is used in the session container object, used to pass through multiple types of connection objects to a single PSFComputer parameterclassed parameter.
	
	.PARAMETER DisplayName
		The display name for the type.
		Pick anything that intuitively points at what the object is.
	
	.PARAMETER TypeName
		The full name of the type.
	
	.EXAMPLE
		PS C:\> Register-PSFSessionObjectType -DisplayName 'PSSession' -TypeName 'System.Management.Automation.Runspaces.PSSession'
	
		Registers the type 'System.Management.Automation.Runspaces.PSSession' under the name of 'PSSession'.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$DisplayName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$TypeName
	)
	
	process
	{
		[PSFramework.ComputerManagement.ComputerManagementHost]::KnownSessionTypes[$TypeName] = $DisplayName
	}
}

function Export-PSFConfig
{
<#
	.SYNOPSIS
		Exports configuration items to a Json file.
	
	.DESCRIPTION
		Exports configuration items to a Json file.
	
	.PARAMETER FullName
		Select the configuration objects to export by filtering by their full name.
	
	.PARAMETER Module
		Select the configuration objects to export by filtering by their module name.
	
	.PARAMETER Name
		Select the configuration objects to export by filtering by their name.
	
	.PARAMETER Config
		The configuration object(s) to export.
		Returned by Get-PSFConfig.
	
	.PARAMETER ModuleName
		Exports all configuration pertinent to a module to a predefined path.
		Exported configuration items include all settings marked as 'ModuleExport' that have been changed from the default value.
	
	.PARAMETER ModuleVersion
		The configuration version of the module-settings to write.
	
	.PARAMETER Scope
		Which predefined path to write module specific settings to.
		Only file scopes are considered.
		By default it writes to the suer profile.
	
	.PARAMETER OutPath
		The path (filename included) to export to.
		Will fail if the folder does not exist, will overwrite the file if it exists.
	
	.PARAMETER SkipUnchanged
		If set, configuration objects whose value was not changed from its original value will not be exported.
		(Note: Settings that were updated with the same value as the original default will still be considered changed)
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Get-PSFConfig | Export-PSFConfig -OutPath '~/export.json'
		
		Exports all current settings to json.
	
	.EXAMPLE
		Export-PSFConfig -Module MyModule -OutPath '~/export.json' -SkipUnchanged
		
		Exports all settings of the module 'MyModule' that are no longer the original default values to json.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding(DefaultParameterSetName = 'FullName', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Export-PSFConfig')]
	param (
		[Parameter(ParameterSetName = "FullName", Position = 0, Mandatory = $true)]
		[string]
		$FullName,
		
		[Parameter(ParameterSetName = "Module", Position = 0, Mandatory = $true)]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = "Module", Position = 1)]
		[string]
		$Name = "*",
		
		[Parameter(ParameterSetName = "Config", Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
		[PSFramework.Configuration.Config[]]
		$Config,
		
		[Parameter(ParameterSetName = "ModuleName", Mandatory = $true)]
		[string]
		$ModuleName,
		
		[Parameter(ParameterSetName = "ModuleName")]
		[int]
		$ModuleVersion = 1,
		
		[Parameter(ParameterSetName = "ModuleName")]
		[PSFramework.Configuration.ConfigScope]
		$Scope = "FileUserShared",
		
		[Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'Config')]
		[Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'FullName')]
		[Parameter(Position = 2, Mandatory = $true, ParameterSetName = 'Module')]
		[string]
		$OutPath,
		
		[switch]
		$SkipUnchanged,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		$items = @()
		
		# Values 1, 2, 4 and 8 represent the four registry locations
		if (($Scope -band 15) -and $ModuleName)
		{
			Stop-PSFFunction -String 'Export-PSFConfig.ToRegistry' -EnableException $EnableException -Category InvalidArgument -Tag 'fail', 'scope', 'registry'
			return
		}
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		if (-not $ModuleName)
		{
			foreach ($item in $Config) { $items += $item }
			if ($FullName) { $items = Get-PSFConfig -FullName $FullName }
			if ($Module) { $items = Get-PSFConfig -Module $Module -Name $Name }
		}
	}
	end
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		if (-not $ModuleName)
		{
			try { Write-PsfConfigFile -Config ($items | Where-Object { -not $SkipUnchanged -or -not $_.Unchanged }) -Path $OutPath -Replace }
			catch
			{
				Stop-PSFFunction -String 'Export-PSFConfig.Write.Error' -EnableException $EnableException -ErrorRecord $_ -Tag 'fail', 'export'
				return
			}
		}
		else
		{
			if ($Scope -band 16) # File: User Local
			{
				Write-PsfConfigFile -Config (Get-PSFConfig -Module $ModuleName -Force | Where-Object ModuleExport | Where-Object Unchanged -NE $true) -Path (Join-Path $script:path_FileUserLocal "$($ModuleName.ToLower())-$($ModuleVersion).json")
			}
			if ($Scope -band 32) # File: User Shared
			{
				Write-PsfConfigFile -Config (Get-PSFConfig -Module $ModuleName -Force | Where-Object ModuleExport | Where-Object Unchanged -NE $true) -Path (Join-Path $script:path_FileUserShared "$($ModuleName.ToLower())-$($ModuleVersion).json")
			}
			if ($Scope -band 64) # File: System-Wide
			{
				Write-PsfConfigFile -Config (Get-PSFConfig -Module $ModuleName -Force | Where-Object ModuleExport | Where-Object Unchanged -NE $true) -Path (Join-Path $script:path_FileSystem "$($ModuleName.ToLower())-$($ModuleVersion).json")
			}
		}
	}
}

function Get-PSFConfig
{
	<#
		.SYNOPSIS
			Retrieves configuration elements by name.
		
		.DESCRIPTION
			Retrieves configuration elements by name.
			Can be used to search the existing configuration list.
	
		.PARAMETER FullName
			Default: "*"
			Search for configurations using the full name
		
		.PARAMETER Name
			Default: "*"
			The name of the configuration element(s) to retrieve.
			May be any string, supports wildcards.
		
		.PARAMETER Module
			Default: "*"
			Search configuration by module.
		
		.PARAMETER Force
			Overrides the default behavior and also displays hidden configuration values.
		
		.EXAMPLE
			PS C:\> Get-PSFConfig 'Mail.To'
			
			Retrieves the configuration element for the key "Mail.To"
	
		.EXAMPLE
			PS C:\> Get-PSFConfig -Force
	
			Retrieve all configuration elements from all modules, even hidden ones.
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[OutputType([PSFramework.Configuration.Config])]
	[CmdletBinding(DefaultParameterSetName = "FullName", HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFConfig')]
	Param (
		[Parameter(ParameterSetName = "FullName", Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$FullName = "*",
		
		[Parameter(ParameterSetName = "Module", Position = 1)]
		[string]
		$Name = "*",
		
		[Parameter(ParameterSetName = "Module", Position = 0)]
		[string]
		$Module = "*",
		
		[switch]
		$Force
	)
	
	process
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			"Module"
			{
				[PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object {
					($_.Name -like $Name) -and
					($_.Module -like $Module) -and
					((-not $_.Hidden) -or ($Force))
				} | Sort-Object Module, Name
			}
			
			"FullName"
			{
				[PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object {
					("$($_.Module).$($_.Name)" -like $FullName) -and
					((-not $_.Hidden) -or ($Force))
				} | Sort-Object Module, Name
			}
		}
	}
}


function Get-PSFConfigValue
{
	<#
		.SYNOPSIS
			Returns the configuration value stored under the specified name.
		
		.DESCRIPTION
			Returns the configuration value stored under the specified name.
			It requires the full name (<Module>.<Name>) and is usually only called by functions.
		
		.PARAMETER FullName
			The full name (<Module>.<Name>) of the configured value to return.
	
		.PARAMETER Fallback
			A fallback value to use, if no value was registered to a specific configuration element.
			This basically is a default value that only applies on a "per call" basis, rather than a system-wide default.
		
		.PARAMETER NotNull
			By default, this function returns null if one tries to retrieve the value from either a Configuration that does not exist or a Configuration whose value was set to null.
			However, sometimes it may be important that some value was returned.
			By specifying this parameter, the function will throw an error if no value was found at all.
		
		.EXAMPLE
			PS C:\> Get-PSFConfigValue -FullName 'System.MailServer'
	
			Returns the configured value that was assigned to the key 'System.MailServer'
	
		.EXAMPLE
			PS C:\> Get-PSFConfigValue -FullName 'Default.CoffeeMilk' -Fallback 0
	
			Returns the configured value for 'Default.CoffeeMilk'. If no such value is configured, it returns '0' instead.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectComparisonWithNull", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFConfigValue')]
	param (
		[Alias('Name')]
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$FullName,
		
		[object]
		$Fallback,
		
		[switch]
		$NotNull
	)
	
	process
	{
		$temp = $null
		$temp = [PSFramework.Configuration.ConfigurationHost]::Configurations[$FullName].Value
		if ($null -eq $temp) { $temp = $Fallback }
		
		if ($NotNull -and ($null -eq $temp))
		{
			Stop-PSFFunction -String 'Get-PSFConfigValue.NoValue' -StringValues $FullName -EnableException $true -Category InvalidData -Target $FullName
		}
		return $temp
	}
}

function Import-PSFConfig {
<#
	.SYNOPSIS
		Imports a configuration file into the configuration system.
	
	.DESCRIPTION
		Imports a configuration file into the configuration system.
		There are two modes of import:
		- By ModuleName for the module cache scenario:
		https://psframework.org/documentation/documents/psframework/configuration/scenario-cache.html
		This consumes the json files generated by Export-PSFConfig used in the same scenario.
		- By explicit Path.
		When importing by path, you use a configuration schema to parse the input file.
		The default schema expects the json file format produced by Export-PSFConfig,
		however you can freely extend this using the Register-PSFConfigSchema to understand other formats,
		such as csv, XML, yaml, or whatever else you may care to parse as configuration.
	
	.PARAMETER Path
		The path to the file to import.
		Ensure the file is properly formatted for the configuration schema specified.
	
	.PARAMETER ModuleName
		Import configuration items specific to a module from the default configuration paths.
	
	.PARAMETER ModuleVersion
		The configuration version of the module-settings to load.
	
	.PARAMETER Scope
		Where to import the module specific configuration items form.
		Only file-based scopes are supported for this.
		By default, all locations are queried, with user settings beating system settings.
	
	.PARAMETER Schema
		The configuration schema to use for import.
		Use Register-PSFConfigSchema to extend the way input content can be laid out.
	
	.PARAMETER IncludeFilter
		If specified, only elements with names that are similar (-like) to names in this list will be imported.
	
	.PARAMETER ExcludeFilter
		Elements that are similar (-like) to names in this list will not be imported.
	
	.PARAMETER Peek
		Rather than applying the setting, return the configuration items that would have been applied.
	
	.PARAMETER AllowDelete
		Configurations that have been imported will be flagged as deletable.
		This allows to purge them at a later time using Remove-PSFConfig.
	
	.PARAMETER EnvironmentPrefix
		Import values from environment variables.
		Entries will be expected to start with the prefix, then an Underscore, then the full name of the configuration setting.
		Example: PSF_PSFramework.Utility.Size.Digits
		By default, the same value formatting needs to be adhered to as is in registry settings.
		For example, to store the number 3, the value would be "Int:3". Use:
		  (Get-PSFConfig -FullName '<name of setting>').RegistryData
		To see how an existing setting would look in that format.
		You can switch to simple mode using the '-Simple' parameter.
		Which cannot handle complex objects, but has less overhead for simple data types.
	
	.PARAMETER Simple
		Switches the import from environment variables into a simple data mode.
		In this mode it will only understand a few simple data types, but provide for very simple value formatting:
		- An empty string will be $null
		- "true" will be $true
		- "false" will be $false
		- A number (e.g. "12") will be parsed as integer first, long second, double third
		- A DateTime compliant string will be parsed as such, ignoring local culture.
		- A value starting with any character followed by a "|" will be considered a string array.
		  the first character will be the delimiter.
		  ";|abc;def;ghi" would thus become @("abc","def","ghi")
		- Anything else will be considered a string.
	
	.PARAMETER PassThru
		Return configuration settings that have been imported.
		By default, this command will not produce any output.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Import-PSFConfig -Path '.\config.json'
		
		Imports the configuration stored in '.\config.json'
	
	.EXAMPLE
		PS C:\> Import-PSFConfig -ModuleName mymodule
		
		Imports all the module specific settings that have been persisted in any of the default file system paths.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "")]
	[CmdletBinding(DefaultParameterSetName = "Path", HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Import-PSFConfig')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Path")]
		[string[]]
		$Path,
		
		[Parameter(ParameterSetName = "ModuleName", Mandatory = $true)]
		[string]
		$ModuleName,
		
		[Parameter(ParameterSetName = "ModuleName")]
		[int]
		$ModuleVersion = 1,
		
		[Parameter(ParameterSetName = "ModuleName")]
		[PSFramework.Configuration.ConfigScope]
		$Scope = "FileUserLocal, FileUserShared, FileSystem",
		
		[Parameter(ParameterSetName = "Path")]
		[PsfValidateSet(TabCompletion = 'PSFramework-Config-Schema')]
		[string]
		$Schema = "Default",
		
		[Parameter(ParameterSetName = "Path")]
		[string[]]
		$IncludeFilter,
		
		[Parameter(ParameterSetName = "Path")]
		[string[]]
		$ExcludeFilter,
		
		[Parameter(ParameterSetName = "Path")]
		[switch]
		$Peek,
		
		[Parameter(ParameterSetName = 'Path')]
		[switch]
		$AllowDelete,
		
		[Parameter(ParameterSetName = 'Environment')]
		[string]
		$EnvironmentPrefix,
		
		[Parameter(ParameterSetName = 'Environment')]
		[switch]
		$Simple,
		
		[switch]
		$PassThru,
		
		[switch]
		$EnableException
	)
	
	begin {
		$settings = @{
			IncludeFilter = $IncludeFilter
			ExcludeFilter = $ExcludeFilter
			Peek		  = $Peek.ToBool()
			AllowDelete   = $AllowDelete.ToBool()
			EnableException = $EnableException.ToBool()
			Cmdlet	      = $PSCmdlet
			Path		  = (Get-Location).Path
			PassThru	  = $PassThru.ToBool()
		}
		
		$schemaScript = [PSFramework.Configuration.ConfigurationHost]::Schemata[$Schema]
	}
	process {
		#region Explicit Path
		foreach ($item in $Path) {
			try { $resolvedItem = Resolve-PSFPath -Path $item -Provider FileSystem }
			catch { $resolvedItem = $item } # More than just filesystem paths are permissible
			
			foreach ($rItem in $resolvedItem) {
				$schemaScript.ToGlobal().Invoke($rItem, $settings)
			}
		}
		#endregion Explicit Path
		
		#region ModuleName
		if ($ModuleName) {
			$data = Read-PsfConfigPersisted -Module $ModuleName -Scope $Scope -ModuleVersion $ModuleVersion
			
			foreach ($value in $data.Values) {
				if (-not $value.KeepPersisted) { Set-PSFConfig -FullName $value.FullName -Value $value.Value -EnableException:$EnableException -PassThru:$PassThru }
				else { Set-PSFConfig -FullName $value.FullName -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($value.Value, $value.Type)) -EnableException:$EnableException -PassThru:$PassThru }
			}
		}
		#endregion ModuleName
		
		#region Environment
		if ($EnvironmentPrefix) {
			foreach ($entry in Read-PsfConfigEnvironment -Prefix $EnvironmentPrefix -Simple:$Simple) {
				Set-PSFConfig -FullName $entry.FullName -Value $entry.Value -PassThru:$PassThru -EnableException:$EnableException
			}
		}
		#endregion Environment
	}
}

function Register-PSFConfig
{
<#
	.SYNOPSIS
		Registers an existing configuration object in registry.
	
	.DESCRIPTION
		Registers an existing configuration object in registry.
		This allows simple persisting of settings across powershell consoles.
		It also can be used to generate a registry template, which can then be used to create policies.
	
	.PARAMETER Config
		The configuration object to write to registry.
		Can be retrieved using Get-PSFConfig.
	
	.PARAMETER FullName
		The full name of the setting to be written to registry.
	
	.PARAMETER Module
		The name of the module, whose settings should be written to registry.
	
	.PARAMETER Name
		Default: "*"
		Used in conjunction with the -Module parameter to restrict the number of configuration items written to registry.
	
	.PARAMETER Scope
		Default: UserDefault
		Who will be affected by this export how? Current user or all? Default setting or enforced?
		Legal values: UserDefault, UserMandatory, SystemDefault, SystemMandatory
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Get-PSFConfig psframework.message.* | Register-PSFConfig
	
		Retrieves all configuration items that that start with psframework.message. and registers them in registry for the current user.
	
	.EXAMPLE
		PS C:\> Register-PSFConfig -FullName "psframework.developer.mode.enable" -Scope SystemDefault
	
		Retrieves the configuration item "psframework.developer.mode.enable" and registers it in registry as the default setting for all users on this machine.
	
	.EXAMPLE
		PS C:\> Register-PSFConfig -Module MyModule -Scope SystemMandatory
	
		Retrieves all configuration items of the module MyModule, then registers them in registry to enforce them for all users on the current system.
#>
	[CmdletBinding(DefaultParameterSetName = "Default", HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFConfig')]
	param (
		[Parameter(ParameterSetName = "Default", Position = 0, ValueFromPipeline = $true)]
		[PSFramework.Configuration.Config[]]
		$Config,
		
		[Parameter(ParameterSetName = "Default", Position = 0, ValueFromPipeline = $true)]
		[string[]]
		$FullName,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Name", Position = 0)]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = "Name", Position = 1)]
		[string]
		$Name = "*",
		
		[PSFramework.Configuration.ConfigScope]
		$Scope = "UserDefault",
		
		[switch]
		$EnableException
	)
	
	begin
	{
		if ($script:NoRegistry -and ($Scope -band 10))
		{
			Stop-PSFFunction -String 'Register-PSFConfig.NoRegistry' -Tag 'NotSupported' -Category ResourceUnavailable
			return
		}
		
		# Linux and MAC default to local user store file
		if ($script:NoRegistry -and ($Scope -eq "UserDefault"))
		{
			$Scope = [PSFramework.Configuration.ConfigScope]::FileUserLocal
		}
		# Linux and MAC get redirection for SystemDefault to FileSystem
		if ($script:NoRegistry -and ($Scope -eq "SystemDefault"))
		{
			$Scope = [PSFramework.Configuration.ConfigScope]::FileSystem
		}
		
		function Write-Config
		{
			[CmdletBinding()]
			param (
				[PSFramework.Configuration.Config]
				$Config,
				
				[PSFramework.Configuration.ConfigScope]
				$Scope,
				
				[bool]
				$EnableException,
				
				[string]
				$FunctionName = (Get-PSCallStack)[0].Command
			)
			
			if (-not $Config -or ($Config.RegistryData -eq "<type not supported>"))
			{
				Stop-PSFFunction -String 'Register-PSFConfig.Type.NotSupported' -StringValues $Config.FullName -EnableException $EnableException -Category InvalidArgument -Tag "config", "fail" -Target $Config -FunctionName $FunctionName -ModuleName "PSFramework"
				return
			}
			
			try
			{
				Write-PSFMessage -Level Verbose -String 'Register-PSFConfig.Registering' -StringValues $Config.FullName, $Scope -Tag "Config" -Target $Config -FunctionName $FunctionName -ModuleName "PSFramework"
				#region User Default
				if (1 -band $Scope)
				{
					Ensure-RegistryPath -Path $script:path_RegistryUserDefault -ErrorAction Stop
					Set-ItemProperty -Path $script:path_RegistryUserDefault -Name $Config.FullName -Value $Config.RegistryData -ErrorAction Stop
				}
				#endregion User Default
				
				#region User Mandatory
				if (2 -band $Scope)
				{
					Ensure-RegistryPath -Path $script:path_RegistryUserEnforced -ErrorAction Stop
					Set-ItemProperty -Path $script:path_RegistryUserEnforced -Name $Config.FullName -Value $Config.RegistryData -ErrorAction Stop
				}
				#endregion User Mandatory
				
				#region System Default
				if (4 -band $Scope)
				{
					Ensure-RegistryPath -Path $script:path_RegistryMachineDefault -ErrorAction Stop
					Set-ItemProperty -Path $script:path_RegistryMachineDefault -Name $Config.FullName -Value $Config.RegistryData -ErrorAction Stop
				}
				#endregion System Default
				
				#region System Mandatory
				if (8 -band $Scope)
				{
					Ensure-RegistryPath -Path $script:path_RegistryMachineEnforced -ErrorAction Stop
					Set-ItemProperty -Path $script:path_RegistryMachineEnforced -Name $Config.FullName -Value $Config.RegistryData -ErrorAction Stop
				}
				#endregion System Mandatory
			}
			catch
			{
				Stop-PSFFunction -String 'Register-PSFConfig.Registering.Failed' -StringValues $Config.FullName, $Scope -EnableException $EnableException -Tag "config", "fail" -Target $Config -ErrorRecord $_ -FunctionName $FunctionName -ModuleName "PSFramework"
				return
			}
		}
		
		function Ensure-RegistryPath
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
			[CmdletBinding()]
			param (
				[string]
				$Path
			)
			
			if (-not (Test-Path $Path))
			{
				$null = New-Item $Path -Force
			}
		}
		
		# For file based persistence
		$fileConfigurationItems = @()
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		#region Registry Based
		if ($Scope -band 15)
		{
			switch ($PSCmdlet.ParameterSetName)
			{
				"Default"
				{
					foreach ($item in $Config)
					{
						Write-Config -Config $item -Scope $Scope -EnableException $EnableException
					}
					
					foreach ($item in $FullName)
					{
						if ([PSFramework.Configuration.ConfigurationHost]::Configurations.ContainsKey($item))
						{
							Write-Config -Config ([PSFramework.Configuration.ConfigurationHost]::Configurations[$item]) -Scope $Scope -EnableException $EnableException
						}
					}
				}
				"Name"
				{
					foreach ($item in ([PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object Module -EQ $Module | Where-Object Name -Like $Name))
					{
						Write-Config -Config $item -Scope $Scope -EnableException $EnableException
					}
				}
			}
		}
		#endregion Registry Based
		
		#region File Based
		else
		{
			switch ($PSCmdlet.ParameterSetName)
			{
				"Default"
				{
					foreach ($item in $Config)
					{
						if ($fileConfigurationItems.FullName -notcontains $item.FullName) { $fileConfigurationItems += $item }
					}
					
					foreach ($item in $FullName)
					{
						if (($fileConfigurationItems.FullName -notcontains $item) -and ([PSFramework.Configuration.ConfigurationHost]::Configurations.ContainsKey($item)))
						{
							$fileConfigurationItems += [PSFramework.Configuration.ConfigurationHost]::Configurations[$item]
						}
					}
				}
				"Name"
				{
					foreach ($item in ([PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object Module -EQ $Module | Where-Object Name -Like $Name))
					{
						if ($fileConfigurationItems.FullName -notcontains $item.FullName) { $fileConfigurationItems += $item }
					}
				}
			}
		}
		#endregion File Based
	}
	end
	{
		#region Finish File Based Persistence
		if ($Scope -band 16)
		{
			Write-PsfConfigFile -Config $fileConfigurationItems -Path (Join-Path $script:path_FileUserLocal "psf_config.json")
		}
		if ($Scope -band 32)
		{
			Write-PsfConfigFile -Config $fileConfigurationItems -Path (Join-Path $script:path_FileUserShared "psf_config.json")
		}
		if ($Scope -band 64)
		{
			Write-PsfConfigFile -Config $fileConfigurationItems -Path (Join-Path $script:path_FileSystem "psf_config.json")
		}
		#endregion Finish File Based Persistence
	}
}

function Register-PSFConfigSchema
{
<#
	.SYNOPSIS
		Register new schemas for ingersting configuration data.
	
	.DESCRIPTION
		Register new schemas for ingersting configuration data.
		This can be used to dynamically extend the configuration system and add new file types as supported input.
	
	.PARAMETER Name
		The name of the Schema to register.
	
	.PARAMETER Schema
		The Schema Code to register.
	
	.EXAMPLE
		PS C:\> Register-PSFConfigSchema -Name Default -Schema $scriptblock
	
		Registers the scriptblock stored in $scriptblock under 'Default'
#>
	[CmdletBinding()]
	Param (
		[string]
		$Name,
		
		[ScriptBlock]
		$Schema
	)
	
	process
	{
		[PSFramework.Configuration.ConfigurationHost]::Schemata[$Name] = $Schema
	}
}

function Register-PSFConfigValidation
{
	<#
		.SYNOPSIS
			Registers a validation scriptblock for use with the configuration system.
		
		.DESCRIPTION
			Registers a validation scriptblock for use with the configuration system.
	
			The scriptblock must be designed according to a few guidelines:
			- It must not throw exceptions
			- It must accept a single parameter (the value to be tested)
			- It must return an object with two properties: 'Message', 'Value' and 'Success'.
			The Success property should be boolean and indicate whether the value is valid.
			The Value property contains the validated input. The scriptblock may legally convert the input (For example from string to int in case of integer validation)
			The message contains a string that will be passed along to an exception in case the input is NOT valid.
		
		.PARAMETER Name
			The name under which to register the validation scriptblock
		
		.PARAMETER ScriptBlock
			The scriptblock to register
		
		.EXAMPLE
			PS C:\> Register-PSFConfigValidation -Name IntPositive -ScriptBlock $scriptblock
	
			Registers the scriptblock stored in $scriptblock as validation with the name IntPositive
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFConfigValidation')]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[ScriptBlock]
		$ScriptBlock
	)
	process
	{
		[PSFramework.Configuration.ConfigurationHost]::Validation[$Name] = $ScriptBlock
	}
}

function Remove-PSFConfig
{
<#
	.SYNOPSIS
		Removes configuration items from memory.
	
	.DESCRIPTION
		This command removes configuration items from memory.
		However, not all settings can just be deleted!
		A configuration item must be flagged as deletable.
		This can be done using Set-PSFConfig -AllowDelete or Import-PSFConfig -AllowDelete.
		Certain schema versions of configuration json may also support defining this in the file.
	
		Limitations to flagging configuration as deletable:
		> Once a configuration item has been initialized, its deletable status is frozen.
		  The last time it is possible to change the deletable status is during initialization.
		> A setting that has been set as mandated by policy cannot be removed.
	
		Reason for this limit:
		The configuration system is designed for multiple scenarios.
		Deleting settings makes sense in some, while in others it is actually detrimental.
		Initialization is especially designed for the module scenario, where the module's configuration is its options menu.
		In this scenario, having a user deleting settings could lead to broken execution and unintended code paths, that might be at odds with policies defined.
	
	.PARAMETER Config
		The configuration object to remove from memory.
		Can be retrieved using Get-PSFConfig.
	
	.PARAMETER FullName
		The full name of the setting to be removed from memory.
	
	.PARAMETER Module
		The name of the module, whose settings should be removed from memory.
	
	.PARAMETER Name
		Default: "*"
		Used in conjunction with the -Module parameter to restrict the number of configuration items deleted from memory.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Remove-PSFConfig -FullName 'Phase1.Step1.Server' -Confirm:$false
	
		Deletes the setting 'Phase1.Step1.Server' from memory, assuming it exists and supports deletion.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	param (
		[Parameter(ParameterSetName = "Default", Position = 0, ValueFromPipeline = $true)]
		[PSFramework.Configuration.Config[]]
		$Config,
		
		[Parameter(ParameterSetName = "Default", Position = 0, ValueFromPipeline = $true)]
		[string[]]
		$FullName,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Name", Position = 0)]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = "Name", Position = 1)]
		[string]
		$Name = "*"
	)
	
	process
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			"Default"
			{
				#region Try removing all items specified
				foreach ($item in $Config)
				{
					if (-not (Test-PSFShouldProcess -ActionString 'PSFramework.Configuration.Remove-PSFConfig.ShouldRemove' -Target $item.FullName)) { continue }
					try { $result = [PSFramework.Configuration.ConfigurationHost]::DeleteConfiguration($item.FullName) }
					catch { Stop-PSFFunction -String Configuration.Remove-PSFConfig.InvalidConfiguration -StringValues $item.FullName -EnableException ($ErrorActionPreference -eq 'Stop') -Continue -Cmdlet $PSCmdlet -ErrorRecord $_ }
					
					if ($result) { Write-PSFMessage -Level InternalComment -String Configuration.Remove-PSFConfig.DeleteSuccessful -StringValues $item.FullName }
					else { Write-PSFMessage -Level Warning -String Configuration.Remove-PSFConfig.DeleteFailed -StringValues $item.FullName, $item.AllowDelete, $item.PolicyEnforced }
				}
				# Since configuration items will also bind to string, if any were included, break the switch
				if (Test-PSFParameterBinding -ParameterName Config) { break }
				#endregion Try removing all items specified
				
				#region Try removing all full names specified
				foreach ($nameItem in $FullName)
				{
					if (-not (Test-PSFShouldProcess -ActionString 'PSFramework.Configuration.Remove-PSFConfig.ShouldRemove' -Target $nameItem)) { continue }
					$item = Get-PSFConfig -FullName $nameItem
					
					try { $result = [PSFramework.Configuration.ConfigurationHost]::DeleteConfiguration($nameItem) }
					catch { Stop-PSFFunction -String Configuration.Remove-PSFConfig.InvalidConfiguration -StringValues $nameItem -EnableException ($ErrorActionPreference -eq 'Stop') -Continue -Cmdlet $PSCmdlet -ErrorRecord $_ }
					
					
					if ($result) { Write-PSFMessage -Level InternalComment -String Configuration.Remove-PSFConfig.DeleteSuccessful -StringValues $item.FullName }
					else { Write-PSFMessage -Level Warning -String Configuration.Remove-PSFConfig.DeleteFailed -StringValues $item.FullName, $item.AllowDelete, $item.PolicyEnforced }
				}
				#endregion Try removing all full names specified
			}
			"Name"
			{
				#region Try removing by filter
				foreach ($item in (Get-PSFConfig -Module $Module -Name $Name))
				{
					if (-not (Test-PSFShouldProcess -ActionString 'PSFramework.Configuration.Remove-PSFConfig.ShouldRemove' -Target $item.FullName)) { continue }
					
					try { $result = [PSFramework.Configuration.ConfigurationHost]::DeleteConfiguration($item.FullName) }
					catch { Stop-PSFFunction -String Configuration.Remove-PSFConfig.InvalidConfiguration -StringValues $item.FullName -EnableException ($ErrorActionPreference -eq 'Stop') -Continue -Cmdlet $PSCmdlet -ErrorRecord $_ }
					
					if ($result) { Write-PSFMessage -Level InternalComment -String Configuration.Remove-PSFConfig.DeleteSuccessful -StringValues $item.FullName }
					else { Write-PSFMessage -Level Warning -String Configuration.Remove-PSFConfig.DeleteFailed -StringValues $item.FullName, $item.AllowDelete, $item.PolicyEnforced }
				}
				#endregion Try removing by filter
			}
		}
	}
}

function Reset-PSFConfig
{
<#
	.SYNOPSIS
		Reverts a configuration item to its default value.
	
	.DESCRIPTION
		This command can be used to revert a configuration item to the value it was initialized with.
		Generally, this amounts to reverting it to its default value.
		
		In order for a reset to be possible, two conditions must be met:
		- The setting must have been initialized.
		- The setting cannot have been enforced by policy.
	
	.PARAMETER ConfigurationItem
		A configuration object as returned by Get-PSFConfig.
	
	.PARAMETER FullName
		The full name of the setting to reset, offering the maximum of precision.
	
	.PARAMETER Module
		The name of the module, from which configurations should be reset.
		Used in conjunction with the -Name parameter to filter a specific set of items.
	
	.PARAMETER Name
		Used in conjunction with the -Module parameter to select which settings to reset using wildcard comparison.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Reset-PSFConfig -Module MyModule
	
		Resets all configuration items of the MyModule to default.
	
	.EXAMPLE
		PS C:\> Get-PSFConfig | Reset-PSFConfig
	
		Resets ALL configuration items to default.
	
	.EXAMPLE
		PS C:\> Reset-PSFConfig -FullName MyModule.Group.Setting1
	
		Resets the configuration item named 'MyModule.Group.Setting1'.
#>
	[CmdletBinding(DefaultParameterSetName = 'Pipeline', SupportsShouldProcess = $true, ConfirmImpact = 'Low', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Reset-PSFConfig')]
	param (
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
		[PSFramework.Configuration.Config[]]
		$ConfigurationItem,
		
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
		[string[]]
		$FullName,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Module')]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = 'Module')]
		[string]
		$Name = "*",
		
		[switch]
		$EnableException
	)
	
	process
	{
		#region By configuration Item
		foreach ($item in $ConfigurationItem)
		{
			if (Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $item.FullName -ActionString 'Reset-PSFConfig.Resetting')
			{
				try { $item.ResetValue() }
				catch { Stop-PSFFunction -String 'Reset-PSFConfig.Resetting.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue -EnableException $EnableException }
			}
		}
		#endregion By configuration Item
		
		#region By FullName
		foreach ($nameItem in $FullName)
		{
			# The configuration items themselves can be cast to string, so they need to be filtered out,
			# otherwise on bind they would execute for this code-path as well.
			if ($nameItem -ceq "PSFramework.Configuration.Config") { continue }
			
			foreach ($item in (Get-PSFConfig -FullName $nameItem))
			{
				if (Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $item.FullName -ActionString 'Reset-PSFConfig.Resetting')
				{
					try { $item.ResetValue() }
					catch { Stop-PSFFunction -String 'Reset-PSFConfig.Resetting.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue -EnableException $EnableException}
				}
			}
		}
		#endregion By FullName
		if ($Module)
		{
			foreach ($item in (Get-PSFConfig -Module $Module -Name $Name))
			{
				if (Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $item.FullName -ActionString 'Reset-PSFConfig.Resetting')
				{
					try { $item.ResetValue() }
					catch { Stop-PSFFunction -String 'Reset-PSFConfig.Resetting.Failed' -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $EnableException -Continue }
				}
			}
		}
	}
}

function Select-PSFConfig
{
<#
	.SYNOPSIS
		Select a subset of configuration entries and return them as objects.
	
	.DESCRIPTION
		Select a subset of configuration entries and return them as objects.
		
		This can be used to retrieve related configuration entries as a single PowerShell object.
		
		For example, assuming there are the following configuration entries:
		
		LoggingProvider.LogFile.AutoInstall
		LoggingProvider.LogFile.Enabled
		LoggingProvider.LogFile.ExcludeModules
		LoggingProvider.LogFile.ExcludeTags
		LoggingProvider.LogFile.IncludeModules
		LoggingProvider.LogFile.IncludeTags
		LoggingProvider.LogFile.InstallOptional
		
		Then this line:
		Select-PSFConfig 'LoggingProvider.LogFile.*'
		
		Will return a PSCustomObject that looks similar to this:
		
		_Name           : LogFile
		_FullName       : LoggingProvider.LogFile
		_Depth          : 1
		_Children       : {}
		AutoInstall     : False
		Enabled         : False
		ExcludeModules  : {}
		ExcludeTags     : {}
		IncludeModules  : {}
		IncludeTags     : {}
		InstallOptional : True
		
		This selection is recursive:
		It will group on each part of the FullName of the selected configuration entries.
		- Entries that only have children and no straight values (In the example above, that would be the first, the "LoggingProvider" node) will not be included and only return children.
		- Entries with values AND children, will have child entries included in the _Children property.
		- Even child entries of Entries with values will be returned
	
	.PARAMETER FullName
		String filter to select, which configuration entries to select on.
		Use the same value on Get-PSFConfig to see what configuration entries will be processed.
	
	.PARAMETER Depth
		Only entries at the specified depth level will be returned.
		Depth starts at "0"
		In the name 'LoggingProvider.LogFile.AutoInstall' ...
	
		- "LoggingProvider" would be depth 0
		- "LogFile" would be depth 1
		- ...
	
	.EXAMPLE
		PS C:\> Select-PSFConfig 'LoggingProvider.LogFile.*'
	
		Selects all configuration settings under 'LoggingProvider.LogFile.*', grouping the value ends as PSObject.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding()]
	param (
		[Alias('Name')]
		[string]
		$FullName,
		
		[int[]]
		$Depth
	)
	
	begin
	{
		function Group-Config
		{
			[CmdletBinding()]
			param (
				$Config,
				
				[int]
				$Depth
			)
			
			$grouped = $Config | Group-Object { $_.FullName.Split('.')[$Depth] }
			foreach ($group in $grouped)
			{
				if (-not $group.Name) { continue }
				$data = [ordered]@{
					_Name = $group.Name
					_FullName = $group.Group[0].FullName.Split('.')[0..($Depth)] -join "."
					_Depth = $Depth
					_Children = @()
				}
				if ($subGroups = $group.Group | Where-Object { $_.FullName.Split(".").Count -gt ($Depth + 2) })
				{
					$data._Children = Group-Config -Config $subGroups -Depth ($Depth + 1)
					$data._Children
				}
				
				foreach ($cfgItem in ($group.Group | Where-Object { $_.FullName.Split(".").Count -eq ($Depth + 2) }))
				{
					$cfgName = $cfgItem.FullName -replace "^([^\.]+\.){0,$($Depth + 1)}"
					$data[$cfgName] = $cfgItem.Value
				}
				if ($data.Keys.Count -gt 4) { [PSCustomObject]$data }
			}
		}
	}
	process
	{
		$configItems = Get-PSFConfig -FullName $FullName
		Group-Config -Config $configItems -Depth 0 | ForEach-Object {
			if (-not $Depth) { return $_ }
			if ($_._Depth -in $Depth) { $_ }
		}
	}
}

function Unregister-PSFConfig
{
<#
	.SYNOPSIS
		Removes registered configuration settings.
	
	.DESCRIPTION
		Removes registered configuration settings.
		This function can be used to remove settings that have been persisted for either user or computer.
	
		Note: This command has no effect on configuration setings currently in memory.
	
	.PARAMETER ConfigurationItem
		A configuration object as returned by Get-PSFConfig.
	
	.PARAMETER FullName
		The full name of the configuration setting to purge.
	
	.PARAMETER Module
		The module, amongst which settings should be unregistered.
	
	.PARAMETER Name
		The name of the setting to unregister.
		For use together with the module parameter, to limit the amount of settings that are unregistered.
	
	.PARAMETER Scope
		Settings can be set to either default or enforced, for user or the entire computer.
		By default, only DefaultSettings for the user are unregistered.
		Use this parameter to choose the actual scope for the command to process.
	
	.EXAMPLE
		PS C:\> Get-PSFConfig | Unregister-PSFConfig
	
		Completely removes all registered configurations currently loaded in memory.
		In most cases, this will mean removing all registered configurations.
	
	.EXAMPLE
		PS C:\> Unregister-PSFConfig -Scope SystemDefault -FullName 'MyModule.Path.DefaultExport'
	
		Unregisters the setting 'MyModule.Path.DefaultExport' from the list of computer-wide defaults.
		Note: Changing system wide settings requires running the console with elevation.
	
	.EXAMPLE
		PS C:\> Unregister-PSFConfig -Module MyModule
	
		Unregisters all configuration settings for the module MyModule.
#>
	[CmdletBinding(DefaultParameterSetName = 'Pipeline', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Unregister-PSFConfig')]
	param (
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
		[PSFramework.Configuration.Config[]]
		$ConfigurationItem,
		
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
		[string[]]
		$FullName,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Module')]
		[string]
		$Module,
		
		[Parameter(ParameterSetName = 'Module')]
		[string]
		$Name = "*",
		
		[PSFramework.Configuration.ConfigScope]
		$Scope = "UserDefault"
	)
	
	begin
	{
		if ($script:NoRegistry -and ($Scope -band 10))
		{
			Stop-PSFFunction -String 'Unregister-PSFConfig.NoRegistry' -Tag 'NotSupported' -Category ResourceUnavailable
			return
		}
		
		# Linux and MAC default to local user store file
		if ($script:NoRegistry -and ($Scope -eq "UserDefault"))
		{
			$Scope = [PSFramework.Configuration.ConfigScope]::FileUserLocal
		}
		# Linux and MAC get redirection for SystemDefault to FileSystem
		if ($script:NoRegistry -and ($Scope -eq "SystemDefault"))
		{
			$Scope = [PSFramework.Configuration.ConfigScope]::FileSystem
		}
		
		#region Initialize Collection
		$registryProperties = @()
		if ($Scope -band 1)
		{
			if (Test-Path $script:path_RegistryUserDefault) { $registryProperties += Get-ItemProperty -Path $script:path_RegistryUserDefault }
		}
		if ($Scope -band 2)
		{
			if (Test-Path $script:path_RegistryUserEnforced) { $registryProperties += Get-ItemProperty -Path $script:path_RegistryUserEnforced }
		}
		if ($Scope -band 4)
		{
			if (Test-Path $script:path_RegistryMachineDefault) { $registryProperties += Get-ItemProperty -Path $script:path_RegistryMachineDefault }
		}
		if ($Scope -band 8)
		{
			if (Test-Path $script:path_RegistryMachineEnforced) { $registryProperties += Get-ItemProperty -Path $script:path_RegistryMachineEnforced }
		}
		$pathProperties = @()
		if ($Scope -band 16)
		{
			$fileUserLocalSettings = @()
			if (Test-Path (Join-Path $script:path_FileUserLocal "psf_config.json")) { $fileUserLocalSettings = Get-Content (Join-Path $script:path_FileUserLocal "psf_config.json") -Encoding UTF8 | ConvertFrom-Json }
			if ($fileUserLocalSettings)
			{
				$pathProperties += [pscustomobject]@{
					Path	   = (Join-Path $script:path_FileUserLocal "psf_config.json")
					Properties = $fileUserLocalSettings
					Changed    = $false
				}
			}
		}
		if ($Scope -band 32)
		{
			$fileUserSharedSettings = @()
			if (Test-Path (Join-Path $script:path_FileUserShared "psf_config.json")) { $fileUserSharedSettings = Get-Content (Join-Path $script:path_FileUserShared "psf_config.json") -Encoding UTF8 | ConvertFrom-Json }
			if ($fileUserSharedSettings)
			{
				$pathProperties += [pscustomobject]@{
					Path	   = (Join-Path $script:path_FileUserShared "psf_config.json")
					Properties = $fileUserSharedSettings
					Changed    = $false
				}
			}
		}
		if ($Scope -band 64)
		{
			$fileSystemSettings = @()
			if (Test-Path (Join-Path $script:path_FileSystem "psf_config.json")) { $fileSystemSettings = Get-Content (Join-Path $script:path_FileSystem "psf_config.json") -Encoding UTF8 | ConvertFrom-Json }
			if ($fileSystemSettings)
			{
				$pathProperties += [pscustomobject]@{
					Path	   = (Join-Path $script:path_FileSystem "psf_config.json")
					Properties = $fileSystemSettings
					Changed    = $false
				}
			}
		}
		#endregion Initialize Collection
		
		$common = 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider'
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		# Silently skip since no action necessary
		if (-not ($pathProperties -or $registryProperties)) { return }
		
		foreach ($item in $ConfigurationItem)
		{
			# Registry
			foreach ($hive in ($registryProperties | Where-Object { $_.PSObject.Properties.Name -eq $item.FullName }))
			{
				Remove-ItemProperty -Path $hive.PSPath -Name $item.FullName
			}
			# Prepare file
			foreach ($fileConfig in ($pathProperties | Where-Object { $_.Properties.FullName -contains $item.FullName }))
			{
				$fileConfig.Properties = $fileConfig.Properties | Where-Object FullName -NE $item.FullName
				$fileConfig.Changed = $true
			}
		}
		
		foreach ($item in $FullName)
		{
			# Ignore string-casted configurations
			if ($item -ceq "PSFramework.Configuration.Config") { continue }
			
			# Registry
			foreach ($hive in ($registryProperties | Where-Object { $_.PSObject.Properties.Name -eq $item }))
			{
				Remove-ItemProperty -Path $hive.PSPath -Name $item
			}
			# Prepare file
			foreach ($fileConfig in ($pathProperties | Where-Object { $_.Properties.FullName -contains $item }))
			{
				$fileConfig.Properties = $fileConfig.Properties | Where-Object FullName -NE $item
				$fileConfig.Changed = $true
			}
		}
		
		if ($Module)
		{
			$compoundName = "{0}.{1}" -f $Module, $Name
			
			# Registry
			foreach ($hive in ($registryProperties | Where-Object { $_.PSObject.Properties.Name -like $compoundName }))
			{
				foreach ($propName in $hive.PSObject.Properties.Name)
				{
					if ($propName -in $common) { continue }
					
					if ($propName -like $compoundName)
					{
						Remove-ItemProperty -Path $hive.PSPath -Name $propName
					}
				}
			}
			# Prepare file
			foreach ($fileConfig in ($pathProperties | Where-Object { $_.Properties.FullName -like $compoundName }))
			{
				$fileConfig.Properties = $fileConfig.Properties | Where-Object FullName -NotLike $compoundName
				$fileConfig.Changed = $true
			}
		}
	}
	end
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		foreach ($fileConfig in $pathProperties)
		{
			if (-not $fileConfig.Changed) { continue }
			
			if ($fileConfig.Properties)
			{
				$fileConfig.Properties | ConvertTo-Json | Set-Content -Path $fileConfig.Path -Encoding UTF8
			}
			else
			{
				Remove-Item $fileConfig.Path
			}
		}
	}
}


function Get-PSFFeature
{
<#
	.SYNOPSIS
		Returns a list of all registered features.
	
	.DESCRIPTION
		Returns a list of all registered features.
	
	.PARAMETER Name
		The name to filter by.
	
	.EXAMPLE
		PS C:\> Get-PSFFeature
	
		Returns all features registered.
#>
	[CmdletBinding()]
	param (
		[string]
		$Name = "*"
	)
	
	process
	{
		[PSFramework.Feature.FeatureHost]::Features.Values | Where-Object Name -Like $Name
	}
}

function Register-PSFFeature
{
<#
	.SYNOPSIS
		Registers a feature for use in the PSFramework Feature Flag System.
	
	.DESCRIPTION
		Registers a feature for use in the PSFramework Feature Flag System.
		This allows offering a common interface for enabling and disabling features on-demand.
		Typical use-cases:
		- Experimental Features
		- Reverting breaking behavior on a per-module basis.
	
	.PARAMETER Name
		The name of the feature to register.
		Feature names are scoped globally, so please prefix by your own module's name.
	
	.PARAMETER Description
		A description of the feature, so users can discover what it is about.
	
	.PARAMETER NotGlobal
		Disables global flags for this feature.
		By default, features can be enabled or disabled on a global scope.
	
	.PARAMETER NotModuleSpecific
		Disables module specific feature flags.
		By default, individual modules can override the global settings either way.
		This may not really be applicable for all features however.
	
	.PARAMETER Owner
		The name of the module owning the feature.
		Autodiscovery is attempted, but it is recommended to explicitly specify the owning module's name.
	
	.EXAMPLE
		PS C:\> Register-PSFFeature -Name 'MyModule.DividebyZeroExp' -Description 'Attempt to divide by zero' -Owner MyModule
	
		Registers the feature under its owning module and adds a nice description.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$Description,
		
		[switch]
		$NotGlobal,
		
		[switch]
		$NotModuleSpecific,
		
		[string]
		$Owner = (Get-PSCallStack)[1].InvocationInfo.MyCommand.ModuleName
	)
	
	begin
	{
		$featureObject = New-Object PSFramework.Feature.FeatureItem -Property @{
			Name = $Name
			Owner = $Owner
			Global = (-not $NotGlobal)
			ModuleSpecific = (-not $NotModuleSpecific)
			Description = $Description
		}
	}
	process
	{
		[PSFramework.Feature.FeatureHost]::Features[$Name] = $featureObject
	}
}

function Set-PSFFeature
{
<#
	.SYNOPSIS
		Toggles a feature on or off.
	
	.DESCRIPTION
		Toggles a feature on or off.
		This controls the flags for optional features a module might offer.
	
		Features can be controlled globally or specific to a module that tries to consume it.
		Module specific settings can override global settings, if a feature supports both global and module flags.
	
	.PARAMETER Name
		The name of the feature to set.
	
	.PARAMETER Value
		The value to set it to.
	
	.PARAMETER ModuleName
		The module it should apply to.
		Specifying this parameter sets the flag only for the module specified.
	
	.EXAMPLE
		PS C:\> Set-PSFFeature -Name 'PSFramework.InheritEnableException' -Value $true -ModuleName SPReplicator
	
		This sets the flag for the Enable Exception Inheritance Name to $true, but only applies to the module SPReplicator.
	
	.EXAMPLE
		PS C:\> Set-PSFFeature -Name 'MyModule.Feierabend' -Value $true
	
		This enables the global flag for the MyModule.Feierabend feature.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[PsfValidateSet(TabCompletion = 'PSFramework.Feature.Name')]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[bool]
		$Value,
		
		[string]
		$ModuleName
	)
	process
	{
		foreach ($featureItem in $Name)
		{
			if ($ModuleName)
			{
				[PSFramework.Feature.FeatureHost]::WriteModuleFlag($ModuleName, $Name, $Value)
			}
			else
			{
				[PSFramework.Feature.FeatureHost]::WriteGlobalFlag($Name, $Value)
			}
		}
	}
}

function Test-PSFFeature
{
<#
	.SYNOPSIS
		Tests whether a given feature has been enabled.
	
	.DESCRIPTION
		Tests whether a given feature has been enabled.
		Use this within the feature-owning module to determine, whether a feature should be enabled or not.
	
	.PARAMETER Name
		The feature to test for.
	
	.PARAMETER ModuleName
		The name of the module that seeks to use the feature.
		Must be specified in order to determine module-specific flags.
	
	.EXAMPLE
		PS C:\> Test-PSFFeature -Name PSFramework.InheritEnableException -ModuleName SPReplicator
	
		Tests whether the module SPReplicator has enabled the Enable Exception Inheritance feature.
#>
	[OutputType([bool])]
	[CmdletBinding()]
	param (
		[PsfValidateSet(TabCompletion = 'PSFramework.Feature.Name')]
		[parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$ModuleName
	)
	
	begin
	{
		$featureItem = Get-PSFFeature -Name $Name
	}
	process
	{
		if (-not $featureItem.Global) { [PSFramework.Feature.FeatureHost]::ReadModuleFlag($Name, $ModuleName) }
		else { [PSFramework.Feature.FeatureHost]::ReadFlag($Name, $ModuleName) }
	}
}

function Get-PSFCallback
{
<#
	.SYNOPSIS
		Returns a list of callback scripts.
	
	.DESCRIPTION
		Returns a list of callback scripts.
		Use Register-PSFCallback to register new callback scripts.
		Use Unregister-PSFCallback to remove callback scripts.
		Use Invoke-PSFCallback within a function of your module to execute all registered callback scripts that apply.
	
	.PARAMETER Name
		The name to filter by.
	
	.PARAMETER All
		Return all callback scripts, even those specific to other runspaces.
	
	.EXAMPLE
		PS C:\> Get-PSFCallback
	
		Returns all callback scripts relevant to the current runspace.
	
	.EXAMPLE
		PS C:\> Get-PSFCallback -All
	
		Returns all callback scripts in the entire process.
	
	.EXAMPLE
		PS C:\> Get-PSFCallback -Name MyModule.Configuration
	
		Returns the callback script named 'MyModule.Configuration'
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
	[OutputType([PSFramework.FlowControl.Callback])]
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string[]]
		$Name = '*',
		
		[switch]
		$All
	)
	
	process
	{
		foreach ($nameString in $Name)
		{
			[PSFramework.FlowControl.CallbackHost]::Get($nameString, $All.ToBool())
		}
	}
}

function Get-PSFUserChoice
{
<#
	.SYNOPSIS
		Prompts the user to choose between a set of options.
	
	.DESCRIPTION
		Prompts the user to choose between a set of options.
		Returns the index of the choice picked as a number.
	
	.PARAMETER Options
		The options the user may pick from.
		The user selects a choice by specifying the letter associated with a choice.
		The letter assigned to a choice is picked from the character after the first '&' in any specified string.
		If there is no '&', the system will automatically pick the first letter as choice letter:
		"This &is an example" will have the character "i" bound for the choice.
		"This is &an example" will have the character "a" bound for the choice.
		"This is an example" will have the character "T" bound for the choice.
	
		This parameter takes both strings and hashtables (in any combination).
		A hashtable is expected to have two properties, 'Label' and 'Help'.
		Label is the text shown in the initial prompt, help what the user sees when requesting help.
	
	.PARAMETER Caption
		The title of the question, so the user knows what it is all about.
	
	.PARAMETER Message
		A message to offer to the user. Be more specific about the implications of this choice.
	
	.PARAMETER DefaultChoice
		The index of the choice made by default.
		By default, the first option is selected as default choice.
	
	.EXAMPLE
		PS C:\> Get-PSFUserChoice -Options "1) Create a new user", "2) Disable a user", "3) Unlock an account", "4) Get a cup of coffee", "5) Exit" -Caption "User administration menu" -Message "What operation do you want to perform?"
	
		Prompts the user for what operation to perform from the set of options provided
#>
	[OutputType([System.Int32])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object[]]
		$Options,
		
		[string]
		$Caption,
		
		[string]
		$Message,
		
		[int]
		$DefaultChoice = 0
	)
	
	begin
	{
		$choices = @()
		foreach ($option in $Options)
		{
			if ($option -is [hashtable])
			{
				$label = $option.Keys -match '^l' | Select-Object -First 1
				[string]$labelValue = $option[$label]
				$help = $option.Keys -match '^h' | Select-Object -First 1
				[string]$helpValue = $option[$help]
				
			}
			else
			{
				$labelValue = "$option"
				$helpValue = "$option"
			}
			if ($labelValue -match "&") { $choices += New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList $labelValue, $helpValue }
			else { $choices += New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList "&$($labelValue.Trim())", $helpValue }
		}
	}
	process
	{
		# Will error on one option so we just return the value 0 (which is the result of the only option the user would have)
		# This is for cases where the developer dynamically assembles options so that they don't need to ensure a minimum of two options.
		if ($Options.Count -eq 1) { return 0 }
		
		$Host.UI.PromptForChoice($Caption, $Message, $choices, $DefaultChoice)
	}
}

function Register-PSFCallback
{
<#
	.SYNOPSIS
		Registers a scriptblock to execute when a command calls Invoke-PSFCallback.
	
	.DESCRIPTION
		Registers a scriptblock to execute when a command calls Invoke-PSFCallback.
		The basic concept of this feature is for a module to offer a registration point,
		where foreign modules - even those unknown to the implementing module - can register
		scriptblocks as delegates. These will then be executed in the implementing module's commands,
		where those call Invoke-PSFCallback.
	
		When designing a callback, keep in mind, that it will be executed on all applicable commmands.
		A major aspect to consider here is the execution time, as this will get added on top of each applicable execution.
	
	.PARAMETER Name
		Name of the callback.
		Must be unique.
	
	.PARAMETER ModuleName
		The name of the module from which Invoke-PSFCallback is being called.
	
	.PARAMETER CommandName
		Name of the command calling Invoke-PSFCallback.
		Allows wildcard matching.
	
	.PARAMETER ScriptBlock
		The scriptblock to execute as callback action.
		This scriptblock will receive a single argument: A hashtable.
		That hashtable will contain the following keys:
		- Command:        Name of the command calling Invoke-PSFCallback
		- ModuleName:     Name of the module the command calling Invoke-PSFCallback is part of.
		- CallerFunction: Name of the command calling the command calling Invoke-PSFCallback
		- CallerModule:   Name of the module of the command calling the command calling Invoke-PSFCallback
		- Data:           Additional data specified by the command calling Invoke-PSFCallback
	
	.PARAMETER Scope
		Whether the callback script is valid in this runspace only (default) or process-wide.
	
	.PARAMETER BreakAffinity
		By default, the callback scriptblock is being executed in the runspace that defined it.
		Setting this parameter, the callback scriptblock is instead being executed in whatever
		runspace it is being triggered from.
	
	.EXAMPLE
		PS C:\> Register-PSFCallback -Name 'MyModule.Configuration' -ModuleName 'DomainManagement' -CommandName '*' -ScriptBlock $ScriptBlock
	
		Defines a callback named 'MyModule.Configuration'.
		This callback scriptblock will be triggered from all commands of the DomainManagement module,
		however only from the current runspace.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$ModuleName,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]
		$CommandName,
		
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[scriptblock]
		$ScriptBlock,
		
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[ValidateSet('CurrentRunspace', 'Process')]
		[string]
		$Scope = 'CurrentRunspace',
		
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[switch]
		$BreakAffinity
	)
	
	process
	{
		$callback = New-Object PSFramework.Flowcontrol.Callback -Property @{
			Name		  = $Name
			ModuleName    = $ModuleName
			CommandName   = $CommandName
			BreakAffinity = $BreakAffinity
			ScriptBlock   = $ScriptBlock
		}
		if ($Scope -eq 'CurrentRunspace') { $callback.Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId }
		[PSFramework.FlowControl.CallbackHost]::Add($callback)
	}
}

function Stop-PSFFunction
{
<#
	.SYNOPSIS
		Function that interrupts a function.
	
	.DESCRIPTION
		Function that interrupts a function.
		
		This function is a utility function used by other functions to reduce error catching overhead.
		It is designed to allow gracefully terminating a function with a warning by default and also allow opt-in into terminating errors.
		It also allows simple integration into loops.
		
		Note:
		When calling this function with the intent to terminate the calling function in non-ExceptionEnabled mode too, you need to add a return below the call.
		
		For a more detailed explanation - including commented full-scale implementation examples - see the associated help article:
		Get-Help about_psf_flowcontrol
	
	.PARAMETER Message
		A message to pass along, explaining just what the error was.
	
	.PARAMETER String
		A stored string to use to write the log.
		Used in combination with the localization component.
		For more details see the help on Import-PSFLocalizedString and Get-PSFLocalizedString.
	
	.PARAMETER StringValues
		Values to format into the localized string referred to in the -String parameter.
	
	.PARAMETER EnableException
		Replaces user friendly yellow warnings with bloody red exceptions of doom!
		Use this if you want the function to throw terminating errors you want to catch.
	
	.PARAMETER Category
		What category does this termination belong to?
		Is automatically set when passing an error record. Helps with differentiating exceptions without having to resort to text parsing.
	
	.PARAMETER ErrorRecord
		An option to include an inner exception in the error record (and in the exception thrown, if one is thrown).
		Use this, whenever you call Stop-PSFFunction in a catch block.
		
		Note:
		Pass the full error record, not just the exception.
	
	.PARAMETER Tag
		Tags to add to the message written.
		This allows filtering and grouping by category of message, targeting specific messages.
	
	.PARAMETER FunctionName
		The name of the function to crash.
		This parameter is very optional, since it automatically selects the name of the calling function.
		The function name is used as part of the errorid.
		That in turn allows easily figuring out, which exception belonged to which function when checking out the $error variable.
	
	.PARAMETER ModuleName
		The name of the module, the function to be crashed is part of.
		This parameter is very optional, since it automatically selects the name of the calling function.
	
	.PARAMETER File
		The file in which Stop-PSFFunction was called.
		Will be automatically set, but can be overridden when necessary.
	
	.PARAMETER Line
		The line on which Stop-PSFFunction was called.
		Will be automatically set, but can be overridden when necessary.
	
	.PARAMETER Exception
		Allows specifying an inner exception as input object. This will be passed on to the logging and used for messages.
		When specifying both ErrorRecord AND Exception, Exception wins, but ErrorRecord is still used for record metadata.
	
	.PARAMETER OverrideExceptionMessage
		Disables automatic appending of exception messages.
		Use in cases where you already have a speaking message interpretation and do not need the original message.
	
	.PARAMETER Target
		The object that was processed when the error was thrown.
		For example, if you were trying to process a Database Server object when the processing failed, add the object here.
		This object will be in the error record (which will be written, even in non-silent mode, just won't show it).
		If you specify such an object, it becomes simple to actually figure out, just where things failed at.
	
	.PARAMETER AlwaysWarning
		Ensures the command always writes a warning, no matter what.
		by default, when -EnableException is set to $true it will hide the warning instead.
		You can enable this to always be on for your module by setting the feature flag: PSFramework.Stop-PSFFunction.ShowWarning
		For more information on feature flags, see "Get-Help Set-PSFFeature -Detailed"
	
	.PARAMETER Continue
		This will cause the function to call continue while not running with exceptions enabled (-EnableException).
		Useful when mass-processing items where an error shouldn't break the loop.
	
	.PARAMETER SilentlyContinue
		This will cause the function to call continue while running with exceptions enabled (-EnableException).
		Useful when mass-processing items where an error shouldn't break the loop.
	
	.PARAMETER ContinueLabel
		When specifying a label in combination with "-Continue" or "-SilentlyContinue", this function will call continue with this specified label.
		Helpful when trying to continue on an upper level named loop.
	
	.PARAMETER Cmdlet
		The $PSCmdlet object of the calling command.
		Used to write exceptions in a more hidden manner, avoiding exposing internal script text in the default message display.
	
	.PARAMETER StepsUpward
		When not throwing an exception and not calling continue, Stop-PSFFunction signals the calling command to stop.
		In some cases you may want to signal a step or more further up the chain (notably from helper functions within a function).
		This parameter allows you to add additional steps up the callstack that it will notify.
	
	.EXAMPLE
		Stop-PSFFunction -Message "Foo failed bar!" -EnableException $EnableException -ErrorRecord $_
		return
		
		Depending on whether $EnableException is true or false it will:
		- Throw a bloody terminating error. Game over.
		- Write a nice warning about how Foo failed bar, then terminate the function. The return on the next line will then end the calling function.
	
	.EXAMPLE
		Stop-PSFFunction -Message "Foo failed bar!" -EnableException $EnableException -Category InvalidOperation -Target $foo -Continue
		
		Depending on whether $EnableException is true or false it will:
		- Throw a bloody terminating error. Game over.
		- Write a nice warning about how Foo failed bar, then call continue to process the next item in the loop.
		In both cases, the error record added to $error will have the content of $foo added, the better to figure out what went wrong.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(DefaultParameterSetName = 'Message', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Stop-PSFFunction')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Message')]
		[string]
		$Message,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'String')]
		[string]
		$String,
		
		[Parameter(ParameterSetName = 'String')]
		[object[]]
		$StringValues,
		
		[bool]
		$EnableException,
		
		[System.Management.Automation.ErrorCategory]
		$Category = ([System.Management.Automation.ErrorCategory]::NotSpecified),
		
		[Alias('InnerErrorRecord')]
		[System.Management.Automation.ErrorRecord[]]
		$ErrorRecord,
		
		[string[]]
		$Tag,
		
		[string]
		$FunctionName,
		
		[string]
		$ModuleName,
		
		[string]
		$File,
		
		[int]
		$Line,
		
		[System.Exception]
		$Exception,
		
		[switch]
		$OverrideExceptionMessage,
		
		[object]
		$Target,
		
		[switch]
		$AlwaysWarning,
		
		[switch]
		$Continue,
		
		[switch]
		$SilentlyContinue,
		
		[string]
		$ContinueLabel,
		
		[System.Management.Automation.PSCmdlet]
		$Cmdlet,
		
		[int]
		$StepsUpward = 0
	)
	
	if ($Cmdlet) { $myCmdlet = $Cmdlet }
	else { $myCmdlet = $PSCmdlet }
	
	#region Initialize information on the calling command
	$callStack = (Get-PSCallStack)[1]
	if (-not $FunctionName) { $FunctionName = $callStack.Command }
	if (-not $FunctionName) { $FunctionName = "<Unknown>" }
	if (-not $ModuleName) { $ModuleName = $callstack.InvocationInfo.MyCommand.ModuleName }
	if (-not $ModuleName) { $ModuleName = "<Unknown>" }
	if (-not $File) { $File = $callStack.Position.File }
	if (-not $Line) { $Line = $callStack.Position.StartLineNumber }
	if ((Test-PSFParameterBinding -ParameterName EnableException -Not) -and (Test-PSFFeature -Name "PSFramework.InheritEnableException" -ModuleName $ModuleName))
	{
		$EnableException = [bool]$PSCmdlet.GetVariableValue('EnableException')
	}
	#endregion Initialize information on the calling command
	
	#region Apply Transforms
	#region Target Transform
	if ($null -ne $Target)
	{
		$Target = Convert-PsfMessageTarget -Target $Target -FunctionName $FunctionName -ModuleName $ModuleName
	}
	#endregion Target Transform
	
	#region Exception Transforms
	if ($Exception)
	{
		$Exception = Convert-PsfMessageException -Exception $Exception -FunctionName $FunctionName -ModuleName $ModuleName
	}
	elseif ($ErrorRecord)
	{
		$int = 0
		while ($int -lt $ErrorRecord.Length)
		{
			$tempException = Convert-PsfMessageException -Exception $ErrorRecord[$int].Exception -FunctionName $FunctionName -ModuleName $ModuleName
			if ($tempException -ne $ErrorRecord[$int].Exception)
			{
				$ErrorRecord[$int] = New-Object System.Management.Automation.ErrorRecord($tempException, $ErrorRecord[$int].FullyQualifiedErrorId, $ErrorRecord[$int].CategoryInfo.Category, $ErrorRecord[$int].TargetObject)
			}
			
			$int++
		}
	}
	#endregion Exception Transforms
	#endregion Apply Transforms
	
	#region Message Handling
	$records = @()
	$showWarning = $AlwaysWarning
	if (-not $showWarning) { $showWarning = Test-PSFFeature -Name 'PSFramework.Stop-PSFFunction.ShowWarning' -ModuleName $ModuleName }
	
	$paramWritePSFMessage = @{
		Level				     = 'Warning'
		EnableException		     = $EnableException
		FunctionName			 = $FunctionName
		Target				     = $Target
		Tag					     = $Tag
		ModuleName			     = $ModuleName
		File					 = $File
		Line					 = $Line
	}
	if ($OverrideExceptionMessage) { $paramWritePSFMessage['OverrideExceptionMessage'] = $true }
	if ($Message) { $paramWritePSFMessage["Message"] = $Message }
	else
	{
		$paramWritePSFMessage["String"] = $String
		$paramWritePSFMessage["StringValues"] = $StringValues
	}
	
	if ($ErrorRecord -or $Exception)
	{
		if ($ErrorRecord)
		{
			foreach ($record in $ErrorRecord)
			{
				if (-not $Exception) { $newException = New-Object System.Exception($record.Exception.Message, $record.Exception) }
				else { $newException = $Exception }
				if ($record.CategoryInfo.Category) { $Category = $record.CategoryInfo.Category }
				$records += New-Object System.Management.Automation.ErrorRecord($newException, "$($ModuleName)_$FunctionName", $Category, $Target)
			}
		}
		else
		{
			$records += New-Object System.Management.Automation.ErrorRecord($Exception, "$($ModuleName)_$FunctionName", $Category, $Target)
		}
		
		# Manage Debugging
		if ($EnableException -and -not $showWarning) { Write-PSFMessage -ErrorRecord $records @paramWritePSFMessage 3>$null }
		else { Write-PSFMessage -ErrorRecord $records @paramWritePSFMessage }
	}
	else
	{
		$exception = New-Object System.Exception($Message)
		$records += New-Object System.Management.Automation.ErrorRecord($Exception, "$($ModuleName)_$FunctionName", $Category, $Target)
		
		# Manage Debugging
		if ($EnableException -and -not $showWarning) { Write-PSFMessage -ErrorRecord $records @paramWritePSFMessage 3>$null }
		else { Write-PSFMessage -ErrorRecord $records @paramWritePSFMessage }
	}
	#endregion Message Handling
	
	#region Silent Mode
	if ($EnableException)
	{
		if ($SilentlyContinue)
		{
			foreach ($record in $records) { $myCmdlet.WriteError($record) }
			if ($ContinueLabel) { continue $ContinueLabel }
			else { continue }
		}
		
		# Extra insurance that it'll stop
		$psframework_killqueue.Enqueue($callStack.InvocationInfo.GetHashCode())
		
		# Need to use "throw" as otherwise calling function will not be interrupted without passing the cmdlet parameter
		if (-not $Cmdlet) { throw $records[0] }
		else { $Cmdlet.ThrowTerminatingError($records[0]) }
	}
	#endregion Silent Mode
	
	#region Non-Silent Mode
	else
	{
		# This ensures that the error is stored in the $error variable AND has its Stacktrace (simply adding the record would lack the stacktrace)
		foreach ($record in $records)
		{
			$null = Write-Error -Message $record -Category $Category -TargetObject $Target -Exception $record.Exception -ErrorId "$($ModuleName)_$FunctionName" -ErrorAction Continue 2>&1
		}
		
		if ($Continue)
		{
			if ($ContinueLabel) { continue $ContinueLabel }
			else { continue }
		}
		else
		{
			# Make sure the function knows it should be stopping
			if ($StepsUpward -eq 0) { $psframework_killqueue.Enqueue($callStack.InvocationInfo.GetHashCode()) }
			elseif ($StepsUpward -gt 0) { $psframework_killqueue.Enqueue((Get-PSCallStack)[($StepsUpward + 1)].InvocationInfo.GetHashCode()) }
			return
		}
	}
	#endregion Non-Silent Mode
}

function Test-PSFFunctionInterrupt
{
    <#
        .SYNOPSIS
            Tests whether the calling function should be interrupted.
        
        .DESCRIPTION
            This helper function is designed to work in tandem with Stop-PSFFunction.
            When gracefully terminating a function, there is a major issue:
            "Return" will only stop the current one of the three blocks (Begin, Process, End).
            All other statements have side effects or produce lots of red text.
    
            So, Stop-PSFFunction writes a variable into the parent scope, that signals the function should cease.
            This function then checks for that very variable and returns true if it is set.
    
            This avoids having to handle odd variables in the parent function and causes the least impact on contributors.
	
			For a more detailed explanation - including commented full-scale implementation examples - see the associated help article:
			Get-Help about_psf_flowcontrol
        
        .EXAMPLE
            if (Test-PSFFunctionInterrupt) { return }
    
            The calling function will stop if this function returns true.
    #>
	[OutputType([System.Boolean])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Test-PSFFunctionInterrupt')]
	Param (
		
	)
	
	$psframework_killqueue -contains (Get-PSCallStack)[1].InvocationInfo.GetHashCode()
}

function Test-PSFLanguageMode
{
<#
	.SYNOPSIS
		Tests, in what language mode a specified scriptblock is in.
	
	.DESCRIPTION
		Tests, in what language mode a specified scriptblock is in.
		Use this to determine the trustworthyness of a scriptblock, or for insights, into what its capabilities are.
	
	.PARAMETER ScriptBlock
		The scriptblock to test.
	
	.PARAMETER Mode
		The Languagemode(s) to compare it to.
		The scriptblock must be in one of the specified modes.
		Defaults to 'FullLanguage'
	
	.PARAMETER Not
		Reverses the test results - now the scriptblock may NOT be in one of the specified language modes.
	
	.EXAMPLE
		PS C:\> Test-PSFLanguageMode -ScriptBlock $ScriptBlock
	
		Returns, whether the $Scriptblock is in FullLanguage mode.
	
	.EXAMPLE
		PS C:\> Test-PSFLanguageMode -ScriptBlock $code -Mode ConstrainedLanguage -Not
	
		Returns $true if the specified scriptblock is NOT inconstrained language mode.
#>
	[OutputType([boolean])]
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$ScriptBlock,
		
		[System.Management.Automation.PSLanguageMode[]]
		$Mode = 'FullLanguage',
		
		[switch]
		$Not
	)
	
	process
	{
		$languageMode = [PSFramework.Utility.UtilityHost]::GetPrivateProperty("LanguageMode", $ScriptBlock)
		if ($Not) { $languageMode -notin $Mode }
		else { $languageMode -in $Mode }
	}
}

function Test-PSFParameterBinding
{
    <#
        .SYNOPSIS
            Helper function that tests, whether a parameter was bound.
        
        .DESCRIPTION
            Helper function that tests, whether a parameter was bound.
        
        .PARAMETER ParameterName
            The name(s) of the parameter that is tested for being bound.
			By default, the check is true when AT LEAST one was bound.
    
        .PARAMETER Not
            Reverses the result. Returns true if NOT bound and false if bound.
	
		.PARAMETER And
			All specified parameters must be present, rather than at least one of them.
	
		.PARAMETER Mode
			Parameters can be explicitly bound or as scriptblocks to be invoked for each item piped to the command.
			The mode determines, which will be tested for.
			Supported Modes: Any, Explicit, PipeScript.
			By default, any will do.
			Whether a parameter was bound as PipeScript is only detectable during the begin block.
        
        .PARAMETER BoundParameters
            The hashtable of bound parameters. Is automatically inherited from the calling function via default value. Needs not be bound explicitly.
        
        .EXAMPLE
            if (Test-PSFParameterBinding "Day")
            {
                
            }
    
            Snippet as part of a function. Will check whether the parameter "Day" was bound. If yes, whatever logic is in the conditional will be executed.
	
		.EXAMPLE
			Test-PSFParameterBinding -Not 'Login', 'Spid', 'ExcludeSpid', 'Host', 'Program', 'Database'
	
			Returns whether none of the parameters above were specified.
	
		.EXAMPLE
			Test-PSFParameterBinding -And 'Login', 'Spid', 'ExcludeSpid', 'Host', 'Program', 'Database'
	
			Returns whether any of the specified parameters was not bound
    #>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Test-PSFParameterBinding')]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string[]]
		$ParameterName,
		
		[Alias('Reverse')]
		[switch]
		$Not,
		
		[switch]
		$And,
		
		[ValidateSet('Any', 'Explicit', 'PipeScript')]
		[string]
		$Mode = 'Any',
		
		[object]
		$BoundParameters = (Get-PSCallStack)[0].InvocationInfo.BoundParameters
	)
	
	process
	{
		if ($And)
		{
			$test = $true
		}
		else
		{
			$test = $false
		}
		$pipeScriptForbidden = $Mode -eq "Explicit"
		$explicitForbidden = $Mode -eq "PipeScript"
		
		foreach ($name in $ParameterName)
		{
			$isPipeScript = ($BoundParameters.$name.PSObject.TypeNames -eq 'System.Management.Automation.CmdletParameterBinderController+DelayedScriptBlockArgument') -as [bool]
			if ($And)
			{
				if (-not $BoundParameters.ContainsKey($name))
				{
					$test = $false
					continue
				}
				if ($isPipeScript -and $pipeScriptForbidden) { $test = $false }
				if (-not $isPipeScript -and $explicitForbidden) { $test = $false }
				
			}
			else
			{
				if ($BoundParameters.ContainsKey($name))
				{
					if ($isPipeScript -and -not $pipeScriptForbidden) { $test = $true }
					if (-not $isPipeScript -and -not $explicitForbidden) { $test = $true }
				}
			}
		}
		
		return ((-not $Not) -eq $test)
	}
}
if (-not (Test-Path Alias:Was-Bound)) { Set-Alias -Value Test-PSFParameterBinding -Name Was-Bound -Scope Global }

function Test-PSFPowerShell
{
<#
	.SYNOPSIS
		Tests for conditions in the PowerShell environment.
	
	.DESCRIPTION
		This helper command can evaluate various runtime conditions, such as:
		- PowerShell Version
		- PowerShell Edition
		- Operating System
		- Elevation
		This makes it easier to do conditional code.
		It also makes it easier to simulate code-paths during pester tests, by mocking this command.
	
	.PARAMETER PSMinVersion
		PowerShell must be running under at least this version.
	
	.PARAMETER PSMaxVersion
		PowerShell most not be runnign on a version higher than this.
	
	.PARAMETER Edition
		PowerShell must be running in the specifioed edition (Core or Desktop)
	
	.PARAMETER OperatingSystem
		PowerShell must be running on the specified OS.
	
	.PARAMETER Elevated
		PowerShell must be running with elevation.
		
		Note:
		This test is only supported on Windows.
		On other OS it will automatically succede and assume root privileges.
	
	.PARAMETER ComputerName
		The computer on which to test local PowerShell conditions.
		If this parameter is not specified, it tests the current PowerShell process and hosting OS.
		Accepts established PowerShell sessions.
	
	.PARAMETER Credential
		The credentials to use when connecting to a remote computer.
	
	.EXAMPLE
		PS C:\> Test-PSFPowerShell -PSMinVersion 5.0
	
		Will return $false, unless the executing powershell version is at least 5.0
	
	.EXAMPLE
		PS C:\> Test-PSFPowerShell -Edition Core
	
		Will return $true, if the current powershell session is a PowerShell core session.
	
	.EXAMPLE
		PS C:\> Test-PSFPowerShell -Elevated
	
		Will return $false if on windows and not running as admin.
		Will return $true otherwise.
	
	.EXAMPLE
		PS C:\> Test-PSFPowerShell -PSMinVersion 6.1 -OperatingSystem Windows
	
		Will return $false unless executed on a PowerShell 6.1 console running on windows.
#>
	[OutputType([System.Boolean])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Test-PSFPowerShell')]
	param (
		[Version]
		$PSMinVersion,
		
		[Version]
		$PSMaxVersion,
		
		[PSFramework.FlowControl.PSEdition]
		$Edition,
		
		[PSFramework.FlowControl.OperatingSystem]
		[Alias('OS')]
		$OperatingSystem,
		
		[switch]
		$Elevated,
		
		[PSFComputer]
		$ComputerName,
		
		[PSCredential]
		$Credential
	)
	
	begin
	{
		$parameter = $PSBoundParameters | ConvertTo-PSFHashtable -Include ComputerName, Credential
	}
	process
	{
		#region Local execution for performance reasons separate
		if (-not $PSBoundParameters.ContainsKey('ComputerName'))
		{
			#region PS Version Test
			if ($PSMinVersion -and ($PSMinVersion -ge $PSVersionTable.PSVersion))
			{
				return $false
			}
			if ($PSMaxVersion -and ($PSMaxVersion -le $PSVersionTable.PSVersion))
			{
				return $false
			}
			#endregion PS Version Test
			
			#region PS Edition Test
			if ($Edition -like "Desktop")
			{
				if ($PSVersionTable.PSEdition -eq "Core")
				{
					return $false
				}
			}
			if ($Edition -like "Core")
			{
				if ($PSVersionTable.PSEdition -ne "Core")
				{
					return $false
				}
			}
			#endregion PS Edition Test
			
			#region OS Test
			if ($OperatingSystem)
			{
				switch ($OperatingSystem)
				{
					"MacOS"
					{
						if ($PSVersionTable.PSVersion.Major -lt 6) { return $false }
						if (-not $IsMacOS) { return $false }
					}
					"Linux"
					{
						if ($PSVersionTable.PSVersion.Major -lt 6) { return $false }
						if (-not $IsLinux) { return $false }
					}
					"Windows"
					{
						if (($PSVersionTable.PSVersion.Major -ge 6) -and (-not $IsWindows))
						{
							return $false
						}
					}
				}
			}
			#endregion OS Test
			
			#region Elevation
			if ($Elevated)
			{
				if (($PSVersionTable.PSVersion.Major -lt 6) -or ($IsWindows))
				{
					$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
					$principal = New-Object Security.Principal.WindowsPrincipal $identity
					if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
					{
						return $false
					}
				}
			}
			#endregion Elevation
			
			return $true
		}
		#endregion Local execution for performance reasons separate
		
		Invoke-PSFCommand @parameter -ScriptBlock {
			#region PS Version Test
			if ($PSMinVersion -and ($PSMinVersion -ge $PSVersionTable.PSVersion))
			{
				return $false
			}
			if ($PSMaxVersion -and ($PSMaxVersion -le $PSVersionTable.PSVersion))
			{
				return $false
			}
			#endregion PS Version Test
			
			#region PS Edition Test
			if ($Edition -like "Desktop")
			{
				if ($PSVersionTable.PSEdition -eq "Core")
				{
					return $false
				}
			}
			if ($Edition -like "Core")
			{
				if ($PSVersionTable.PSEdition -ne "Core")
				{
					return $false
				}
			}
			#endregion PS Edition Test
			
			#region OS Test
			if ($OperatingSystem)
			{
				switch ($OperatingSystem)
				{
					"MacOS"
					{
						if ($PSVersionTable.PSVersion.Major -lt 6) { return $false }
						if (-not $IsMacOS) { return $false }
					}
					"Linux"
					{
						if ($PSVersionTable.PSVersion.Major -lt 6) { return $false }
						if (-not $IsLinux) { return $false }
					}
					"Windows"
					{
						if (($PSVersionTable.PSVersion.Major -ge 6) -and (-not $IsWindows))
						{
							return $false
						}
					}
				}
			}
			#endregion OS Test
			
			#region Elevation
			if ($Elevated)
			{
				if (($PSVersionTable.PSVersion.Major -lt 6) -or ($IsWindows))
				{
					$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
					$principal = New-Object Security.Principal.WindowsPrincipal $identity
					if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
					{
						return $false
					}
				}
			}
			#endregion Elevation
			
			return $true
		}
	}
}

function Unregister-PSFCallback
{
<#
	.SYNOPSIS
		Removes a callback from the list of registered callbacks.
	
	.DESCRIPTION
		Removes a callback from the list of registered callbacks.
	
	.PARAMETER Name
		The name of the callback to remove.
		Does NOT support wildcards.
	
	.PARAMETER Callback
		A full callback object to remove.
		Use Get-PSFCallback to get the list of relevant callback objects.
	
	.EXAMPLE
		PS C:\> Unregister-PSFCallback -Name 'MyModule.Configuration'
	
		Unregisters the 'MyModule.Configuration' callback script.
	
	.EXAMPLE
		PS C:\> Get-PSFCallback | Unregister-PSFCallback
	
		Removes all callback scripts applicable to the current runspace.
#>
	[CmdletBinding(DefaultParameterSetName = 'Name')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Name')]
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true, ParameterSetName = 'Object', Mandatory = $true)]
		[PSFramework.FlowControl.Callback[]]
		$Callback
	)
	
	process
	{
		foreach ($callbackItem in $Callback)
		{
			[PSFramework.FlowControl.CallbackHost]::Remove($callbackItem)
		}
		foreach ($nameString in $Name)
		{
			foreach ($callbackItem in ([PSFramework.FlowControl.CallbackHost]::Get($nameString, $false)))
			{
				if ($callbackItem.Name -ne $nameString) { continue }
				[PSFramework.FlowControl.CallbackHost]::Remove($callbackItem)
			}
		}
	}
}

function Export-PSFModuleClass
{
<#
	.SYNOPSIS
		Exports a module-defined PowerShell class irrespective of how the module is being imported.
	
	.DESCRIPTION
		Exports a module-defined PowerShell class irrespective of how the module is being imported.
		This avoids having to worry about how the module is being imported.
	
		Please beware the risk of class-name-collisions however.
	
	.PARAMETER ClassType
		The types to publish.
	
	.EXAMPLE
		PS C:\> Export-PSFModuleClass -ClassType ([MyModule_MyClass])
	
		Publishes the class MyModule_MyClass, making it available outside of your module.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[System.Type[]]
		$ClassType
	)
	
	begin
	{
		$internalExecutionContext = [PSFramework.Utility.UtilityHost]::GetExecutionContextFromTLS()
		$topLevelSessionState = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('TopLevelSessionState', $internalExecutionContext)
		$globalScope = [PSFramework.Utility.UtilityHost]::GetPrivateProperty('GlobalScope', $topLevelSessionState)
		$addMethod = $globalScope.GetType().GetMethod('AddType', [System.Reflection.BindingFlags]'Instance, NonPublic')
	}
	process
	{
		foreach ($typeObject in $ClassType)
		{
			$arguments = @($typeObject.Name, $typeObject)
			$addMethod.Invoke($globalScope, $arguments)
		}
	}
}

function Import-PSFCmdlet
{
<#
	.SYNOPSIS
		Loads a cmdlet into the current context.
	
	.DESCRIPTION
		Loads a cmdlet into the current context.
		This can be used to register a cmdlet during module import, making it easy to have hybrid modules publishing both cmdlets and functions.
		Can also be used to register cmdlets written in PowerShell classes.
	
	.PARAMETER Name
		The name of the cmdlet to register.
	
	.PARAMETER Type
		The type of the class implementing the cmdlet.
	
	.PARAMETER HelpFile
		Path to the help XML containing the help for the cmdlet.
	
	.PARAMETER Module
		Module to inject the cmdlet into.
	
	.EXAMPLE
		PS C:\> Import-PSFCmdlet -Name Get-Something -Type ([GetSomethingCommand])
	
		Imports the Get-Something cmdlet into the current context.
	
	.EXAMPLE
		PS C:\> Import-PSFCmdlet -Name Get-Something -Type ([GetSomethingCommand]) -Module (Get-Module PSReadline)
	
		Imports the Get-Something cmdlet into the PSReadline module.
	
	.NOTES
		Original Author: Chris Dent
		Link: https://www.indented.co.uk/cmdlets-without-a-dll/
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Import-PSFCmdlet')]
	param (
		[Parameter(Mandatory = $true)]
		[String]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[Type]
		$Type,
		
		[string]
		$HelpFile,
		
		[System.Management.Automation.PSModuleInfo]
		$Module
	)
	
	begin
	{
		$scriptBlock = {
			param (
				[String]
				$Name,
				
				[Type]
				$Type,
				
				[string]
				$HelpFile
			)
			
			$sessionStateCmdletEntry = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry(
				$Name,
				$Type,
				$HelpFile
			)
			
			$context = [PSFramework.Utility.UtilityHost]::GetExecutionContextFromTLS()
			
			# Get the SessionStateInternal type
			$internalType = [PowerShell].Assembly.GetType('System.Management.Automation.SessionStateInternal')
			
			# Get a valid constructor which accepts a param of type ExecutionContext
			$constructor = $internalType.GetConstructor(
				[System.Reflection.BindingFlags]'Instance,NonPublic',
				$null,
				$context.GetType(),
				$null
			)
			
			# Get the SessionStateInternal for this execution context
			$sessionStateInternal = $constructor.Invoke($context)
			
			# Get the method which allows Cmdlets to be added to the session
			$method = $internalType.GetMethod(
				'AddSessionStateEntry',
				[System.Reflection.BindingFlags]'Instance,NonPublic',
				$null,
				$sessionStateCmdletEntry.GetType(),
				$null
			)
			# Invoke the method.
			$method.Invoke($sessionStateInternal, $sessionStateCmdletEntry)
		}
	}
	
	process
	{
		if (-not $Module) { $scriptBlock.Invoke($Name, $Type, $HelpFile) }
		else { $Module.Invoke($scriptBlock, @($Name, $Type, $HelpFile)) }
	}
}

function Register-PSFParameterClassMapping
{
<#
	.SYNOPSIS
		Registers types to a parameter classes input interpretation.
	
	.DESCRIPTION
		The parameter classes shipped in PSFramework can be extended to support input of an unknown object type.
		In order to accomplish that, it is necessary to register the name of that type (and the properties to use) using this command.
	
		On input interpretation, it will check the TypeNames property on the PSObject for evaluation.
		This means you can also specify custom PSObjects by giving them a dedicated name.
	
	.PARAMETER ParameterClass
		The parameter class to extend.
	
	.PARAMETER TypeName
		The name of the type to register.
	
	.PARAMETER Properties
		The properties to check.
		When processing an object of this type, it will try to access the properties in this order, trying to make something fit the intended result.
		The first property that is a fit for the parameter class is chosen, other ones are ignored.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Register-PSFParameterClassMapping -ParameterClass 'Computer' -TypeName 'microsoft.activedirectory.management.adcomputer' -Properties 'DNSHostName', 'Name'
	
		This extends the computer parameter class by ...
		- having it accept the type 'microsoft.activedirectory.management.adcomputer'
		- having it use the 'DNSHostName' property if available, falling back to 'Name' if necessary
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFParameterClassMapping')]
	param (
		[Parameter(Mandatory = $true)]
		[PSFramework.Parameter.ParameterClasses]
		$ParameterClass,
		
		[Parameter(Mandatory = $true)]
		[string]
		$TypeName,
		
		[Parameter(Mandatory = $true)]
		[string[]]
		$Properties,
		
		[switch]
		$EnableException
	)
	
	process
	{
		try
		{
			switch ($ParameterClass)
			{
				"Computer"
				{
					[PSFramework.Parameter.ComputerParameter]::SetTypePropertyMapping($TypeName, $Properties)
				}
				"DateTime"
				{
					[PSFramework.Parameter.DateTimeParameter]::SetTypePropertyMapping($TypeName, $Properties)
				}
				"TimeSpan"
				{
					[PSFramework.Parameter.TimeSpanParameter]::SetTypePropertyMapping($TypeName, $Properties)
				}
				"Encoding"
				{
					[PSFramework.Parameter.EncodingParameter]::SetTypePropertyMapping($TypeName, $Properties)
				}
				default
				{
					Stop-PSFFunction -String 'Register-PSFParameterClassMapping.NotImplemented' -StringValues $ParameterClass -EnableException $EnableException -Tag 'fail', 'argument' -Category NotImplemented
					return
				}
			}
		}
		catch
		{
			Stop-PSFFunction -String 'Register-PSFParameterClassMapping.Registration.Error' -StringValues $ParameterClass, $Typename -EnableException $EnableException -Tag 'fail', '.NET' -ErrorRecord $_
			return
		}
	}
}

function Set-PSFTypeAlias
{
<#
	.SYNOPSIS
		Registers or updates an alias for a .NET type.
	
	.DESCRIPTION
		Registers or updates an alias for a .NET type.
		Use this function during module import to create shortcuts for typenames users can be expected to interact with directly.
	
	.PARAMETER AliasName
		The short and useful alias for the type.
	
	.PARAMETER TypeName
		The full name of the type.
		Example: 'System.IO.FileInfo'
	
	.PARAMETER Mapping
		A hashtable of alias to typename mappings.
		Useful to registering a full set of type aliases.
	
	.EXAMPLE
		PS C:\> Set-PSFTypeAlias -AliasName 'file' -TypeName 'System.IO.File'
	
		Creates an alias for the type 'System.IO.File' named 'file'
	
	.EXAMPLE
		PS C:\> Set-PSFTypeAlias -Mapping @{
			file = 'System.IO.File'
			path = 'System.IO.Path'
		}
	
		Creates an alias for the type 'System.IO.File' named 'file'
		Creates an alias for the type 'System.IO.Path' named 'path'
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(DefaultParameterSetName = 'Name', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFTypeAlias')]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name', ValueFromPipelineByPropertyName = $true)]
		[string]
		$AliasName,
		
		[Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Name', ValueFromPipelineByPropertyName = $true)]
		[string]
		$TypeName,
		
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Hashtable')]
		[hashtable]
		$Mapping
	)
	
	begin
	{
		# Obtain a reference to the TypeAccelerators type
		$TypeAcceleratorType = [psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")
	}
	process
	{
		foreach ($key in $Mapping.Keys)
		{
			$TypeAcceleratorType::Add($key, $Mapping[$key])
		}
		if ($AliasName)
		{
			$TypeAcceleratorType::Add($AliasName, $TypeName)
		}
	}
}

function Get-PSFLicense
{
<#
	.SYNOPSIS
		Returns registered licenses
	
	.DESCRIPTION
		Returns all matching licenses from the PSFramework internal license cache.
	
	.PARAMETER Filter
		Default: "*"
		Filters for the name of the product. Uses the -like operator.
	
	.PARAMETER ProductType
		Only licenses of products for any of the specified types are considered.
	
	.PARAMETER LicenseType
		Only licenses of any matching type are returned.
	
	.PARAMETER Manufacturer
		Default: "*"
		Only licenses for products of a matching manufacturer are returned. Uses the -like operator for comparisons.
	
	.EXAMPLE
		PS C:\> Get-PSFLicense *Microsoft*
	
		Returns all registered licenses for products with the string "Microsoft" in their name
	
	.EXAMPLE
		PS C:\> Get-PSFLicense -LicenseType Commercial -ProductType Library
	
		Returns a list of all registered licenses for products that have commercial licenses and are libraries.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding(PositionalBinding = $false, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFLicense')]
	[OutputType([PSFramework.License.License])]
	param (
		[Parameter(Position = 0)]
		[Alias('Product')]
		[String]
		$Filter = "*",
		
		[PSFramework.License.ProductType[]]
		$ProductType,
		
		[PSFramework.License.LicenseType]
		$LicenseType,
		
		[String]
		$Manufacturer = "*"
	)
	
	process
	{
		[PSFramework.License.LicenseHost]::Get() | Where-Object {
			if ($_.Product -notlike $Filter) { return $false }
			if ($_.Manufacturer -notlike $Manufacturer) { return $false }
			if ($ProductType -and ($_.ProductType -notin $ProductType)) { return $false }
			if ($licenseType -and -not ($_.LicenseType -band $LicenseType)) { return $false }
			return $true
		}
	}
}


function New-PSFLicense
{
<#
	.SYNOPSIS
		Creates a new license object and registers it
	
	.DESCRIPTION
		This function creates a new license object used by the PSFramework licensing component. The license is automatically registered in the current process' license store.
	
	.PARAMETER Product
		The product that is being licensed
	
	.PARAMETER Manufacturer
		The entity that produced the licensed product
	
	.PARAMETER ProductVersion
		The version of the licensed product
	
	.PARAMETER ProductType
		What kind of product is te license for?
		Options: Module, Script, Library, Application, Other
	
	.PARAMETER Name
		Most licenses used have a name. Feel free to register that name as well.
	
	.PARAMETER Version
		What version is the license?
	
	.PARAMETER Date
		When was the product licensed with the registered license
	
	.PARAMETER Type
		Default: Free
		This shows the usual limitations that apply to this license. By Default, licenses are considered free and may be modified, but require attribution when used in your own product.
	
	.PARAMETER Text
		The full text of your license.
	
	.PARAMETER Description
		A description of the content. Useful when describing how some license is used within your own product.
	
	.PARAMETER Parent
		The license of the product within which the product of this license is used.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
		
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> New-PSFLicense -Product 'Awesome Test Product' -Manufacturer 'Awesome Inc.' -ProductVersion '1.0.1.0' -ProductType Application -Name FreeBSD -Version "3.0.0.0" -Date (Get-Date -Year 2016 -Month 11 -Day 28 -Hour 0 -Minute 0 -Second 0) -Text @"
		Copyright (c) 2016, Awesome Inc.
		All rights reserved.

		Redistribution and use in source and binary forms, with or without
		modification, are permitted provided that the following conditions are met:

		1. Redistributions of source code must retain the above copyright notice, this
		   list of conditions and the following disclaimer.
		2. Redistributions in binary form must reproduce the above copyright notice,
		   this list of conditions and the following disclaimer in the documentation
		   and/or other materials provided with the distribution.

		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
		ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
		WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
		DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
		ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
		(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
		LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
		ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
		(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
		SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

		The views and conclusions contained in the software and documentation are those
		of the authors and should not be interpreted as representing official policies,
		either expressed or implied, of the FreeBSD Project.
		"@
	
		This registers the Awesome Test Product as licensed under the common FreeBSD license.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/New-PSFLicense')]
	[OutputType([PSFramework.License.License])]
	param
	(
		[Parameter(Mandatory = $true)]
		[String]
		$Product,
		
		[String]
		$Manufacturer = "ACME ltd.",
		
		[Version]
		$ProductVersion = "1.0.0.0",
		
		[Parameter(Mandatory = $true)]
		[PSFramework.License.ProductType]
		$ProductType,
		
		[String]
		$Name = "Unknown",
		
		[Version]
		$Version = "1.0.0.0",
		
		[DateTime]
		$Date = (Get-Date -Year 1989 -Month 10 -Day 3 -Hour 0 -Minute 0 -Second 0),
		
		[PSFramework.License.LicenseType]
		$Type = "Free",
		
		[Parameter(Mandatory = $true)]
		[String]
		$Text,
		
		[string]
		$Description,
		
		[PSFramework.License.License]
		$Parent
	)
	
	# Create and fill object
	$license = New-Object PSFramework.License.License -Property @{
		Product	       = $Product
		Manufacturer   = $Manufacturer
		ProductVersion = $ProductVersion
		ProductType    = $ProductType
		LicenseName    = $Name
		LicenseVersion = $Version
		LicenseDate    = $Date
		LicenseType    = $Type
		LicenseText    = $Text
		Description    = $Description
		Parent		   = $Parent
	}
	if (Test-PSFShouldProcess -Action 'Create License' -Target $license -PSCmdlet $PSCmdlet)
	{
		if (-not ([PSFramework.License.LicenseHost]::Get($license)))
		{
			[PSFramework.License.LicenseHost]::Add($license)
		}
		
		return $license
	}
}


function Remove-PSFLicense
{
<#
	.SYNOPSIS
		Removes a registered license from the license store
	
	.DESCRIPTION
		Removes a registered license from the license store
	
	.PARAMETER License
		The license to remove
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Get-PSFLicense "FooBar" | Remove-PSFLicense
	
		Removes the license for the product "FooBar" from the license store.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Remove-PSFLicense')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[PSFramework.License.License[]]
		$License,
		
		[switch]
		$EnableException
	)
	
	Process
	{
		foreach ($licenseObject in $License)
		{
			if (Test-PSFShouldProcess -Action 'Remove License' -Target $licenseObject -PSCmdlet $PSCmdlet)
			{
				try { [PSFramework.License.LicenseHost]::Remove($licenseObject) }
				catch
				{
					Stop-PSFFunction -Message "Failed to remove license" -ErrorRecord $_ -EnableException $EnableException -Target $licenseObject -Continue
				}
			}
		}
	}
}


function Get-PSFLocalizedString
{
<#
	.SYNOPSIS
		Returns the localized strings of a module.
	
	.DESCRIPTION
		Returns the localized strings of a module.
		By default, it creates a variable that has access to each localized string in the module (with string name as propertyname).
		Alternatively, by specifying a specific string, that string can instead be returned.
	
	.PARAMETER Module
		The name of the module to map.
	
	.PARAMETER Name
		The name of the string to return
	
	.EXAMPLE
		PS C:\> Get-PSFLocalizedString -Module 'MyModule'
	
		Returns an object that can be used to access any localized string.
	
	.EXAMPLE
		PS C:\> Get-PSFLocalizedString -Module 'MyModule' -Name 'ErrorValidation'
	
		Returns the string for the module 'MyModule'  that is stored under the 'ErrorValidation'  name.
#>
	[OutputType([PSFramework.Localization.LocalStrings], ParameterSetName = 'Default')]
	[OutputType([System.String], ParameterSetName = 'Name')]
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Name')]
		[Parameter(Mandatory = $true, ParameterSetName = 'Default')]
		[string]
		$Module,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Name')]
		[string]
		$Name
	)
	
	process
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Default' { New-Object PSFramework.Localization.LocalStrings($Module) }
			'Name' { (New-Object PSFramework.Localization.LocalStrings($Module)).$Name }
		}
	}
}

function Import-PSFLocalizedString
{
<#
	.SYNOPSIS
		Imports a set of localized strings from a PowerShell data file.
	
	.DESCRIPTION
		Imports a set of localized strings from a PowerShell data file.
		This is used to feed the localized string feature set.
		Always import for all languages, do not select by current language - the system handles language selection.
	
		Strings are process wide, so loading additional languages can be offloaded into a background task.
	
	.PARAMETER Path
		The path to the psd1 file to import as strings file.
	
	.PARAMETER Module
		The module for which to import the strings.
	
	.PARAMETER Language
		The language of the specific strings file.
		Defaults to en-US.
	
	.EXAMPLE
		PS C:\> Import-PSFLocalizedString -Path '$moduleRoot\strings.psd1' -Module 'MyModule'
	
		Imports the strings stored in strings.psd1 for the module MyModule as 'en-US' language strings.
	
	.NOTES
		This command is not safe to expose in a JEA endpoint.
		In its need to maintain compatibility it allows for a path for arbitrary code execution.
#>
	[PSFramework.PSFCore.NoJeaCommand()]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Module,
		
		[PsfValidateSet(TabCompletion = 'PSFramework-LanguageNames', NoResults = 'Continue')]
		[string]
		$Language = 'en-US'
	)
	
	begin
	{
		try { $resolvedPath = Resolve-PSFPath -Path $Path -Provider FileSystem }
		catch { Stop-PSFFunction -Message "Failed to resolve path: $Path" -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_ }
	}
	process
	{
		foreach ($pathItem in $resolvedPath)
		{
			$data = Import-PSFPowerShellDataFile -Path $pathItem
			foreach ($key in $data.Keys)
			{
				[PSFramework.Localization.LocalizationHost]::Write($Module, $key, $Language, $data[$key])
			}
		}
	}
}

function Add-PSFLoggingProviderRunspace
{
<#
	.SYNOPSIS
		Adds a runspace to the list of dynamically included runspaces of an active logging provider instance.
	
	.DESCRIPTION
		Adds a runspace to the list of dynamically included runspaces of an active logging provider instance.
		This is designed to allow runspaces to add themselves "on the fly" to a specific logging provider.
	
		Consider this scenario:
		You have a large workload you spread across many runspaces.
		However, each workload item might perform one out of three different categories of tasks.
		You want each of these categories to log into a dedicated logfile and have prepared a provider for each.
		Set each such logging instance as "-RequiresInclude" so by default nothing gets logged to any of them.
		Then each workload item can call this command to add itself to the correct logging provider instance.
	
		When done, call "Remove-PSFLoggingProviderRunspace" to remove that runspace correctly from the instance.
		When using runspaces with a runspace pool, runspaces might be recycled for workitems of other categories, so cleaning it up is a useful habit.
	
		Note:
		This call will fail if the instance has not been created yet!
		After setting up the logging provider instance using Set-PSFLoggingProvider, a short delay may occur before the instance is created.
		With the default configuration, this delay should be no worse than 6 seconds and generally a lot less.
		You can use "Get-PSFLoggingProviderInstance -ProviderName <providername> -Name <instancename>" to check whether it has been created.
	
	.PARAMETER ProviderName
		Name of the logging provider the instance is part of.
	
	.PARAMETER InstanceName
		Name of the logging provider instance to target.
		Default: "default"  (the instance created when you omit the instancename parameter on Set-PSFLoggingProvider)
	
	.PARAMETER Runspace
		The Runspace ID of the runspace to add.
		Defaults to the current runspace.
	
	.EXAMPLE
		PS C:\> Add-PSFLoggingProviderRunspace -ProviderName 'logfile' -InstanceName UpdateTask
	
		Adds the current runspace to the list of included runspaces on the logfile instance "UpdateTask".
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$ProviderName,
		
		[string]
		$InstanceName = 'default',
		
		[guid]
		$Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId
	)
	
	process
	{
		$instance = Get-PSFLoggingProviderInstance -ProviderName $ProviderName -Name $InstanceName
		if (-not $instance) {
			Stop-PSFFunction -String 'Add-PSFLoggingProviderRunspace.Instance.NotFound' -StringValues $ProviderName, $InstanceName -EnableException $true -Category ObjectNotFound -Cmdlet $PSCmdlet
		}
		
		$instance.AddRunspace($Runspace)
	}
}

function Get-PSFLoggingProvider
{
<#
	.SYNOPSIS
		Returns a list of the registered logging providers.
	
	.DESCRIPTION
		Returns a list of the registered logging providers.
		Those are used to log messages to whatever system they are designed to log to.
	
		PSFramework ships with a few default logging providers.
		Custom logging destinations can be created by implementing your own, custom provider and registering it using Register-PSFLoggingProvider.
	
	.PARAMETER Name
		Default: '*'
		The name to filter by
	
	.EXAMPLE
		PS C:\> Get-PSFLoggingProvider
	
		Returns all logging provider
	
	.EXAMPLE
		PS C:\> Get-PSFLoggingProvider -Name filesystem
	
		Returns the filesystem provider
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFLoggingProvider')]
	[OutputType([PSFramework.Logging.Provider])]
	Param (
		[Alias('Provider', 'ProviderName')]
		[string]
		$Name = "*"
	)
	
	process
	{
		[PSFramework.Logging.ProviderHost]::Providers.Values | Where-Object Name -Like $Name | Sort-Object ProviderVersion, Name
	}
}

function Get-PSFLoggingProviderInstance
{
<#
	.SYNOPSIS
		Returns a list of the enabled logging provider instances.
	
	.DESCRIPTION
		Returns a list of the enabled logging provider instances.
		Those are used to log messages to whatever system they are designed to log to.
	
		PSFramework ships with a few default logging providers.
		Custom logging destinations can be created by implementing your own, custom provider and registering it using Register-PSFLoggingProvider.
	
	.PARAMETER ProviderName
		Default: '*'
		The name of the provider the instance is an instance of.
	
	.PARAMETER Name
		Default: '*'
		The name of the instance to filter by.
	
	.PARAMETER Force
		Enables returning disabled instances.
	
	.EXAMPLE
		PS C:\> Get-PSFLoggingProviderInstance
	
		Returns all enabled logging provider instances.
	
	.EXAMPLE
		PS C:\> Get-PSFLoggingProviderInstance -ProviderName logfile -Force
	
		Returns all logging provider instances - enabled or not - of the logfile provider
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFLoggingProvider')]
	[OutputType([PSFramework.Logging.Provider])]
	param (
		[string]
		$ProviderName = '*',
		
		[string]
		$Name = '*',
		
		[switch]
		$Force
	)
	
	process
	{
		foreach ($provider in ([PSFramework.Logging.ProviderHost]::Providers.Values | Sort-Object Name))
		{
			if ($provider.ProviderVersion -lt 2) { continue }
			if ($provider.Name -notlike $ProviderName) { continue }
			
			foreach ($instance in ($provider.Instances.Values | Sort-Object Name))
			{
				if ($instance.Name -notlike $Name) { continue }
				if (-not ($instance.Enabled -or $Force)) { continue }
				$instance
			}
		}
	}
}

function Import-PSFLoggingProvider
{
<#
	.SYNOPSIS
		Imports logging provider code and configuration from a hosting source.
	
	.DESCRIPTION
		Imports logging provider code and configuration from a hosting source.
		This enables centrally providing logging provider settings that are retrieved by running this command.
	
		You can simply run this command with no arguments.
		It will then only do anything, if there is a defined value for the configuration setting "PSFramework.Logging.Provider.Source".
	
		If specifying a path or relying on the configuration setting above, it expects the path to ...
		- Be either a weblink or a file system path
		- Point at a json file containing the relevant provider information
		- Be accessible without specific authentication information
	
		Alternatively to specifying a path (or relying on the configured value), you can also give it the same data raw via the "-Data" parameter.
		This needs to be the exact same data layout as provided by the json file, only already readied as PowerShell objects.
	
		In both cases, you provide one or multiple items which may contain the following Properties (all others will be ignored):
		- ProviderPath
		- ProviderName
		- InstallationConfig
		- ProviderConfig
	
		# Providerpath
		#---------------
	
		The ProviderPath property is a full or relative path to a scriptfile that contains LoggingProvider code.
		A relative path would be relative to the path of the json file originally retrieved.
		If calling this command with the "-Data" parameter, relative paths are not supported.
		The scriptfile must be valid PowerShell code, however the original extension matters not.
		The file will be run as untrusted code, so it will fail in Constraiend Language Mode, unless you sign the provider script with a whitelisted publisher certificate.
	
		# ProviderName
		#---------------
	
		The name of the provider to install/configure.
		This property is needed in order to use the subsequent two configuration properties.
		
		Note: If specifying both ProviderPath and ProviderName, it will FIRST install the new provider.
		You can thus deploy and configure a provider in the same setting.
	
		# InstallationConfig
		#---------------------
	
		A PSObject with properties of its own.
		These properties should contain the property & values you would use in Install-PSFLoggingProvider.
		Invalid entries (property-names that do not match a parameter on Install-PSFLoggingProvider) in this call will cause an error loading the setting.
	
		# ProviderConfig
		#-----------------
		
		A PSObject with properties of its own.
		Or an array thereof, if you want to configure multiple instances of the same provider in one go.
		Similar to the InstallationConfig property, these property/value pairs are used to dynamically bind to Set-PSFLoggingProvider, configuring the provider.
	
	
		Example json file:
		[
			{
				"ProviderName":  "logfile",
				"ProviderConfig":  {
					"InstanceName":  "SystemLogInstance",
					"FilePath":  "C:\\logs\\MyTask-%date%.csv",
					"TimeFormat":  "yyyy-MM-dd HH:mm:ss.fff",
					"Enabled":  true
				}
			}
		]
	
	.PARAMETER Path
		Path to a json file providing logging provider settings or new logging providers to load.
		Can be either a weblink or a file system path.
		See description for details on how the json file should look like.
	
	.PARAMETER Data
		The finished provider data to process.
		The PowerShell object version of the json data otherwise provided through a path.
		See description for details on how the data should look like.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Import-PSFLoggingProvider
	
		Imports the preconfigured logging provider resource file (or silently does nothing if none is configured).
	
	.EXAMPLE
		PS C:\> Import-PSFLoggingProvider -Path \\server\share\psframework\logging.json
	
		Imports the logging provider resource file from the specified network path.
#>
	[CmdletBinding(DefaultParameterSetName = 'Path')]
	param (
		[Parameter(ParameterSetName = 'Path')]
		[PsfValidateScript('PSFramework.Validate.Uri.Absolute', ErrorString = 'PSFramework.Validate.Uri.Absolute')]
		[string]
		$Path,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Data')]
		$Data,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		#region Helper Functions
		function Import-ProviderData
		{
			[CmdletBinding()]
			param (
				$Data,
				
				[AllowEmptyString()]
				[string]
				$ConfigPath
			)
			
			if ($Data.ProviderPath)
			{
				try { Install-ProviderFile -Path $Data.ProviderPath -ConfigPath $ConfigPath }
				catch { throw }
			}
			
			if ($Data.ProviderName)
			{
				if ($Data.InstallationConfig)
				{
					$config = $Data.InstallationConfig | ConvertTo-PSFHashtable
					Install-PSFLoggingProvider -Name $Data.ProviderName @config
				}
				foreach ($instance in $Data.ProviderConfig)
				{
					$config = $instance | ConvertTo-PSFHashtable
					Set-PSFLoggingProvider -Name $Data.ProviderName @config
				}
			}
		}
		
		function Install-ProviderFile
		{
			[CmdletBinding()]
			param (
				[string]
				$Path,
				
				[AllowEmptyString()]
				[string]
				$ConfigPath
			)
			
			#region Resolve Path and get code data
			$basePath = ""
			if ($ConfigPath) { $basePath = $ConfigPath -replace '[\\/][^\\/]+$' }
			
			[uri]$uri = $Path
			if (-not $uri.IsAbsoluteUri -and $ConfigPath)
			{
				switch (([uri]$basePath).Scheme)
				{
					'https' { $uri = '{0}/{1}' -f $basePath, $Path }
					'file' { $uri = '{0}{1}{2}' -f $basePath, [System.IO.Path]::DirectorySeparatorChar, $Path }
				}
			}
			if (-not $uri.IsAbsoluteUri) { throw "Invalid path: $Path - Cannot resolve absolute path!" }
			
			try
			{
				if ($uri.Scheme -eq 'file') { [string]$dataReceived = Get-Content -Path $uri -ErrorAction Stop -Raw }
				else { [string]$dataReceived = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction Stop }
			}
			catch { throw }
			#endregion Resolve Path and get code data
			
			#region Execute provider scriptcode
			$errors = $null
			$null = [System.Management.Automation.Language.Parser]::ParseInput($dataReceived, [ref]$null, [ref]$errors)
			if ($errors) { throw "Syntax error in file processed from $uri" }
			
			$tempPath = Get-PSFPath -Name Temp
			$scriptPath = Join-Path -Path $tempPath -ChildPath "provider-$(Get-Random).ps1"
			$encoding = New-Object System.Text.UTF8Encoding($true)
			[System.IO.File]::WriteAllText($scriptPath, $dataReceived, $encoding)
			
			# Loading a file from within the module context runs the provider script from within that (trusted) context as well.
			# This has various nasty consequences in Constrained language Mode
			# We avoid this by rehoming the scriptblock to the global sessionstate
			$scriptBlock = { & $args[0] }
			[PSFramework.Utility.UtilityHost]::ImportScriptBlock($scriptBlock, $true) # $true = Import into global, rather than local sessionstate
			try { $scriptBlock.Invoke($scriptPath) }
			catch { throw }
			Remove-Item -Path $scriptPath -Force -ErrorAction Ignore
			#endregion Execute provider scriptcode
		}
		#endregion Helper Functions
	}
	process
	{
		$effectivePath = ""
		switch ($PSCmdlet.ParameterSetName)
		{
			#region Process path-based imports
			'Path'
			{
				$effectivePath = $Path
				if (-not $effectivePath) { $effectivePath = Get-PSFConfigValue -FullName 'PSFramework.Logging.Provider.Source' }
				
				# This case is relevant when adding the command "just in case", where in some environments the configuration may be provided and in others not.
				if (-not $effectivePath) { return }
				
				[uri]$uri = $effectivePath
				try
				{
					if ($uri.Scheme -eq 'file') { $dataReceived = Get-Content -Path $effectivePath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
					else { $dataReceived = Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
				}
				catch
				{
					Stop-PSFFunction -String 'Import-PSFLoggingProvider.Import.Error' -StringValues $effectivePath -ErrorRecord $_ -EnableException $EnableException
					return
				}
			}
			#endregion Process path-based imports
			#region Process offered data
			'Data'
			{
				$dataReceived = $Data
			}
			#endregion Process offered data
		}
		foreach ($datum in $dataReceived)
		{
			try { Import-ProviderData -Data $datum }
			catch { Stop-PSFFunction -String 'Import-PSFLoggingProvider.Datum.Error' -EnableException $EnableException -ErrorRecord $_ -Continue -Target $datum }
		}
	}
}

function Install-PSFLoggingProvider
{
	<#
		.SYNOPSIS
			Installs a logging provider for the PSFramework.
		
		.DESCRIPTION
			This command installs a logging provider registered with the PSFramework.
			
			Some providers may require special installation steps, that cannot be handled by the common initialization / configuration.
			For example, a provider may require installation of binaries that require elevation.
	
			In order to cover those scenarios, a provider can include an installation script, which is called by this function.
			It can also provide additional parameters to this command, which are dynamically provided once the -Name parameter has been passed.
	
			When registering the logging provider (Using Register-PSFLoggingProvider), you can specify the logic executed by this command with these parameters:
			- IsInstalledScript :      Must return $true when installation has already been performed. If this returns not $false, then this command will do nothing at all.
			- InstallationScript :     The script performing the actual installation
			- InstallationParameters : A script that returns dynamic parameters. This can be used to generate additional parameters that can modify the installation process.
			
			NOTE:
			This module does not contain help/guidance on how to generate dynamic parameters!
		
		.PARAMETER Name
			The name of the provider to install
		
		.PARAMETER EnableException
			This parameters disables user-friendly warnings and enables the throwing of exceptions.
			This is less user friendly, but allows catching exceptions in calling scripts.
	
		.EXAMPLE
			PS C:\> Install-PSFLoggingProvider -Name Eventlog
	
			Installs a logging provider named 'eventlog'
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Install-PSFLoggingProvider')]
	param (
		[Alias('Provider', 'ProviderName')]
		[string]
		$Name,
		
		[switch]
		$EnableException
	)
	
	dynamicparam
	{
		if ($Name -and ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name)))
		{
			[PSFramework.Logging.ProviderHost]::Providers[$Name].InstallationParameters.InvokeGlobal()
		}
	}
	
	process
	{
		if (-not ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name)))
		{
			Stop-PSFFunction -String 'Install-PSFLoggingProvider.Provider.NotFound' -StringValues $Name -EnableException $EnableException -Category InvalidArgument -Target $Name -Tag 'logging', 'provider', 'install'
			return
		}
		
		$provider = [PSFramework.Logging.ProviderHost]::Providers[$Name]
		
		if (-not $provider.IsInstalledScript.InvokeGlobal())
		{
			try { $provider.InstallationScript.InvokeGlobal($PSBoundParameters) }
			catch
			{
				Stop-PSFFunction -String 'Install-PSFLoggingProvider.Installation.Error' -StringValues $Name -EnableException $EnableException -Target $Name -ErrorRecord $_ -Tag 'logging', 'provider', 'install'
				return
			}
		}
	}
}

function Register-PSFLoggingProvider
{
<#
	.SYNOPSIS
		Registers a new logging provider to the PSFramework logging system.
	
	.DESCRIPTION
		This function registers all components of the PSFramework logging provider systems.
		It allows you to define your own logging destination and configuration and tie them into the default logging system.
		
		In order to properly utilize its power, it becomes necessary to understand how the logging works beneath the covers:
		- On Start of the logging script, it runs a one-time scriptblock per enabled provider (this will also occur when later enabling a provider)
		- Thereafter the script will continue, logging in cycles of Start > Log all Messages > Log all Errors > End
		Each of those steps has its own event, allowing for fine control over what happens where.
		- Finally, on shutdown of a provider it again offers an option to execute some code (to dispose/free resources in use)
		
		NOTE: Logging Provider Versions
		There are two versions / generations of logging providers, that are fundamentally different from each other:
		
		Version 1
		---------
		
		All providers share the same scope for the execution of ALL of those actions/scriptblocks!
		This makes it important to give your variables/functions a unique name, in order to avoid conflicts.
		General Guideline:
		- All variables should start with the name of the provider and an underscore. Example: $filesystem_root
		- All functions should use the name of the provider as prefix. Example: Clean-FileSystemErrorXml
		
		Version 2
		---------
		
		Each provider runs in an isolated module context.
		A provider can have multiple instances of itself active at the same time, each with separate resource isolation.
		Additional tooling provided makes it also easier to publish complex logging providers.
		Share variables between events by making them script-scope (e.g.: $script:path)
	
	.PARAMETER Name
		A unique name for your provider. Registering a provider under a name already registered, NOTHING will happen.
		This function will instead silently terminate.
	
	.PARAMETER Version2
		Flags the provider as a second generation logging provider.
		This reduces the complexity and improves the overall user experience while adding multi-instance capability to the service.
		All new providers should be built as version2 providers.
		Generation 1 legacy providers are still supported under the PSFramework Reliability Promise
	
	.PARAMETER Enabled
		Setting this will enable the provider on registration.
	
	.PARAMETER ConfigurationRoot
		Provider instance information is stored in the configuration system.
		Assuming you would store the path location for the provider under this config setting:
		'PSFramework.Logging.LogFile.FilePath'
		Then the ConfigurationRoot would be:
		'PSFramework.Logging.LogFile'
		
		For more information on the configuration system, see:
		https://psframework.org/documentation/documents/psframework/configuration.html
	
	.PARAMETER InstanceProperties
		The properties needed to define an instance of a provider.
		Examples from the default providers:
		LogFile: 'CsvDelimiter','FilePath','FileType','Headers','IncludeHeader','Logname','TimeFormat'
		GELF: 'Encrypt','GelfServer','Port'
	
	.PARAMETER ConfigurationDefaultValues
		A hashtable containing the default values to assume when creating a new instance of a logging provider.
		This data is used during Set-PSFLoggingProvider when nothing in particular is specified for a given value.
		Instances that are defined through configuration are responsible for their full configuration set and will not be provided these values.
	
	.PARAMETER FunctionDefinitions
		If your provider instances need access to helper functions, the easiest way is to provide them using this parameter.
		Specify a scriptblock that contains your function statements with the full definition, they will be made available to the provider instances.
		Note: All logging provider instances are isolated from each other.
		Even though multiple instances will have access to equal instances, they will not share access to variables and such.
	
	.PARAMETER RegistrationEvent
		Scriptblock that should be executed on registration.
		This allows you to perform installation actions synchronously, with direct user interaction.
		At the same time, by adding it as this parameter, it will only performed on the initial registration, rather than every time the provider is registered (runspaces, Remove-Module/Import-Module)
	
	.PARAMETER BeginEvent
		The actions that should be taken once when setting up the logging.
		Can well be used to register helper functions or loading other resources that should be loaded on start only.
	
	.PARAMETER StartEvent
		The actions taken at the beginning of each logging cycle.
		Typically used to establish connections or do some necessary pre-connections.
	
	.PARAMETER MessageEvent
		The actions taken to process individual messages.
		The very act of writing logs.
		This scriptblock receives a message object (As returned by Get-PSFMessage) as first and only argument.
		Under some circumstances, this message may be a $null object, your scriptblock must be able to handle this.
	
	.PARAMETER ErrorEvent
		The actions taken to process individual error messages.
		The very act of writing logs.
		This scriptblock receives a message object (As returned by 'Get-PSFMessage -Errors') as first and only argument.
		Under some circumstances, this message may be a $null object, your scriptblock must be able to handle this.
		This consists of complex, structured data and may not be suitable to all logging formats.
		However all errors are ALWAYS accompanied by a message, making integrating this optional.
	
	.PARAMETER EndEvent
		Actions taken when finishing up a logging cycle. Can be used to close connections.
	
	.PARAMETER FinalEvent
		Final action to take when the logging terminates.
		This should release all resources reserved.
		This event will fire when:
		- The console is being closed
		- The logging script is stopped / killed
		- The logging provider is disabled
	
	.PARAMETER ConfigurationParameters
		The function Set-PSFLoggingProvider can be used to configure this logging provider.
		Using this parameter it is possible to register dynamic parameters when configuring your provider.
	
	.PARAMETER ConfigurationScript
		When using Set-PSFLoggingProvider, this script can be used to input given by the dynamic parameters generated by the -ConfigurationParameters parameter.
	
	.PARAMETER IsInstalledScript
		A scriptblock verifying that all prerequisites are properly installed.
	
	.PARAMETER InstallationScript
		A scriptblock performing the installation of the provider's prerequisites.
		Used by Install-PSFProvider in conjunction with the script provided by -InstallationParameters
	
	.PARAMETER InstallationParameters
		A scriptblock returning dynamic parameters that are offered when running Install-PSFprovider.
		Those can then be used by the installation scriptblock specified in the aptly named '-InstallationScript' parameter.
	
	.PARAMETER ConfigurationSettings
		This is executed before actually registering the scriptblock.
		It allows you to include any logic you wish, but it is specifically designed for configuration settings using Set-PSFConfig with the '-Initialize' parameter.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Register-PSFLoggingProvider -Name "filesystem" -Enabled $true -RegistrationEvent $registrationEvent -BeginEvent $begin_event -StartEvent $start_event -MessageEvent $message_Event -ErrorEvent $error_Event -EndEvent $end_event -FinalEvent $final_event -ConfigurationParameters $configurationParameters -ConfigurationScript $configurationScript -IsInstalledScript $isInstalledScript -InstallationScript $installationScript -InstallationParameters $installationParameters -ConfigurationSettings $configuration_Settings
		
		Registers the filesystem provider, providing events for every single occasion.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[PSFramework.PSFCore.NoJeaCommandAttribute()]
	[CmdletBinding(DefaultParameterSetName = 'Version1', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFLoggingProvider')]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(ParameterSetName = 'Version2')]
		[switch]
		$Version2,
		
		[switch]
		$Enabled,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Version2')]
		[string]
		$ConfigurationRoot,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Version2')]
		[string[]]
		$InstanceProperties,
		
		[Parameter(ParameterSetName = 'Version2')]
		[Hashtable]
		$ConfigurationDefaultValues = @{ },
		
		[Parameter(ParameterSetName = 'Version2')]
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$FunctionDefinitions = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$RegistrationEvent,
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$BeginEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$StartEvent = { },
		
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$MessageEvent,
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$ErrorEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$EndEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$FinalEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$ConfigurationParameters = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$ConfigurationScript = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$IsInstalledScript = { $true },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$InstallationScript = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$InstallationParameters = { },
		
		[System.Management.Automation.ScriptBlock]
		[PsfValidateLanguageMode()]
		$ConfigurationSettings,
		
		[switch]
		$EnableException
	)
	
	if ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name))
	{
		return
	}
	
	if ($ConfigurationSettings) { & $ConfigurationSettings }
	if (Test-PSFParameterBinding -ParameterName Enabled)
	{
		Set-PSFConfig -FullName "LoggingProvider.$Name.Enabled" -Value $Enabled.ToBool() -DisableHandler
	}
	
	switch ($PSCmdlet.ParameterSetName)
	{
		#region Implement Version 1 Logging Provider (legacy)
		'Version1'
		{
			$provider = New-Object PSFramework.Logging.Provider
			$provider.Name = $Name
			$provider.BeginEvent = $BeginEvent
			$provider.StartEvent = $StartEvent
			$provider.MessageEvent = $MessageEvent
			$provider.ErrorEvent = $ErrorEvent
			$provider.EndEvent = $EndEvent
			$provider.FinalEvent = $FinalEvent
			$provider.ConfigurationParameters = $ConfigurationParameters
			$provider.ConfigurationScript = $ConfigurationScript
			$provider.IsInstalledScript = $IsInstalledScript
			$provider.InstallationScript = $InstallationScript
			$provider.InstallationParameters = $InstallationParameters
			
			$provider.IncludeModules = Get-PSFConfigValue -FullName "LoggingProvider.$Name.IncludeModules" -Fallback @()
			$provider.ExcludeModules = Get-PSFConfigValue -FullName "LoggingProvider.$Name.ExcludeModules" -Fallback @()
			$provider.IncludeTags = Get-PSFConfigValue -FullName "LoggingProvider.$Name.IncludeTags" -Fallback @()
			$provider.ExcludeTags = Get-PSFConfigValue -FullName "LoggingProvider.$Name.ExcludeTags" -Fallback @()
			
			$provider.InstallationOptional = Get-PSFConfigValue -FullName "LoggingProvider.$Name.InstallOptional" -Fallback $false
			
			[PSFramework.Logging.ProviderHost]::Providers[$Name] = $provider
		}
		#endregion Implement Version 1 Logging Provider (legacy)
		
		#region Implement Version 2 Logging Provider
		'Version2'
		{
			# Initialize default config for logging providers
			Set-PSFConfig -Module LoggingProvider -Name "$Name.Enabled" -Value $false -Initialize -Validation "bool" -Description "Whether the logging provider should be enabled on registration"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.AutoInstall" -Value $false -Initialize -Validation "bool" -Description "Whether the logging provider should be installed on registration"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.InstallOptional" -Value $false -Initialize -Validation "bool" -Description "Whether installing the logging provider is mandatory, in order for it to be enabled"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.IncludeModules" -Value @() -Initialize -Validation "stringarray" -Description "Module whitelist. Only messages from listed modules will be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.ExcludeModules" -Value @() -Initialize -Validation "stringarray" -Description "Module blacklist. Messages from listed modules will not be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.IncludeFunctions" -Value @() -Initialize -Validation "stringarray" -Description "Function whitelist. Only messages from listed functions will be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.ExcludeFunctions" -Value @() -Initialize -Validation "stringarray" -Description "Function blacklist. Messages from listed functions will not be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.IncludeTags" -Value @() -Initialize -Validation "stringarray" -Description "Tag whitelist. Only messages with these tags will be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.ExcludeTags" -Value @() -Initialize -Validation "stringarray" -Description "Tag blacklist. Messages with these tags will not be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.IncludeRunspaces" -Value @() -Initialize -Validation "guidarray" -Description "Runpace whitelist. Only messages from listed runspace guids will be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.ExcludeRunspaces" -Value @() -Initialize -Validation "guidarray" -Description "Runpace blacklist. Messages from listed runspace guids will not be logged"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.IncludeWarning" -Value $true -Initialize -Validation "bool" -Description "Whether to log warning messages"
			Set-PSFConfig -Module LoggingProvider -Name "$Name.MinLevel" -Value 1 -Initialize -Validation "integer1to9" -Description "The minimum message level to include in logs. Lower means more important - eg: Verbose is level 5, Host is level 2. Levels range from 1 through 9, Warning level messages are not included in this scale."
			Set-PSFConfig -Module LoggingProvider -Name "$Name.MaxLevel" -Value 9 -Initialize -Validation "integer1to9" -Description "The maximum message level to include in logs. Lower means more important - eg: Verbose is level 5, Host is level 2. Levels range from 1 through 9, Warning level messages are not included in this scale."
			Set-PSFConfig -Module LoggingProvider -Name "$Name.RequiresInclude" -Value $false -Initialize -Validation "bool" -Description "Whether any include rule must exist - and be met - before a message is accepted for logging"
			
			# Initialize custom config defined by logging provider
			foreach ($property in $InstanceProperties)
			{
				Set-PSFConfig -FullName "$ConfigurationRoot.$property" -Value $ConfigurationDefaultValues[$property] -Initialize
			}
			
			$provider = New-Object PSFramework.Logging.ProviderV2
			$provider.Name = $Name
			$provider.ConfigurationRoot = $ConfigurationRoot.Trim('.')
			$provider.InstanceProperties = $InstanceProperties
			$provider.ConfigurationDefaultValues = $ConfigurationDefaultValues
			$provider.BeginEvent = $BeginEvent
			$provider.StartEvent = $StartEvent
			$provider.MessageEvent = $MessageEvent
			$provider.ErrorEvent = $ErrorEvent
			$provider.EndEvent = $EndEvent
			$provider.FinalEvent = $FinalEvent
			$provider.Functions = $FunctionDefinitions
			$provider.ConfigurationParameters = $ConfigurationParameters
			$provider.ConfigurationScript = $ConfigurationScript
			$provider.IsInstalledScript = $IsInstalledScript
			$provider.InstallationScript = $InstallationScript
			$provider.InstallationParameters = $InstallationParameters
			$provider.InstallationOptional = Get-PSFConfigValue -FullName "LoggingProvider.$Name.InstallOptional" -Fallback $false
			
			[PSFramework.Logging.ProviderHost]::Providers[$Name] = $provider
		}
		#endregion Implement Version 2 Logging Provider
	}
	
	
	try { if ($RegistrationEvent) { & $RegistrationEvent } }
	catch
	{
		$dummy = $null
		$null = [PSFramework.Logging.ProviderHost]::Providers.TryRemove($Name, [ref]$dummy)
		Stop-PSFFunction -String 'Register-PSFLoggingProvider.RegistrationEvent.Failed' -StringValues $Name -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'register'
		return
	}
	
	#region Auto-Install & Enable
	$shouldEnable = Get-PSFConfigValue -FullName "LoggingProvider.$Name.Enabled" -Fallback $false
	$isInstalled = $provider.IsInstalledScript.InvokeGlobal()
	
	if (-not $isInstalled -and (Get-PSFConfigValue -FullName "LoggingProvider.$Name.AutoInstall" -Fallback $false))
	{
		try
		{
			Install-PSFLoggingProvider -Name $Name -EnableException
			$isInstalled = $provider.IsInstalledScript.InvokeGlobal()
		}
		catch
		{
			if ($provider.InstallationOptional)
			{
				Write-PSFMessage -Level Warning -String 'Register-PSFLoggingProvider.Installation.Failed' -StringValues $Name -ErrorRecord $_ -Tag 'logging', 'provider', 'fail', 'install' -EnableException $EnableException
			}
			else
			{
				Stop-PSFFunction -String 'Register-PSFLoggingProvider.Installation.Failed' -StringValues $Name -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'install'
				return
			}
		}
	}
	
	if ($shouldEnable)
	{
		if ($isInstalled -or $provider.InstallationOptional) { $provider.Enabled = $true }
		else
		{
			Stop-PSFFunction -String 'Register-PSFLoggingProvider.NotInstalled.Termination' -StringValues $Name -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'install'
			return
		}
	}
	#endregion Auto-Install & Enable
}

function Remove-PSFLoggingProviderRunspace
{
<#
	.SYNOPSIS
		Removes a runspace from the list of dynamically included runspaces of an active logging provider instance.
	
	.DESCRIPTION
		Removes a runspace from the list of dynamically included runspaces of an active logging provider instance.
		See the help on Add-PSFLoggingProviderRunspace for details on how and why this is desirable.
	
	.PARAMETER ProviderName
		Name of the logging provider the instance is part of.
	
	.PARAMETER InstanceName
		Name of the logging provider instance to target.
		Default: "default"  (the instance created when you omit the instancename parameter on Set-PSFLoggingProvider)
	
	.PARAMETER Runspace
		The Runspace ID of the runspace to remove.
		Defaults to the current runspace.
	
	.EXAMPLE
		PS C:\> Remove-PSFLoggingProviderRunspace -ProviderName 'logfile' -InstanceName UpdateTask
	
		Removes the current runspace from the list of included runspaces on the logfile instance "UpdateTask".
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$ProviderName,
		
		[string]
		$InstanceName = 'default',
		
		[guid]
		$Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId
	)
	
	process
	{
		$instance = Get-PSFLoggingProviderInstance -ProviderName $ProviderName -Name $InstanceName
		if ($instance) {
			$instance.RemoveRunspace($Runspace)
		}
	}
}

function Set-PSFLoggingProvider
{
<#
	.SYNOPSIS
		Configures a logging provider.
	
	.DESCRIPTION
		This command allows configuring the way a logging provider works.
		This grants the ability to ...
		- Enable / Disable a provider
		- Set additional parameters defined by the provider (each provider may implement its own settings, exposed through dynamic parameters)
		- Configure filters about what messages get sent to a given provider.
	
	.PARAMETER Name
		The name of the provider to configure
	
	.PARAMETER InstanceName
		A description of the InstanceName parameter.
	
	.PARAMETER Enabled
		Whether the provider should be enabled or disabled.
	
	.PARAMETER IncludeModules
		Only messages from modules listed here will be logged.
		Exact match only, an empty list results in all modules being logged.
	
	.PARAMETER ExcludeModules
		Messages from excluded modules will not be logged using this provider.
		Overrides -IncludeModules in case of overlap.
	
	.PARAMETER IncludeFunctions
		Only messages from functions that match at least one entry noted here will be logged.
		Uses wildcard expressions.
	
	.PARAMETER ExcludeFunctions
		Messages from functions that match at least one entry noted here will NOT be logged.
		Uses wildcard expressions.
	
	.PARAMETER IncludeRunspaces
		Only messages that come from one of the defined runspaces will be logged.
	
	.PARAMETER ExcludeRunspaces
		Messages that come from one of the defined runspaces will NOT be logged.
	
	.PARAMETER IncludeTags
		Only messages containing the listed tags will be logged.
		Exact match only, only a single match is required for a message to qualify.
	
	.PARAMETER ExcludeTags
		Messages containing any of the listed tags will not be logged.
		Overrides -IncludeTags in case of overlap.
	
	.PARAMETER MinLevel
		The minimum level of a message that will be logged.
		Note: The lower the message level, the MORE important it is.
		Levels range from 1 through 9:
		- InternalComment: 9
		- Debug: 8
		- Verbose: 5
		- Host: 2
		- Critical: 1
		The level "Warning" is not represented on this scale.
	
	.PARAMETER MaxLevel
		The maximum level of a message that will be logged.
		Note: The lower the message level, the MORE important it is.
		Levels range from 1 through 9:
		- InternalComment: 9
		- Debug: 8
		- Verbose: 5
		- Host: 2
		- Critical: 1
		The level "Warning" is not represented on this scale.
	
	.PARAMETER RequiresInclude
		By default, messages will be written to a logging provider, unless a specific exclude rule was met or any include rule was not met.
		That means, if no exclude and include rules exist at a given time, all messages will be written to the logging provider instance.
		Setting this to true will instead require at least one include rule to exist - and be met - before logging a message.
		This is designed for in particular for runspace-bound logging providers, which might at runtime swiftly gain or lose included runspaces.
	
	.PARAMETER ExcludeWarning
		Whether to exclude warnings from the logging provider / instance.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Set-PSFLoggingProvider -Name filesystem -Enabled $false
		
		Disables the filesystem provider.
	
	.EXAMPLE
		PS C:\> Set-PSFLoggingProvider -Name filesystem -ExcludeModules "PSFramework"
		
		Prevents all messages from the PSFramework module to be logged to the file system
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFLoggingProvider')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias('Provider', 'ProviderName')]
		[string]
		$Name,
		
		[string]
		$InstanceName,
		
		[bool]
		$Enabled,
		
		[string[]]
		$IncludeModules,
		
		[string[]]
		$ExcludeModules,
		
		[string[]]
		$IncludeFunctions,
		
		[string[]]
		$ExcludeFunctions,
		
		[guid[]]
		$IncludeRunspaces,
		
		[guid[]]
		$ExcludeRunspaces,
		
		[string[]]
		$IncludeTags,
		
		[string[]]
		$ExcludeTags,
		
		[ValidateRange(1,9)]
		[int]
		$MinLevel,
		
		[ValidateRange(1, 9)]
		[int]
		$MaxLevel,
		
		[switch]
		$RequiresInclude,
		
		[switch]
		$ExcludeWarning,
		
		[switch]
		$EnableException
	)
	
	dynamicparam
	{
		if ($Name -and ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name)))
		{
			$provider = [PSFramework.Logging.ProviderHost]::Providers[$Name]
			$results = $provider.ConfigurationParameters.InvokeGlobal() | Where-Object { $_ -is [System.Management.Automation.RuntimeDefinedParameterDictionary] }
			if (-not $results) { $results = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary }
			
			#region Process V2 Properties
			# Since V1 Providers do not have the property, this loop will never execute for them
			foreach ($propertyName in $provider.InstanceProperties)
			{
				$parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
				$parameterAttribute.ParameterSetName = '__AllParameterSets'
				$attributesCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
				$attributesCollection.Add($parameterAttribute)
				$RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter($propertyName, [object], $attributesCollection)
				
				$results.Add($propertyName, $RuntimeParam)
			}
			#endregion Process V2 Properties
			
			$results
		}
	}
	
	begin
	{
		if (-not ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name)))
		{
			Stop-PSFFunction -String 'Set-PSFLoggingProvider.Provider.NotFound' -StringValues $Name -EnableException $EnableException -Category InvalidArgument -Target $Name
			return
		}
		
		$provider = [PSFramework.Logging.ProviderHost]::Providers[$Name]
		if ($InstanceName -and $provider.ProviderVersion -eq 'Version_1')
		{
			Stop-PSFFunction -String 'Set-PSFLoggingProvider.Provider.V1NoInstance' -StringValues $Name -EnableException $EnableException -Category InvalidArgument -Target $Name
			return
		}
		
		[PSFramework.Utility.UtilityHost]::ImportScriptBlock($provider.IsInstalledScript, $true)
		
		if ((-not $provider.Enabled) -and (-not $provider.IsInstalledScript.InvokeGlobal()) -and $Enabled)
		{
			Stop-PSFFunction -String 'Set-PSFLoggingProvider.Provider.NotInstalled' -StringValues $Name -EnableException $EnableException -Category InvalidOperation -Target $Name
			return
		}
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		$provider.ConfigurationScript.InvokeGlobal($PSBoundParameters)
		
		$instanceAffix = ''
		if ($InstanceName -and ($InstanceName -ne "Default")) { $instanceAffix = "$InstanceName." }
		
		#region V2 Instance Properties
		foreach ($propertyName in $provider.InstanceProperties)
		{
			$value = $provider.ConfigurationDefaultValues[$propertyName]
			$initialize = $true
			if (Test-PSFParameterBinding -ParameterName $propertyName)
			{
				$initialize = $false
				$value = $PSBoundParameters[$propertyName]
			}
			
			Set-PSFConfig -FullName "$($provider.ConfigurationRoot).$($instanceAffix)$($propertyName)" -Value $value -Initialize:$initialize
		}
		#endregion V2 Instance Properties
		
		#region Filter Configuration
		$setProperty = -not $InstanceName -or $InstanceName -eq "Default"
		if (Test-PSFParameterBinding -ParameterName "IncludeModules")
		{
			if ($setProperty) { $provider.IncludeModules = $IncludeModules }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)IncludeModules" -Value $IncludeModules
		}
		if (Test-PSFParameterBinding -ParameterName "ExcludeModules")
		{
			if ($setProperty) { $provider.ExcludeModules = $ExcludeModules }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)ExcludeModules" -Value $ExcludeModules
		}
		
		if (Test-PSFParameterBinding -ParameterName "IncludeFunctions")
		{
			if ($setProperty) { $provider.IncludeFunctions = $IncludeFunctions }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)IncludeFunctions" -Value $IncludeFunctions
		}
		if (Test-PSFParameterBinding -ParameterName "ExcludeFunctions")
		{
			if ($setProperty) { $provider.ExcludeFunctions = $ExcludeFunctions }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)ExcludeFunctions" -Value $ExcludeFunctions
		}
		
		if (Test-PSFParameterBinding -ParameterName "IncludeRunspaces")
		{
			if ($setProperty) { $provider.IncludeRunspaces = $IncludeRunspaces }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)IncludeRunspaces" -Value $IncludeRunspaces
		}
		if (Test-PSFParameterBinding -ParameterName "ExcludeRunspaces")
		{
			if ($setProperty) { $provider.ExcludeRunspaces = $ExcludeRunspaces }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)ExcludeRunspaces" -Value $ExcludeRunspaces
		}
		
		if (Test-PSFParameterBinding -ParameterName "IncludeTags")
		{
			if ($setProperty) { $provider.IncludeTags = $IncludeTags }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)IncludeTags" -Value $IncludeTags
		}
		if (Test-PSFParameterBinding -ParameterName "ExcludeTags")
		{
			if ($setProperty) { $provider.ExcludeTags = $ExcludeTags }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)ExcludeTags" -Value $ExcludeTags
		}
		
		if ($MinLevel)
		{
			if ($setProperty) { $provider.MinLevel = $MinLevel }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)MinLevel" -Value $MinLevel
		}
		if ($MaxLevel)
		{
			if ($setProperty) { $provider.MaxLevel = $MaxLevel }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)MaxLevel" -Value $MaxLevel
		}
		if (Test-PSFParameterBinding -ParameterName "ExcludeWarning")
		{
			if ($setProperty) { $provider.IncludeWarning = -not $ExcludeWarning }
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)IncludeWarning" -Value (-not $ExcludeWarning)
		}
		
		# V2 Only
		if (Test-PSFParameterBinding -ParameterName "RequiresInclude"){
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)RequiresInclude" -Value $RequiresInclude
		}
		#endregion Filter Configuration
		
		if (Test-PSFParameterBinding -ParameterName "Enabled")
		{
			Set-PSFConfig -FullName "LoggingProvider.$($provider.Name).$($instanceAffix)Enabled" -Value $Enabled
			if ($provider.ProviderVersion -eq 'Version_1') { $provider.Enabled = $Enabled }
			elseif ($provider.Instances[$InstanceName])
			{
				$provider.Instances[$InstanceName].Enabled = $Enabled
			}
		}
	}
}


function Get-PSFMessage
{
	<#
		.SYNOPSIS
			Returns log entries for the PSFramework
		
		.DESCRIPTION
			Returns log entries for the PSFramework. Handy when debugging or developing a script using it.
		
		.PARAMETER FunctionName
			Default: "*"
			Only messages written by similar functions will be returned.
		
		.PARAMETER ModuleName
			Default: "*"
			Only messages written by commands from similar modules will be returned.
		
		.PARAMETER Target
			Only messages handling the specified target will be returned.
		
		.PARAMETER Tag
			Only messages containing one of these tags will be returned.
		
		.PARAMETER Last
			Only messages written by the last X executions will be returned.
			Uses Get-History to determine execution. Ignores Get-PSFmessage commands.
			By default, this will also include messages from other runspaces. If your command executes in parallel, that's useful.
			If it doesn't and you were offloading executions to other runspaces, consider also filtering by runspace using '-Runspace'
		
		.PARAMETER Skip
			How many executions to skip when specifying '-Last'.
			Has no effect without the '-Last' parameter.
		
		.PARAMETER Runspace
			The guid of the runspace to return messages from.
			By default, messages from all runspaces are returned.
			Run the following line to see the list of guids:
	
			Get-Runspace | ft Id, Name, InstanceId -Autosize
	
		.PARAMETER Level
			Limit the message selection by level.
			Message levels have a numeric value, making it easier to select a range:
			
			  -Level (1..6)
	
			Will select the first 6 levels (Critical - SomewhatVerbose).
		
		.PARAMETER Errors
			Instead of log entries, the error entries will be retrieved
		
		.EXAMPLE
			Get-PSFMessage
			
			Returns all log entries currently in memory.
	
		.EXAMPLE
			Get-PSFMessage -Target "a" -Last 1 -Skip 1
	
			Returns all log entries that targeted the object "a" in the second last execution sent.
	
		.EXAMPLE
			Get-PSFMessage -Tag "fail" -Last 5
	
			Returns all log entries within the last 5 executions that contained the tag "fail"
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFMessage')]
	param (
		[string]
		$FunctionName = "*",
		
		[string]
		$ModuleName = "*",
		
		[AllowNull()]
		$Target,
		
		[string[]]
		$Tag,
		
		[int]
		$Last,
		
		[int]
		$Skip = 0,
		
		[guid]
		$Runspace,
		
		[PSFramework.Message.MessageLevel[]]
		$Level,
		
		[switch]
		$Errors
	)
	
	process
	{
		if ($Errors) { $messages = [PSFramework.Message.LogHost]::GetErrors() | Where-Object { ($_.FunctionName -like $FunctionName) -and ($_.ModuleName -like $ModuleName) } }
		else { $messages = [PSFramework.Message.LogHost]::GetLog() | Where-Object { ($_.FunctionName -like $FunctionName) -and ($_.ModuleName -like $ModuleName) } }
		
		if (Test-PSFParameterBinding -ParameterName Target)
		{
			$messages = $messages | Where-Object TargetObject -EQ $Target
		}
		
		if (Test-PSFParameterBinding -ParameterName Tag)
		{
			$messages = $messages | Where-Object { $_.Tags | Where-Object { $_ -in $Tag } }
		}
		
		if (Test-PSFParameterBinding -ParameterName Runspace)
		{
			$messages = $messages | Where-Object Runspace -EQ $Runspace
		}
		
		if (Test-PSFParameterBinding -ParameterName Last)
		{
			$history = Get-History | Where-Object CommandLine -NotLike "Get-PSFMessage*" | Select-Object -Last $Last -Skip $Skip
			if ($history)
			{
				$start = $history[0].StartExecutionTime
				$end = $history[-1].EndExecutionTime
				
				$messages = $messages | Where-Object {
					($_.Timestamp -ge $start) -and ($_.Timestamp -le $end) -and ($_.Runspace -eq ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId))
				}
			}
		}
		
		if (Test-PSFParameterBinding -ParameterName Level)
		{
			$messages = $messages | Where-Object Level -In $Level
		}
		
		return $messages
	}
}

function Get-PSFMessageLevelModifier
{
<#
	.SYNOPSIS
		Returns all registered message level modifiers with similar name.
	
	.DESCRIPTION
		Returns all registered message level modifiers with similar name.
	
		Message level modifiers are created using New-PSFMessageLevelModifier and allow dynamically modifying the actual message level written by commands.
	
	.PARAMETER Name
		Default: "*"
		A name filter - only commands that are similar to the filter will be returned.
	
	.EXAMPLE
		PS C:\> Get-PSFMessageLevelModifier
	
		Returns all message level filters
	
	.EXAMPLE
		PS C:\> Get-PSFmessageLevelModifier -Name "mymodule.*"
	
		Returns all message level filters that start with "mymodule."
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFMessageLevelModifier')]
	Param (
		[string]
		$Name = "*"
	)
	
	([PSFramework.Message.MessageHost]::MessageLevelModifiers.Values) | Where-Object Name -Like $Name
}

function New-PSFMessageLevelModifier
{
	<#
		.SYNOPSIS
			Allows modifying message levels by powerful filters.
		
		.DESCRIPTION
			Allows modifying message levels by powerful filters.
			
			This is designed to allow a developer to have more control over what is written how during the development process.
			It also allows a debug user to fine tune what he is shown.
			
			This functionality is NOT designed for default implementation within a module.
			Instead, set healthy message levels for your own messages and leave others to tend to their own levels.
		
			Note:
			Adding too many level modifiers may impact performance, use with discretion.
		
		.PARAMETER Name
			The name of the level modifier.
			Can be arbitrary, but must be unique. Not case sensitive.
		
		.PARAMETER Modifier
			The level modifier to apply.
			- Use a negative value to make a message more relevant
			- Use a positive value to make a message less relevant
			While not limited to this range, the original levels range from 1 through 9:
			- 1-3 : Written to host and debug by default
			- 4-6 : Written to verbose and debug by default
			- 7-9 : Internas, written only to debug
		
		.PARAMETER IncludeFunctionName
			Only messages from functions with one of these exact names will be considered.
		
		.PARAMETER ExcludeFunctionName
			Messages from functions with one of these exact names will be ignored.
		
		.PARAMETER IncludeModuleName
			Only messages from modules with one of these exact names will be considered.
		
		.PARAMETER ExcludeModuleName
			Messages from module with one of these exact names will be ignored.
		
		.PARAMETER IncludeTags
			Only messages that contain one of these tags will be considered.
		
		.PARAMETER ExcludeTags
			Messages that contain one of these tags will be ignored.
		
		.PARAMETER EnableException
			This parameters disables user-friendly warnings and enables the throwing of exceptions.
			This is less user friendly, but allows catching exceptions in calling scripts.
		
		.EXAMPLE
			PS C:\> New-PSFMessageLevelModifier -Name 'MyModule-Include' -Modifier -9 -IncludeModuleName MyModule
			PS C:\> New-PSFMessageLevelModifier -Name 'MyModule-Exclude' -Modifier 9 -ExcludeModuleName MyModule
			
			These settings will cause all messages from the module 'MyModule' to be highly prioritized and almost certainly written to host.
			It will also make it highly unlikely, that messages from other modules will even be considered for anything but the lowest level.
			
			This is useful when prioritizing your own module during development.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/New-PSFMessageLevelModifier')]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[int]
		$Modifier,
		
		[string]
		$IncludeFunctionName,
		
		[string]
		$ExcludeFunctionName,
		
		[string]
		$IncludeModuleName,
		
		[string]
		$ExcludeModuleName,
		
		[string[]]
		$IncludeTags,
		
		[string[]]
		$ExcludeTags,
		
		[switch]
		$EnableException
	)
	
	process
	{
		if (Test-PSFParameterBinding -ParameterName IncludeFunctionName, ExcludeFunctionName, IncludeModuleName, ExcludeModuleName, IncludeTags, ExcludeTags -Not)
		{
			Stop-PSFFunction -Message "Must specify at least one condition in order to apply message level modifier!" -EnableException $EnableException -Category InvalidArgument -Tag 'fail', 'argument', 'message', 'level'
			return
		}
		
		$properties = $PSBoundParameters | ConvertTo-PSFHashtable -Include Name, Modifier, IncludeFunctionName, ExcludeFunctionName, IncludeModuleName, ExcludeModuleName, IncludeTags, ExcludeTags
		$levelModifier = New-Object PSFramework.Message.MessageLevelModifier -Property $properties
		
		[PSFramework.Message.MessageHost]::MessageLevelModifiers[$levelModifier.Name] = $levelModifier
		
		$levelModifier
	}
}

function Register-PSFMessageEvent
{
	<#
		.SYNOPSIS
			Registers an event to when a message is written.
		
		.DESCRIPTION
			Registers an event to when a message is written.
			These events will fire whenever the written message fulfills the specified filter criteria.
	
			This allows integrating direct alerts and reactions to messages as they occur.
	
			Warnings:
			- Adding many subscriptions can impact overall performance, even without triggering.
			- Events are executed synchronously. executing complex operations may introduce a significant delay to the command execution.
	
			It is recommended to push processing that involves outside resources to a separate runspace, then use the event to pass the object as trigger.
			The TaskEngine component may prove to be just what is needed to accomplish this.
		
		.PARAMETER Name
			The name of the subscription.
			Each subscription must have a name, subscriptions of equal name will overwrite each other.
			This is in order to avoid having runspace uses explode the number of subscriptions on each invocation.
		
		.PARAMETER ScriptBlock
			The scriptblock to execute.
			It will receive the message entry (as returned by Get-PSFMessage) as its sole argument.
		
		.PARAMETER MessageFilter
			Filter by message content. Understands wildcards, but not regex.
		
		.PARAMETER ModuleNameFilter
			Filter by Name of the module, from which the message comes. Understands wildcards, but not regex.
		
		.PARAMETER FunctionNameFilter
			Filter by Name of the function, from which the message comes. Understands wildcards, but not regex.
		
		.PARAMETER TargetFilter
			Filter by target object. Performs equality comparison on an object level.
		
		.PARAMETER LevelFilter
			Include only messages of the specified levels.
		
		.PARAMETER TagFilter
			Only include messages with any of the specified tags.
		
		.PARAMETER RunspaceFilter
			Only include messages which were written by the specified runspace.
			You can find out the current runspace ID by running this:
			  [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId
			You can retrieve the primary runspace - the Guid used by the runspace the user sees - by running this:
			  [PSFramework.Utility.UtilityHost]::PrimaryRunspace
		
		.EXAMPLE
			PS C:\> Register-PSFMessageEvent -Name 'Mymodule.OffloadTrigger' -ScriptBlock $ScriptBlock -Tag 'engine' -Module 'MyModule' -Level Warning
	
			Registers an event subscription ...
			- Under the name 'Mymodule.OffloadTrigger' ...
			- To execute $ScriptBlock ...
			- Whenever a message is written with the tag 'engine' by the module 'MyModule' at the level 'Warning'
	#>
	[CmdletBinding(PositionalBinding = $false, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFMessageEvent')]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$ScriptBlock,
		
		[string]
		$MessageFilter,
		
		[string]
		$ModuleNameFilter,
		
		[string]
		$FunctionNameFilter,
		
		$TargetFilter,
		
		[PSFramework.Message.MessageLevel[]]
		$LevelFilter,
		
		[string[]]
		$TagFilter,
		
		[System.Guid]
		$RunspaceFilter
	)
	
	process
	{
		$properties = $PSBoundParameters | ConvertTo-PSFHashtable -Include Name, ScriptBlock, MessageFilter, ModuleNameFilter, FunctionNameFilter, TargetFilter, LevelFilter, TagFilter, RunspaceFilter
		$eventSubscription = New-Object PSFramework.Message.MessageEventSubscription -Property $properties
		
		[PSFramework.Message.MessageHost]::Events[$Name] = $eventSubscription
	}
}

function Register-PSFMessageTransform
{
	<#
		.SYNOPSIS
			Registers a scriptblock that can transform message content.
		
		.DESCRIPTION
			Registers a scriptblock that can transform message content.
			This can be used to convert some kinds of input. Specifically:
			
			Target:
			When specifying a target, this target may require some conversion.
			For example, an object containing a live connection may need to have a static copy stored instead,
			as otherwise its export on a different runspace may cause access violations.
			
			Exceptions:
			Some exceptions may need transforming.
			For example some APIs might wrap the actual exception into a common wrapper.
			In this scenario you may want the actual exception in order to provide more specific information.
			
			In all instances, the scriptblock will be called, receiving only the relevant object as its sole input.
			
			Note: This transformation is performed synchronously on the active runspace. Complex scriptblocks may delay execution times when a matching object is passed.
		
		.PARAMETER TargetType
			The full typename of the target object to apply the scriptblock to.
			All objects of that typename will be processed through that scriptblock.
		
		.PARAMETER ExceptionType
			The full typename of the exception object to apply the scriptblock to.
			All objects of that typename will be processed through that scriptblock.
			Note: In case of error records, the type of the Exception Property is inspected. The error record as a whole will not be touched, except for having its exception exchanged.
		
		.PARAMETER ScriptBlock
			The scriptblock that performs the transformation.
		
		.PARAMETER TargetTypeFilter
			A filter for the typename of the target object to transform.
			Supports wildcards, but not regex.
			WARNING: Adding too many filter-type transforms may impact overall performance, try to avoid using them!
		
		.PARAMETER ExceptionTypeFilter
			A filter for the typename of the exception object to transform.
			Supports wildcards, but not regex.
			WARNING: Adding too many filter-type transforms may impact overall performance, try to avoid using them!
		
		.PARAMETER FunctionNameFilter
			Default: "*"
			Allows filtering by function name, in order to consider whether the function is affected.
			Supports wildcards, but not regex.
			WARNING: Adding too many filter-type transforms may impact overall performance, try to avoid using them!
		
		.PARAMETER ModuleNameFilter
			Default: "*"
			Allows filtering by module name, in order to consider whether the function is affected.
			Supports wildcards, but not regex.
			WARNING: Adding too many filter-type transforms may impact overall performance, try to avoid using them!
		
		.EXAMPLE
			PS C:\> Register-PSFMessageTransform -TargetType 'mymodule.category.classname' -ScriptBlock $ScriptBlock
			
			Whenever a target object of type 'mymodule.category.classname' is specified, invoke $ScriptBlock (with the object as sole argument) and store the result as target instead.
		
		.EXAMPLE
			PS C:\> Register-PSFMessageTransform -ExceptionType 'mymodule.category.exceptionname' -ScriptBlock $ScriptBlock
			
			Whenever an exception or error record of type 'mymodule.category.classname' is specified, invoke $ScriptBlock (with the object as sole argument) and store the result as exception instead.
			If the full error record is specified, only the updated exception will be inserted
	
		.EXAMPLE
			PS C:\> Register-PSFMessageTransform -TargetTypeFilter 'mymodule.category.*' -ScriptBlock $ScriptBlock
	
			Adds a transform for all target objects that are of a type whose full name starts with 'mymodule.category.'
			All target objects matching that typename will be run through the specified scriptblock, which in return generates the new target object.
	#>
	[CmdletBinding(PositionalBinding = $false, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFMessageTransform')]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = "Target")]
		[string]
		$TargetType,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Exception")]
		[string]
		$ExceptionType,
		
		[Parameter(Mandatory = $true)]
		[ScriptBlock]
		$ScriptBlock,
		
		[Parameter(Mandatory = $true, ParameterSetName = "TargetFilter")]
		[string]
		$TargetTypeFilter,
		
		[Parameter(Mandatory = $true, ParameterSetName = "ExceptionFilter")]
		[string]
		$ExceptionTypeFilter,
		
		[Parameter(ParameterSetName = "TargetFilter")]
		[Parameter(ParameterSetName = "ExceptionFilter")]
		$FunctionNameFilter = "*",
		
		[Parameter(ParameterSetName = "TargetFilter")]
		[Parameter(ParameterSetName = "ExceptionFilter")]
		$ModuleNameFilter = "*"
	)
	
	process
	{
		if ($TargetType) { [PSFramework.Message.MessageHost]::TargetTransforms[$TargetType] = $ScriptBlock }
		if ($ExceptionType) { [PSFramework.Message.MessageHost]::ExceptionTransforms[$ExceptionType] = $ScriptBlock }
		
		if ($TargetTypeFilter)
		{
			$condition = New-Object PSFramework.Message.TransformCondition($TargetTypeFilter, $ModuleNameFilter, $FunctionNameFilter, $ScriptBlock, "Target")
			[PSFramework.Message.MessageHost]::TargetTransformList.Add($condition)
		}
		
		if ($ExceptionTypeFilter)
		{
			$condition = New-Object PSFramework.Message.TransformCondition($ExceptionTypeFilter, $ModuleNameFilter, $FunctionNameFilter, $ScriptBlock, "Exception")
			[PSFramework.Message.MessageHost]::ExceptionTransformList.Add($condition)
		}
	}
}

function Remove-PSFMessageLevelModifier
{
	<#
		.SYNOPSIS
			Removes a message level modifier.
		
		.DESCRIPTION
			Removes a message level modifier.
	
			Message Level Modifiers can be created by using New-PSFMessageLevelModifier.
			They are used to emphasize or deemphasize messages, in order to help with debugging.
		
		.PARAMETER Name
			Name of the message level modifier to remove.
		
		.PARAMETER Modifier
			The actual modifier to remove, as returned by Get-PSFMessageLevelModifier.
		
		.PARAMETER EnableException
			This parameters disables user-friendly warnings and enables the throwing of exceptions.
			This is less user friendly, but allows catching exceptions in calling scripts.
		
		.EXAMPLE
			PS C:\> Get-PSFMessageLevelModifier | Remove-PSFMessageLevelModifier
	
			Removes all message level modifiers, restoring everything to their default levels.
	
		.EXAMPLE
			PS C:\> Remove-PSFMessageLevelModifier -Name "mymodule.foo"
	
			Removes the message level modifier named "mymodule.foo"
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Remove-PSFMessageLevelModifier')]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true)]
		[PSFramework.Message.MessageLevelModifier[]]
		$Modifier,
		
		[switch]
		$EnableException
	)
	
	process
	{
		foreach ($item in $Name)
		{
			if ($item -eq "PSFramework.Message.MessageLevelModifier") { continue }
			
			if ([PSFramework.Message.MessageHost]::MessageLevelModifiers.ContainsKey($item))
			{
				$dummy = $null
				$null = [PSFramework.Message.MessageHost]::MessageLevelModifiers.TryRemove($item, [ref] $dummy)
			}
			else
			{
				Stop-PSFFunction -Message "No message level modifier of name $item found!" -EnableException $EnableException -Category InvalidArgument -Tag 'fail','input','level','message' -Continue
			}
		}
		foreach ($item in $Modifier)
		{
			if ([PSFramework.Message.MessageHost]::MessageLevelModifiers.ContainsKey($item.Name))
			{
				$dummy = $null
				$null = [PSFramework.Message.MessageHost]::MessageLevelModifiers.TryRemove($item.Name, [ref]$dummy)
			}
			else
			{
				Stop-PSFFunction -Message "No message level modifier of name $($item.Name) found!" -EnableException $EnableException -Category InvalidArgument -Tag 'fail', 'input', 'level', 'message' -Continue
			}
		}
	}
}

function Wait-PSFMessage
{
<#
	.SYNOPSIS
		Waits until the PSFramework log queue has been flushed.
	
	.DESCRIPTION
		Waits until the PSFramework log queue has been flushed.
		Also supports ending the logging runspace.
	
		This is designed to explicitly handle script termination for tasks that run in custom hosts that do not properly fire runspace termination events, leading to infinitely hanging tasks.
	
	.PARAMETER Timeout
		Maximum duration for the command to wait until it terminates even if there are messages left.
	
	.PARAMETER Terminate
		If this parameter is specified it will terminate the running logging runspace.
		Use this if your script will run in a powershell host that does not properly execute termination events.
		Danger!!!! Should never be used in a script that might be called by other scripts, as this might prematurely end logging!
	
	.EXAMPLE
		PS C:\> Wait-PSFMessage
	
		Waits until all pending messages are logged.
	
	.EXAMPLE
		PS C:\> Wait-PSFMessage -Timeout 1m -Terminate
	
		Waits up to one minute for all messages to be flushed, then terminates the logging runspace
#>
	[CmdletBinding()]
	param (
		[PSFDateTime]
		$Timeout = "5m",
		
		[switch]
		$Terminate
	)
	
	begin
	{
		#region Helper Functions
		function Test-LogFlushed
		{
			[OutputType([bool])]
			[CmdletBinding()]
			param (
				
			)
			
			# Catch pending messages
			if ([PSFramework.Message.LogHost]::OutQueueLog.Count -gt 0) { return $false }
			if ([PSFramework.Message.LogHost]::OutQueueError.Count -gt 0) { return $false }
			
			# Catch whether currently processing a message
			if ([PSFramework.Logging.ProviderHost]::LoggingState -like 'Writing') { return $false }
			if ([PSFramework.Logging.ProviderHost]::LoggingState -like 'Initializing') { return $false }
			
			return $true
		}
		#endregion Helper Functions
	}
	process
	{
		if (([PSFramework.Message.LogHost]::OutQueueLog.Count -gt 0) -or ([PSFramework.Message.LogHost]::OutQueueError.Count -gt 0))
		{
			if ((Get-PSFRunspace -Name 'psframework.logging').State -notlike 'Running') { Start-PSFRunspace -Name 'psframework.logging' -NoMessage }
		}
		while ($Timeout.Value -gt (Get-Date))
		{
			if (Test-LogFlushed)
			{
				break
			}
			Start-Sleep -Milliseconds 50
		}
		
		if ($Terminate)
		{
			Stop-PSFRunspace -Name 'psframework.logging'
		}
	}
}

function Write-PSFHostColor
{
<#
	.SYNOPSIS
		Function that recognizes html-style tags to insert color into printed text.
	
	.DESCRIPTION
		Function that recognizes html-style tags to insert color into printed text.
		
		Color tags should be designed to look like this:
		<c="<console color>">Text</c>
		For example this would be a valid string:
		"This message should <c="red">partially be painted in red</c>!"
		
		This allows specifying color within strings and avoids having to piece together colored text in multiple calls to Write-Host.
		Only colors that are part of the ConsoleColor enumeration can be used. Bad colors will be ignored in favor of the default color.
	
	.PARAMETER String
		The message to write to host.
	
	.PARAMETER DefaultColor
		Default: (Get-DbaConfigValue -Name "message.infocolor")
		The color to write stuff to host in when no (or bad) color-code was specified.
	
	.PARAMETER NoNewLine
		Specifies that the content displayed in the console does not end with a newline character.
	
	.PARAMETER Level
		By default, all messages to Write-PSFHostColor will be printed to host.
		By specifying a level, it will only print the text if that level is within the range visible to the user.
	
		Visibility is controlled by the following two configuration settings:
		  psframework.message.info.maximum
		  psframework.message.info.minimum
	
	.EXAMPLE
		Write-PSFHostColor -String 'This is going to be <c="red">bloody red</c> text! And this is <c="green">green stuff</c> for extra color'
		
		Will print the specified line in multiple colors
	
	.EXAMPLE
		$string1 = 'This is going to be <c="red">bloody red</c> text! And this is <c="green">green stuff</c> for extra color'
		$string2 = '<c="red">bloody red</c> text! And this is <c="green">green stuff</c> for extra color'
		$string3 = 'This is going to be <c="red">bloody red</c> text! And this is <c="green">green stuff</c>'
		$string1, $string2, $string3 | Write-PSFHostColor -DefaultColor "Magenta"
		
		Will print all three lines, respecting the color-codes, but use the color "Magenta" as default color.
	
	.EXAMPLE
		$stringLong = @"
		Dear <c="red">Sirs</c><c="green"> and</c> <c="blue">Madams</c>,
		
		it has come to our attention that you are not sufficiently <c="darkblue">awesome!</c>
		Kindly improve your <c="yellow">AP</c> (<c="magenta">awesome-ness points</c>) by at least 50% to maintain you membership in Awesome Inc!
		
		You have <c="green">27 3/4</c> days time to meet this deadline. <c="darkyellow">After this we will unfortunately be forced to rend you assunder and sacrifice your remains to the devil</c>.
		
		Best regards,
		<c="red">Luzifer</c>
		"@
		Write-PSFHostColor -String $stringLong
		
		Will print a long multiline text in its entirety while still respecting the colorcodes
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Write-PSFHostColor')]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[string[]]
		$String,
		
		[ConsoleColor]
		$DefaultColor = (Get-PSFConfigValue -FullName "psframework.message.info.color"),
		
		[switch]
		$NoNewLine,
		
		[PSFramework.Message.MessageLevel]
		$Level
	)
	begin
	{
		$em = [PSFramework.Message.MessageHost]::InfoColorEmphasis
		$sub = [PSFramework.Message.MessageHost]::InfoColorSubtle
		
		$max_info = [PSFramework.Message.MessageHost]::MaximumInformation
		$min_info = [PSFramework.Message.MessageHost]::MinimumInformation
	}
	process
	{
		if ($Level)
		{
			if (($max_info -lt $Level) -or ($min_info -gt $Level)) { return }
		}
		
		foreach ($line in $String)
		{
			foreach ($row in $line.Split("`n")) #.Split([environment]::NewLine))
			{
				if ($row -notlike '*<c=["'']*["'']>*</c>*') { Microsoft.PowerShell.Utility\Write-Host -Object $row -ForegroundColor $DefaultColor -NoNewline:$NoNewLine }
				else
				{
					$row = $row -replace '<c=["'']em["'']>', "<c='$em'>" -replace '<c=["'']sub["'']>', "<c='$sub'>"
					$match = ($row | Select-String '<c=["''](.*?)["'']>(.*?)</c>' -AllMatches).Matches
					$index = 0
					$count = 0
					
					while ($count -le $match.Count)
					{
						if ($count -lt $Match.Count)
						{
							Microsoft.PowerShell.Utility\Write-Host -Object $row.SubString($index, ($match[$count].Index - $Index)) -ForegroundColor $DefaultColor -NoNewline
							try { Microsoft.PowerShell.Utility\Write-Host -Object $match[$count].Groups[2].Value -ForegroundColor $match[$count].Groups[1].Value -NoNewline -ErrorAction Stop }
							catch { Microsoft.PowerShell.Utility\Write-Host -Object $match[$count].Groups[2].Value -ForegroundColor $DefaultColor -NoNewline -ErrorAction Stop }
							
							$index = $match[$count].Index + $match[$count].Length
							$count++
						}
						else
						{
							Microsoft.PowerShell.Utility\Write-Host -Object $row.SubString($index) -ForegroundColor $DefaultColor -NoNewline:$NoNewLine
							$count++
						}
					}
				}
			}
		}
	}
}


function Write-PSFMessageProxy
{
<#
	.SYNOPSIS
		A proxy command that allows smoothly redirecting messages to Write-PSFMessage.
	
	.DESCRIPTION
		This function is designed to pick up the alias it was called by and to redirect the message that was sent to Write-PSFMessage.
		For example, by creating an alias for Write-Host pointing at 'Write-PSFMessageProxy' will cause it to redirect the message at 'Important' level (which is written to host by default, but also logged).
		
		By creating those aliases, it becomes easy to shift current scripts to use the logging, without having to actually update the code.
	
	.PARAMETER Message
		The message to write.
	
	.PARAMETER NoNewline
		Dummy parameter to make Write-Host redirection happy.
		IT WILL BE IGNORED!
	
	.PARAMETER Separator
		Dummy parameter to make Write-Host redirection happy.
		IT WILL BE IGNORED!
	
	.PARAMETER ForegroundColor
		Configure the foreground color for host messages.
	
	.PARAMETER BackgroundColor
		Dummy parameter to make Write-Host redirection happy.
		IT WILL BE IGNORED!
	
	.PARAMETER Tags
		Add tags to the messages.
	
	.EXAMPLE
		PS C:\> Write-PSFMessageProxy "Example Message"
		
		Will write the message "Example Message" to verbose.
	
	.EXAMPLE
		PS C:\> Set-Alias Write-Host Write-PSFMessageProxy
		PS C:\> Write-Host "Example Message"
		
		This will create an alias named "Write-Host" pointing at "Write-PSFMessageProxy".
		Then it will write the message "Example Message", which is automatically written to Level "Important" (which by default will be written to host).
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Write-PSFMessageProxy')]
	param (
		[Parameter(Position = 0)]
		[Alias('Object', 'MessageData')]
		[string]
		$Message,
		
		[switch]
		$NoNewline,
		
		$Separator,
		
		[System.ConsoleColor]
		$ForegroundColor,
		
		[System.ConsoleColor]
		$BackgroundColor,
		
		[string[]]
		$Tags = 'proxied'
	)
	
	begin
	{
		$call = (Get-PSCallStack)[0].InvocationInfo
		$callStack = (Get-PSCallStack)[1]
		$FunctionName = $callStack.Command
		$ModuleName = $callstack.InvocationInfo.MyCommand.ModuleName
		if (-not $ModuleName) { $ModuleName = "<Unknown>" }
		$File = $callStack.Position.File
		$Line = $callStack.Position.StartLineNumber
		
		$splatParam = @{
			Tag		     = $Tags
			FunctionName = $FunctionName
			ModuleName   = $ModuleName
			File		 = $File
			Line		 = $Line
		}
		
		# Adapt chosen forgroundcolor
		if (Test-PSFParameterBinding -ParameterName ForegroundColor)
		{
			$Message = "<c='$($ForegroundColor)'>{0}</c>" -f $Message
		}
	}
	process
	{
		switch ($call.InvocationName)
		{
			"Write-Host" { Write-PSFMessage -Level Important -Message $Message @splatParam }
			"Write-Verbose" { Write-PSFMessage -Level Verbose -Message $Message @splatParam }
			"Write-Warning" { Write-PSFMessage -Level Warning -Message $Message @splatParam }
			"Write-Debug" { Write-PSFMessage -Level System -Message $Message @splatParam }
			"Write-Information" { Write-PSFMessage -Level Important -Message $Message @splatParam }
			default { Write-PSFMessage -Level Verbose -Message $Message @splatParam }
		}
	}
}

function Get-PSFPipeline
{
<#
	.SYNOPSIS
		Generates meta-information for the pipeline from the calling command.
	
	.DESCRIPTION
		Generates meta-information for the pipeline from the calling command.
	
	.EXAMPLE
		PS C:\> Get-Pipeline
	
		Generates meta-information for the pipeline from the calling command.
#>
	[OutputType([PSFramework.Meta.Pipeline])]
	[CmdletBinding()]
	param (
		
	)
	
	begin
	{
		function Get-PrivateProperty
		{
			[CmdletBinding()]
			param (
				$Object,
				
				[string]
				$Name,
				
				[ValidateSet('Any', 'Field', 'Property')]
				[string]
				$Type = 'Any'
			)
			
			if ($null -eq $Object) { return }
			
			$typeObject = $Object.GetType()
			[System.Reflection.BindingFlags]$flags = "NonPublic, Instance"
			switch ($Type)
			{
				'Field'
				{
					$field = $typeObject.GetField($Name, $flags)
					$field.GetValue($Object)
				}
				'Property'
				{
					$property = $typeObject.GetProperty($Name, $flags)
					$property.GetValue($Object)
				}
				'Any'
				{
					$field = $typeObject.GetField($Name, $flags)
					if ($field) { return $field.GetValue($Object) }
					$property = $typeObject.GetProperty($Name, $flags)
					$property.GetValue($Object)
				}
			}
		}
	}
	process
	{
		$callerCmdlet = (Get-PSCallStack)[1].GetFrameVariables()["PSCmdlet"].Value
		
		$commandRuntime = Get-PrivateProperty -Object $callerCmdlet -Name _commandRuntime -Type Field
		$pipelineProcessor = Get-PrivateProperty -Object $commandRuntime -Name PipelineProcessor -Type Property
		$localPipeline = Get-PrivateProperty -Object $pipelineProcessor -Name LocalPipeline -Type Property
		
		$pipeline = New-Object PSFramework.Meta.Pipeline -Property @{
			InstanceId = $localPipeline.InstanceId
			StartTime  = Get-PrivateProperty -Object $localPipeline -Name _pipelineStartTime -Type Field
			Text	   = Get-PrivateProperty -Object $localPipeline -Name HistoryString -Type Property
			PipelineItem = $localPipeline
		}
		
		if ($pipeline.Text)
		{
			$tokens = $null
			$errorItems = $null
			$ast = [System.Management.Automation.Language.Parser]::ParseInput($pipeline.Text, [ref]$tokens, [ref]$errorItems)
			$pipeline.Ast = $ast
			
			$baseItem = $ast.EndBlock.Statements[0]
			if ($baseItem -is [System.Management.Automation.Language.AssignmentStatementAst])
			{
				$pipeline.OutputAssigned = $true
				$pipeline.OutputAssignedTo = $baseItem.Left
				$baseItem = $baseItem.Right.PipelineElements
			}
			else { $baseItem = $baseItem.PipelineElements }
			
			if ($baseItem[0] -is [System.Management.Automation.Language.CommandExpressionAst])
			{
				if ($baseItem[0].Expression -is [System.Management.Automation.Language.VariableExpressionAst])
				{
					$pipeline.InputFromVariable = $true
					$pipeline.InputVariable = $baseItem[0].Expression.VariablePath.UserPath
				}
				else { $pipeline.InputDirect = $true }
				if ($baseItem[0].Expression -is [System.Management.Automation.Language.ConstantExpressionAst])
				{
					$pipeline.InputValue = $baseItem[0].Expression.Value
				}
				elseif ($baseItem[0].Expression -is [System.Management.Automation.Language.ArrayLiteralAst])
				{
					$pipeline.InputValue = @()
					foreach ($element in $baseItem[0].Expression.Elements)
					{
						if ($element -is [System.Management.Automation.Language.ConstantExpressionAst])
						{
							$pipeline.InputValue += $element.Value
						}
						else { $pipeline.InputValue += $element }
					}
				}
				else { $pipeline.InputValue = $baseItem[0].Expression }
			}
		}
		
		$commands = Get-PrivateProperty -Object $pipelineProcessor -Name Commands -Type Property
		$index = 0
		foreach ($command in $commands)
		{
			$commandItem = Get-PrivateProperty -Object $command -Name Command
			$pipeline.Commands.Add((New-Object PSFramework.Meta.PipelineCommand($pipeline.InstanceId, $index, (Get-PrivateProperty -Object $command -Name CommandInfo), $commandItem.MyInvocation, $commandItem)))
			$index++
		}
		
		$pipeline
	}
}

function Clear-PSFResultCache
{
	<#
		.SYNOPSIS
			Clears the result cache
		
		.DESCRIPTION
			Clears the result cache, which can come in handy if you have a huge amount of data stored within and want to free the memory.
	
		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
		
		.EXAMPLE
			PS C:\> Clear-PSFResultCache
	
			Clears the result cache, freeing up any used memory.
	#>
	[CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess = $true, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Clear-PSFresultCache')]
	param (
		
	)
	
	process
	{
		if (Test-PSFShouldProcess -Target 'Result Cache' -ActionString 'Clear-PSFResultCache.Clear' -PSCmdlet $PSCmdlet)
		{
			[PSFramework.ResultCache.ResultCache]::Clear()
		}
	}
}

function Get-PSFResultCache
{
<#
	.SYNOPSIS
		Returns the last stored result
	
	.DESCRIPTION
		Functions that implement the result cache store their information in the cache. This can then be retrieved by the user running this command.
		This forgives the user for forgetting to store the output in a variable and is especially precious when running commands that take a while to execute.
	
	.PARAMETER Type
		Default: Value
		Options: All, Value
		By default, this function will return the output that was cached during the last execution. However, this mode can be switched:
		- All: Returns everything that has been cached. This includes the name of the command calling Set-PFSResultCache as well as the timestamp when it was called.
		- Value: Returns just the object(s) that were written to cache
	
	.EXAMPLE
		PS C:\> Get-PSFResultCache
	
		Returns the latest cached result.
	
	.EXAMPLE
		PS C:\> Get-PSFResultCache -Type 'All'
	
		Returns a meta-information object containing the last result, when it was written and which function did the writing.
#>
	
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFResultCache')]
	param (
		[ValidateSet('Value','All')]
		[string]
		$Type = 'Value'
	)
	
	switch ($Type)
	{
		'All'
		{
			[pscustomobject]@{
				Result    = ([PSFramework.ResultCache.ResultCache]::Result)
				Function  = ([PSFramework.ResultCache.ResultCache]::Function)
				Timestamp = ([PSFramework.ResultCache.ResultCache]::Timestamp)
			}
		}
		'Value'
		{
			[PSFramework.ResultCache.ResultCache]::Result
		}
	}
}
if (-not (Test-Path "alias:Get-LastResult")) { New-Alias -Name Get-LastResult -Value Get-PSFResultCache -Description "A more intuitive name for users to call Get-PSFResultCache" }
if (-not (Test-Path "alias:glr")) { New-Alias -Name glr -Value Get-PSFResultCache -Description "A faster name for users to call Get-PSFResultCache" }

function Set-PSFResultCache
{
<#
	.SYNOPSIS
		Stores a result in the result cache
	
	.DESCRIPTION
		Stores a result in the result cache.
		This function is designed for use in other functions, a user should never have cause to use it directly himself.
	
	.PARAMETER InputObject
		The value to store in the result cache.
	
	.PARAMETER DisableCache
		Allows you to control, whether the function actually writes to the cache. Useful when used in combination with -PassThru.
		Does not suppress output via -PassThru. However in combination, these two parameters make caching within a pipeline practical.
	
	.PARAMETER PassThru
		The objects that are being cached are passed through this function.
		By default, Set-PSFResultCache doesn't have any output.
	
	.PARAMETER CommandName
		Default: (Get-PSCallStack)[0].Command
		The name of the command that called Set-PSFResultCache.
		Is automatically detected and usually doesn't need to be changed.
	
	.EXAMPLE
		PS C:\> Set-PSFResultCache -InputObject $Results -DisableCache $NoRes
		
		Stores the contents of $Results in the result cache, but does nothing if $NoRes is $true (the default Switch-name for disabling the result cache)
	
	.EXAMPLE
		PS C:\> Get-ChildItem $path | Get-Acl | Set-PSFResultCache -DisableCache $NoRes -PassThru
		
		Gets all items in $Path, then retrieves each of their Acl, finally it stores those in the result cache (if it isn't disabled via $NoRes) and finally passes each Acl through for the user to see.
		This will return all objects, even if $NoRes is set to $True.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFResultCache')]
	param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[AllowEmptyCollection()]
		[AllowEmptyString()]
		[AllowNull()]
		[Alias('Value')]
		[Object]
		$InputObject,
		
		[boolean]
		$DisableCache = $false,
		
		[Switch]
		$PassThru,
		
		[string]
		$CommandName = (Get-PSCallStack)[0].Command
	)
	
	begin
	{
		$isPipeline = -not $PSBoundParameters.ContainsKey("InputObject")
		[PSFramework.ResultCache.ResultCache]::Function = $CommandName
		
		if ($isPipeline -and -not $DisableCache)
		{
			[PSFramework.ResultCache.ResultCache]::Result = [System.Collections.ArrayList]@()
		}
	}
	process
	{
		if (-not $DisableCache)
		{
			if ($isPipeline) { $null = [PSFramework.ResultCache.ResultCache]::Result.Add($InputObject) }
			else { [PSFramework.ResultCache.ResultCache]::Result = $InputObject }
		}
		if ($PassThru) { $InputObject }
	}
	end
	{
		if ($isPipeline -and -not $DisableCache)
		{
			[PSFramework.ResultCache.ResultCache]::Result = [PSFramework.ResultCache.ResultCache]::Result.ToArray()
		}
	}
}

function Get-PSFDynamicContentObject
{
<#
	.SYNOPSIS
		Retrieves a named value object that can be updated from another runspace.
	
	.DESCRIPTION
		Retrieves a named value object that can be updated from another runspace.
	
		This comes in handy to have a variable that is automatically updated.
		Use this function to receive an object under a given name.
		Use Set-PSFDynamicContentObject to update the value of the object.
	
		It matters not from what runspace you update the object.
	
		Note:
		When planning to use such an object, keep in mind that it can easily change its content at any given time.
	
	.PARAMETER Name
		The name of the object to retrieve.
		Will create an empty value object if the object doesn't already exist.
	
	.EXAMPLE
		PS C:\> Get-PSFDynamicContentObject -Name "Test"
	
		Returns the Dynamic Content Object named "test"
#>
	[OutputType([PSFramework.Utility.DynamicContentObject])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFDynamicContentObject')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string[]]
		$Name
	)
	
	process
	{
		foreach ($item in $Name)
		{
			[PSFramework.Utility.DynamicContentObject]::Get($Name)
		}
	}
}

function Get-PSFRunspace
{
<#
	.SYNOPSIS
		Returns registered runspaces.
	
	.DESCRIPTION
		Returns a list of runspaces that have been registered with the PSFramework
	
	.PARAMETER Name
		Default: "*"
		Only registered runspaces of similar names are returned.
	
	.EXAMPLE
		PS C:\> Get-PSFRunspace
	
		Returns all registered runspaces
	
	.EXAMPLE
		PS C:\> Get-PSFRunspace -Name 'mymodule.maintenance'
	
		Returns the runspace registered under the name 'mymodule.maintenance'
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFRunspace')]
	Param (
		[string]
		$Name = "*"
	)
	
	process
	{
		[PSFramework.Runspace.RunspaceHost]::Runspaces.Values | Where-Object Name -Like $Name
	}
}

function Register-PSFRunspace
{
<#
	.SYNOPSIS
		Registers a scriptblock to run in the background.
	
	.DESCRIPTION
		This function registers a scriptblock to run in separate runspace.
		This is different from most runspace solutions, in that it is designed for permanent background tasks that need to be done.
		It guarantees a single copy of the task to run within the powershell process, even when running the same module in many runspaces in parallel.
		
		The scriptblock must be built with some rules in mind, for details on using this system run:
		Get-Help about_psf_runspace
	
		Updating:
		If this function is called multiple times, targeting the same name, it will update the scriptblock.
		- If that scriptblock is the same as the previous scriptblock, nothing changes
		- If that scriptblock is different from the previous ones, it will be registered, but will not be executed right away!
		  Only after stopping and starting the runspace will it operate under the new scriptblock.
	
	.PARAMETER ScriptBlock
		The scriptblock to run in a dedicated runspace.
	
	.PARAMETER Name
		The name to register the scriptblock under.
	
	.PARAMETER NoMessage
		Setting this will prevent messages be written to the message / logging system.
		This is designed to make the PSFramework not flood the log on each import.
	
	.EXAMPLE
		PS C:\> Register-PSFRunspace -ScriptBlock $scriptBlock -Name 'mymodule.maintenance'
	
		Registers the script defined in $scriptBlock under the name 'mymodule.maintenance'
		It does not start the runspace yet. If it already exists, it will overwrite the scriptblock without affecting the running script.
	
	.EXAMPLE
		PS C:\> Register-PSFRunspace -ScriptBlock $scriptBlock -Name 'mymodule.maintenance'
		PS C:\> Start-PSFRunspace -Name 'mymodule.maintenance'
	
		Registers the script defined in $scriptBlock under the name 'mymodule.maintenance'
		Then it starts the runspace, running the registered $scriptBlock
#>
	[CmdletBinding(PositionalBinding = $false, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFRunspace')]
	param
	(
		[Parameter(Mandatory = $true)]
		[Scriptblock]
		$ScriptBlock,
		
		[Parameter(Mandatory = $true)]
		[String]
		$Name,
		
		[switch]
		$NoMessage
	)
	
	if ([PSFramework.Runspace.RunspaceHost]::Runspaces.ContainsKey($Name))
	{
		if (-not $NoMessage) { Write-PSFMessage -Level Verbose -String 'Register-PSFRunspace.Runspace.Updating' -StringValues $Name -Target $Name -Tag 'runspace', 'register' }
		[PSFramework.Runspace.RunspaceHost]::Runspaces[$Name].SetScript($ScriptBlock)
	}
	else
	{
		if (-not $NoMessage) { Write-PSFMessage -Level Verbose -String 'Register-PSFRunspace.Runspace.Creating' -StringValues $Name -Target $Name -Tag 'runspace', 'register' }
		[PSFramework.Runspace.RunspaceHost]::Runspaces[$Name] = New-Object PSFramework.Runspace.RunspaceContainer($Name, $ScriptBlock)
	}
}

function Set-PSFDynamicContentObject
{
<#
	.SYNOPSIS
		Updates a value object that can easily be accessed on another runspace.
	
	.DESCRIPTION
		Updates a value object that can easily be accessed on another runspace.
		
		The Dynamic Content Object system allows the user to easily have the content of a variable updated in the background.
		The update is performed by this very function.
	
	.PARAMETER Name
		The name of the value to update.
		Not case sensitive.
	
	.PARAMETER Object
		The value object to update
	
	.PARAMETER Value
		The value to apply
	
	.PARAMETER Queue
		Set the object to be a threadsafe queue.
		Safe to use in multiple runspaces in parallel.
		Will not apply changes if the current value is already such an object.
	
	.PARAMETER Stack
		Set the object to be a threadsafe stack.
		Safe to use in multiple runspaces in parallel.
		Will not apply changes if the current value is already such an object.
	
	.PARAMETER List
		Set the object to be a threadsafe list.
		Safe to use in multiple runspaces in parallel.
		Will not apply changes if the current value is already such an object.
	
	.PARAMETER Dictionary
		Set the object to be a threadsafe dictionary.
		Safe to use in multiple runspaces in parallel.
		Will not apply changes if the current value is already such an object.
	
	.PARAMETER PassThru
		Has the command returning the object just set.
	
	.PARAMETER Reset
		Clears the dynamic content object's collection objects.
		Use this to ensure the collection is actually empty.
		Only used in combination of either -Queue, -Stack, -List or -Dictionary.
	
	.EXAMPLE
		PS C:\> Set-PSFDynamicContentObject -Name Test -Value $Value
		
		Sets the Dynamic Content Object named "test" to the value $Value.
	
	.EXAMPLE
		PS C:\> Set-PSFDynamicContentObject -Name MyModule.Value -Queue
		
		Sets the Dynamic Content Object named "MyModule.Value" to contain a threadsafe queue.
		This queue will be safe to enqueue and dequeue from, no matter the number of runspaces accessing it simultaneously.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[OutputType([PSFramework.Utility.DynamicContentObject])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFDynamicContentObject')]
	Param (
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true)]
		[PSFramework.Utility.DynamicContentObject[]]
		$Object,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Value')]
		[AllowNull()]
		$Value = $null,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Queue')]
		[switch]
		$Queue,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Stack')]
		[switch]
		$Stack,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'List')]
		[switch]
		$List,
		
		[Parameter(Mandatory = $true, ParameterSetName = 'Dictionary')]
		[switch]
		$Dictionary,
		
		[switch]
		$PassThru,
		
		[switch]
		$Reset
	)
	
	process
	{
		foreach ($item in $Name)
		{
			if ($Queue) { [PSFramework.Utility.DynamicContentObject]::Set($item, $Value, 'Queue') }
			elseif ($Stack) { [PSFramework.Utility.DynamicContentObject]::Set($item, $Value, 'Stack') }
			elseif ($List) { [PSFramework.Utility.DynamicContentObject]::Set($item, $Value, 'List') }
			elseif ($Dictionary) { [PSFramework.Utility.DynamicContentObject]::Set($item, $Value, 'Dictionary') }
			else { [PSFramework.Utility.DynamicContentObject]::Set($item, $Value, 'Common') }
			
			if ($PassThru) { [PSFramework.Utility.DynamicContentObject]::Get($item) }
		}
		
		foreach ($item in $Object)
		{
			$item.Value = $Value
			if ($Queue) { $item.ConcurrentQueue($Reset) }
			if ($Stack) { $item.ConcurrentStack($Reset) }
			if ($List) { $item.ConcurrentList($Reset) }
			if ($Dictionary) { $item.ConcurrentDictionary($Reset) }
			
			if ($PassThru) { $item }
		}
	}
}

function Start-PSFRunspace
{
<#
	.SYNOPSIS
		Starts a runspace that was registered to the PSFramework
	
	.DESCRIPTION
		Starts a runspace that was registered to the PSFramework
		Simply registering does not automatically start a given runspace. Only by executing this function will it take effect.
	
	.PARAMETER Name
		The name of the registered runspace to launch
	
	.PARAMETER Runspace
		The runspace to launch. Returned by Get-PSFRunspace
	
	.PARAMETER NoMessage
		Setting this will prevent messages be written to the message / logging system.
		This is designed to make the PSFramework not flood the log on each import.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Start-PSFRunspace -Name 'mymodule.maintenance'
		
		Starts the runspace registered under the name 'mymodule.maintenance'
#>
	[CmdletBinding(SupportsShouldProcess = $true, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Start-PSFRunspace')]
	param (
		[Parameter(ValueFromPipeline = $true)]
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true)]
		[PSFramework.Runspace.RunspaceContainer[]]
		$Runspace,
		
		[switch]
		$NoMessage,
		
		[switch]
		$EnableException
	)
	
	process
	{
		foreach ($item in $Name)
		{
			# Ignore all output from Get-PSFRunspace - it'll be handled by the second loop
			if ($item -eq "psframework.runspace.runspacecontainer") { continue }
			
			if ([PSFramework.Runspace.RunspaceHost]::Runspaces.ContainsKey($item))
			{
				if ($PSCmdlet.ShouldProcess($item, "Starting Runspace"))
				{
					try
					{
						if (-not $NoMessage) { Write-PSFMessage -Level Verbose -String 'Start-PSFRunspace.Starting' -StringValues ($item) -Target $item -Tag "runspace", "start" }
						[PSFramework.Runspace.RunspaceHost]::Runspaces[$item].Start()
					}
					catch
					{
						Stop-PSFFunction -String 'Start-PSFRunspace.Starting.Failed' -StringValues $item -ErrorRecord $_ -EnableException $EnableException -Tag "fail", "argument", "runspace", "start" -Target $item -Continue
					}
				}
			}
			else
			{
				Stop-PSFFunction -String 'Start-PSFRunspace.UnknownRunspace' -StringValues $item -EnableException $EnableException -Category InvalidArgument -Tag "fail", "argument", "runspace", "start" -Target $item -Continue
			}
		}
		
		foreach ($item in $Runspace)
		{
			if ($PSCmdlet.ShouldProcess($item.Name, "Starting Runspace"))
			{
				try
				{
					if (-not $NoMessage) { Write-PSFMessage -Level Verbose -String 'Start-PSFRunspace.Starting' -StringValues $item.Name -Target $item -Tag "runspace", "start" }
					$item.Start()
				}
				catch
				{
					Stop-PSFFunction -String 'Start-PSFRunspace.Starting.Failed' -StringValues $item.Name -EnableException $EnableException -Tag "fail", "argument", "runspace", "start" -Target $item -Continue
				}
			}
		}
	}
}

function Stop-PSFRunspace
{
<#
	.SYNOPSIS
		Stops a runspace that was registered to the PSFramework
	
	.DESCRIPTION
		Stops a runspace that was registered to the PSFramework
		Will not cause errors if the runspace is already halted.
		
		Runspaces may not automatically terminate immediately when calling this function.
		Depending on the implementation of the scriptblock, this may in fact take a little time.
		If the scriptblock hasn't finished and terminated the runspace in a seemingly time, it will be killed by the system.
		This timeout is by default 30 seconds, but can be altered by using the Configuration System.
		For example, this line will increase the timeout to 60 seconds:
		Set-PSFConfig -FullName PSFramework.Runspace.StopTimeout -Value 60
	
	.PARAMETER Name
		The name of the registered runspace to stop
	
	.PARAMETER Runspace
		The runspace to stop. Returned by Get-PSFRunspace
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Stop-PSFRunspace -Name 'mymodule.maintenance'
		
		Stops the runspace registered under the name 'mymodule.maintenance'
	
	.NOTES
		Additional information about the function.
#>
	[CmdletBinding(SupportsShouldProcess = $true, HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Stop-PSFRunspace')]
	param (
		[Parameter(ValueFromPipeline = $true)]
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true)]
		[PSFramework.Runspace.RunspaceContainer[]]
		$Runspace,
		
		[switch]
		$EnableException
	)
	
	process
	{
		foreach ($item in $Name)
		{
			# Ignore all output from Get-PSFRunspace - it'll be handled by the second loop
			if ($item -eq "psframework.runspace.runspacecontainer") { continue }
			
			if ([PSFramework.Runspace.RunspaceHost]::Runspaces.ContainsKey($item))
			{
				if ($PSCmdlet.ShouldProcess($item, "Stopping Runspace"))
				{
					try
					{
						Write-PSFMessage -Level Verbose -String 'Stop-PSFRunspace.Stopping' -StringValues ($item) -Target $item -Tag "runspace", "stop"
						[PSFramework.Runspace.RunspaceHost]::Runspaces[$item].Stop()
					}
					catch
					{
						Stop-PSFFunction -String 'Stop-PSFRunspace.Stopping.Failed' -StringValues ($item) -EnableException $EnableException -Tag "fail", "argument", "runspace", "stop" -Target $item -Continue -ErrorRecord $_
					}
				}
			}
			else
			{
				Stop-PSFFunction -String 'Stop-PSFRunspace.UnknownRunspace' -StringValues ($item) -EnableException $EnableException -Category InvalidArgument -Tag "fail", "argument", "runspace", "stop" -Target $item -Continue
			}
		}
		
		foreach ($item in $Runspace)
		{
			if ($PSCmdlet.ShouldProcess($item.Name, "Stopping Runspace"))
			{
				try
				{
					Write-PSFMessage -Level Verbose -String 'Stop-PSFRunspace.Stopping' -StringValues $item.Name -Target $item -Tag "runspace", "stop"
					$item.Stop()
				}
				catch
				{
					Stop-PSFFunction -String 'Stop-PSFRunspace.Stopping.Failed' -StringValues $item.Name -EnableException $EnableException -Tag "fail", "argument", "runspace", "stop" -Target $item -Continue -ErrorRecord $_
				}
			}
		}
	}
}

function ConvertFrom-PSFClixml
{
<#
	.SYNOPSIS
		Converts data that was serialized from an object back into that object.
	
	.DESCRIPTION
		Converts data that was serialized from an object back into that object.
	
		Use Import-PSFclixml to restore objects serialized and written to file.
		This command is designed for converting serialized data in memory, for example to expand objects returned by a network api.
	
	.PARAMETER InputObject
		The serialized data to restore to objects.
	
	.EXAMPLE
		PS C:\> $data | ConvertFrom-PSFClixml
	
		Converts the data stored in $data back into objects
#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		$InputObject
	)
	
	begin
	{
		$byteList = New-Object System.Collections.ArrayList
		
		function Convert-Item
		{
			[CmdletBinding()]
			param (
				$Data
			)
			
			if ($Data -is [System.String])
			{
				try { [PSFramework.Serialization.ClixmlSerializer]::FromStringCompressed($Data) }
				catch { [PSFramework.Serialization.ClixmlSerializer]::FromString($Data) }
			}
			else
			{
				try { [PSFramework.Serialization.ClixmlSerializer]::FromByteCompressed($Data) }
				catch { [PSFramework.Serialization.ClixmlSerializer]::FromByte($Data) }
			}
		}
	}
	process
	{
		if ($InputObject -is [string]) { Convert-Item -Data $InputObject }
		elseif ($InputObject -is [System.Byte[]]) { Convert-Item -Data $InputObject }
		elseif ($InputObject -is [System.Byte]) { $null = $byteList.Add($InputObject) }
		else { Stop-PSFFunction -String 'ConvertFrom-PSFClixml.BadInput' -EnableException $true }
	}
	end
	{
		if ($byteList.Count -gt 0)
		{
			Convert-Item -Data ([System.Byte[]]$byteList.ToArray())
		}
	}
}

function ConvertTo-PSFClixml
{
<#
	.SYNOPSIS
		Converts an input object into a serialized string or byte array.
	
	.DESCRIPTION
		Converts an input object into a serialized string or byte array.
		Works analogous to Export-PSFClixml, only it does not require being written to file.
	
	.PARAMETER Depth
		Specifies how many levels of contained objects are included in the XML representation. The default value is 2.
	
	.PARAMETER InputObject
		The object(s) to serialize.
	
	.PARAMETER Style
		Whether to export as byte (better compression) or as string (often easier to transmit using other utilities/apis).
	
	.PARAMETER NoCompression
		By default, exported data is compressed, saving a lot of storage at the cost of some CPU cycles.
		This switch disables this compression, making string-style exports compatible with Import-Clixml.
	
	.EXAMPLE
		PS C:\> Get-ChildItem | ConvertTo-PSFClixml
	
		Scans all items in the current folder and then converts that into a compressed clixml string.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
	[CmdletBinding()]
	param (
		[int]
		$Depth,
		
		[Parameter(ValueFromPipeline = $true)]
		$InputObject,
		
		[PSFramework.Serialization.ClixmlDataStyle]
		$Style = 'String',
		
		[switch]
		$NoCompression
	)
	
	begin
	{
		$data = @()
	}
	process
	{
		$data += $InputObject
	}
	end
	{
		try
		{
			if ($Style -like 'Byte')
			{
				if ($NoCompression)
				{
					if ($Depth) { [PSFramework.Serialization.ClixmlSerializer]::ToByte($data, $Depth) }
					else { [PSFramework.Serialization.ClixmlSerializer]::ToByte($data) }
				}
				else
				{
					if ($Depth) { [PSFramework.Serialization.ClixmlSerializer]::ToByteCompressed($data, $Depth) }
					else { [PSFramework.Serialization.ClixmlSerializer]::ToByteCompressed($data) }
				}
			}
			else
			{
				if ($NoCompression)
				{
					if ($Depth) { [PSFramework.Serialization.ClixmlSerializer]::ToString($data, $Depth) }
					else { [PSFramework.Serialization.ClixmlSerializer]::ToString($data) }
				}
				else
				{
					if ($Depth) { [PSFramework.Serialization.ClixmlSerializer]::ToStringCompressed($data, $Depth) }
					else { [PSFramework.Serialization.ClixmlSerializer]::ToStringCompressed($data) }
				}
			}
		}
		catch
		{
			Stop-PSFFunction -String 'ConvertTo-PSFClixml.Conversion.Error' -ErrorRecord $_ -EnableException $true -Target $resolvedPath -Cmdlet $PSCmdlet
		}
	}
}

function Export-PSFClixml
{
<#
	.SYNOPSIS
		Writes objects to the filesystem.
	
	.DESCRIPTION
		Writes objects to the filesystem.
		In opposite to the default Export-Clixml cmdlet, this function offers data compression as the default option.
		
		Exporting to regular clixml is still supported though.
	
	.PARAMETER Path
		The path to write to.
	
	.PARAMETER Depth
		Specifies how many levels of contained objects are included in the XML representation. The default value is 2.
	
	.PARAMETER InputObject
		The object(s) to serialize.
	
	.PARAMETER Style
		Whether to export as byte (better compression) or as string (often easier to transmit using other utilities/apis).
	
	.PARAMETER NoCompression
		By default, exported data is compressed, saving a lot of storage at the cost of some CPU cycles.
		This switch disables this compression, making string-style exports compatible with Import-Clixml.
	
	.PARAMETER PassThru
		Passes all objects along the pipeline.
		By default, Export-PSFClixml does not produce output.
	
	.PARAMETER Encoding
		The encoding to use when using string-style export.
		By default, it exports as UTF8 encoding.
	
	.EXAMPLE
		PS C:\> Get-ChildItem | Export-PSFClixml -Path 'C:\temp\data.byte'
		
		Exports a list of all items in the current path as compressed binary file to C:\temp\data.byte
	
	.EXAMPLE
		PS C:\> Get-ChildItem | Export-PSFClixml -Path C:\temp\data.xml -Style 'String' -NoCompression
		
		Exports a list of all items in the current path as a default clixml readable by Import-Clixml
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Export-PSFClixml')]
	param (
		[PsfValidateScript('PSFramework.Validate.FSPath.FileOrParent', ErrorString = 'PSFramework.Validate.FSPath.FileOrParent')]
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Path,
		
		[int]
		$Depth,
		
		[Parameter(ValueFromPipeline = $true)]
		$InputObject,
		
		[PSFramework.Serialization.ClixmlDataStyle]
		$Style = 'Byte',
		
		[switch]
		$NoCompression,
		
		[switch]
		$PassThru,
		
		[PSFEncoding]
		$Encoding = (Get-PSFConfigValue -FullName 'PSFramework.Text.Encoding.DefaultWrite')
	)
	
	begin
	{
		try { $resolvedPath = Resolve-PSFPath -Path $Path -Provider FileSystem -SingleItem -NewChild }
		catch { Stop-PSFFunction -String 'Validate.FSPath.FileOrParent' -StringValues $Path -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_ }
		[System.Collections.ArrayList]$data = @()
	}
	process
	{
		$null = $data.Add($InputObject)
		if ($PassThru) { $InputObject }
	}
	end
	{
		try
		{
			Write-PSFMessage -Level Verbose -String 'Export-PSFClixml.Exporting' -StringValues $resolvedPath
			if ($Style -like 'Byte')
			{
				if ($NoCompression)
				{
					if ($Depth) { [System.IO.File]::WriteAllBytes($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToByte($data.ToArray(), $Depth))) }
					else { [System.IO.File]::WriteAllBytes($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToByte($data.ToArray()))) }
				}
				else
				{
					if ($Depth) { [System.IO.File]::WriteAllBytes($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToByteCompressed($data.ToArray(), $Depth))) }
					else { [System.IO.File]::WriteAllBytes($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToByteCompressed($data.ToArray()))) }
				}
			}
			else
			{
				if ($NoCompression)
				{
					if ($Depth) { [System.IO.File]::WriteAllText($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToString($data.ToArray(), $Depth)), $Encoding) }
					else { [System.IO.File]::WriteAllText($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToString($data.ToArray())), $Encoding) }
				}
				else
				{
					if ($Depth) { [System.IO.File]::WriteAllText($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToStringCompressed($data.ToArray(), $Depth)), $Encoding) }
					else { [System.IO.File]::WriteAllText($resolvedPath, ([PSFramework.Serialization.ClixmlSerializer]::ToStringCompressed($data.ToArray())), $Encoding) }
				}
			}
		}
		catch
		{
			Stop-PSFFunction -String 'Export-PSFClixml.Exporting.Failed' -ErrorRecord $_ -EnableException $true -Target $resolvedPath -Cmdlet $PSCmdlet
		}
	}
}

function Get-PSFTypeSerializationData
{
<#
	.SYNOPSIS
		Creates a type extension XML for serializing an object
	
	.DESCRIPTION
		Creates a type extension XML for serializing an object
		Use this to register a type with a type serializer, so it will retain its integrity across process borders.
	
		This is relevant in order to have an object retain its type when ...
		- sending it over PowerShell Remoting
		- writing it to file via Export-Clixml and reading it later via Import-Clixml
	
		Note:
		In the default serializer, all types registered must:
		- Have all public properties be read & writable (the write needs not do anything, but it must not throw an exception).
		- All non-public properties will be ignored.
		- Come from an Assembly with a static name (like an existing dll file, not compiled at runtime).
	
	.PARAMETER InputObject
		The type to serialize.
		- Accepts a type object
		- The string name of the type
		- An object, whose type will then be determined
	
	.PARAMETER Mode
		Whether all types listed should be generated as a single definition ('Grouped'; default) or as one definition per type.
		Since multiple files have worse performance, it is generally recommended to group them all in a single file.
	
	.PARAMETER Fragment
		By setting this, the type XML is emitted without the outer XML shell, containing only the <Type> node(s).
		Use this if you want to add the output to existing type extension xml.
	
	.PARAMETER Serializer
		The serializer to use for the conversion.
		By default, the PSFramework serializer is used, which should work well enough, but requires the PSFramework to be present.
	
	.PARAMETER Method
		The serialization method to use.
		By default, the PSFramework serialization method is used, which should work well enough, but requires the PSFramework to be present.
	
	.EXAMPLE
		PS C:\> Get-PSFTypeSerializationData -InputObject 'My.Custom.Type'
	
		Generates an XML text that can be used to register via Update-TypeData.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectUsageOfAssignmentOperator", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFTypeSerializationData')]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[object[]]
		$InputObject,
		
		[ValidateSet('Grouped','SingleItem')]
		[string]
		$Mode = "Grouped",
		
		[switch]
		$Fragment,
		
		[string]
		$Serializer = "PSFramework.Serialization.SerializationTypeConverter",
		
		[string]
		$Method = "GetSerializationData"
	)
	
	begin
	{
		#region XML builder functions
		function Get-XmlHeader
		{
			<#
				.SYNOPSIS
					Returns the header for a types XML file
			#>
			[OutputType([string])]
			[CmdletBinding()]
			Param (
				
			)
			
			@"
<?xml version="1.0" encoding="utf-8"?>
<Types>

"@
		}
		
		function Get-XmlBody
		{
			<#
				.SYNOPSIS
					Processes a type into proper XML
			#>
			[OutputType([string])]
			[CmdletBinding()]
			Param (
				[string]
				$Type,
				
				[string]
				$Serializer,
				
				[string]
				$Method
			)
			
			@"

  <!-- $Type -->
  <Type>
    <Name>Deserialized.$Type</Name>
    <Members>
      <MemberSet>
        <Name>PSStandardMembers</Name>
        <Members>
          <NoteProperty>
            <Name>
              TargetTypeForDeserialization
            </Name>
            <Value>
              $Type
            </Value>
          </NoteProperty>
        </Members>
      </MemberSet>
    </Members>
  </Type>
  <Type>
    <Name>$Type</Name>
    <Members>
      <CodeProperty IsHidden="true">
        <Name>SerializationData</Name>
        <GetCodeReference>
          <TypeName>$Serializer</TypeName>
          <MethodName>$Method</MethodName>
        </GetCodeReference>
      </CodeProperty>
    </Members>
    <TypeConverter>
      <TypeName>$Serializer</TypeName>
    </TypeConverter>
  </Type>

"@
		}
		
		function Get-XmlFooter
		{
			<#
				.SYNOPSIS
					Returns the footer for a types XML file
			#>
			[OutputType([string])]
			[CmdletBinding()]
			Param (
				
			)
			@"
</Types>
"@
		}
		#endregion XML builder functions
		
		$types = @()
		if ($Mode -eq 'Grouped')
		{
			if (-not $Fragment) { $xml = Get-XmlHeader }
			else { $xml = "" }
		}
	}
	process
	{
		foreach ($item in $InputObject)
		{
			if ($null -eq $item) { continue }
			$type = $null
			if ($res = $item -as [System.Type]) { $type = $res }
			else { $type = $item.GetType() }
			
			if ($type -in $types) { continue }
			
			switch ($Mode)
			{
				'Grouped' { $xml += Get-XmlBody -Method $Method -Serializer $Serializer -Type $type.FullName }
				'SingleItem'
				{
					if (-not $Fragment)
					{
						$xml = Get-XmlHeader
						$xml += Get-XmlBody -Method $Method -Serializer $Serializer -Type $type.FullName
						$xml += Get-XmlFooter
						$xml
					}
					else
					{
						Get-XmlBody -Method $Method -Serializer $Serializer -Type $type.FullName
					}
				}
			}
			
			$types += $type
		}
	}
	end
	{
		if ($Mode -eq 'Grouped')
		{
			if (-not $Fragment) { $xml += Get-XmlFooter }
			$xml
		}
	}
}

function Import-PSFClixml
{
<#
	.SYNOPSIS
		Imports objects serialized using Export-Clixml or Export-PSFClixml.
	
	.DESCRIPTION
		Imports objects serialized using Export-Clixml or Export-PSFClixml.
	
		It can handle compressed and non-compressed exports.
	
	.PARAMETER Path
		Path to the files to import.
	
	.PARAMETER Encoding
		Text-based files might be stored with any arbitrary encoding chosen.
		By default, this function assumes UTF8 encoding (the default export encoding for Export-PSFClixml).
	
	.EXAMPLE
		PS C:\> Import-PSFClixml -Path '.\object.xml'
	
		Imports the objects serialized to object.xml in the current folder.
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Import-PSFClixml')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('FullName')]
		[string[]]
		$Path,
		
		[PSFEncoding]
		$Encoding = (Get-PSFConfigValue -FullName 'psframework.text.encoding.defaultread' -Fallback 'utf-8')
	)
	
	process
	{
		try { $resolvedPath = Resolve-PSFPath -Path $Path -Provider FileSystem }
		catch { Stop-PSFFunction -String 'Import-PSFClixml.Path.Resolution' -StringValues $Path -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet -Target $Path }
		
		foreach ($pathItem in $resolvedPath)
		{
			if ((Get-Item $pathItem).PSIsContainer)
			{
				Stop-PSFFunction -String 'Import-PSFClixml.Path.NotFile' -StringValues $pathItem -EnableException $true -Target $pathItem
			}
			Write-PSFMessage -Level Verbose -String 'Import-PSFClixml.Processing' -StringValues $pathItem -Target $pathItem
			
			[byte[]]$bytes = [System.IO.File]::ReadAllBytes($pathItem)
			
			try { [PSFramework.Serialization.ClixmlSerializer]::FromByteCompressed($bytes) }
			catch
			{
				[string]$string = [System.IO.File]::ReadAllText($pathItem, $Encoding)
				try { [PSFramework.Serialization.ClixmlSerializer]::FromString($string) }
				catch
				{
					try { [PSFramework.Serialization.ClixmlSerializer]::FromStringCompressed($string) }
					catch
					{
						try { [PSFramework.Serialization.ClixmlSerializer]::FromByte($bytes) }
						catch
						{
							Stop-PSFFunction -String 'Import-PSFClixml.Conversion.Failed' -EnableException $true -Target $pathItem -Cmdlet $PSCmdlet
						}
					}
				}
				
			}
		}
	}
}

function Register-PSFTypeSerializationData
{
<#
	.SYNOPSIS
		Registers serialization xml Typedata.
	
	.DESCRIPTION
		Registers serialization xml Typedata.
		Use Get-PSFTypeSerializationData to generate such a string.
		When building a module, consider shipping that xml type extension in a dedicated file as part of the module and import it as part of the manifest's 'TypesToProcess' node.
	
	.PARAMETER TypeData
		The data to register.
		Generate with Get-PSFTypeSerializationData.
	
	.PARAMETER Path
		Where the file should be stored before appending.
		While type extensions can be added at runtime directly from memory, from file is more reliable.
		By default, a PSFramework path is chosen.
		The default path can be configured under the 'PSFramework.Serialization.WorkingDirectory' confguration setting.
	
	.EXAMPLE
		PS C:\> Get-PSFTypeSerializationData -InputObject 'My.Custom.Type' | Register-PSFTypeSerializationData
	
		Generates a custom type serialization xml and registers it.
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFTypeSerializationData')]
	Param (
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[string[]]
		$TypeData,
		
		[string]
		$Path = (Get-PSFConfigValue -FullName 'PSFramework.Serialization.WorkingDirectory' -Fallback $script:path_typedata)
	)
	
	begin
	{
		if (-not (Test-Path $Path -PathType Container))
		{
			$null = New-Item -Path $Path -ItemType Directory -Force
		}
	}
	process
	{
		foreach ($item in $TypeData)
		{
			$name = $item -split "`n" | Select-String "<Name>(.*?)</Name>" | Where-Object { $_ -notmatch "<Name>Deserialized.|<Name>PSStandardMembers</Name>|<Name>SerializationData</Name>" } | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
			$fullName = Join-Path $Path.Trim "$($name).Types.ps1xml"
			
			$item | Set-Content -Path $fullName -Force -Encoding UTF8
			Update-TypeData -AppendPath $fullName
		}
	}
}

function Register-PSFTeppArgumentCompleter
{
    <#
        .SYNOPSIS
            Registers a parameter for a prestored Tepp.
        
        .DESCRIPTION
            Registers a parameter for a prestored Tepp.
            This function allows easily registering a function's parameter for Tepp in the function-file, rather than in a centralized location.
        
        .PARAMETER Command
            Name of the command whose parameter should receive Tepp.
        
        .PARAMETER Parameter
            Name of the parameter that should be Tepp'ed.
        
        .PARAMETER Name
            Name of the Tepp Completioner to use.
			Use the same name as was assigned in Register-PSFTeppScriptblock (which needs to be called first).
        
        .EXAMPLE
            Register-PSFTeppArgumentCompleter -Command Get-Test -Parameter Example -Name MyModule.Example
    
            Registers the parameter 'Example' of the command 'Get-Test' to receive the tab completion registered to 'MyModule.Example'
    #>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFTeppArgumentCompleter')]
	Param (
		[Parameter(Mandatory = $true)]
		[string[]]
		$Command,
		
		[Parameter(Mandatory = $true)]
		[string[]]
		$Parameter,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)
	process
	{
		foreach ($Param in $Parameter)
		{
			$scriptBlock = [PSFramework.TabExpansion.TabExpansionHost]::Scripts[$Name].ScriptBlock
			if ([PSFramework.TabExpansion.TabExpansionHost]::Scripts[$Name].InnerScriptBlock)
			{
				[PSFramework.Utility.UtilityHost]::ImportScriptBlock($scriptBlock, $true)
			}
			Register-ArgumentCompleter -CommandName $Command -ParameterName $Param -ScriptBlock $scriptBlock
		}
	}
}

function Register-PSFTeppScriptblock
{
    <#
        .SYNOPSIS
            Registers a scriptblock under name, to later be available for TabExpansion.
        
        .DESCRIPTION
            Registers a scriptblock under name, to later be available for TabExpansion.
	
			This system supports two separate types of input: Full or Simple.
	
			Simple:
			The scriptblock simply must return string values.
			PSFramework will then do the rest of the processing when the user asks for tab completion.
			This is the simple-most way to implement tab completion, for a full example, look at the first example in this help.
	
			Full:
			A full scriptblock implements all that is needed to provide Tab Expansion.
			For more details and guidance, see the following concept help:
				Get-Help about_psf_tabexpansion
        
        .PARAMETER ScriptBlock
            The scriptblock to register.
        
        .PARAMETER Name
            The name under which the scriptblock should be registered.
			It is recommended to prefix the name with the module (e.g.: mymodule.<name>), as names are shared across all implementing modules.
	
		.PARAMETER Mode
			Whether the script provided is a full or simple scriptblock.
			By default, this function automatically detects this, but just in case, you can override this detection.
	
		.PARAMETER CacheDuration
			How long a tab completion result is valid.
			By default, PSFramework tab completion will run the scriptblock on each call.
			This can be used together with a background refresh mechanism to offload the cost of expensive queries into the background.
			See Set-PSFTeppResult for details on how to refresh the cache.
	
		.PARAMETER Global
			Whether the scriptblock should be executed in the global context.
			This parameter is needed to reliably execute in background runspaces, but means no direct access to module content.
	
		.EXAMPLE
			Register-PSFTeppScriptblock -Name "psalcohol-liquids" -ScriptBlock { "beer", "mead", "wine", "vodka", "whiskey", "rum" }
			Register-PSFTeppArgumentCompleter -Command Get-Alcohol -Parameter Type -Name "psalcohol-liquids"
	
			In step one we set a list of questionable liquids as the list of available beverages for parameter 'Type' on the command 'Get-Alcohol'
        
        .EXAMPLE
            Register-PSFTeppScriptblock -ScriptBlock $scriptBlock -Name MyFirstTeppScriptBlock
    
            Stores the scriptblock stored in $scriptBlock under the name "MyFirstTeppScriptBlock"
	
		.EXAMPLE
			$scriptBlock = { (Get-ChildItem (Get-PSFConfigValue -FullName mymodule.path.scripts -Fallback "$env:USERPROFILE\Documents\WindowsPowerShell\Scripts")).FullName }
			Register-PSFTeppScriptblock -Name mymodule-scripts -ScriptBlock $scriptBlock -Mode Simple
	
			Stores a simple scriptblock that will return a list of strings under the name "mymodule-scripts".
			The system will wrap all the stuff around this that is necessary to provide Tab Expansion and filter out output that doesn't fit the user input so far.
    #>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFTeppScriptblock')]
	Param (
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$ScriptBlock,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[PSFramework.TabExpansion.TeppScriptMode]
		$Mode = "Auto",
		
		[PSFramework.Parameter.TimeSpanParameter]
		$CacheDuration = 0,
		
		[switch]
		$Global
	)
	
	process
	{
		[PSFramework.TabExpansion.TabExpansionHost]::RegisterCompletion($Name, $ScriptBlock, $Mode, $CacheDuration, $Global)
	}
}


function Set-PSFTeppResult
{
<#
	.SYNOPSIS
		Refreshes the tab completion value cache.
	
	.DESCRIPTION
		Refreshes the tab completion value cache for the specified completion scriptblock.
	
		Tab Completion scriptblocks can be configured to retrieve values from a dedicated cache.
		This allows seamless background refreshes of completion data and eliminates all waits for the user.
	
	.PARAMETER TabCompletion
		The name of the completion script to set the last results for.
	
	.PARAMETER Value
		The values to set.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Set-PSFTeppResult -TabCompletion 'MyModule.Computer' -Value (Get-ADComputer -Filter *).Name
	
		Stores the names of all computers in AD into the tab completion cache of the completion scriptblock 'MyModule.Computer'
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFTeppResult')]
	param (
		[Parameter(Mandatory = $true)]
		[PSFramework.Validation.PsfValidateSetAttribute(ScriptBlock = { [PSFramework.TabExpansion.TabExpansionHost]::Scripts.Keys } )]
		[string]
		$TabCompletion,
		
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[string[]]
		$Value
	)
	
	process
	{
		if (Test-PSFShouldProcess -PSCmdlet $PSCmdlet -Target $TabCompletion -ActionString 'Set-PSFTeppResult.UpdateValue')
		{
			[PSFramework.TabExpansion.TabExpansionHost]::Scripts[$TabCompletion].LastResult = $Value
			[PSFramework.TabExpansion.TabExpansionHost]::Scripts[$TabCompletion].LastExecution = ([System.DateTime]::Now)
		}
	}
}

function Disable-PSFTaskEngineTask
{
<#
	.SYNOPSIS
		Disables a task registered to the PSFramework task engine.
	
	.DESCRIPTION
		Disables a task registered to the PSFramework task engine.
	
	.PARAMETER Name
		Name of the task to disable.
	
	.PARAMETER Task
		The task registered. Must be a task object returned by Get-PSFTaskEngineTask.
	
	.EXAMPLE
		PS C:\> Get-PSFTaskEngineTask -Name 'mymodule.maintenance' | Disable-PSFTaskEngineTask
		
		Disables the task named 'mymodule.maintenance'
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Disable-PSFTaskEngineTask')]
	param (
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true)]
		[PSFramework.TaskEngine.PsfTask[]]
		$Task
	)
	
	process
	{
		foreach ($item in $Task)
		{
			if ($item.Enabled)
			{
				Write-PSFMessage -Level Verbose -String 'Disable-PSFTaskEngineTask.Disabling' -StringValues $item.Name -Tag 'disable', 'taskengine', 'task'
				$item.Enabled = $false
			}
		}
		foreach ($taskName in $Name)
		{
			foreach ($taskObject in Get-PSFTaskEngineTask -Name $taskName)
			{
				Write-PSFMessage -Level Verbose -String 'Disable-PSFTaskEngineTask.Disabling' -StringValues $taskObject.Name -Tag 'disable', 'taskengine', 'task'
				$taskObject.Enabled = $false
			}
		}
	}
}

function Enable-PSFTaskEngineTask
{
	<#
		.SYNOPSIS
			Enables a task registered to the PSFramework task engine.
		
		.DESCRIPTION
			Enables a task registered to the PSFramework task engine.
	
			Note:
			Tasks are enabled by default. Use this function to re-enable a task disabled by Disable-PSFTaskEngineTask.
	
		.PARAMETER Name
			Name of the task to enable.
		
		.PARAMETER Task
			The task registered. Must be a task object returned by Get-PSFTaskEngineTask.
		
		.EXAMPLE
			PS C:\> Get-PSFTaskEngineTask -Name 'mymodule.maintenance' | Enable-PSFTaskEngineTask
	
			Enables the task named 'mymodule.maintenance'
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Enable-PSFTaskEngineTask')]
	param (
		[string[]]
		$Name,
		
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[PSFramework.TaskEngine.PsfTask[]]
		$Task
	)
	
	begin
	{
		$didSomething = $false
	}
	process
	{
		foreach ($item in $Task)
		{
			if (-not $item.Enabled)
			{
				Write-PSFMessage -Level Verbose -String 'Enable-PSFTaskEngineTask.Enable' -StringValues $item.Name -Tag 'enable', 'taskengine', 'task'
				$item.Enabled = $true
				$didSomething = $true
			}
		}
		
		foreach ($taskName in $Name)
		{
			foreach ($taskObject in Get-PSFTaskEngineTask -Name $taskName)
			{
				if (-not $taskObject.Enabled)
				{
					Write-PSFMessage -Level Verbose -String 'Enable-PSFTaskEngineTask.Enable' -StringValues $taskObject.Name -Tag 'enable', 'taskengine', 'task'
					$taskObject.Enabled = $true
					$didSomething = $true
				}
			}
		}
	}
	end
	{
		# If we enabled any task, start the runspace again, in case it isn't already running (no effect if it is)
		if ($didSomething) { Start-PSFRunspace -Name 'psframework.taskengine' }
	}
}

function Get-PSFTaskEngineCache
{
	<#
		.SYNOPSIS
			Retrieve values from the cache for a task engine task.
		
		.DESCRIPTION
			Retrieve values from the cache for a task engine task.
			Tasks scheduled under the PSFramework task engine do not have a way to directly pass information to the primary runspace.
			Using Set-PSFTaskEngineCache, they can store the information somewhere where the main runspace can retrieve it using this function.
		
		.PARAMETER Module
			The name of the module that generated the task.
			Use scriptname in case of using this within a script.
			Note: Must be the same as the name used within the task when calling 'Set-PSFTaskEngineCache'
		
		.PARAMETER Name
			The name of the task for which the cache is.
			Note: Must be the same as the name used within the task when calling 'Set-PSFTaskEngineCache'
		
		.EXAMPLE
			PS C:\> Get-PSFTaskEngineCache -Module 'mymodule' -Name 'maintenancetask'
	
			Retrieves the information stored under 'mymodule.maintenancetask'
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFTaskEngineCache')]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Module,
		
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name
	)
	
	process
	{
		$cacheItem = [PSFramework.TaskEngine.TaskHost]::GetCacheItem($Module, $Name)
		if (-not $cacheItem) { return }
		
		$value = $cacheItem.GetValue()
		if ($null -ne $value) { $value }
	}
}


function Get-PSFTaskEngineTask
{
	<#
		.SYNOPSIS
			Returns tasks registered for the task engine
		
		.DESCRIPTION
			Returns tasks registered for the task engine
		
		.PARAMETER Name
			Default: "*"
			Only tasks with similar names are returned.
		
		.EXAMPLE
			PS C:\> Get-PSFTaskEngineTask
	
			Returns all tasks registered to the task engine
	
		.EXAMPLE
			PS C:\> Get-PSFTaskEngineTask -Name 'mymodule.*'
	
			Returns all tasks registered to the task engine whose name starts with 'mymodule.'
			(It stands to reason that only tasks belonging to the module 'mymodule' would be returned that way)
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Get-PSFTaskEngineTask')]
	Param (
		[string]
		$Name = "*"
	)
	
	process
	{
		[PSFramework.TaskEngine.TaskHost]::Tasks.Values | Where-Object Name -Like $Name
	}
}

function Register-PSFTaskEngineTask
{
	<#
		.SYNOPSIS
			Allows scheduling PowerShell tasks, that are perfomed in the background.
		
		.DESCRIPTION
			Allows scheduling PowerShell tasks, that are perfomed in the background.
	
			All scriptblocks scheduled like this will be performed on a separate runspace.
			None of the scriptblocks will affect the main session (so you cannot manipulate variables, etc.)
	
			This system is designed for two use-cases:
			- Reducing module import time by off-loading expensive one-time actions (such as building a cache) in the background
			- Scheduling periodic script executions that should occur while the process is running (e.g.: continuous maintenance, cache updates, ...)
	
			It also avoids overloading the client computer by executing too many tasks at the same time, as multiple modules running code in the background might.
			Instead tasks that are due simultaneously are processed by priority.
		
		.PARAMETER Name
			The name of the task.
			Must be unique, otherwise it will update the existing task.
	
		.PARAMETER Description
			Description of the task.
			Helps documenting the task and what it is supposed to be doing.
		
		.PARAMETER ScriptBlock
			The task/scriptblock that should be performed as a background task.
		
		.PARAMETER Once
			Whether the task should be performed only once.
		
		.PARAMETER Interval
			The interval at which the task should be repeated.
		
		.PARAMETER Delay
			How far after the initial registration should the task script wait before processing this.
			This can be used to delay background stuff that should not content with items that would be good to have as part of the module import.
		
		.PARAMETER Priority
			How important is this task?
			If multiple tasks are due at the same maintenance cycle, the more critical one will be processed first.
	
		.PARAMETER ResetTask
			If the task already exists, it will be reset by setting this parameter (this switch is ignored when creating new tasks).
			This allows explicitly registering tasks for re-execution, even though they were set to execute once only.
		
		.PARAMETER EnableException
			This parameters disables user-friendly warnings and enables the throwing of exceptions.
			This is less user friendly, but allows catching exceptions in calling scripts.
		
		.EXAMPLE
			PS C:\> Register-PSFTaskEngineTask -Name 'mymodule.buildcache' -ScriptBlock $ScriptBlock -Once -Description 'Builds the object cache used by the mymodule module'
	
			Registers the task contained in $ScriptBlock under the name 'mymodule.buildcache' to execute once at the system's earliest convenience in a medium (default) priority.
	
		.EXAMPLE
			PS C:\> Register-PSFTaskEngineTask -Name 'mymodule.maintenance' -ScriptBlock $ScriptBlock -Interval "00:05:00" -Delay "00:01:00" -Priority Critical -Description 'Performs critical system maintenance in order for the mymodule module to function'
	
			Registers the task contained in $ScriptBlock under the name 'mymodule.maintenance'
			- Sets it to execute every 5 minutes
			- Sets it to wait for 1 minute after registration before starting the first execution
			- Sets it to priority "Critical", ensuring it takes precedence over most other tasks.
	#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFTaskEngineTask')]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[string]
		$Description,
		
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$ScriptBlock,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Once")]
		[switch]
		$Once,
		
		[Parameter(Mandatory = $true, ParameterSetName = "Repeating")]
		[PsfValidateScript('PSFramework.Validate.TimeSpan.Positive', ErrorString = 'PSFramework.Validate.TimeSpan.Positive')]
		[PSFTimeSpan]
		$Interval,
		
		[PSFTimeSpan]
		$Delay,
		
		[PSFramework.TaskEngine.Priority]
		$Priority = "Medium",
		
		[switch]
		$ResetTask,
		
		[switch]
		$EnableException
	)
	
	process
	{
		
		#region Case: Task already registered
		if ([PSFramework.TaskEngine.TaskHost]::Tasks.ContainsKey($Name))
		{
			$task = [PSFramework.TaskEngine.TaskHost]::Tasks[$Name]
			if (Test-PSFParameterBinding -ParameterName Description) { $task.Description = $Description }
			if ($task.ScriptBlock -ne $ScriptBlock) { $task.ScriptBlock = $ScriptBlock }
			if (Test-PSFParameterBinding -ParameterName Once) { $task.Once = $Once }
			if (Test-PSFParameterBinding -ParameterName Interval)
			{
				$task.Once = $false
				$task.Interval = $Interval
			}
			if (Test-PSFParameterBinding -ParameterName Delay) { $task.Delay = $Delay }
			if (Test-PSFParameterBinding -ParameterName Priority) { $task.Priority = $Priority }
			
			if ($ResetTask)
			{
				$task.Registered = Get-Date
				$task.LastExecution = New-Object System.DateTime(0)
				$task.State = 'Pending'
			}
		}
		#endregion Case: Task already registered
		
		#region New Task
		else
		{
			$task = New-Object PSFramework.TaskEngine.PsfTask
			$task.Name = $Name
			if (Test-PSFParameterBinding -ParameterName Description) { $task.Description = $Description }
			$task.ScriptBlock = $ScriptBlock
			if (Test-PSFParameterBinding -ParameterName Once) { $task.Once = $true }
			if (Test-PSFParameterBinding -ParameterName Interval) { $task.Interval = $Interval }
			if (Test-PSFParameterBinding -ParameterName Delay) { $task.Delay = $Delay }
			$task.Priority = $Priority
			$task.Registered = Get-Date
			[PSFramework.TaskEngine.TaskHost]::Tasks[$Name] = $task
		}
		#endregion New Task
	}
	end { Start-PSFRunspace -Name "psframework.taskengine" -EnableException:$EnableException }
}

function Set-PSFTaskEngineCache
{
<#
	.SYNOPSIS
		Sets values and configuration for a cache entry.
	
	.DESCRIPTION
		Allows applying values and settings for a cache.
		This allows applying a lifetime to cached data or offering a mechanism to automatically refresh it on retrieval.
	
		This feature is specifically designed to interact with the Task Engine powershell task scheduler (See Register-PSFTaskEngineTask for details).
		However it is open for interaction with all tools.
		In particular, the cache is threadsafe to use through these functions.
		The cache is global to the process, NOT the current runspace.
		Background runspaces access the same data in a safe manner.
	
	.PARAMETER Module
		The name of the module that generated the task.
		Use scriptname in case of using this within a script.
	
	.PARAMETER Name
		The name of the task for which the cache is.
	
	.PARAMETER Value
		The value to set this cache to.
	
	.PARAMETER Lifetime
		How long values stored in this cache should remain valid.
	
	.PARAMETER Collector
		A scriptblock that is used to refresh the data cached.
		Should return values in a save manner, will be called if retrieving data on a cache that has expired.
	
	.PARAMETER CollectorArgument
		An argument to pass to the collector script.
		Allows passing in values as argument to the collector script.
		The arguments are stored persistently and are not subject to expiration.
	
	.EXAMPLE
		PS C:\> Set-PSFTaskEngineCache -Module 'mymodule' -Name 'maintenancetask' -Value $results
		
		Stores the content of $results in the cache 'mymodule / maintenancetask'
		These values can now be retrieved using Get-PSFTaskEngineCache.
	
	.EXAMPLE
		PS C:\> Set-PSFTaskEngineCache -Module MyModule -Name DomainController -Lifetime 8h -Collector { Get-ADDomainController }
	
		Registers a cache that lists all domain controllers in the current domain, keeping the data valid for 8 hours before refreshing it.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Set-PSFTaskEngineCache')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Module,
		
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name,
		
		[AllowNull()]
		[object]
		$Value,
		
		[PsfValidateScript('PSFramework.Validate.TimeSpan.Positive', ErrorString = 'PSFramework.Validate.TimeSpan.Positive')]
		[PSFTimespan]
		$Lifetime,
		
		[System.Management.Automation.ScriptBlock]
		$Collector,
		
		[object]
		$CollectorArgument
	)
	
	process
	{
		if ([PSFramework.TaskEngine.TaskHost]::TestCacheItem($Module, $Name))
		{
			$cacheItem = [PSFramework.TaskEngine.TaskHost]::GetCacheItem($Module, $Name)
		}
		else { $cacheItem = [PSFramework.TaskEngine.TaskHost]::NewCacheItem($Module, $Name) }
		if (Test-PSFParameterBinding -ParameterName Value) { $cacheItem.Value = $Value }
		if (Test-PSFParameterBinding -ParameterName Lifetime) { $cacheItem.Expiration = $Lifetime }
		if (Test-PSFParameterBinding -ParameterName Collector) { $cacheItem.Collector = $Collector }
		if (Test-PSFParameterBinding -ParameterName CollectorArgument) { $cacheItem.CollectorArgument = $CollectorArgument }
	}
}

function Test-PSFTaskEngineCache
{
	<#
		.SYNOPSIS
			Tests, whether the specified task engine cache-entry has been written.
		
		.DESCRIPTION
			Tests, whether the specified task engine cache-entry has been written.
		
		.PARAMETER Module
			The name of the module that generated the task.
			Use scriptname in case of using this within a script.
			Note: Must be the same as the name used within the task when calling 'Set-PSFTaskEngineCache'
		
		.PARAMETER Name
			The name of the task for which the cache is.
			Note: Must be the same as the name used within the task when calling 'Set-PSFTaskEngineCache'
		
		.EXAMPLE
			PS C:\> Test-PSFTaskEngineCache -Module 'mymodule' -Name 'maintenancetask'
	
			Returns, whether the cache has been set for the module 'mymodule' and the task 'maintenancetask'
			Does not require the cache to actually contain a value, but must exist.
	#>
	[OutputType([System.Boolean])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Test-PSFTaskEngineCache')]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Module,
		
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$Name
	)
	
	process
	{
		[PSFramework.TaskEngine.TaskHost]::TestCacheItem($Module, $Name)
	}
}

function Test-PSFTaskEngineTask
{
	<#
		.SYNOPSIS
			Tests, whether the specified task has already been executed.
		
		.DESCRIPTION
			Tests, whether the specified task has already been executed.
			Returns false, if the task doesn't exist.
		
		.PARAMETER Name
			Name of the task to test
		
		.EXAMPLE
			PS C:\> Test-PSFTaskEngineTask -Name 'mymodule.maintenance'
	
			Returns, whether the task named 'mymodule.maintenance' has already been executed at least once.
	#>
	[OutputType([System.Boolean])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Test-PSFTaskEngineTask')]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)
	
	process
	{
		if (-not ([PSFramework.TaskEngine.TaskHost]::Tasks.ContainsKey($Name)))
		{
			return $false
		}
		
		$task = [PSFramework.TaskEngine.TaskHost]::Tasks[$Name]
		$task.LastExecution -gt $task.Registered
	}
}

function Compare-PSFArray
{
    <#
    .SYNOPSIS
        Compares two arrays.
    
    .DESCRIPTION
        Compares two arrays.
    
    .PARAMETER ReferenceObject
        The first array to compare with the second array.
    
    .PARAMETER DifferenceObject
        The second array to compare with the first array.
    
    .PARAMETER OrderSpecific
        Makes the comparison order specific.
        By default, the command does not care for the order the objects are stored in.
    
    .PARAMETER Quiet
        Rather than returning a delta report object, return a single truth statement:
        - $true if the two arrays are equal
        - $false if the two arrays are NOT equal.
    
    .EXAMPLE
        PS C:\> Compare-PSFArray -ReferenceObject $arraySource -DifferenceObject $arrayDestination -Quiet -OrderSpecific

        Compares the two sets of objects, and returns ...
        - $true if both sets contains the same objects in the same order
        - $false if they do not
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[object[]]
		$ReferenceObject,
		
		[Parameter(Mandatory = $true, Position = 1)]
		[object[]]
		$DifferenceObject,
		
		[switch]
		$OrderSpecific,
		
		[switch]
		$Quiet
	)
	
	process
	{
		#region Not Order Specific
		if (-not $OrderSpecific)
		{
			$delta = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject
			if ($delta)
			{
				if ($Quiet) { return $false }
				[PSCustomObject]@{
					ReferenceObject  = $ReferenceObject
					DifferenceObject = $DifferenceObject
					Delta		     = $delta
					IsEqual		     = $false
				}
				return
			}
			else
			{
				if ($Quiet) { return $true }
				[PSCustomObject]@{
					ReferenceObject  = $ReferenceObject
					DifferenceObject = $DifferenceObject
					Delta		     = $delta
					IsEqual		     = $true
				}
				return
			}
		}
		#endregion Not Order Specific
		
		#region Order Specific
		else
		{
			if ($Quiet -and ($ReferenceObject.Count -ne $DifferenceObject.Count)) { return $false }
			$result = [PSCustomObject]@{
				ReferenceObject  = $ReferenceObject
				DifferenceObject = $DifferenceObject
				Delta		     = @()
				IsEqual		     = $true
			}
			
			$maxCount = [math]::Max($ReferenceObject.Count, $DifferenceObject.Count)
			[System.Collections.ArrayList]$indexes = @()
			
			foreach ($number in (0 .. ($maxCount - 1)))
			{
				if ($number -ge $ReferenceObject.Count)
				{
					$null = $indexes.Add($number)
					continue
				}
				if ($number -ge $DifferenceObject.Count)
				{
					$null = $indexes.Add($number)
					continue
				}
				if ($ReferenceObject[$number] -ne $DifferenceObject[$number])
				{
					if ($Quiet) { return $false }
					$null = $indexes.Add($number)
					continue
				}
			}
			
			if ($indexes.Count -gt 0)
			{
				$result.IsEqual = $false
				$result.Delta = $indexes.ToArray()
			}
			
			$result
		}
		#endregion Order Specific
	}
}


function ConvertFrom-PSFArray
{
<#
	.SYNOPSIS
		Flattens properties that have array values.
	
	.DESCRIPTION
		Flattens properties that have array values.
		With this you can prepare objects for export to systems that cannot handle collection in propertyvalues.
		This flattening happens using a string join operation, so the output on modified properties is guaranteed to be a string.
	
	.PARAMETER JoinBy
		The string sequence to join values by.
		Defaults to ", "
	
	.PARAMETER PropertyName
		The properties to affect.
		Interprets wildcards, defaults to '*'.
	
	.PARAMETER InputObject
		The objects the properties of which to flatten.
	
	.EXAMPLE
		PS C:\> Get-Something | ConvertFrom-PSFArray | Export-Csv -Path .\output.csv
	
		Processes the output of Get-Something in order to produce a flat table to export data to csv without trimming collections.
#>
	[CmdletBinding()]
	param (
		[Parameter(Position = 0)]
		[string]
		$JoinBy = ', ',
		
		[Parameter(Position = 1)]
		[string[]]
		$PropertyName = '*',
		
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	
	process
	{
		$props = [ordered]@{ }
		foreach ($property in $InputObject.PSObject.Properties)
		{
			#region Skip non-collection properties
			if ($property.Value -isnot [System.Collections.ICollection])
			{
				$props[$property.Name] = $property.Value
				continue
			}
			#endregion Skip non-collection properties
			
			#region Handle whether the property should be processed at all
			$found = $false
			foreach ($name in $PropertyName)
			{
				if ($property.Name -like $name)
				{
					$found = $true
					break
				}
			}
			if (-not $found)
			{
				$props[$property.Name] = $property.Value
				continue
			}
			#endregion Handle whether the property should be processed at all
			
			$props[$property.Name] = $property.Value -join $JoinBy
		}
		[PSCustomObject]$props
	}
}

function Get-PSFPath
{
<#
	.SYNOPSIS
		Access a configured path.
	
	.DESCRIPTION
		Access a configured path.
		Paths can be configured using Set-PSFPath or using the configuration system.
		To register a path using the configuration system create a setting key named like this:
		"PSFramework.Path.<PathName>"
		For example the following setting points at the temp path:
		"PSFramework.Path.Temp"
	
	.PARAMETER Name
		Name of the path to retrieve.
	
	.EXAMPLE
		PS C:\> Get-PSFPath -Name 'temp'
	
		Returns the temp path.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Name
	)
	
	process
	{
		Get-PSFConfigValue -FullName "PSFramework.Path.$Name"
	}
}

function Get-PSFScriptblock
{
<#
	.SYNOPSIS
		Access the scriptblocks stored with Set-PSFScriptblock.
	
	.DESCRIPTION
		Access the scriptblocks stored with Set-PSFScriptblock.
	
		Use this command to access scriptblocks designed for easy, processwide access.
	
	.PARAMETER Name
		The name of the scriptblock to request.
		It's mandatory for explicitly requesting a scriptblock, but optional to use with -List as a filter.
	
	.PARAMETER List
		Instead of requesting a specific scriptblock, list the available ones.
		This can be further filtered by using a wildcard supporting string as -Name.
	
	.EXAMPLE
		PS C:\> Get-PSFScriptblock -Name 'MyModule.TestServer'
	
		Returns the scriptblock stored as 'MyModule.TestServer'
	
	.EXAMPLE
		PS C:\> Get-PSFScriptblock -List
	
		Returns a list of all scriptblocks
	
	.EXAMPLE
		PS C:\> Get-PSFScriptblock -List -Name 'MyModule.TestServer'
	
		Returns scriptblock and meta information for the MyModule.TestServer scriptblock.
#>
	[OutputType([PSFramework.Utility.ScriptBlockItem], ParameterSetName = 'List')]
	[OutputType([System.Management.Automation.ScriptBlock], ParameterSetName = 'Name')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidDefaultValueForMandatoryParameter", "")]
	[CmdletBinding(DefaultParameterSetName = 'Name')]
	param (
		[Parameter(ParameterSetName = 'List')]
		[Parameter(Mandatory = $true, ParameterSetName = 'Name', ValueFromPipeline = $true)]
		[string[]]
		$Name = '*',
		
		[Parameter(Mandatory = $true, ParameterSetName = 'List')]
		[switch]
		$List
	)
	
	begin
	{
		[System.Collections.ArrayList]$sent = @()
		$allItems = [PSFramework.Utility.UtilityHost]::ScriptBlocks.Values
	}
	process
	{
		:main foreach ($nameText in $Name)
		{
			switch ($PSCmdlet.ParameterSetName)
			{
				'Name'
				{
					if ($sent -contains $nameText) { continue main }
					$null = $sent.Add($nameText)
					[PSFramework.Utility.UtilityHost]::ScriptBlocks[$nameText].ScriptBlock
				}
				'List'
				{
					foreach ($item in $allItems)
					{
						if ($item.Name -notlike $nameText) { continue }
						if ($sent -contains $item.Name) { continue }
						$null = $sent.Add($item.Name)
						$item
					}
				}
			}
		}
	}
}

function Import-PSFPowerShellDataFile
{
<#
	.SYNOPSIS
		A wrapper command around Import-PowerShellDataFile
	
	.DESCRIPTION
		A wrapper command around Import-PowerShellDataFile
		This enables use of the command on PowerShell 3+ as well as during JEA endpoints.
	
		Note: The protective value of Import-PowerShellDataFile is only offered when run on PS5+.
		This is merely meant to provide compatibility in the scenarios, where the original command would fail!
		If you care about PowerShell security, update to the latest version (in which case this command is still as secure as the default command, as that is what will actually be run.
	
	.PARAMETER Path
		The path from which to load the data file.
	
	.PARAMETER LiteralPath
		The path from which to load the data file.
		In opposite to the Path parameter, input here will not be interpreted.
	
	.EXAMPLE
		PS C:\> Import-PSFPowerShellDataFile -Path .\data.psd1
	
		Safely loads the data stored in data.psd1
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
	[CmdletBinding()]
	Param (
		[Parameter(ParameterSetName = 'ByPath')]
		[string[]]
		$Path,
		
		[Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByLiteralPath')]
		[Alias('PSPath')]
		[string[]]
		$LiteralPath
	)
	
	process
	{
		# If launched in JEA Endpoint, Import-PowerShellDataFile is unavailable due to a bug
		# It is important to check the initial sessionstate, as the module's current state will be 'FullLanguage' instead.
		# Import-PowerShellDataFile is also unavailable before PowerShell v5
		if (($ExecutionContext.Host.Runspace.InitialSessionState.LanguageMode -eq 'NoLanguage') -or ($PSVersionTable.PSVersion.Major -lt 5))
		{
			foreach ($resolvedPath in ($Path | Resolve-PSFPath -Provider FileSystem | Select-Object -Unique))
			{
				Invoke-Expression (Get-Content -Path $resolvedPath -Raw)
			}
			foreach ($pathItem in $LiteralPath)
			{
				Invoke-Expression (Get-Content -Path $pathItem -Raw)
			}
		}
		else
		{
			Import-PowerShellDataFile @PSBoundParameters
		}
	}
}


function Join-PSFPath
{
<#
    .SYNOPSIS
        Performs multisegment path joins.
    
    .DESCRIPTION
        Performs multisegment path joins.
    
    .PARAMETER Path
        The basepath to join on.
    
    .PARAMETER Child
        Any number of child paths to add.
	
	.PARAMETER Normalize
		Normalizes path separators for the path segments offered.
		This ensures the correct path separators for the current OS are chosen.
    
    .EXAMPLE
        PS C:\> Join-PSFPath -Path 'C:\temp' 'Foo' 'Bar'
    
        Returns 'C:\temp\Foo\Bar'
	
	.EXAMPLE
		PS C:\> Join-PSFPath -Path 'C:\temp' 'Foo' 'Bar' -Normalize
    
        Returns 'C:\temp\Foo\Bar' on a Windows OS.
		Returns 'C:/temp/Foo/Bar' on most non-Windows OSes.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$Path,
		
		[Parameter(ValueFromRemainingArguments = $true)]
		[string[]]
		$Child,
		
		[switch]
		$Normalize
	)
	
	process
	{
		$resultingPath = $Path
		
		foreach ($childItem in $Child)
		{
			$resultingPath = Join-Path -Path $resultingPath -ChildPath $childItem
		}
		
		if ($Normalize)
		{
			$defaultSeparator = [System.IO.Path]::DirectorySeparatorChar
			$altSeparator = [System.IO.Path]::AltDirectorySeparatorChar
			$resultingPath = $resultingPath.Replace($altSeparator, $defaultSeparator)
		}
		
		$resultingPath
	}
}

function New-PSFSupportPackage
{
<#
	.SYNOPSIS
		Creates a package of troubleshooting information that can be used by developers to help debug issues.
	
	.DESCRIPTION
		This function creates an extensive debugging package that can help with reproducing and fixing issues.
		
		The file will be created on the desktop by default and will contain quite a bit of information:
		- OS Information
		- Hardware Information (CPU, Ram, things like that)
		- .NET Information
		- PowerShell Information
		- Your input history
		- The In-Memory message log
		- The In-Memory error log
		- Screenshot of the console buffer (Basically, everything written in your current console, even if you have to scroll upwards to see it).
	
	.PARAMETER Path
		The folder where to place the output xml in.
		Defaults to your desktop.
	
	.PARAMETER Include
		What to include in the export.
		By default, all is included.
	
	.PARAMETER Exclude
		Anything not to include in the export.
		Use this to explicitly exclude content you do not wish to be part of the dump (for example for data protection reasons).
	
	.PARAMETER Variables
		Name of additional variables to attach.
		This allows you to add the content of variables to the support package, if you believe them to be relevant to the case.
	
	.PARAMETER ExcludeError
		By default, the content of $Error is included, as it often can be helpful in debugging, even with error handling using the message system.
		However, there can be rare instances where this will explode the total export size to gigabytes, in which case it becomes necessary to skip this.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		New-PSFSupportPackage
		
		Creates a large support pack in order to help us troubleshoot stuff.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "")]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/New-PSFSupportPackage')]
	param (
		[string]
		$Path = "$($env:USERPROFILE)\Desktop",
		
		[PSFramework.Utility.SupportData]
		$Include = 'All',
		
		[PSFramework.Utility.SupportData]
		$Exclude = 'None',
		
		[string[]]
		$Variables,
		
		[switch]
		$ExcludeError,
		
		[switch]
		[Alias('Silent')]
		$EnableException
	)
	
	begin
	{
		#region Helper functions
		function Get-ShellBuffer
		{
			[CmdletBinding()]
			param ()
			
			if ($Host.Name -eq 'Windows PowerShell ISE Host')
			{
				return $psIse.CurrentPowerShellTab.ConsolePane.Text
			}
			
			try
			{
				# Define limits
				$rec = New-Object System.Management.Automation.Host.Rectangle
				$rec.Left = 0
				$rec.Right = $host.ui.rawui.BufferSize.Width - 1
				$rec.Top = 0
				$rec.Bottom = $host.ui.rawui.BufferSize.Height - 1
				
				# Load buffer
				$buffer = $host.ui.rawui.GetBufferContents($rec)
				
				# Convert Buffer to list of strings
				$int = 0
				$lines = @()
				while ($int -le $rec.Bottom)
				{
					$n = 0
					$line = ""
					while ($n -le $rec.Right)
					{
						$line += $buffer[$int, $n].Character
						$n++
					}
					$line = $line.TrimEnd()
					$lines += $line
					$int++
				}
				
				# Measure empty lines at the beginning
				$int = 0
				$temp = $lines[$int]
				while ($temp -eq "") { $int++; $temp = $lines[$int] }
				
				# Measure empty lines at the end
				$z = $rec.Bottom
				$temp = $lines[$z]
				while ($temp -eq "") { $z--; $temp = $lines[$z] }
				
				# Skip the line launching this very function
				$z--
				
				# Measure empty lines at the end (continued)
				$temp = $lines[$z]
				while ($temp -eq "") { $z--; $temp = $lines[$z] }
				
				# Cut results to the limit and return them
				return $lines[$int .. $z]
			}
			catch { }
		}
		#endregion Helper functions
	}
	process
	{
		$filePathXml = Join-Path $Path "powershell_support_pack_$(Get-Date -Format "yyyy_MM_dd-HH_mm_ss").cliDat"
		$filePathZip = $filePathXml -replace "\.cliDat$", ".zip"
		
		Write-PSFMessage -Level Critical -String 'New-PSFSupportPackage.Header' -StringValues $filePathZip, (Get-PSFConfigValue -FullName 'psframework.supportpackage.contactmessage' -Fallback '')
		
		$hash = @{ }
		if (($Include -band 1) -and -not ($Exclude -band 1))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.Messages'
			$hash["Messages"] = Get-PSFMessage
		}
		if (($Include -band 2) -and -not ($Exclude -band 2))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.MsgErrors'
			$hash["Errors"] = Get-PSFMessage -Errors
		}
		if (($Include -band 4) -and -not ($Exclude -band 4))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.ConsoleBuffer'
			$hash["ConsoleBuffer"] = Get-ShellBuffer
		}
		if (($Include -band 8) -and -not ($Exclude -band 8))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.OperatingSystem'
			$hash["OperatingSystem"] = if ($IsLinux -or $IsMacOs)
			{
				[PSCustomObject]@{
					OSVersion = [System.Environment]::OSVersion
					ProcessorCount = [System.Environment]::ProcessorCount
					Is64Bit   = [System.Environment]::Is64BitOperatingSystem
					LogicalDrives = [System.Environment]::GetLogicalDrives()
					SystemDirectory = [System.Environment]::SystemDirectory
				}
			}
			else
			{
				Get-CimInstance -ClassName Win32_OperatingSystem
			}
		}
		if (($Include -band 16) -and -not ($Exclude -band 16))
		{
			$hash["CPU"] = if ($IsLinux -and (Test-Path -Path /proc/cpuinfo))
			{
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.CPU' -StringValues '/proc/cpuinfo'
				Get-Content -Raw -Path /proc/cpuinfo
			}
			else
			{
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.CPU' -StringValues Win32_Processor
				Get-CimInstance -ClassName Win32_Processor
			}
		}
		if (($Include -band 32) -and -not ($Exclude -band 32))
		{
			$hash["Ram"] = if ($IsLinux -and (Test-Path -Path /proc/meminfo))
			{
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.RAM' -StringValues '/proc/meminfo'
				Get-Content -Raw -Path /proc/meminfo
			}
			else
			{
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.RAM' -StringValues Win32_PhysicalMemory
				Get-CimInstance -ClassName Win32_PhysicalMemory
			}
		}
		if (($Include -band 64) -and -not ($Exclude -band 64))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.PSVersion'
			$hash["PSVersion"] = $PSVersionTable
		}
		if (($Include -band 128) -and -not ($Exclude -band 128))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.History'
			$hash["History"] = Get-History
		}
		if (($Include -band 256) -and -not ($Exclude -band 256))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.Modules'
			$hash["Modules"] = Get-Module
		}
		if ((($Include -band 512) -and -not ($Exclude -band 512)) -and (Get-Command -Name Get-PSSnapIn -ErrorAction SilentlyContinue))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.Snapins'
			$hash["SnapIns"] = Get-PSSnapin
		}
		if (($Include -band 1024) -and -not ($Exclude -band 1024))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.Assemblies'
			$hash["Assemblies"] = [appdomain]::CurrentDomain.GetAssemblies() | Select-Object CodeBase, FullName, Location, ImageRuntimeVersion, GlobalAssemblyCache, IsDynamic
		}
		if (Test-PSFParameterBinding -ParameterName "Variables")
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.Variables' -StringValues ($Variables -join ", ")
			$hash["Variables"] = $Variables | Get-Variable -ErrorAction Ignore
		}
		if (($Include -band 2048) -and -not ($Exclude -band 2048) -and (-not $ExcludeError))
		{
			Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.PSErrors'
			$hash["PSErrors"] = @()
			foreach ($errorItem in $global:Error) { $hash["PSErrors"] += New-Object PSFramework.Message.PsfException($errorItem) }
		}
		if (($Include -band 4096) -and -not ($Exclude -band 4096))
		{
			if (Test-Path function:Get-DbatoolsLog)
			{
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.DbaTools.Messages'
				$hash["DbatoolsMessages"] = Get-DbatoolsLog
				Write-PSFMessage -Level Important -String 'New-PSFSupportPackage.DbaTools.Errors'
				$hash["DbatoolsErrors"] = Get-DbatoolsLog -Errors
			}
		}
		
		$data = [pscustomobject]$hash
		
		try { $data | Export-PsfClixml -Path $filePathXml -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -String 'New-PSFSupportPackage.Export.Failed' -ErrorRecord $_ -Target $filePathXml -EnableException $EnableException
			return
		}
		
		try { Compress-Archive -Path $filePathXml -DestinationPath $filePathZip -ErrorAction Stop }
		catch
		{
			Stop-PSFFunction -String 'New-PSFSupportPackage.ZipCompression.Failed' -ErrorRecord $_ -Target $filePathZip -EnableException $EnableException
			return
		}
		
		Remove-Item -Path $filePathXml -ErrorAction Ignore
	}
}

function Remove-PSFAlias
{
<#
	.SYNOPSIS
		Removes an alias from the global scope.
	
	.DESCRIPTION
		Removes an alias from the global* scope.
		Please note that this always affects the global scope and should not be used lightly.
		This has the potential to break code that does not comply with PowerShell best practices and relies on the use of aliases.
	
		Refuses to delete constant aliases.
		Requires the '-Force' parameter to delete ReadOnly aliases.
	
		*This includes aliases exported by modules.
	
	.PARAMETER Name
		The name of the alias to remove.
	
	.PARAMETER Force
		Enforce removal of aliases. Required to remove ReadOnly aliases (including default aliases such as "select" or "group").
	
	.EXAMPLE
		PS C:\> Remove-PSFAlias -Name 'grep'
	
		Removes the global alias 'grep'
	
	.EXAMPLE
		PS C:\> Remove-PSFAlias -Name 'select' -Force
	
		Removes the default alias 'select'
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
		[string[]]
		$Name,
		
		[switch]
		$Force
	)
	
	process
	{
		foreach ($alias in $Name)
		{
			try { [PSFramework.Utility.UtilityHost]::RemovePowerShellAlias($alias, $Force.ToBool()) }
			catch { Stop-PSFFunction -Message $_ -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_ -OverrideExceptionMessage }
		}
	}
}

function Resolve-PSFDefaultParameterValue
{
<#
	.SYNOPSIS
		Used to filter and process default parameter values.
	
	.DESCRIPTION
		This command picks all the default parameter values from a reference hashtable.
		It then filters all that match a specified command and binds them to that specific command, narrowing its focus.
		These get merged into either a new or a specified hashtable and returned.
	
	.PARAMETER Reference
		The hashtable to pick default parameter values from.
	
	.PARAMETER CommandName
		The commands to pick default parameter values for.
	
	.PARAMETER Target
		The target hashtable to merge results into.
		By default an empty hashtable is used.
	
	.PARAMETER ParameterName
		Only resolve for specific parameter names.
	
	.EXAMPLE
		PS C:\> Resolve-PSFDefaultParameterValue -Reference $global:PSDefaultParameterValues -CommandName 'Invoke-WebRequest'
	
		Returns a hashtable containing all default parameter values in the global scope affecting the command 'Invoke-WebRequest'.
#>
	[OutputType([System.Collections.Hashtable])]
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Resolve-PSFDefaultParameterValue')]
	param (
		[Parameter(Mandatory = $true)]
		[System.Collections.Hashtable]
		$Reference,
		
		[Parameter(Mandatory = $true)]
		[string[]]
		$CommandName,
		
		[System.Collections.Hashtable]
		$Target = @{ },
		
		[string[]]
		$ParameterName = "*"
	)
	
	begin
	{
		$defaultItems = @()
		foreach ($key in $Reference.Keys)
		{
			$defaultItems += [PSCustomObject]@{
				Key	    = $key
				Value   = $Reference[$key]
				Command = $key.Split(":")[0]
				Parameter = $key.Split(":")[1]
			}
		}
	}
	process
	{
		foreach ($command in $CommandName)
		{
			foreach ($item in $defaultItems)
			{
				if ($command -notlike $item.Command) { continue }
				
				foreach ($parameter in $ParameterName)
				{
					if ($item.Parameter -like $parameter)
					{
						if ($parameter -ne "*") { $Target["$($command):$($parameter)"] = $item.Value }
						else { $Target["$($command):$($item.Parameter)"] = $item.Value }
					}
				}
			}
		}
	}
	end
	{
		$Target
	}
}

function Resolve-PSFPath
{
<#
	.SYNOPSIS
		Resolves a path.
	
	.DESCRIPTION
		Resolves a path.
		Will try to resolve to paths including some basic path validation and resolution.
		Will fail if the path cannot be resolved (so an existing path must be reached at).
	
	.PARAMETER Path
		The path to validate.
	
	.PARAMETER Provider
		Ensure the path is of the expected provider.
		Allows ensuring one does not operate in the wrong provider.
		Common providers include the filesystem, the registry or the active directory.
	
	.PARAMETER SingleItem
		Ensure the path should resolve to a single path only.
		This may - intentionally or not - trip up wildcard paths.
	
	.PARAMETER NewChild
		Assumes one wishes to create a new child item.
		The parent path will be resolved and must validate true.
		The final leaf will be treated as a leaf item that does not exist yet.
	
	.EXAMPLE
		PS C:\> Resolve-PSFPath -Path report.log -Provider FileSystem -NewChild -SingleItem
	
		Ensures the resolved path is a FileSystem path.
		This will resolve to the current folder and the file report.log.
		Will not ensure the file exists or doesn't exist.
		If the current path is in a different provider, it will throw an exception.
	
	.EXAMPLE
		PS C:\> Resolve-PSFPath -Path ..\*
	
		This will resolve all items in the parent folder, whatever the current path or drive might be.
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Resolve-PSFPath')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string[]]
		$Path,
		
		[string]
		$Provider,
		
		[switch]
		$SingleItem,
		
		[switch]
		$NewChild
	)
	
	process
	{
		foreach ($inputPath in $Path)
		{
			if ($inputPath -eq ".")
			{
				$inputPath = (Get-Location).Path
			}
			if ($NewChild)
			{
				$parent = Split-Path -Path $inputPath
				$child = Split-Path -Path $inputPath -Leaf
				
				try
				{
					if (-not $parent) { $parentPath = Get-Location -ErrorAction Stop }
					else { $parentPath = Resolve-Path $parent -ErrorAction Stop }
				}
				catch { Stop-PSFFunction -String 'Resolve-PSFPath.Path.ParentExistsNot' -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet }
				
				if ($SingleItem -and (($parentPath | Measure-Object).Count -gt 1))
				{
					Stop-PSFFunction -String 'Resolve-PSFPath.Path.MultipleParents' -EnableException $true -Cmdlet $PSCmdlet
				}
				
				if ($Provider -and ($parentPath.Provider.Name -ne $Provider))
				{
					Stop-PSFFunction -String 'Resolve-PSFPath.Path.WrongProvider' -StringValues $parentPath.Provider.Name, $Provider -EnableException $true -Cmdlet $PSCmdlet
				}
				
				foreach ($parentItem in $parentPath)
				{
					Join-Path $parentItem.ProviderPath $child
				}
			}
			else
			{
				try { $resolvedPaths = Resolve-Path $inputPath -ErrorAction Stop }
				catch { Stop-PSFFunction -String 'Resolve-PSFPath.Path.ExistsNot' -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet }
				
				if ($SingleItem -and (($resolvedPaths | Measure-Object).Count -gt 1))
				{
					Stop-PSFFunction -String 'Resolve-PSFPath.Path.MultipleItems' -EnableException $true -Cmdlet $PSCmdlet
				}
				
				if ($Provider -and ($resolvedPaths.Provider.Name -ne $Provider))
				{
					Stop-PSFFunction -String 'Resolve-PSFPath.Path.WrongProvider' -StringValues $Provider, $resolvedPaths.Provider.Name -EnableException $true -Cmdlet $PSCmdlet
				}
				
				$resolvedPaths.ProviderPath
			}
		}
	}
}

function Select-PSFPropertyValue
{
<#
	.SYNOPSIS
		Expand specific property values based on selection logic.
	
	.DESCRIPTION
		This command allows picking a set of properties and then returning ...
		- All their values
		- The value that meets specific rules
		- A composite value
	
	.PARAMETER Property
		The properties to work with, in the order they should be considered.
	
	.PARAMETER Fallback
		Whether to fall back on other properties if the first one doesn't contain values.
		This picks the value of the first property that actually has a value.
	
	.PARAMETER Select
		Select either the largest or lowest propertyvalue in the Propertynames specified.
	
	.PARAMETER JoinBy
		Joins the selected properties by the string specified.
	
	.PARAMETER FormatWith
		Formats the selected properties into the specified format string.
	
	.PARAMETER InputObject
		The object(s) whose properties to inspect.
	
	.EXAMPLE
		PS C:\> Get-ADComputer -Filter * | Select-PSFPropertyValue -Property 'DNSHostName', 'Name' -Fallback
		
		For each computer in the domain, it will pick the DNSHostName if available, otherwise the Name.
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string[]]
		$Property,
		
		[Parameter(ParameterSetName = 'Fallback')]
		[switch]
		$Fallback,
		
		[Parameter(ParameterSetName = 'Select')]
		[ValidateSet('Lowest', 'Largest')]
		[string]
		$Select,
		
		[Parameter(ParameterSetName = 'Join')]
		[string]
		$JoinBy,
		
		[Parameter(ParameterSetName = 'Format')]
		[string]
		$FormatWith,
		
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	
	process
	{
		foreach ($object in $InputObject)
		{
			switch ($PSCmdlet.ParameterSetName)
			{
				'Default'
				{
					foreach ($prop in $Property)
					{
						$object.$Prop
					}
				}
				'Fallback'
				{
					foreach ($prop in $Property)
					{
						if ($null -ne ($object.$Prop | Remove-PSFNull -Enumerate))
						{
							$object.$prop
							break
						}
					}
				}
				'Select'
				{
					$values = @()
					foreach ($prop in $Property)
					{
						$values += $object.$Prop
					}
					if ($Select -eq 'Largest') { $values | Sort-Object -Descending | Select-Object -First 1 }
					else { $values | Sort-Object | Select-Object -First 1 }
					
				}
				'Join'
				{
					$values = @()
					foreach ($prop in $Property)
					{
						$values += $object.$Prop
					}
					$values -join $JoinBy
				}
				'Format'
				{
					$values = @()
					foreach ($prop in $Property)
					{
						$values += $object.$Prop
					}
					$FormatWith -f $values
				}
			}
		}
	}
}

function Set-PSFPath
{
<#
	.SYNOPSIS
		Configures or updates a path under a name.
	
	.DESCRIPTION
		Configures or updates a path under a name.
		The path can be persisted using the "-Register" command.
		Paths setup like this can be retrieved using Get-PSFPath.
	
	.PARAMETER Name
		Name the path should be stored under.
	
	.PARAMETER Path
		The path that should be returned under the name.
	
	.PARAMETER Register
		Registering a path in order for it to persist across sessions.
	
	.PARAMETER Scope
		The configuration scope it should be registered under.
		Defaults to UserDefault.
		Configuration scopes are the default locations configurations are being stored at.
		For more details see:
		https://psframework.org/documentation/documents/psframework/configuration/persistence-location.html
	
	.EXAMPLE
		PS C:\> Set-PSFPath -Name 'temp' -Path 'C:\temp'
	
		Configures C:\temp as the current temp path. (does not override $env:temp !)
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		
		[Parameter(ParameterSetName = 'Register', Mandatory = $true)]
		[switch]
		$Register,
		
		[Parameter(ParameterSetName = 'Register')]
		[PSFramework.Configuration.ConfigScope]
		$Scope = [PSFramework.Configuration.ConfigScope]::UserDefault
	)
	
	process
	{
		Set-PSFConfig -FullName "PSFramework.Path.$Name" -Value $Path
		if ($Register) { Register-PSFConfig -FullName "PSFramework.Path.$Name" -Scope $Scope }
	}
}

function Set-PSFScriptblock
{
<#
	.SYNOPSIS
		Stores a scriptblock in the central scriptblock store.
	
	.DESCRIPTION
		Stores a scriptblock in the central scriptblock store.
		This store can be accessed using Get-PSFScriptblock.
		It is used to share scriptblocks outside of scope and runspace boundaries.
		Scriptblocks thus registered can be accessed by C#-based services, such as the PsfValidateScript attribute.
	
	.PARAMETER Name
		The name of the scriptblock.
		Must be unique, it is recommended to prefix the module name:
		<Module>.<Scriptblock>
	
	.PARAMETER Scriptblock
		The scriptcode to register
	
	.PARAMETER Global
		Whether the scriptblock should be invoked in the global context.
		If defined, accessing the scriptblock will automatically globalize it before returning it.
	
	.EXAMPLE
		PS C:\> Set-PSFScriptblock -Name 'MyModule.TestServer' -Scriptblock $Scriptblock
	
		Stores the scriptblock contained in $Scriptblock under the 'MyModule.TestServer' name.
	
	.NOTES
		Repeatedly registering the same scriptblock (e.g. in multi-runspace scenarios) is completely safe:
		- Access is threadsafe & Runspacesafe
		- Overwriting the scriptblock does not affect the statistics
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$Scriptblock,
		
		[switch]
		$Global
	)
	process
	{
		if ([PSFramework.Utility.UtilityHost]::ScriptBlocks.ContainsKey($Name))
		{
			[PSFramework.Utility.UtilityHost]::ScriptBlocks[$Name].Scriptblock = $Scriptblock
			if ($Global.IsPresent) { [PSFramework.Utility.UtilityHost]::ScriptBlocks[$Name].Global = $Global }
		}
		else
		{
			[PSFramework.Utility.UtilityHost]::ScriptBlocks[$Name] = New-Object PSFramework.Utility.ScriptBlockItem($Name, $Scriptblock, $Global)
		}
	}
}

<#
Registers the cmdlets published by this module.
Necessary for full hybrid module support.
#>
$commonParam = @{
	HelpFile  = (Resolve-Path "$($script:ModuleRoot)\en-us\PSFramework.dll-Help.xml")
	Module = $ExecutionContext.SessionState.Module
}

Import-PSFCmdlet @commonParam -Name ConvertTo-PSFHashtable -Type ([PSFramework.Commands.ConvertToPSFHashtableCommand])
Import-PSFCmdlet @commonParam -Name Invoke-PSFCallback -Type ([PSFramework.Commands.InvokePSFCallbackCommand])
Import-PSFCmdlet @commonParam -Name Invoke-PSFProtectedCommand -Type ([PSFramework.Commands.InvokePSFProtectedCommand])
Import-PSFCmdlet @commonParam -Name Remove-PSFNull -Type ([PSFramework.Commands.RemovePSFNullCommand])
Import-PSFCmdlet @commonParam -Name Select-PSFObject -Type ([PSFramework.Commands.SelectPSFObjectCommand])
Import-PSFCmdlet @commonParam -Name Set-PSFConfig -Type ([PSFramework.Commands.SetPSFConfigCommand])
Import-PSFCmdlet @commonParam -Name Test-PSFShouldProcess -Type ([PSFramework.Commands.TestPSFShouldProcessCommand])
Import-PSFCmdlet @commonParam -Name Write-PSFMessage -Type ([PSFramework.Commands.WritePSFMessageCommand])

# Define our type aliases
$TypeAliasTable = @{
	PsfArgumentCompleter    = "PSFramework.TabExpansion.PsfArgumentCompleterAttribute"
	PSFComputer			    = "PSFramework.Parameter.ComputerParameter"
	PSFComputerParameter    = "PSFramework.Parameter.ComputerParameter"
	PSFDateTime			    = "PSFramework.Parameter.DateTimeParameter"
	PSFDateTimeParameter    = "PSFramework.Parameter.DateTimeParameter"
	PsfDynamicTransform     = 'PSFramework.Utility.DynamicTransformationAttribute'
	PSFEncoding			    = "PSFramework.Parameter.EncodingParameter"
	PSFEncodingParameter    = "PSFramework.Parameter.EncodingParameter"
	PSFNumber			    = 'PSFramework.Utility.Number'
	psfrgx				    = "PSFramework.Utility.RegexHelper"
	PsfScriptBlock		    = 'PSFramework.Utility.PsfScriptBlock'
	PSFSize				    = "PSFramework.Utility.Size"
	PSFTimeSpan			    = "PSFramework.Parameter.TimeSpanParameter"
	PSFTimeSpanParameter    = "PSFramework.Parameter.TimeSpanParameter"
	PsfValidateLanguageMode = "PSFramework.Validation.PsfValidateLanguageMode"
	PSFValidatePattern	    = "PSFramework.Validation.PsfValidatePatternAttribute"
	PSFValidateScript	    = "PSFramework.Validation.PsfValidateScriptAttribute"
	PSFValidateSet		    = "PSFramework.Validation.PsfValidateSetAttribute"
}

Set-PSFTypeAlias -Mapping $TypeAliasTable

Import-PSFLocalizedString -Path "$script:ModuleRoot\en-us\*.psd1" -Module PSFramework -Language 'en-US'

$script:strings = Get-PSFLocalizedString -Module PSFramework

Register-PSFConfigSchema -Name Default -Schema {
	param (
		[string]
		$Resource,
		
		[System.Collections.Hashtable]
		$Settings
	)
	
	#region Converting parameters
	$Peek = $Settings["Peek"]
	$ExcludeFilter = $Settings["ExcludeFilter"]
	$IncludeFilter = $Settings["IncludeFilter"]
	$AllowDelete = $Settings["AllowDelete"]
	$EnableException = $Settings["EnableException"]
	Set-Location -Path $Settings["Path"]
	$PassThru = $Settings["PassThru"]
	#endregion Converting parameters
	
	#region Utility Function
	function Read-PsfConfigFile
	{
<#
	.SYNOPSIS
		Reads a configuration file and parses it.
	
	.DESCRIPTION
		Reads a configuration file and parses it.
	
	.PARAMETER Path
		The path to the file to parse.
	
	.PARAMETER WebLink
		The link to a website to download straight as raw json.
	
	.PARAMETER RawJson
		Raw json data to interpret.
	
	.EXAMPLE
		PS C:\> Read-PsfConfigFile -Path config.json
	
		Reads the config.json file and returns interpreted configuration objects.
#>
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true, ParameterSetName = 'Path')]
			[string]
			$Path,
			
			[Parameter(Mandatory = $true, ParameterSetName = 'Weblink')]
			[string]
			$Weblink,
			
			[Parameter(Mandatory = $true, ParameterSetName = 'RawJson')]
			[string]
			$RawJson
		)
		
		#region Utility Function
		function New-ConfigItem
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
			[CmdletBinding()]
			param (
				$FullName,
				
				$Value,
				
				$Type,
				
				[switch]
				$KeepPersisted,
				
				[switch]
				$Enforced,
				
				[switch]
				$Policy
			)
			
			[pscustomobject]@{
				FullName	  = $FullName
				Value		  = $Value
				Type		  = $Type
				KeepPersisted = $KeepPersisted
				Enforced	  = $Enforced
				Policy	      = $Policy
			}
		}
		
		function Get-WebContent
		{
			[CmdletBinding()]
			param (
				[string]
				$WebLink
			)
			
			$webClient = New-Object System.Net.WebClient
			$webClient.Encoding = [System.Text.Encoding]::UTF8
			$webClient.DownloadString($WebLink)
		}
		#endregion Utility Function
		
		if ($Path)
		{
			if (-not (Test-Path $Path)) { return }
			$data = Get-Content -Path $Path -Encoding UTF8 -Raw | ConvertFrom-Json -ErrorAction Stop
		}
		if ($Weblink)
		{
			$data = Get-WebContent -WebLink $Weblink | ConvertFrom-Json -ErrorAction Stop
		}
		if ($RawJson)
		{
			$data = $RawJson | ConvertFrom-Json -ErrorAction Stop
		}
		
		foreach ($item in $data)
		{
			#region No Version
			if (-not $item.Version)
			{
				New-ConfigItem -FullName $item.FullName -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($item.Value, $item.Type))
			}
			#endregion No Version
			
			#region Version One
			if ($item.Version -eq 1)
			{
				if ((-not $item.Style) -or ($item.Style -eq "Simple")) { New-ConfigItem -FullName $item.FullName -Value $item.Data }
				else
				{
					if (($item.Type -eq "Object") -or ($item.Type -eq 12))
					{
						New-ConfigItem -FullName $item.FullName -Value $item.Value -Type "Object" -KeepPersisted
					}
					else
					{
						New-ConfigItem -FullName $item.FullName -Value ([PSFramework.Configuration.ConfigurationHost]::ConvertFromPersistedValue($item.Value, $item.Type))
					}
				}
			}
			#endregion Version One
		}
	}
	#endregion Utility Function
	
	try
	{
		if ($Resource -like "http*") { $data = Read-PsfConfigFile -Weblink $Resource -ErrorAction Stop }
		else
		{
			$pathItem = $null
			try { $pathItem = Resolve-PSFPath -Path $Resource -SingleItem -Provider FileSystem }
			catch { }
			if ($pathItem) { $data = Read-PsfConfigFile -Path $pathItem -ErrorAction Stop }
			else { $data = Read-PsfConfigFile -RawJson $Resource -ErrorAction Stop }
		}
	}
	catch { Stop-PSFFunction -String 'Configuration.Schema.Default.ImportFailed' -StringValues $Resource -EnableException $EnableException -Tag 'fail', 'import' -ErrorRecord $_ -Continue -Target $Resource -Cmdlet $Settings["Cmdlet"] }
	
	:element foreach ($element in $data)
	{
		#region Exclude Filter
		foreach ($exclusion in $ExcludeFilter)
		{
			if ($element.FullName -like $exclusion)
			{
				continue element
			}
		}
		#endregion Exclude Filter
		
		#region Include Filter
		if ($IncludeFilter)
		{
			$isIncluded = $false
			foreach ($inclusion in $IncludeFilter)
			{
				if ($element.FullName -like $inclusion)
				{
					$isIncluded = $true
					break
				}
			}
			
			if (-not $isIncluded) { continue }
		}
		#endregion Include Filter
		
		if ($Peek) { $element }
		else
		{
			try
			{
				if (-not $element.KeepPersisted) { Set-PSFConfig -FullName $element.FullName -Value $element.Value -EnableException -AllowDelete:$AllowDelete -PassThru:$PassThru }
				else { Set-PSFConfig -FullName $element.FullName -PersistedValue $element.Value -PersistedType $element.Type -AllowDelete:$AllowDelete -PassThru:$PassThru }
			}
			catch
			{
				Stop-PSFFunction -String 'Configuration.Schema.Default.SetFailed' -StringValues $element.FullName -ErrorRecord $_ -EnableException $EnableException -Tag 'fail', 'import' -Continue -Target $Resource -Cmdlet $Settings["Cmdlet"]
			}
		}
	}
}

Register-PSFConfigSchema -Name MetaJson -Schema {
	param (
		[string]
		$Resource,
		
		[System.Collections.Hashtable]
		$Settings
	)
	
	Write-PSFMessage -String 'Configuration.Schema.MetaJson.ProcessResource' -StringValues $Resource -ModuleName PSFramework
	
	#region Converting parameters
	$Peek = $Settings["Peek"]
	$ExcludeFilter = $Settings["ExcludeFilter"]
	$IncludeFilter = $Settings["IncludeFilter"]
	$AllowDelete = $Settings["AllowDelete"]
	$script:EnableException = $Settings["EnableException"]
	$script:cmdlet = $Settings["Cmdlet"]
	Set-Location -Path $Settings["Path"]
	$PassThru = $Settings["PassThru"]
	#endregion Converting parameters
	
	#region Utility Function
	function Read-V1Node
	{
		[CmdletBinding()]
		param (
			$NodeData,
			
			[string]
			$Path,
			
			[Hashtable]
			$Result
		)
		
		Write-PSFMessage -String 'Configuration.Schema.MetaJson.ProcessFile' -StringValues $Path -ModuleName PSFramework
		
		$basePath = Split-Path -Path $Path
		if ($NodeData.ModuleName) { $moduleName = "{0}." -f $NodeData.ModuleName }
		else { $moduleName = "" }
		
		#region Import Resources
		foreach ($property in $NodeData.Static.PSObject.Properties)
		{
			$Result["$($moduleName)$($property.Name)"] = $property.Value
		}
		foreach ($property in $NodeData.Object.PSObject.Properties)
		{
			$Result["$($moduleName)$($property.Name)"] = $property.Value | ConvertFrom-PSFClixml
		}
		foreach ($property in $NodeData.Dynamic.PSObject.Properties)
		{
			$Result["$($moduleName)$(Resolve-V1String -String $property.Name)"] = Resolve-V1String -String $property.Value
		}
		#endregion Import Resources
		
		#region Import included / linked configuration files
		foreach ($include in $NodeData.Include)
		{
			$resolvedInclude = Resolve-V1String -String $include
			$uri = [uri]$resolvedInclude
			if ($uri.IsAbsoluteUri)
			{
				try
				{
					$newData = Get-Content $resolvedInclude -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
				}
				catch { Stop-PSFFunction -String 'Configuration.Schema.MetaJson.InvalidJson' -StringValues $resolvedInclude -EnableException $script:EnableException -ModuleName PSFramework -ErrorRecord $_ -Continue -Cmdlet $script:cmdlet }
				try
				{
					$null = Read-V1Node -NodeData $newData -Result $Result -Path $resolvedInclude
					continue
				}
				catch { Stop-PSFFunction -String 'Configuration.Schema.MetaJson.NestedError' -StringValues $resolvedInclude -EnableException $script:EnableException -ModuleName PSFramework -ErrorRecord $_ -Continue -Cmdlet $script:cmdlet }
			}
			
			$joinedPath = Join-Path -Path $basePath -ChildPath ($resolvedInclude -replace '^\.\\', '\')
			try { $resolvedIncludeNew = Resolve-PSFPath -Path $joinedPath -Provider FileSystem -SingleItem }
			catch { Stop-PSFFunction -String 'Configuration.Schema.MetaJson.ResolveFile' -StringValues $joinedPath -EnableException $script:EnableException -ModuleName PSFramework -ErrorRecord $_ -Continue -Cmdlet $script:cmdlet }
			
			try
			{
				$newData = Get-Content $resolvedIncludeNew -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
			}
			catch { Stop-PSFFunction -String 'Configuration.Schema.MetaJson.InvalidJson' -StringValues $resolvedIncludeNew -EnableException $script:EnableException -ModuleName PSFramework -ErrorRecord $_ -Continue -Cmdlet $script:cmdlet }
			try
			{
				$null = Read-V1Node -NodeData $newData -Result $Result -Path $resolvedIncludeNew
				continue
			}
			catch { Stop-PSFFunction -String 'Configuration.Schema.MetaJson.NestedError' -StringValues $resolvedIncludeNew -EnableException $script:EnableException -ModuleName PSFramework -ErrorRecord $_ -Continue -Cmdlet $script:cmdlet }
		}
		#endregion Import included / linked configuration files
		
		$Result
	}
	
	function Resolve-V1String
	{
	<#
		.SYNOPSIS
			Resolves a string by inserting placeholders for environment variables.
		
		.DESCRIPTION
			Resolves a string by inserting placeholders for environment variables.
		
		.PARAMETER String
			The string to resolve.
		
		.EXAMPLE
			PS C:\> Resolve-V1String -String '.\%COMPUTERNAME%\config.json'
		
			Resolves the specified string, inserting the local computername for %COMPUTERNAME%.
	#>
		[CmdletBinding()]
		param (
			$String
		)
		if ($String -isnot [string]) { return $String }
		
		$scriptblock = {
			param (
				$Match
			)
			
			$script:envData[$Match.Value]
		}
		
		[regex]::Replace($String, $script:envDataNamesRGX, $scriptblock)
	}
	#endregion Utility Function
	
	#region Utility Computation
	$script:envData = @{ }
	foreach ($envItem in (Get-ChildItem env:\))
	{
		$script:envData["%$($envItem.Name)%"] = $envItem.Value
	}
	$script:envDataNamesRGX = $script:envData.Keys -join '|'
	#endregion Utility Computation
	
	#region Accessing Content
	try { $resolvedPath = Resolve-PSFPath -Path $Resource -Provider FileSystem -SingleItem }
	catch
	{
		Stop-PSFFunction -String 'Configuration.Schema.MetaJson.ResolveFile' -StringValues $Resource -ModuleName PSFramework -FunctionName 'Schema: MetaJson' -EnableException $EnableException -ErrorRecord $_ -Cmdlet $script:cmdlet
		return
	}
	
	try { $importData = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
	catch
	{
		Stop-PSFFunction -String 'Configuration.Schema.MetaJson.InvalidJson' -StringValues $Resource -ModuleName PSFramework -FunctionName 'Schema: MetaJson' -EnableException $EnableException -ErrorRecord $_ -Cmdlet $script:cmdlet
		return
	}
	#endregion Accessing Content
	
	switch ($importData.Version)
	{
		1
		{
			$configurationHash = Read-V1Node -NodeData $importData -Path $resolvedPath -Result @{ }
			$configurationItems = $configurationHash.Keys | ForEach-Object {
				[pscustomobject]@{
					FullName = $_
					Value = $configurationHash[$_]
				}
			}
			
			foreach ($configItem in $configurationItems)
			{
				if ($ExcludeFilter | Where-Object { $configItem.FullName -like $_ }) { continue }
				if ($IncludeFilter -and -not ($IncludeFilter | Where-Object { $configItem.FullName -like $_ })) { continue }
				if ($Peek)
				{
					$configItem
					continue
				}
				
				Set-PSFConfig -FullName $configItem.FullName -Value $configItem.Value -AllowDelete:$AllowDelete -PassThru:$PassThru
			}
		}
		default
		{
			Stop-PSFFunction -String 'Configuration.Schema.MetaJson.UnknownVersion' -StringValues $Resource, $importData.Version -ModuleName PSFramework -FunctionName 'Schema: MetaJson' -EnableException $EnableException -Cmdlet $script:cmdlet
			return
		}
	}
}

Register-PSFConfigValidation -Name "bool" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	try
	{
		if ($Value.GetType().FullName -notin "System.Boolean", 'System.Management.Automation.SwitchParameter')
		{
			$Result.Message = "Not a boolean: $Value"
			$Result.Success = $False
			return $Result
		}
	}
	catch
	{
		$Result.Message = "Not a boolean: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $Value -as [bool]
	
	return $Result
}

Register-PSFConfigValidation -Name "consolecolor" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [System.ConsoleColor]$color = $Value }
	catch
	{
		$Result.Message = "Not a console color: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $color
	
	return $Result
}

Register-PSFConfigValidation -Name "credential" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	try
	{
		if ($Value.GetType().FullName -ne "System.Management.Automation.PSCredential")
		{
			$Result.Message = "Not a credential: $Value"
			$Result.Success = $False
			return $Result
		}
	}
	catch
	{
		$Result.Message = "Not a credential: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $Value
	
	return $Result
}

Register-PSFConfigValidation -Name "datetime" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [DateTime]$DateTime = $Value }
	catch
	{
		$Result.Message = "Not a DateTime: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $DateTime
	
	return $Result
}

Register-PSFConfigValidation -Name "double" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSOBject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [double]$number = $Value }
	catch
	{
		$Result.Message = "Not a double: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $number
	
	return $Result
}

Register-PSFConfigValidation -Name "guidarray" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try
	{
		$data = @()
		foreach ($item in $Value)
		{
			$data += [guid]$item
		}
	}
	catch
	{
		$Result.Message = "Not a guid array: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $data
	
	return $Result
}

Register-PSFConfigValidation -Name "integer" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSOBject -Property @{
		Success = $True
		Value = $null
		Message = ""
	}
	
	try { [int]$number = $Value }
	catch
	{
		$Result.Message = "Not an integer: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $number
	
	return $Result
}

Register-PSFConfigValidation -Name "integer0to9" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value = $null
		Message = ""
	}
	
	try { [int]$number = $Value }
	catch
	{
		$Result.Message = "Not an integer: $Value"
		$Result.Success = $False
		return $Result
	}
	
	if (($number -lt 0) -or ($number -gt 9))
	{
		$Result.Message = "Out of range. Specify a number ranging from 0 to 9"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $Number
	
	return $Result
}

Register-PSFConfigValidation -Name "integer1to9" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [int]$number = $Value }
	catch
	{
		$Result.Message = "Not an integer: $Value"
		$Result.Success = $False
		return $Result
	}
	
	if (($number -lt 1) -or ($number -gt 9))
	{
		$Result.Message = "Out of range. Specify a number ranging from 1 to 9"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $Number
	
	return $Result
}

Register-PSFConfigValidation -Name "integerarray" -ScriptBlock {
	param (
		$var
	)
	
	$test = $true
	try { [int[]]$res = $var }
	catch { $test = $false }
	
	[pscustomobject]@{
		Success = $test
		Value   = $res
		Message = "Casting $var as [int[]] failure. Input is being identified as $($var.GetType())"
	}
}

Register-PSFConfigValidation -Name "integerpositive" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSOBject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [int]$number = $Value }
	catch
	{
		$Result.Message = "Not an integer: $Value"
		$Result.Success = $False
		return $Result
	}
	
	if ($number -lt 0)
	{
		$Result.Message = "Negative value: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $number
	
	return $Result
}

Register-PSFConfigValidation -Name "languagecode" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	$legal = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures).Name | Where-Object { $_ -and ($_.Trim()) }
	
	if ($Value -in $legal)
	{
		$Result.Value = [string]$Value
	}
	else
	{
		$Result.Success = $false
		$Result.Message = [PSFramework.Localization.LocalizationHost]::Read('PSFramework.Configuration_ValidateLanguage')
	}
	
	return $Result
}

Register-PSFConfigValidation -Name "psframework.logfilefiletype" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success  = $True
		Value    = $null
		Message  = ""
	}
	
	try { [PSFramework.Logging.LogFileFileType]$type = $Value }
	catch
	{
		$Result.Message = "Not a logfile file type: $Value . Specify one of these values: $(([enum]::GetNames([PSFramework.Logging.LogFileFileType])) -join ", ")"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $type
	
	return $Result
}

Register-PSFConfigValidation -Name "long" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSOBject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [long]$number = $Value }
	catch
	{
		$Result.Message = "Not a long: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $number
	
	return $Result
}

Register-PSFConfigValidation -Name "sizestyle" -ScriptBlock {
    param (
        $Value
    )

    $Result = New-Object PSObject -Property @{
        Success = $True
        Value   = $null
        Message = ""
    }

    try { [PSFramework.Utility.SizeStyle]$style = $Value }
    catch {
        $Result.Message = "Not a size style: $Value"
        $Result.Success = $False
        return $Result
    }

    $Result.Value = $style

    return $Result
}

Register-PSFConfigValidation -Name "string" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try
	{
		# Seriously, this should work for almost anybody and anything
		[string]$data = $Value
	}
	catch
	{
		$Result.Message = "Not a string: $Value"
		$Result.Success = $False
		return $Result
	}
	
	if ([string]::IsNullOrEmpty($data))
	{
		$Result.Message = "Is an empty string: $Value"
		$Result.Success = $False
		return $Result
	}
	
	if ($data -eq $Value.GetType().FullName)
	{
		$Result.Message = "Is an object with no proper string representation: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $data
	
	return $Result
}

Register-PSFConfigValidation -Name "stringarray" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success  = $True
		Value    = $null
		Message  = ""
	}
	
	try
	{
		$data = @()
		# Seriously, this should work for almost anybody and anything
		foreach ($item in $Value)
		{
			$data += [string]$item
		}
	}
	catch
	{
		$Result.Message = "Not a string array: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $data
	
	return $Result
}

Register-PSFConfigValidation -Name "timespan" -ScriptBlock {
	Param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	try { [timespan]$timespan = [PSFramework.Parameter.TimeSpanParameter]$Value }
	catch
	{
		$Result.Message = "Not a Timespan: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $timespan
	
	return $Result
}

Register-PSFConfigValidation -Name "uriabsolute" -ScriptBlock {
	param (
		$Value
	)
	
	$Result = New-Object PSObject -Property @{
		Success = $True
		Value   = $null
		Message = ""
	}
	
	$stringValue = $Value -as [string]
	[uri]$uri = $stringValue
	
	if (-not $uri.IsAbsoluteUri)
	{
		$Result.Message = "Not an absolute Uri: $Value"
		$Result.Success = $False
		return $Result
	}
	
	$Result.Value = $stringValue
	
	return $Result
}

Set-PSFConfig -Module 'PSFramework' -Name 'ComputerManagement.PSSession.IdleTimeout' -Value (New-TimeSpan -Minutes 15) -Initialize -Validation 'timespan' -Handler { [PSFramework.ComputerManagement.ComputerManagementHost]::PSSessionIdleTimeout = $args[0] } -Description "The idle timeout for cached pssessions. When using Invoke-PSFCommand, it will remember sessions for up to this time after last using them, before cleaning them up."

# Unattended mode, so there is a central flag scripts & modules can detect
Set-PSFConfig -Module PSFramework -Name 'System.Unattended' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.PSFCore.PSFCoreHost]::Unattended = $args[0] } -Description "Central setting, showing whether the current execution is unattended or not. This allows scripts/modules to react to whether there is a user at the controls or not."

Set-PSFConfig -Module PSFramework -Name 'SupportPackage.ContactMessage' -Value ' ' -Initialize -Validation 'string' -Description 'Message shown when using New-PSFSUpportPackage. This allows an organization to tie information on how to submit a support package into the command that generates it'

# Encoding Settings
Set-PSFConfig -Module PSFramework -Name 'Text.Encoding.FullTabCompletion' -Value $false -Initialize -Validation 'bool' -Description 'Whether all encodings should be part of the tab completion for encodings. By default, only a manageable subset is shown.'
Set-PSFConfig -Module PSFramework -Name 'Text.Encoding.DefaultWrite' -Value 'utf-8' -Initialize -Validation 'string' -Description 'The default encoding to use when writing to file. Only applied by implementing commands.'
Set-PSFConfig -Module PSFramework -Name 'Text.Encoding.DefaultRead' -Value 'utf-8' -Initialize -Validation 'string' -Description 'The default encoding to use when reading from file. Only applied by implementing commands.'

# Localization Stuff
Set-PSFConfig -Module PSFramework -Name 'Localization.Language' -Value ([System.Globalization.CultureInfo]::CurrentUICulture.Name) -Initialize -Handler { [PSFramework.Localization.LocalizationHost]::Language = $args[0] } -Validation 'languagecode' -Description 'The language the current PowerShell session is operating under'
Set-PSFConfig -Module PSFramework -Name 'Localization.LoggingLanguage' -Value 'en-US' -Initialize -Handler { [PSFramework.Localization.LocalizationHost]::LoggingLanguage = $args[0] } -Validation 'languagecode' -Description 'The language the current PowerShell session is operating under'

Set-PSFConfig -Module PSFramework -Name 'Logging.MaxErrorCount' -Value 128 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.LogHost]::MaxErrorCount = $args[0] } -Description "The maximum number of error records maintained in-memory. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
Set-PSFConfig -Module PSFramework -Name 'Logging.MaxMessageCount' -Value 1024 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.LogHost]::MaxMessageCount = $args[0] } -Description "The maximum number of messages that can be maintained in the in-memory message queue. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
Set-PSFConfig -Module PSFramework -Name 'Logging.MessageLogEnabled' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.LogHost]::MessageLogEnabled = $args[0] } -Description "Governs, whether a log of recent messages is kept in memory. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
Set-PSFConfig -Module PSFramework -Name 'Logging.ErrorLogEnabled' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.LogHost]::ErrorLogEnabled = $args[0] } -Description "Governs, whether a log of recent errors is kept in memory. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
Set-PSFConfig -Module PSFramework -Name 'Logging.DisableLogFlush' -Value $false -Initialize -Validation "bool" -Description "When shutting down the process, PSFramework will by default flush the log. This ensures that all events are properly logged. If this is not desired, it can be turned off with this setting."
Set-PSFConfig -Module PSFramework -Name 'Logging.Interval' -Value 1000 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.LogHost]::Interval = $args[0] } -Description 'The interval at which the loging runspace runs. Increase to improve performance, reduce the minimize writing latency.'
Set-PSFConfig -Module PSFramework -Name 'Logging.Interval.Idle' -Value 5000 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.LogHost]::IntervalIdle = $args[0] } -Description 'The interval at which the loging runspace runs, when there is nothing to do.'
Set-PSFConfig -Module PSFramework -Name 'Logging.Interval.IdleDuration' -Value (New-TimeSpan -Minutes 2) -Initialize -Validation "timespan" -Handler { [PSFramework.Message.LogHost]::IntervalIdleDuration = $args[0] } -Description 'The time with no message written that needs to occur for the logging runspace to switch to idle mode.'
Set-PSFConfig -Module PSFramework -Name 'Logging.Provider.Source' -Value $null -Initialize -Validation 'uriabsolute' -Description 'Path where PSFramework looks for a provider index file. This file is used to load and configure additional logging providers. See "Get-Help Import-PSFLoggingProvider -Detailed" for more information'
Set-PSFConfig -Module PSFramework -Name 'Logging.Enabled' -Value $true -Initialize -Validation 'bool' -Handler {
	[PSFramework.Message.LogHost]::LoggingEnabled = $args[0]
	if ($args[0]) { Start-PSFRunspace -Name 'psframework.logging' -NoMessage }
	else { Stop-PSFRunspace -Name 'psframework.logging' }
} -Description 'Whether the PSFramework performs any logging at all. Disabling this will stop the background runspace that performs the logging.'


Set-PSFConfig -Module PSFramework -Name 'Message.Info.Minimum' -Value 1 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MinimumInformation = $_ } -Description "The minimum required message level for messages that will be shown to the user."
Set-PSFConfig -Module PSFramework -Name 'Message.Info.Maximum' -Value 3 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MaximumInformation = $_ } -Description "The maximum message level to still display to the user directly."
Set-PSFConfig -Module PSFramework -Name 'Message.Verbose.Minimum' -Value 4 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MinimumVerbose = $_ } -Description "The minimum required message level where verbose information is written."
Set-PSFConfig -Module PSFramework -Name 'Message.Verbose.Maximum' -Value 6 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MaximumVerbose = $_ } -Description "The maximum message level where verbose information is still written."
Set-PSFConfig -Module PSFramework -Name 'Message.Debug.Minimum' -Value 1 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MinimumDebug = $_ } -Description "The minimum required message level where debug information is written."
Set-PSFConfig -Module PSFramework -Name 'Message.Debug.Maximum' -Value 9 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::MaximumDebug = $_ } -Description "The maximum message level where debug information is still written."
Set-PSFConfig -Module PSFramework -Name 'Message.Info.Color' -Value 'Cyan' -Initialize -Validation "consolecolor" -Handler { [PSFramework.Message.MessageHost]::InfoColor = $_ } -Description "The color to use when writing text to the screen on PowerShell."
Set-PSFConfig -Module PSFramework -Name 'Message.Info.Color.Emphasis' -Value 'green' -Initialize -Validation "consolecolor" -Handler { [PSFramework.Message.MessageHost]::InfoColorEmphasis = $_ } -Description "The color to use when emphasizing written text to the screen on PowerShell."
Set-PSFConfig -Module PSFramework -Name 'Message.Info.Color.Subtle' -Value 'gray' -Initialize -Validation "consolecolor" -Handler { [PSFramework.Message.MessageHost]::InfoColorSubtle = $_ } -Description "The color to use when making writing text to the screen on PowerShell appear subtle."
Set-PSFConfig -Module PSFramework -Name 'Message.DeveloperColor' -Value 'Gray' -Initialize -Validation "consolecolor" -Handler { [PSFramework.Message.MessageHost]::DeveloperColor = $_ } -Description "The color to use when writing text with developer specific additional information to the screen on PowerShell."
Set-PSFConfig -Module PSFramework -Name 'Message.ConsoleOutput.Disable' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::DisableVerbosity = $_ } -Description "Global toggle that allows disabling all regular messages to screen. Messages from '-Verbose' and '-Debug' are unaffected"
Set-PSFConfig -Module PSFramework -Name 'Message.Transform.ErrorQueueSize' -Value 512 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.MessageHost]::TransformErrorQueueSize = $_ } -Description "The size of the queue for transformation errors. May be useful for advanced development, but can be ignored usually."
Set-PSFConfig -Module PSFramework -Name 'Message.NestedLevel.Decrement' -Value 0 -Initialize -Validation "integer0to9" -Handler { [PSFramework.Message.MessageHost]::NestedLevelDecrement = $_ } -Description "How many levels should be reduced per callstack depth. This makes commands less verbose, the more nested they are called"
Set-PSFConfig -Module PSFramework -Name 'Developer.Mode.Enable' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::DeveloperMode = $_ } -Description "Developermode enables advanced logging and verbosity features. There is little benefit for enabling this as a regular user. but developers can use it to more easily troubleshoot issues."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Breadcrumbs' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::EnableMessageBreadcrumbs = $_ } -Description "Controls how messages are displayed. Enables Breadcrumb display, showing the entire callstack. Takes precedence over command name display."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.FunctionName' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::EnableMessageDisplayCommand = $_ } -Description "Controls how messages are displayed. Enables command name, showing the name of the writing command. Is overwritten by enabling breadcrumbs."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Timestamp' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::EnableMessageTimestamp = $_ } -Description "Controls how messages are displayed. Enables timestamp display, including a timestamp in each message."

Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.Message.MessageHost]::EnableMessagePrefix = $_ } -Description "Controls how messages are displayed. Enables message prefix display, including a prefix in each message."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix.Error' -Value "##vso[task.logissue type=error;]" -Initialize -Validation "string" -Handler { [PSFramework.Message.MessageHost]::PrefixValueError = $_ } -Description "Prefix value to use when the level is Warning and the tag 'error' is supplied."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix.Warning' -Value "##vso[task.logissue type=warning;]" -Initialize -Validation "string" -Handler { [PSFramework.Message.MessageHost]::PrefixValueWarning = $_ } -Description "Prefix value to use when the level is Warning."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix.Verbose' -Value "##[debug]" -Initialize -Validation "string" -Handler { [PSFramework.Message.MessageHost]::PrefixValueVerbose = $_ } -Description "Prefix value to use when the level is one of the three Verbose levels."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix.Host' -Value "" -Initialize -Validation "string" -Handler { [PSFramework.Message.MessageHost]::PrefixValueHost = $_ } -Description "Prefix value to use when the level is Host."
Set-PSFConfig -Module PSFramework -Name 'Message.Style.Prefix.Significant' -Value "##[section]" -Initialize -Validation "string" -Handler { [PSFramework.Message.MessageHost]::PrefixValueSignificant = $_ } -Description "Prefix value to use when the level is significant or critical."


Set-PSFConfig -Module 'PSFramework' -Name 'Path.Temp' -Value $env:TEMP -Initialize -Validation 'string' -Description "Path pointing at the temp path. Used with Get-PSFPath."
Set-PSFConfig -Module 'PSFramework' -Name 'Path.LocalAppData' -Value $script:path_LocalAppData -Initialize -Validation 'string' -Description "Path pointing at the LocalAppData path. Used with Get-PSFPath."
Set-PSFConfig -Module 'PSFramework' -Name 'Path.AppData' -Value $script:path_AppData -Initialize -Validation 'string' -Description "Path pointing at the AppData path. Used with Get-PSFPath."
Set-PSFConfig -Module 'PSFramework' -Name 'Path.ProgramData' -Value $script:path_ProgramData -Initialize -Validation 'string' -Description "Path pointing at the ProgramData path. Used with Get-PSFPath."

#region Setting the configuration
Set-PSFConfig -Module PSFramework -Name 'Runspace.StopTimeoutSeconds' -Value 30 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Runspace.RunspaceHost]::StopTimeoutSeconds = $args[0] } -Description "Time in seconds that Stop-PSFRunspace will wait for a scriptspace to selfterminate before killing it."
#endregion Setting the configuration

# The path where type-files are stored when registered
Set-PSFConfig -Module PSFramework -Name 'Serialization.WorkingDirectory' -Value $script:path_typedata -Initialize -Validation "string" -Description "The folder in which registered type extension files are placed before import. Relevant for Register-PSFTypeSerializationData."

Set-PSFConfig -Module PSFramework -Name 'Utility.Size.Style' -Value ([PSFramework.Utility.SizeStyle]::Dynamic) -Initialize -Validation sizestyle -Handler { [PSFramework.Utility.UtilityHost]::SizeStyle = $args[0] } -Description "Controls how size objects are displayed by default. Generally, their string representation is calculated to be user friendly (dynamic), can be updated to 'plain' number or a specific size. Can be overriden on a per-object basis."
Set-PSFConfig -Module PSFramework -Name 'Utility.Size.Digits' -Value 2 -Initialize -Validation integer0to9 -Handler { [PSFramework.Utility.UtilityHost]::SizeDigits = $args[0] } -Description "How many digits are used when displaying a size object."

if (-not [PSFramework.Configuration.ConfigurationHost]::ImportFromRegistryDone)
{
	# Read config from all settings
	$config_hash = Read-PsfConfigPersisted -Scope 511
	
	foreach ($value in $config_hash.Values)
	{
		try
		{
			if (-not $value.KeepPersisted) { Set-PSFConfig -FullName $value.FullName -Value $value.Value -EnableException }
			else { Set-PSFConfig -FullName $value.FullName -PersistedValue $value.Value -PersistedType $value.Type -EnableException }
			[PSFramework.Configuration.ConfigurationHost]::Configurations[$value.FullName].PolicySet = $value.Policy
			[PSFramework.Configuration.ConfigurationHost]::Configurations[$value.FullName].PolicyEnforced = $value.Enforced
		}
		catch { }
	}
	
	[PSFramework.Configuration.ConfigurationHost]::ImportFromRegistryDone = $true
}



$FunctionDefinitions = {
	function Export-DataToAzure {
        <#
        .SYNOPSIS
            Function to send logging data to an Azure Workspace

        .DESCRIPTION
            This function is the main function that takes a PSFMessage object to log in an Azure workspace via Rest API call.

        .PARAMETER Message
            This is a PSFMessage object that will be converted to serialized to Json injected to an Azure workspace

        .EXAMPLE
            Export-DataToAzure -Message $objectToProcess

        .NOTES
            # Adapted from https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api
            Rest API documentation: https://docs.microsoft.com/en-us/rest/api/azure/
            Azure Monitor HTTP Data Collector API: https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-collector-api#request-body

            Azure Monitor Data collection API Constrains
            --------------------------------------------
            1. Maximum of 30 MB per post to Azure Monitor Data Collector API. This is a size limit for a single post. If the data from a single post that exceeds 30 MB, you should split the data up to smaller sized chunks and send them concurrently.
            2. Maximum of 32 KB limit for field values. If the field value is greater than 32 KB, the data will be truncated.
            3. Recommended maximum number of fields for a given type is 50. This is a practical limit from a usability and search experience perspective.
            4. A table in a Log Analytics workspace only supports up to 500 columns (referred to as a field in this article).
            5. The maximum number of characters for the column name is 500.

            Notes on Azure workspace table
            ------------------------------
            The table in the Azure workspace will be the LogType specified in PSFConfig. The default is 'Message'
            When looking at the tables in the Azure workspace they will always have _CL appended to them. _CL stands for (for Custom Log)
            In the final table output in the Azure workspace each property imported to the table will have its own column
            and they will be specified by the property type that was inserted to the table.
            Each Azure workspace column name will be suffixed with the data type - _d for double, _b for boolean, _s for string, etc.

            How to register this provider
            -----------------------------
            Set-PSFLoggingProvider -Name AzureLogAnalytics -InstanceName YourInstanceName -WorkspaceId "AzureWorkspaceId" -SharedKey "AzureWorkspaceSharedKey" -LogType "Message" -enabled $True
        #>
		
		[cmdletbinding()]
		param (
			[parameter(Mandatory = $True)]
			$Message
		)
		
		begin {
			# Grab the default configuration values for the logging provider
			$WorkspaceID = Get-ConfigValue -Name 'WorkspaceId'
			$SharedKey = Get-ConfigValue -Name 'SharedKey'
			$LogType = Get-ConfigValue -Name 'LogType'
		}
		
		process {
			# Create a custom PSObject and convert it to a Json object using UTF8 encoding
			$loggingMessage = [PSCustomObject][ordered]@{
				Message = $Message.LogMessage
				Timestamp = $Message.TimeStamp.ToUniversalTime()
				Level   = $Message.Level.ToString()
				Tags    = $Message.Tags
				Data = $Message.Data
				ComputerName = $Message.ComputerName
				Runspace = $Message.Runspace
				UserName = $Message.UserName
				ModuleName = $Message.ModuleName
				FunctionName = $Message.FunctionName
				File    = $Message.File
				CallStack = $Message.CallStack
				TargetObject = $Message.TargetObject
				ErrorRecord = $Message.ErrorRecord
			}
			
			$bodyAsJson = ConvertTo-Json $loggingMessage
			$body = [System.Text.Encoding]::UTF8.GetBytes($bodyAsJson)
			
			$restMethod = "POST"
			$restContentType = "application/json"
			$restResource = "/api/logs"
			$date = [DateTime]::UtcNow.ToString("r")
			$contentLength = $body.Length
			
			$signatureArgs = @{
				WorkspaceID	    = $WorkspaceID
				SharedKey	    = $SharedKey
				DateAndTime	    = $date
				ContentLength   = $contentLength
				RestMethod	    = $restMethod
				RestContentType = $restContentType
				RestResource    = $restResource
			}
			
			# Generate a signature needed to gain access to the Azure workspace
			$signature = Get-LogSignature @signatureArgs
			
			# RestAPI headers
			$headers = @{
				"Authorization"	       = $signature
				"Log-Type"			   = $logType
				"x-ms-date"		       = $date
				"time-generated-field" = "TimeStamp"
			}
			
			try {
				$uri = "https://$($WorkspaceID).ods.opinsights.azure.com$($restResource)?api-version=2016-04-01"
				$webResponse = Invoke-WebRequest -Uri $uri -Method $restMethod -ContentType $restContentType -Headers $headers -Body $body -UseBasicParsing
				switch ($webResponse.StatusCode) {
					'400' {
						switch ($webResponse.StatusDescription) {
							'InactiveCustomer' { throw "Sucessful Post to Azure Workspace" }
							'InvalidApiVersion' { throw "The API version that you specified was not recognized by the service." }
							'InvalidCustomerId' { throw "The workspace ID specified is invalid." }
							'InvalidDataFormat' { throw "Invalid JSON was submitted. The response body might contain more information about how to resolve the error." }
							'InvalidLogType' { throw "The log type specified contained special characters or numerics." }
							'MissingApiVersion' { throw "The API version wasn't specified." }
							'MissingContentType' { throw "The content type wasn't specified." }
							'MissingLogType' { throw "The required value log type wasn't specified." }
							'UnsupportedContentType' { throw "The content type was not set to application/json." }
						}
					}
					
					'403' { throw "The service failed to authenticate the request. Verify that the workspace ID and connection key are valid." }
					'404' { throw "Either the URL provided is incorrect, or the request is too large." }
					'429' { throw "The service is experiencing a high volume of data from your account. Please retry the request later." }
					'500' { throw "The service encountered an internal error. Please retry the request." }
					'503' { throw "The service currently is unavailable to receive requests. Please retry your request." }
				}
			}
			catch { throw }
		}
	}
	
	function Get-LogSignature {
        <#
    .SYNOPSIS
        Function for computing a signature to connect to the Azure workspace

    .DESCRIPTION
        This function will compute a signature that will be used to connect to the Azure workspace in order to save logging data.

    .PARAMETER WorkspaceID
        WorkspaceID is the unique identifer for the Log Analytics workspace, and Signature is a Hash-based Message Authentication Code (HMAC) constructed from the request and computed by using the SHA256 algorithm, and then encoded using Base64 encoding.

    .PARAMETER SharedKey
        This is the Azure workspace shared key.

    .PARAMETER DateAndTime
        The name of a field in the data that contains the timestamp of the data item. If you specify a field then its contents are used for TimeGenerated. If this field isn't specified, the default for TimeGenerated is the time that the message is ingested. The contents of the message field should follow the ISO 8601 format YYYY-MM-DDThh:mm:ssZ.

    .PARAMETER ContentLength
        The content length of the object being injected to the Azure workspace table

    .PARAMETER RestMethod
        Rest Method being used in the connection.

    .PARAMETER RestContentType
        Rest content type being used in the connection.

    .PARAMETER RestResource
        The API resource name: /api/logs.

    .EXAMPLE
        Get-LogSignature @inParameters

    .NOTES
        Any request to the Log analytics HTTP Data Collector API must include the Authorization header.
        To authenticate a request, you must sign the request with either the primary or secondary key for the workspace that is making the request and pass that signature as part of the request.
    #>
		
		[cmdletbinding()]
		param (
			$WorkspaceID,
			
			$SharedKey,
			
			$DateAndTime,
			
			$ContentLength,
			
			$RestMethod,
			
			$RestContentType,
			
			$RestResource
		)
		
		process {
			$xHeaders = "x-ms-date:" + $DateAndTime
			$stringToHash = $RestMethod + "`n" + $ContentLength + "`n" + $RestContentType + "`n" + $xHeaders + "`n" + $RestResource
			$bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
			$keyBytes = [Convert]::FromBase64String($sharedKey)
			$sha256 = New-Object System.Security.Cryptography.HMACSHA256
			$sha256.Key = $keyBytes
			$computedHash = $sha256.ComputeHash($bytesToHash)
			$encodedHash = [Convert]::ToBase64String($computedHash)
			$authorization = 'SharedKey {0}:{1}' -f $WorkspaceID, $encodedHash
			return $authorization
		}
	}
}

#region Events
$message_event = {
	param (
		$Message
	)
	
	Export-DataToAzure -Message $Message
}
#endregion Events

# Configuration values for the logging provider
$configuration_Settings = {
	Set-PSFConfig -Module PSFramework -Name 'Logging.AzureLogAnalytics.WorkspaceId' -Value "" -Initialize -Validation 'string' -Description "WorkspaceId for the Azure Workspace we are logging our data objects to."
	Set-PSFConfig -Module PSFramework -Name 'Logging.AzureLogAnalytics.SharedKey' -Value "" -Initialize -Validation 'string' -Description "SharedId for the Azure Workspace we are logging our data objects to."
	Set-PSFConfig -Module PSFramework -Name 'Logging.AzureLogAnalytics.LogType' -Value "Message" -Initialize -Validation 'string' -Description "Log type we will log information to."
}

# Registered parameters for the logging provider.
# ConfigurationDefaultValues are used for all instances of the azure logging provider
$paramRegisterPSFAzureLogAnalyticsProvider = @{
	Name			   = "AzureLogAnalytics"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.AzureLogAnalytics'
	InstanceProperties = 'WorkspaceId', 'SharedKey', 'LogType'
	MessageEvent	   = $message_Event
	ConfigurationSettings = $configuration_Settings
	FunctionDefinitions = $functionDefinitions
	ConfigurationDefaultValues = @{
		LogType = 'Message'
	}
}

# Register the Azure logging provider
Register-PSFLoggingProvider @paramRegisterPSFAzureLogAnalyticsProvider

$message_event = {
	param (
		$Message
	)
	$style = Get-ConfigValue -Name Style
	$string = $style.Replace('%Time%',$Message.Timestamp.ToString('HH:mm:ss.fff')).Replace('%Date%',$Message.Timestamp.ToString('yyyy-MM-dd')).Replace('%Level%', $Message.Level).Replace('%Module%', $Message.ModuleName).Replace('%FunctionName%', $Message.FunctionName).Replace('%Line%', $Message.Line).Replace('%File%', $Message.File).Replace('%Tags%', ($Message.Tags -join ",")).Replace('%Message%', $Message.LogMessage)
	[System.Console]::WriteLine($string)
}

$configuration_Settings = {
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Console.Style' -Value '%Message%' -Initialize -Validation string -Description 'The style in which the message is printed. Supports several placeholders: %Message%, %Time%, %Date%, %Tags%, %Level%, %Module%, %FunctionName%, %Line%, %File%. Supports newline and tabs.'
}
$paramRegisterPSFLoggingProvider = @{
	Name			   = "console"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.Console'
	InstanceProperties = 'Style'
	MessageEvent	   = $message_Event
	ConfigurationSettings	   = $configuration_Settings
	ConfigurationDefaultValues = @{
		Style = '%Message%'
	}
}

# Register the Console logging provider
Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

$functionDefinitions = {
	function Write-EventLogEntry
	{
		[CmdletBinding()]
		param (
			$Message
		)
		
		$level = 'Information'
		if ($Message.Level -eq 'Warning') { $level = 'Warning' }
		$errorTag = Get-ConfigValue -Name ErrorTag
		if ($Message.Tags -contains $errorTag) { $level = 'Error' }
		if ($Message.Level -eq 'Error') { $level = 'Error' }
		
		$eventID = switch ($level)
		{
			'Information' { Get-ConfigValue -Name InfoID }
			'Warning' { Get-ConfigValue -Name WarningID }
			'Error' { Get-ConfigValue -Name ErrorID }
		}
		
		$data = @(
			$Message.LogMessage
			$Message.Timestamp.ToUniversalTime().ToString((Get-ConfigValue -Name TimeFormat))
			$Message.FunctionName
			$Message.ModuleName
			($Message.Tags -join ",")
			$Message.Level
			$Message.Runspace
			$Message.TargetObject
			$Message.File
			$Message.Line
			$Message.CallStack.ToString()
			$Message.Username
			$PID
			$script:loggingID
		)
		foreach ($key in $Message.Data.Keys)
		{
			$entry = 'Data| {0} : {1}' -f $key, $Message.Data[$key]
			# Max length of line: 31839 characters https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-reporteventa
			if ($entry.Length -gt 31839) { $entry = $entry.SubString(0, 31835) + '...' }
			$data += $entry
		}
		
		try { Write-LogEntry -LogName $script:logName -Source $script:source -Type $level -Category (Get-ConfigValue -Name Category) -EventId $eventID -Data $data }
		catch { throw }
	}
	
	function Write-LogEntry
	{
		[CmdletBinding()]
		param (
			[string]
			$LogName,
			
			[string]
			$Source,
			
			[int]
			$EventID,
			
			[int]
			$Category,
			
			[System.Diagnostics.EventLogEntryType]
			$Type,
			
			[object[]]
			$Data
		)
		$id = New-Object System.Diagnostics.EventInstance($EventID, $Category, $Type)
		$evtObject = New-Object System.Diagnostics.EventLog
		$evtObject.Log = $LogName
		$evtObject.Source = $Source
		$evtObject.WriteEvent($id, $Data)
	}
	
	function Start-EventLogging
	{
		[CmdletBinding()]
		param (
			
		)
		
		$logName = Get-ConfigValue -Name LogName
		$source = Get-ConfigValue -Name Source
		
		$script:loggingID = [System.Guid]::NewGuid()
		$startingMessage = "Starting new logging provider! | Process ID: $PID | Instance Name: $($script:Instance.Name) | Logging ID: $loggingID"
		$data = $startingMessage, $PID, $script:Instance.Name, $loggingID
		try
		{
			Write-LogEntry -LogName $logName -Source $source -Type Information -Category (Get-ConfigValue -Name Category) -EventId 999 -Data $data
			$script:logName = $logName
			$script:source = $source
			return
		}
		catch
		{
			try
			{
				[System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
				Write-LogEntry -LogName $logName -Source $source -Type Information -Category (Get-ConfigValue -Name Category) -EventId 999 -Data $data
				$script:logName = $logName
				$script:source = $source
				return
			}
			catch
			{
				if (-not (Get-ConfigValue -Name UseFallback)) { throw }
				
				Write-LogEntry -LogName Application -Source Application -Type Information -Category (Get-ConfigValue -Name Category) -EventId 999 -Data $data
				$script:logName = 'Application'
				$script:source = 'Application'
			}
		}
	}
}

$begin_event = {
	Start-EventLogging
}

$message_event = {
	param (
		$Message
	)
	
	Write-EventLogEntry -Message $Message
}

$paramRegisterPSFLoggingProvider = @{
	Name			   = "eventlog"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.EventLog'
	InstanceProperties = 'LogName', 'Source', 'UseFallback', 'Category', 'InfoID', 'WarningID', 'ErrorID', 'ErrorTag', 'TimeFormat'
	FunctionDefinitions = $functionDefinitions
	BeginEvent		   = $begin_event
	MessageEvent	   = $message_Event
	ConfigurationDefaultValues = @{
		LogName	    = 'Application'
		Source	    = 'PSFramework'
		UseFallback = $true
		Category    = 1000
		InfoID	    = 1000
		WarningID   = 2000
		ErrorID	    = 666
		ErrorTag    = 'error'
		TimeFormat  = 'yyyy-MM-dd HH:mm:ss.fff'
	}
}

Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

# Action that is performed on registration of the provider using Register-PSFLoggingProvider
$registrationEvent = {
	
}

#region Logging Execution
# Action that is performed when starting the logging script (or the very first time if enabled after launching the logging script)
$begin_event = {
	#region Helper Functions
	function Clean-FileSystemErrorXml
	{
		[CmdletBinding()]
		Param (
			$Path
		)
		
		$totalLength = $Null
		$files = Get-ChildItem -Path $Path.FullName -Filter "$($env:ComputerName)_$($pid)_error_*.xml" | Sort-Object LastWriteTime
		$totalLength = $files | Measure-Object Length -Sum | Select-Object -ExpandProperty Sum
		if (([PSFramework.Message.LogHost]::MaxErrorFileBytes) -gt $totalLength) { return }
		
		$removed = 0
		foreach ($file in $files)
		{
			$removed += $file.Length
			Remove-Item -Path $file.FullName -Force -Confirm:$false
			
			if (($totalLength - $removed) -lt ([PSFramework.Message.LogHost]::MaxErrorFileBytes)) { break }
		}
	}
	
	function Clean-FileSystemMessageLog
	{
		[CmdletBinding()]
		Param (
			$Path
		)
		
		if ([PSFramework.Message.LogHost]::MaxMessagefileCount -eq 0) { return }
		
		$files = Get-ChildItem -Path $Path.FullName -Filter "$($env:ComputerName)_$($pid)_message_*.log" | Sort-Object LastWriteTime
		if (([PSFramework.Message.LogHost]::MaxMessagefileCount) -ge $files.Count) { return }
		
		$removed = 0
		foreach ($file in $files)
		{
			$removed++
			Remove-Item -Path $file.FullName -Force -Confirm:$false
			
			if (($files.Count - $removed) -le ([PSFramework.Message.LogHost]::MaxMessagefileCount)) { break }
		}
	}
	
	function Clean-FileSystemGlobalLog
	{
		[CmdletBinding()]
		Param (
			$Path
		)
		
		# Kill too old files
		Get-ChildItem -Path $Path.FullName | Where-Object Name -Match "^$([regex]::Escape($env:ComputerName))_.+" | Where-Object LastWriteTime -LT ((Get-Date) - ([PSFramework.Message.LogHost]::MaxLogFileAge)) | Remove-Item -Force -Confirm:$false
		
		# Handle the global overcrowding
		$files = Get-ChildItem -Path $Path.FullName | Where-Object Name -Match "^$([regex]::Escape($env:ComputerName))_.+" | Sort-Object LastWriteTime
		if (-not ($files)) { return }
		$totalLength = $files | Measure-Object Length -Sum | Select-Object -ExpandProperty Sum
		
		if (([PSFramework.Message.LogHost]::MaxTotalFolderSize) -gt $totalLength) { return }
		
		$removed = 0
		foreach ($file in $files)
		{
			$removed += $file.Length
			Remove-Item -Path $file.FullName -Force -Confirm:$false
			
			if (($totalLength - $removed) -lt ([PSFramework.Message.LogHost]::MaxTotalFolderSize)) { break }
		}
	}
	#endregion Helper Functions
	
	$filesystem_SelectTargetObject = @{
		Name = 'TargetObject'
		Expression = {
			if ($null -eq $_.TargetObject) { return }
			if ([PSFramework.Message.LogHost]::FileSystemSerializationDepth -lt 0) { return $_.TargetObject }
			if ([PSFramework.Message.LogHost]::FileSystemSerializationDepth -eq 0) { return ($_.TargetObject | ConvertTo-PSFClixml) }
			$_.TargetObject | ConvertTo-PSFClixml -Depth ([PSFramework.Message.LogHost]::FileSystemSerializationDepth)
		}
	}
	$filesystem_SelectTimestamp = @{
		Name = 'Timestamp'
		Expression = {
			$_.Timestamp.ToString([PSFramework.Message.LogHost]::TimeFormat)
		}
	}
}

# Action that is performed at the beginning of each logging cycle
$start_event = {
	$filesystem_path = [PSFramework.Message.LogHost]::LoggingPath
	if (-not (Test-Path $filesystem_path))
	{
		$filesystem_root = New-Item $filesystem_path -ItemType Directory -Force -ErrorAction Stop
	}
	else { $filesystem_root = Get-Item -Path $filesystem_path }
	
	try { [int]$filesystem_num_Error = (Get-ChildItem -Path $filesystem_path.FullName -Filter "$($env:ComputerName)_$($pid)_error_*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name | Select-String -Pattern "(\d+)" -AllMatches).Matches[1].Value }
	catch { }
	try { [int]$filesystem_num_Message = (Get-ChildItem -Path $filesystem_path.FullName -Filter "$($env:ComputerName)_$($pid)_message_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name | Select-String -Pattern "(\d+)" -AllMatches).Matches[1].Value }
	catch { }
	if (-not ($filesystem_num_Error)) { $filesystem_num_Error = 0 }
	if (-not ($filesystem_num_Message)) { $filesystem_num_Message = 0 }
}

# Action that is performed for each message item that is being logged
$message_Event = {
	Param (
		$Message
	)
	
	$filesystem_CurrentFile = Join-Path $filesystem_root.FullName "$($env:ComputerName)_$($pid)_message_$($filesystem_num_Message).log"
	if (Test-Path $filesystem_CurrentFile)
	{
		$filesystem_item = Get-Item $filesystem_CurrentFile
		if ($filesystem_item.Length -gt ([PSFramework.Message.LogHost]::MaxMessagefileBytes))
		{
			$filesystem_num_Message++
			$filesystem_CurrentFile = Join-Path $($filesystem_root.FullName) "$($env:ComputerName)_$($pid)_message_$($filesystem_num_Message).log"
		}
	}
	
	if ($Message)
	{
		if ([PSFramework.Message.LogHost]::FileSystemModernLog)
		{
			if (-not (Test-Path $filesystem_CurrentFile))
			{
				$Message | Select-PSFObject ComputerName, Username, $filesystem_SelectTimestamp, Level, 'LogMessage as Message', Type, FunctionName, ModuleName, File, Line, @{ n = "Tags"; e = { $_.Tags -join "," } }, $filesystem_SelectTargetObject, Runspace, @{ n = "Callstack"; e = { $_.CallStack.ToString().Split("`n") -join " þ "} } | Export-Csv -Path $filesystem_CurrentFile -NoTypeInformation
			}
			else { Add-Content -Path $filesystem_CurrentFile -Value (ConvertTo-Csv ($Message | Select-PSFObject ComputerName, Username, $filesystem_SelectTimestamp, Level, 'LogMessage as Message', Type, FunctionName, ModuleName, File, Line, @{ n = "Tags"; e = { $_.Tags -join "," } }, $filesystem_SelectTargetObject, Runspace, @{ n = "Callstack"; e = { $_.CallStack.ToString().Split("`n") -join " þ " } }) -NoTypeInformation)[1] }
		}
		else { Add-Content -Path $filesystem_CurrentFile -Value (ConvertTo-Csv ($Message | Select-PSFObject ComputerName, Timestamp, Level, 'LogMessage as Message', Type, FunctionName, ModuleName, File, Line, @{ n = "Tags"; e = { $_.Tags -join "," } }, $filesystem_SelectTargetObject, Runspace) -NoTypeInformation)[1] }
	}
}

# Action that is performed for each error item that is being logged
$error_Event = {
	Param (
		$ErrorItem
	)
	
	if ($ErrorItem)
	{
		$ErrorItem | Export-Clixml -Path (Join-Path $filesystem_root.FullName "$($env:ComputerName)_$($pid)_error_$($filesystem_num_Error).xml") -Depth 3
		$filesystem_num_Error++
	}
	
	Clean-FileSystemErrorXml -Path $filesystem_root
}

# Action that is performed at the end of each logging cycle
$end_event = {
	Clean-FileSystemMessageLog -Path $filesystem_root
	Clean-FileSystemGlobalLog -Path $filesystem_root
}

# Action that is performed when stopping the logging script
$final_event = {
	
}
#endregion Logging Execution

#region Function Extension / Integration
# Script that generates the necessary dynamic parameter for Set-PSFLoggingProvider
$configurationParameters = {
	$configroot = "PSFramework.Logging.FileSystem"
	
	$configurations = Get-PSFConfig -FullName "$configroot.*"
	
	$RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	
	foreach ($config in $configurations)
	{
		$ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
		$ParamAttrib.ParameterSetName = '__AllParameterSets'
		$AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$AttribColl.Add($ParamAttrib)
		$RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter(($config.FullName.Replace($configroot, "").Trim(".")), $config.Value.GetType(), $AttribColl)
		
		$RuntimeParamDic.Add(($config.FullName.Replace($configroot, "").Trim(".")), $RuntimeParam)
	}
	return $RuntimeParamDic
}

# Script that is executes when configuring the provider using Set-PSFLoggingProvider
$configurationScript = {
	$configroot = "PSFramework.Logging.FileSystem"
	
	$configurations = Get-PSFConfig -FullName "$configroot.*"
	
	foreach ($config in $configurations)
	{
		if ($PSBoundParameters.ContainsKey(($config.FullName.Replace($configroot, "").Trim("."))))
		{
			Set-PSFConfig -Module $config.Module -Name $config.Name -Value $PSBoundParameters[($config.FullName.Replace($configroot, "").Trim("."))]
		}
	}
}

# Script that returns a boolean value. "True" if all prerequisites are installed, "False" if installation is required
$isInstalledScript = {
	return $true
}

# Script that provides dynamic parameter for Install-PSFLoggingProvider
$installationParameters = {
	# None needed
}

# Script that performs the actual installation, based on the parameters (if any) specified in the $installationParameters script
$installationScript = {
	# Nothing to be done - if you need to install your filesystem, you probably have other issues you need to deal with first ;)
}
#endregion Function Extension / Integration

# Configuration settings to initialize
$configuration_Settings = {
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MaxMessagefileBytes' -Value 5MB -Initialize -Validation "long" -Handler { [PSFramework.Message.LogHost]::MaxMessagefileBytes = $args[0] } -Description "The maximum size of a given logfile. When reaching this limit, the file will be abandoned and a new log created. Set to 0 to not limit the size. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MaxMessagefileCount' -Value 5 -Initialize -Validation "integerpositive" -Handler { [PSFramework.Message.LogHost]::MaxMessagefileCount = $args[0] } -Description "The maximum number of logfiles maintained at a time. Exceeding this number will cause the oldest to be culled. Set to 0 to disable the limit. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MaxErrorFileBytes' -Value 20MB -Initialize -Validation "long" -Handler { [PSFramework.Message.LogHost]::MaxErrorFileBytes = $args[0] } -Description "The maximum size all error files combined may have. When this number is exceeded, the oldest entry is culled. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MaxTotalFolderSize' -Value 100MB -Initialize -Validation "long" -Handler { [PSFramework.Message.LogHost]::MaxTotalFolderSize = $args[0] } -Description "This is the upper limit of length all items in the log folder may have combined across all processes."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MaxLogFileAge' -Value (New-TimeSpan -Days 7) -Initialize -Validation "timespan" -Handler { [PSFramework.Message.LogHost]::MaxLogFileAge = $args[0] } -Description "Any logfile older than this will automatically be cleansed. This setting is global."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.MessageLogFileEnabled' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.LogHost]::MessageLogFileEnabled = $args[0] } -Description "Governs, whether a log file for the system messages is written. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.ErrorLogFileEnabled' -Value $true -Initialize -Validation "bool" -Handler { [PSFramework.Message.LogHost]::ErrorLogFileEnabled = $args[0] } -Description "Governs, whether log files for errors are written. This setting is on a per-Process basis. Runspaces share, jobs or other consoles counted separately."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.ModernLog' -Value $false -Initialize -Validation "bool" -Handler { [PSFramework.Message.LogHost]::FileSystemModernLog = $args[0] } -Description "Enables the modern, more powereful version of the filesystem log, including headers and extra columns"
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.LogPath' -Value $script:path_Logging -Initialize -Validation "string" -Handler { [PSFramework.Message.LogHost]::LoggingPath = $args[0] } -Description "The path where the PSFramework writes all its logs and debugging information."
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.TimeFormat' -Value "$([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.ShortDatePattern) $([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.LongTimePattern)" -Initialize -Validation string -Handler { [PSFramework.Message.LogHost]::TimeFormat = $args[0] } -Description "The format used for timestamps in the logfile"
	Set-PSFConfig -Module PSFramework -Name 'Logging.FileSystem.TargetSerializationDepth' -Value -1 -Initialize -Validation "integer" -Handler { [PSFramework.Message.LogHost]::FileSystemSerializationDepth = $args[0] } -Description "Whether the target object should be stored as a serialized object. 0 or less will see it logged as string, 1 or greater will see it logged as compressed CLIXML."
	
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.Enabled' -Value $true -Initialize -Validation "bool" -Handler { if ([PSFramework.Logging.ProviderHost]::Providers['filesystem']) { [PSFramework.Logging.ProviderHost]::Providers['filesystem'].Enabled = $args[0] } } -Description "Whether the logging provider should be enabled on registration"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.AutoInstall' -Value $false -Initialize -Validation "bool" -Handler { } -Description "Whether the logging provider should be installed on registration"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.InstallOptional' -Value $true -Initialize -Validation "bool" -Handler { } -Description "Whether installing the logging provider is mandatory, in order for it to be enabled"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.IncludeModules' -Value @() -Initialize -Validation "stringarray" -Handler { if ([PSFramework.Logging.ProviderHost]::Providers['filesystem']) { [PSFramework.Logging.ProviderHost]::Providers['filesystem'].IncludeModules = ($args[0] | Write-Output) } } -Description "Module whitelist. Only messages from listed modules will be logged"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.ExcludeModules' -Value @() -Initialize -Validation "stringarray" -Handler { if ([PSFramework.Logging.ProviderHost]::Providers['filesystem']) { [PSFramework.Logging.ProviderHost]::Providers['filesystem'].ExcludeModules = ($args[0] | Write-Output) } } -Description "Module blacklist. Messages from listed modules will not be logged"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.IncludeTags' -Value @() -Initialize -Validation "stringarray" -Handler { if ([PSFramework.Logging.ProviderHost]::Providers['filesystem']) { [PSFramework.Logging.ProviderHost]::Providers['filesystem'].IncludeTags = ($args[0] | Write-Output) } } -Description "Tag whitelist. Only messages with these tags will be logged"
	Set-PSFConfig -Module LoggingProvider -Name 'FileSystem.ExcludeTags' -Value @() -Initialize -Validation "stringarray" -Handler { if ([PSFramework.Logging.ProviderHost]::Providers['filesystem']) { [PSFramework.Logging.ProviderHost]::Providers['filesystem'].ExcludeTags = ($args[0] | Write-Output) } } -Description "Tag blacklist. Messages with these tags will not be logged"
}

$paramRegisterPSFLoggingProvider = @{
	Name				    = "filesystem"
	RegistrationEvent	    = $registrationEvent
	BeginEvent			    = $begin_event
	StartEvent			    = $start_event
	MessageEvent		    = $message_Event
	ErrorEvent			    = $error_Event
	EndEvent			    = $end_event
	FinalEvent			    = $final_event
	ConfigurationParameters = $configurationParameters
	ConfigurationScript	    = $configurationScript
	IsInstalledScript	    = $isInstalledScript
	InstallationScript	    = $installationScript
	InstallationParameters  = $installationParameters
	ConfigurationSettings   = $configuration_Settings
}

Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

#region Logging Execution
# Action that is performed at the beginning of each logging cycle
$start_event = {
	$script:paramSendPsgelfTcp = @{
		'GelfServer' = Get-ConfigValue -Name 'GelfServer'
		'Port'	     = Get-ConfigValue -Name 'Port'
		'Encrypt'    = Get-ConfigValue -Name 'Encrypt'
	}
}

# Action that is performed for each message item that is being logged
$message_Event = {
	param (
		$Message
	)
	
	$gelf_params = $script:paramSendPsgelfTcp.Clone()
	$gelf_params['ShortMessage'] = $Message.LogMessage
	$gelf_params['HostName'] = $Message.ComputerName
	$gelf_params['DateTime'] = $Message.Timestamp
	
	$gelf_params['Level'] = switch ($Message.Level)
	{
		'Critical' { 1 }
		'Important' { 1 }
		'Output' { 3 }
		'Host' { 4 }
		'Significant' { 5 }
		'VeryVerbose' { 6 }
		'Verbose' { 6 }
		'SomewhatVerbose' { 6 }
		'System' { 6 }
		
		default { 7 }
	}
	
	if ($Message.ErrorRecord)
	{
		$gelf_params['FullMessage'] = $Message.ErrorRecord | ConvertTo-Json
	}
	
	# build the additional fields
	$gelf_properties = $Message.PSObject.Properties | Where-Object {
		$_.Name -notin @('Message', 'LogMessage', 'ComputerName', 'Timestamp', 'Level', 'ErrorRecord')
	}
	
	$gelf_params['AdditionalField'] = @{ }
	foreach ($gelf_property in $gelf_properties)
	{
		$gelf_params['AdditionalField'][$gelf_property.Name] = $gelf_property.Value
	}
	
	PSGELF\Send-PSGelfTCP @gelf_params
}
#endregion Logging Execution

#region Installation
$installationParameters = {
	$results = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	$attributesCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
	$parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
	$parameterAttribute.ParameterSetName = '__AllParameterSets'
	$attributesCollection.Add($parameterAttribute)
	
	$validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute('CurrentUser', 'AllUsers')
	$attributesCollection.Add($validateSetAttribute)
	
	$RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter("Scope", [string], $attributesCollection)
	$results.Add("Scope", $RuntimeParam)
	$results
}

$installation_script = {
	param (
		$BoundParameters
	)
	
	$paramInstallModule = @{
		Name = 'PSGELF'
	}
	if ($BoundParameters.Scope) { $paramInstallModule['Scope'] = $BoundParameters.Scope }
	elseif (-not (Test-PSFPowerShell -Elevated)) { $paramInstallModule['Scope'] = 'CurrentUser' }
	
	Install-Module @paramInstallModule
}

$isInstalled_script = {
	(Get-Module PSGELF -ListAvailable) -as [bool]
}
#endregion Installation

# Configuration settings to initialize
$configuration_Settings = {
	Set-PSFConfig -Module PSFramework -Name 'Logging.GELF.GelfServer' -Value "" -Initialize -Validation string -Description "The GELF server to send logs to"
	Set-PSFConfig -Module PSFramework -Name 'Logging.GELF.Port' -Value "" -Initialize -Validation string -Description "The port number the GELF server listens on"
	Set-PSFConfig -Module PSFramework -Name 'Logging.GELF.Encrypt' -Value $true -Initialize -Validation bool -Description "Whether to use TLS encryption when communicating with the GELF server"
}

$paramRegisterPSFLoggingProvider = @{
	Name			   = "gelf"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.GELF'
	InstanceProperties = 'GelfServer', 'Port', 'Encrypt'
	StartEvent		   = $start_event
	MessageEvent	   = $message_Event
	IsInstalledScript  = $isInstalled_script
	InstallationScript = $installation_script
	InstallationParameters = $installationParameters
	ConfigurationSettings = $configuration_Settings
	ConfigurationDefaultValues = @{
		Encrypt = $true
	}
}

Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

$functionDefinitions = {
	function Get-LogFilePath
	{
		[CmdletBinding()]
		param (
			
		)
		
		$path = Get-ConfigValue -Name 'FilePath'
		$logname = Get-ConfigValue -Name 'LogName'
		
		$scriptBlock = {
			param (
				[string]
				$Match
			)
			
			$hash = @{
				'%date%' = (Get-Date -Format 'yyyy-MM-dd')
				'%dayofweek%' = (Get-Date).DayOfWeek
				'%day%'  = (Get-Date).Day
				'%hour%' = (Get-Date).Hour
				'%minute%' = (Get-Date).Minute
				'%username%' = $env:USERNAME
				'%userdomain%' = $env:USERDOMAIN
				'%computername%' = $env:COMPUTERNAME
				'%processid%' = $PID
				'%logname%' = $logname
			}
			
			$hash.$Match
		}
		
		[regex]::Replace($path, '%day%|%computername%|%hour%|%processid%|%date%|%username%|%dayofweek%|%minute%|%userdomain%|%logname%', $scriptBlock, 'IgnoreCase')
	}
	
	function Write-LogFileMessage
	{
		[CmdletBinding()]
		param (
			[Parameter(ValueFromPipeline = $true)]
			$Message,
			
			[bool]
			$IncludeHeader,
			
			[string]
			$FileType,
			
			[string]
			$Path,
			
			[string]
			$CsvDelimiter,
			
			$MessageItem
		)
		
		$parent = Split-Path $Path
		if (-not (Test-Path $parent))
		{
			$null = New-Item $parent -ItemType Directory -Force
		}
		$fileExists = Test-Path $Path
		
		#region Type-Based Output
		switch ($FileType)
		{
			#region Csv
			"Csv"
			{
				if ((-not $fileExists) -and $IncludeHeader) { $Message | ConvertTo-Csv -NoTypeInformation -Delimiter $CsvDelimiter | Set-Content -Path $Path -Encoding $script:encoding }
				else { $Message | ConvertTo-Csv -NoTypeInformation -Delimiter $CsvDelimiter | Select-Object -Skip 1 | Add-Content -Path $Path -Encoding $script:encoding }
			}
			#endregion Csv
			#region Json
			"Json"
			{
				if ($fileExists -and -not $script:JsonSettings.JsonNoComma) { Add-Content -Path $Path -Value "," -Encoding $script:encoding }
				if (-not $script:JsonSettings) { $Message | ConvertTo-Json -Compress:$script:JsonSettings.JsonCompress | Add-Content -Path $Path -NoNewline -Encoding $script:encoding }
				else { $Message | ConvertFrom-Enumeration | ConvertTo-Json -Compress:$script:JsonSettings.JsonCompress | Add-Content -Path $Path -NoNewline -Encoding $script:encoding }
			}
			#endregion Json
			#region XML
			"XML"
			{
				[xml]$xml = $message | ConvertTo-Xml -NoTypeInformation
				$xml.Objects.InnerXml | Add-Content -Path $Path -Encoding $script:encoding
			}
			#endregion XML
			#region Html
			"Html"
			{
				[xml]$xml = $message | ConvertTo-Html -Fragment
				
				if ((-not $fileExists) -and $IncludeHeader)
				{
					$xml.table.tr[0].OuterXml | Add-Content -Path $Path -Encoding $script:encoding
				}
				
				$xml.table.tr[1].OuterXml | Add-Content -Path $Path -Encoding $script:encoding
			}
			#endregion Html
			#region CMTrace
			"CMTrace"
			{
				$cType = 1
				if ($MessageItem.Level -eq 'Warning') { $cType = 2 }
				if ($MessageItem.ErrorRecord) { $cType = 3 }
				$fileEntry = '<no file>'
				if ($MessageItem.File) { $fileEntry = Split-Path -Path $MessageItem.File -Leaf }
				
				$format = '<![LOG[{0}]LOG]!><time="{1:HH:mm:ss.fff}+000" date="{1:MM-dd-yyyy}" component="{6}:{2} > {7}" context="{3}" type="{4}" thread="{5}" file="{6}:{2} > {7}">'
				$line = $format -f $MessageItem.LogMessage, $MessageItem.Timestamp, $MessageItem.Line, $MessageItem.TargetObject, $cType, $MessageItem.Runspace, $fileEntry, $MessageItem.FunctionName
				$line | Add-Content -Path $Path -Encoding $script:encoding
			}
			#endregion CMTrace
		}
		#endregion Type-Based Output
	}
	
	function Invoke-LogRotate
	{
		[CmdletBinding()]
		param (
			
		)
		
		$basePath = Get-ConfigValue -Name 'LogRotatePath'
		if (-not $basePath) { return }
		
		#region Resolve Paths
		$scriptBlock = {
			param (
				[string]
				$Match
			)
			
			$hash = @{
				'%date%' = (Get-Date -Format 'yyyy-MM-dd')
				'%dayofweek%' = (Get-Date).DayOfWeek
				'%day%'  = (Get-Date).Day
				'%hour%' = (Get-Date).Hour
				'%minute%' = (Get-Date).Minute
				'%username%' = $env:USERNAME
				'%userdomain%' = $env:USERDOMAIN
				'%computername%' = $env:COMPUTERNAME
				'%processid%' = $PID
				'%logname%' = $logname
			}
			
			$hash.$Match
		}
		
		$basePath = [regex]::Replace($basePath, '%day%|%computername%|%hour%|%processid%|%date%|%username%|%dayofweek%|%minute%|%userdomain%|%logname%', $scriptBlock, 'IgnoreCase')
		#endregion Resolve Paths
		
		$minimumRetention = (Get-ConfigValue -Name 'LogRetentionTime') -as [PSFTimeSpan] -as [Timespan]
		if (-not $minimumRetention) { throw "No minimum retention defined" }
		if ($minimumRetention.TotalSeconds -le 0) { throw "Minimum retention must be positive! Retention: $minimumRetention" }
		
		# Don't logrotate more than every 5 minutes
		if ($script:lastRotate -gt (Get-Date).AddMinutes(-5)) { return }
		$script:lastRotate = Get-Date
		
		$limit = (Get-Date).Subtract($minimumRetention)
		Get-ChildItem -Path $basePath -Filter (Get-ConfigValue -Name 'LogRotateFilter') -Recurse:(Get-ConfigValue -Name 'LogRotateRecurse') -File | Where-Object LastWriteTime -LT $limit | Remove-Item -Force -ErrorAction Stop
	}
	
	function Update-Mutex
	{
		[CmdletBinding()]
		param ()
		
		$script:mutexName = Get-ConfigValue -Name 'MutexName'
		if ($script:mutexName -and -not $script:mutex)
		{
			$script:mutex = New-Object System.Threading.Mutex($false, $script:mutexName)
			Add-Member -InputObject $script:mutex -MemberType NoteProperty -Name Name -Value $script:mutexName
		}
		elseif ($script:mutexName -and $script:mutex.Name -ne $script:mutexName)
		{
			$script:mutex.Dispose()
			$script:mutex = New-Object System.Threading.Mutex($false, $script:mutexName)
			Add-Member -InputObject $script:mutex -MemberType NoteProperty -Name Name -Value $script:mutexName
		}
		elseif (-not $script:mutexName -and $script:mutex)
		{
			$script:mutex.Dispose()
			$script:mutex = $null
		}
	}
	
	function ConvertFrom-Enumeration {
		[CmdletBinding()]
		param (
			[Parameter(ValueFromPipeline = $true)]
			$InputObject
		)
		
		process {
			$data = @{ }
			foreach ($property in $InputObject.PSObject.Properties) {
				if ($property.Value -is [enum]) {
					$data[$property.Name] = $property.Value -as [string]
				}
				else {
					$data[$property.Name] = $property.Value
				}
			}
			[pscustomobject]$data
		}
	}
}

#region Events
$begin_event = {
	$script:lastRotate = (Get-Date).AddMinutes(-10)
}

$start_event = {
	$script:logfile_headers = Get-ConfigValue -Name 'Headers' | ForEach-Object {
		switch ($_)
		{
			'Tags'
			{
				@{
					Name	   = 'Tags'
					Expression = { $_.Tags -join "," }
				}
			}
			'Message'
			{
				@{
					Name	   = 'Message'
					Expression = { $_.LogMessage }
				}
			}
			'Timestamp'
			{
				@{
					Name	   = 'Timestamp'
					Expression = {
						if (Get-ConfigValue -Name 'UTC')
						{
							if (-not (Get-ConfigValue -Name 'TimeFormat')) { $_.Timestamp.ToUniversalTime() }
							else { $_.Timestamp.ToUniversalTime().ToString((Get-ConfigValue -Name 'TimeFormat')) }
						}
						else
						{
							if (-not (Get-ConfigValue -Name 'TimeFormat')) { $_.Timestamp }
							else { $_.Timestamp.ToString((Get-ConfigValue -Name 'TimeFormat')) }
						}
					}
				}
			}
			default { $_ }
		}
	}
	
	$script:logfile_paramWriteLogFileMessage = @{
		IncludeHeader = Get-ConfigValue -Name 'IncludeHeader'
		FileType	  = Get-ConfigValue -Name 'FileType'
		CsvDelimiter  = Get-ConfigValue -Name 'CsvDelimiter'
		Path		  = Get-LogFilePath
	}
	
	$script:encoding = Get-ConfigValue -Name 'Encoding'
	
	$script:JsonSettings = @{
		JsonCompress = Get-ConfigValue -Name JsonCompress
		JsonString   = Get-ConfigValue -Name JsonString
		JsonNoComma = Get-ConfigValue -Name JsonNoComma
	}
	Update-Mutex
}

$message_event = {
	param (
		$Message
	)
	
	if ($script:mutex) { $null = $script:mutex.WaitOne() }
	try { $Message | Select-Object $script:logfile_headers | Write-LogFileMessage @script:logfile_paramWriteLogFileMessage -MessageItem $Message }
	finally { if ($script:mutex) { $script:mutex.ReleaseMutex() } }
}

$end_event = {
	Invoke-LogRotate
}
#endregion Events

$configuration_Settings = {
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.FilePath' -Value "" -Initialize -Validation string -Description "The path to where the logfile is written. Supports some placeholders such as %Date% to allow for timestamp in the name. For full documentation on the supported wildcards, see the documentation on https://psframework.org"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.Logname' -Value "" -Initialize -Validation string -Description "A special string you can use as a placeholder in the logfile path (by using '%logname%' as placeholder)"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.IncludeHeader' -Value $true -Initialize -Validation bool -Description "Whether a written csv file will include headers"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.Headers' -Value @('ComputerName', 'File', 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Username') -Initialize -Validation stringarray -Description "The properties to export, in the order to select them."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.FileType' -Value "CSV" -Initialize -Validation psframework.logfilefiletype -Description "In what format to write the logfile. Supported styles: CSV, XML, Html, Json or CMTrace. Html, XML and Json will be written as fragments."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.CsvDelimiter' -Value "," -Initialize -Validation string -Description "The delimiter to use when writing to csv."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.TimeFormat' -Value "$([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.ShortDatePattern) $([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.LongTimePattern)" -Initialize -Validation string -Description "The format used for timestamps in the logfile"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.Encoding' -Value "UTF8" -Initialize -Validation string -Description "In what encoding to write the logfile."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.UTC' -Value $false -Initialize -Validation bool -Description "Whether the timestamp in the logfile should be converted to UTC"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.LogRotatePath' -Value "" -Initialize -Validation string -Description "The path where to logrotate. Specifying this setting will cause the logging provider to also rotate older logfiles"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.LogRetentionTime' -Value "30d" -Initialize -Validation timespan -Description "The minimum age for a logfile to be considered for deletion as part of logrotation"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.LogRotateFilter' -Value "*" -Initialize -Validation string -Description "A filter to apply to all files logrotated"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.LogRotateRecurse' -Value $false -Initialize -Validation bool -Description "Whether the logrotate aspect should recursively look for files to logrotate"
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.MutexName' -Value '' -Initialize -Validation string -Description "Name of a mutex to use. Use this to handle parallel logging into the same file from multiple processes, by picking the same name in each process."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.JsonCompress' -Value $false -Initialize -Validation bool -Description "Will compress the json entries, condensing each entry into a single line."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.JsonString' -Value $false -Initialize -Validation bool -Description "Will convert all enumerated properties to string values when converting to json. This causes the level property to be 'Debug','Host', ... rather than 8,2,..."
	Set-PSFConfig -Module PSFramework -Name 'Logging.LogFile.JsonNoComma' -Value $false -Initialize -Validation bool -Description "Prevent adding commas between two json entries."
}

$paramRegisterPSFLoggingProvider = @{
	Name			   = "logfile"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.LogFile'
	InstanceProperties = 'CsvDelimiter', 'FilePath', 'FileType', 'Headers', 'IncludeHeader', 'Logname', 'TimeFormat', 'Encoding', 'UTC', 'LogRotatePath', 'LogRetentionTime', 'LogRotateFilter', 'LogRotateRecurse', 'MutexName', 'JsonCompress', 'JsonString', 'JsonNoComma'
	FunctionDefinitions = $functionDefinitions
	BeginEvent		   = $begin_event
	StartEvent		   = $start_event
	MessageEvent	   = $message_event
	EndEvent		   = $end_event
	ConfigurationDefaultValues = @{
		IncludeHeader = $true
		Headers	      = 'ComputerName', 'File', 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Username'
		FileType	  = 'CSV'
		CsvDelimiter  = ','
		TimeFormat    = "$([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.ShortDatePattern) $([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.LongTimePattern)"
		Encoding	  = 'UTF8'
		LogRetentionTime = '30d'
		LogRotateFilter = '*'
		LogRotateRecurse = $false
	}
	ConfigurationSettings = $configuration_Settings
}

Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

$functionDefinitions = {
	function Send-SplunkData
	{
<#
	.SYNOPSIS
		Writes data to a splunk http event collector.
	
	.DESCRIPTION
		Writes data to a splunk http event collector.
		See this blog post for setting up the Splunk server:
		https://ntsystems.it/post/sending-events-to-splunks-http-event-collector-with-powershell
	
	.PARAMETER InputObject
		The object to send as message.
	
	.PARAMETER HostName
		The name of the computer from which the message was generated.
	
	.PARAMETER Timestamp
		The timestamp fron when the message was generated.
	
	.PARAMETER Uri
		Link to the http collector endpoint to which to write to.
		Example: https://localhost:8088/services/collector
	
	.PARAMETER Token
		The token associated with the http event collector.
#>
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
			$InputObject,
			
			[Parameter(Mandatory = $true)]
			[string]
			$HostName,
			
			[Parameter(Mandatory = $true)]
			[System.DateTime]
			$Timestamp,
			
			[Parameter(Mandatory = $true)]
			[string]
			$Uri,
			
			[Parameter(Mandatory = $true)]
			[string]
			$Token
		)
		process
		{
			# Splunk events can have a 'time' property in epoch time. If it's not set, use current system time.
			$unixEpochStart = New-Object -TypeName DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
			$unixEpochTime = [int]($Timestamp.ToUniversalTime() - $unixEpochStart).TotalSeconds
			
			# Create json object to send
			$eventData = @{
				event = $InputObject
				host  = $HostName
				time = $unixEpochTime
			}
			if ($index = Get-ConfigValue -Name Index) { $eventData.index = $index }
			if ($source = Get-ConfigValue -Name Source) { $eventData.source = $source }
			if ($sourcetype = Get-ConfigValue -Name SourceType) { $eventData.sourcetype = $sourcetype }
			
			$body = ConvertTo-Json -InputObject $eventData -Compress
			
			# Only return if something went wrong, i.e. http response is not "success"
			try { $null = Invoke-RestMethodCustom -Uri $uri -Method Post -Headers @{ Authorization = "Splunk $Token" } -Body $body -ErrorAction Stop -IgnoreCert:$(Get-ConfigValue -Name IgnoreCert) }
			catch { throw }
		}
	}
	
	function Invoke-RestMethodCustom
	{
		[CmdletBinding()]
		param (
			[string]
			$Uri,
			
			[System.Collections.Hashtable]
			$Headers,
			
			[string]
			$Method,
			
			[string]
			$ContentType = 'application/json',
			
			[string]
			$Body,
			
			[switch]
			$IgnoreCert
		)
		
		process
		{
			$request = [System.Net.WebRequest]::Create($Uri)
			foreach ($key in $Headers.Keys) { $request.Headers[$key] = $Headers[$key] }
			$request.Method = $Method
			if ($IgnoreCert) { $request.ServerCertificateValidationCallback = { $true } }
			$request.ContentLength = $Body.Length
			
			$requestWriter = New-Object System.IO.StreamWriter($request.GetRequestStream(), [System.Text.Encoding]::ASCII)
			$requestWriter.Write($Body)
			$requestWriter.Close()
			
			try
			{
				$responseStream = $request.GetResponse().GetResponseStream()
				$reader = New-Object System.IO.StreamReader($responseStream)
				$reader.ReadToEnd()
				$reader.Close()
			}
			catch { throw }
		}
	}
	
	function Write-SplunkMessage
	{
		[CmdletBinding()]
		param (
			$Message
		)
		
		$splunkUrl = Get-ConfigValue -Name 'Url'
		$splunkToken = Get-ConfigValue -Name 'Token'
		$properties = Get-ConfigValue -Name 'Properties'
		$name = Get-ConfigValue -Name 'LogName'
		
		$selectProps = switch ($properties)
		{
			'Message' { 'LogMessage as Message' }
			'Timestamp' { 'Timestamp.ToUniversalTime().ToString("yyyy-MM-dd_HH:mm:ss.fff") as Timestamp' }
			'Level' { 'Level to String' }
			'Type' { 'Type to String' }
			'CallStack' { 'CallStack to String' }
			'ErrorRecord' { 'ErrorRecord to String' }
			default { $_ }
		}
		$selectProps = @($selectProps) + @(@{ Name = 'LogName'; Expression = { $name } })
		
		$Message | Select-PSFObject $selectProps | Send-SplunkData -HostName $Message.ComputerName -Timestamp $Message.Timestamp -Uri $splunkUrl -Token $splunkToken
	}
}

$message_event = {
	param (
		$Message
	)
	Write-SplunkMessage -Message $Message
}

$configuration_Settings = {
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.Url' -Description 'The url to the Splunk http event collector. Example: https://localhost:8088/services/collector'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.Token' -Description 'The token used to authenticate to the Splunk event collector.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.Properties' -Initialize -Value 'Timestamp', 'Message', 'Level', 'Tags', 'FunctionName', 'ModuleName', 'Runspace', 'Username', 'ComputerName', 'TargetObject', 'Data' -Description 'The properties to write to Splunk.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.LogName' -Initialize -Value 'Undefined' -Validation string -Description 'Name associated with the task. Included in each entry, making it easier to reuse the same http event collector for multiple tasks.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.IgnoreCert' -Initialize -Value $false -Validation bool -Description 'Whether the server certificate should be validated or not.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.Index' -Initialize -Value '' -Validation string -Description 'The index to apply to all messages. Uses the splunk-defined default index if omitted.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.Source' -Initialize -Value '' -Validation string -Description 'Event source to add to all messages.'
	Set-PSFConfig -Module 'PSFramework' -Name 'Logging.Splunk.SourceType' -Initialize -Value '' -Validation string -Description 'Event source type to add to all messages.'
}

$paramRegisterPSFLoggingProvider = @{
	Name			   = "splunk"
	Version2		   = $true
	ConfigurationRoot  = 'PSFramework.Logging.Splunk'
	InstanceProperties = 'Url', 'Token', 'Properties', 'LogName', 'IgnoreCert', 'Index', 'Source', 'SourceType'
	MessageEvent	   = $message_Event
	ConfigurationSettings = $configuration_Settings
	FunctionDefinitions = $functionDefinitions
	ConfigurationDefaultValues = @{
		Properties = 'Timestamp', 'Message', 'Level', 'Tags', 'FunctionName', 'ModuleName', 'Runspace', 'Username', 'ComputerName', 'TargetObject', 'Data'
		LogName    = 'Undefined'
		IgnoreCert = $false
	}
}

# Register the Azure logging provider
Register-PSFLoggingProvider @paramRegisterPSFLoggingProvider

$FunctionDefinitions = {

    Function Export-DataToSql {
        <#
        .SYNOPSIS
            Function to send logging data to a Sql database

        .DESCRIPTION
            This function is the main function that takes a PSFMessage object to log in a Sql database.

        .PARAMETER ObjectToProcess
            This is a PSFMessage object that will be converted and serialized then injected to a Sql database.

        .EXAMPLE
            Export-DataToAzure $objectToProcess

        .NOTES
            How to register this provider
            -----------------------------
            Set-PSFLoggingProvider -Name sqllog -InstanceName sqlloginstance -Enabled $true
        #>

        [cmdletbinding()]
        param(
            [parameter(Mandatory = $True)]
            $ObjectToProcess
        )

        begin {
            $SqlServer = Get-ConfigValue -Name 'SqlServer'
            $SqlTable = Get-ConfigValue -Name 'Table'
            $SqlDatabaseName = Get-ConfigValue -Name 'Database'
        }

        process {
            $QueryParameters = @{
                "Message"      = $ObjectToProcess.LogMessage
                "Level"        = $ObjectToProcess.Level -as [string]
                "TimeStamp"    = $ObjectToProcess.TimeStamp.ToUniversalTime()
                "FunctionName" = $ObjectToProcess.FunctionName
                "ModuleName"   = $ObjectToProcess.ModuleName
                "Tags"         = $ObjectToProcess.Tags -join "," -as [string]
                "Runspace"     = $ObjectToProcess.Runspace -as [string]
                "ComputerName" = $ObjectToProcess.ComputerName
                "TargetObject" = $ObjectToProcess.TargetObject -as [string]
                "File"         = $ObjectToProcess.File
                "Line"         = $ObjectToProcess.Line
                "ErrorRecord"  = $ObjectToProcess.ErrorRecord -as [string]
                "CallStack"    = $ObjectToProcess.CallStack -as [string]
            }

            try {
                $SqlInstance = Connect-DbaInstance -SqlInstance $SqlServer
                if ($SqlInstance.ConnectionContext.IsOpen -ne 'True') {
                    $SqlInstance.ConnectionContext.Connect() # Try to connect to the database
                }

                $insertQuery = "INSERT INTO [$SqlDatabaseName].[dbo].[$SqlTable](Message, Level, TimeStamp, FunctionName, ModuleName, Tags, Runspace, ComputerName, TargetObject, [File], Line, ErrorRecord, CallStack)
                VALUES (@Message, @Level, @TimeStamp, @FunctionName, @ModuleName, @Tags, @Runspace, @ComputerName, @TargetObject, @File, @Line, @ErrorRecord, @CallStack)"
                Invoke-DbaQuery -SqlInstance $SqlInstance -Database $SqlDatabaseName -Query $insertQuery -SqlParameters $QueryParameters -EnableException
            }
            catch { throw }
        }
    }

    function New-DefaultSqlDatabaseAndTable {
        <#
        .SYNOPSIS
                This function will create a default sql database object

        .DESCRIPTION
                This function will create the default sql default logging database

        .EXAMPLE
            None
        #>

        [cmdletbinding()]
        param(
        )

        # need to use dba tools to create the database and credentials for connecting.


        begin {

            # set instance and database name variables
            $Credential = Get-ConfigValue -Name 'Credential'
            $SqlServer = Get-ConfigValue -Name 'SqlServer'
            $SqlTable = Get-ConfigValue -Name 'Table'
            $SqlDatabaseName = Get-ConfigValue -Name 'Database'

            $parameters = @{
                SqlInstance = $SqlServer
            }
            if ($Credential) { $parameters.SqlCredential = $Credential }
        }
        process {
            try {
                $dbaconnection = Connect-DbaInstance @parameters
                if (-NOT (Get-DbaDatabase -SqlInstance $dbaconnection | Where-Object Name -eq $SqlDatabaseName)) {
                    $database = New-DbaDatabase -SqlInstance $dbaconnection -Name $SqlDatabaseName
                }
                if (-NOT($database.Tables | Where-Object Name -eq $SqlTable)) {
                    $createtable = "CREATE TABLE $SqlTable (Message VARCHAR(max), Level VARCHAR(max), TimeStamp [DATETIME], FunctionName VARCHAR(max), ModuleName VARCHAR(max), Tags VARCHAR(max), Runspace VARCHAR(36), ComputerName VARCHAR(max), TargetObject VARCHAR(max), [File] VARCHAR(max), Line BIGINT, ErrorRecord VARCHAR(max), CallStack VARCHAR(max))"
                    Invoke-dbaquery -SQLInstance $SqlServer -Database $SqlDatabaseName -query $createtable
                }
            }
            catch {
                throw
            }
        }
    }
}

#region Installation
$installationParameters = {
    $results = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $attributesCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $parameterAttribute.ParameterSetName = '__AllParameterSets'
    $attributesCollection.Add($parameterAttribute)

    $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute('CurrentUser', 'AllUsers')
    $attributesCollection.Add($validateSetAttribute)

    $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter("Scope", [string], $attributesCollection)
    $results.Add("Scope", $RuntimeParam)
    $results
}

$installation_script = {
    param (
        $BoundParameters
    )

    $paramInstallModule = @{
        Name = 'dbatools'
    }
    if ($BoundParameters.Scope) { $paramInstallModule['Scope'] = $BoundParameters.Scope }
    elseif (-not (Test-PSFPowerShell -Elevated)) { $paramInstallModule['Scope'] = 'CurrentUser' }

    Install-Module @paramInstallModule
}

$isInstalled_script = {
    (Get-Module dbatools -ListAvailable) -as [bool]
}
#endregion Installation
#region Events
$begin_event = {
    New-DefaultSqlDatabaseAndTable
}

$message_event = {
    param (
        $Message
    )

    Export-DataToSql -ObjectToProcess $Message
}

# Action that is performed when stopping the logging script.
$final_event = {

}
#endregion Events

# Configuration values for the logging provider
$configuration_Settings = {
	Set-PSFConfig -Module PSFramework -Name 'Logging.Sql.Credential' -Initialize -Validation 'credential' -Description "Credentials used for connecting to the SQL server."
    Set-PSFConfig -Module PSFramework -Name 'Logging.Sql.Database' -Value "LoggingDatabase" -Initialize -Validation 'string' -Description "SQL server database."
    Set-PSFConfig -Module PSFramework -Name 'Logging.Sql.Table' -Value "LoggingTable" -Initialize -Validation 'string' -Description "SQL server database table."
    Set-PSFConfig -Module PSFramework -Name 'Logging.Sql.SqlServer' -Value "" -Initialize -Description "SQL server hosting logs."
}

# Registered parameters for the logging provider.
# ConfigurationDefaultValues are used for all instances of the sql log provider
$paramRegisterPSFSqlProvider = @{
    Name                       = "Sql"
    Version2                   = $true
    ConfigurationRoot          = 'PSFramework.Logging.Sql'
    InstanceProperties         = 'Database', 'Table', 'SqlServer', 'Credential'
    MessageEvent               = $message_Event
    BeginEvent                 = $begin_event
    FinalEvent                 = $final_event
    IsInstalledScript          = $isInstalled_script
    InstallationScript         = $installation_script
    ConfigurationSettings      = $configuration_Settings
    InstallationParameters     = $installationParameters
    FunctionDefinitions        = $functionDefinitions
    ConfigurationDefaultValues = @{
        'Database'  = "LoggingDatabase"
        'Table'     = "LoggingTable"
    }
}

# Register the Azure logging provider
Register-PSFLoggingProvider @paramRegisterPSFSqlProvider

[PSFramework.Logging.ProviderHost]::ProviderV2ModuleScript = {
	param (
		$LoggingProviderInstance
	)
	
	try
	{
		$module = New-Module -Name ([guid]::NewGuid()) -ArgumentList $LoggingProviderInstance -ScriptBlock {
			param (
				$LoggingProviderInstance
			)
			
			$Instance = [pscustomobject]@{
				Name = $LoggingProviderInstance.Name
				Provider = $LoggingProviderInstance.Provider.Name
				ConfigurationRoot = $LoggingProviderInstance.Provider.ConfigurationRoot
			}
			
			# Validate Language Mode for security reasons
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.BeginEvent -Mode 'ConstrainedLanguage') { throw "The event BeginEvent is in constrained language mode and cannot be loaded!" }
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.StartEvent -Mode 'ConstrainedLanguage') { throw "The event StartEvent is in constrained language mode and cannot be loaded!" }
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.MessageEvent -Mode 'ConstrainedLanguage') { throw "The event MessageEvent is in constrained language mode and cannot be loaded!" }
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.ErrorEvent -Mode 'ConstrainedLanguage') { throw "The event ErrorEvent is in constrained language mode and cannot be loaded!" }
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.EndEvent -Mode 'ConstrainedLanguage') { throw "The event EndEvent is in constrained language mode and cannot be loaded!" }
			if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.FinalEvent -Mode 'ConstrainedLanguage') { throw "The event FinalEvent is in constrained language mode and cannot be loaded!" }
			
			if ($LoggingProviderInstance.Provider.Functions)
			{
				if (Test-PSFLanguageMode -ScriptBlock $LoggingProviderInstance.Provider.Functions -Mode "ConstrainedLanguage") { throw "The functions resource scriptblock is in constrained language mode and cannot be loaded!" }
				# Invoke in current scope after localizing the scriptblock into the current context
				$LoggingProviderInstance.Provider.Functions.InvokeEx($false, $true, $false)
			}
			
			${  functionNames  } = @{
				Begin   = [guid]::NewGuid()
				Start   = [guid]::NewGuid()
				Message = [guid]::NewGuid()
				Error   = [guid]::NewGuid()
				End	    = [guid]::NewGuid()
				Final   = [guid]::NewGuid()
			}
			
			function Get-ConfigValue
			{
				[CmdletBinding()]
				param (
					[string]
					$Name
				)
				
				$rootPath = $script:Instance.ConfigurationRoot
				if ($script:Instance.Name -and $script:Instance.Name -ne "Default")
				{
					$rootPath += ".$($script:Instance.Name)"
				}
				
				Get-PSFConfigValue -FullName "$rootPath.$Name"
			}
			
			Set-Content -Path "function:\$(${  functionNames  }.Begin)" -Value $LoggingProviderInstance.Provider.BeginEvent.ToString()
			$LoggingProviderInstance.BeginCommand = Get-Command ${  functionNames  }.Begin
			Set-Content -Path "function:\$(${  functionNames  }.Start)" -Value $LoggingProviderInstance.Provider.StartEvent.ToString()
			$LoggingProviderInstance.StartCommand = Get-Command ${  functionNames  }.Start
			Set-Content -Path "function:\$(${  functionNames  }.Message)" -Value $LoggingProviderInstance.Provider.MessageEvent.ToString()
			$LoggingProviderInstance.MessageCommand = Get-Command ${  functionNames  }.Message
			Set-Content -Path "function:\$(${  functionNames  }.Error)" -Value $LoggingProviderInstance.Provider.ErrorEvent.ToString()
			$LoggingProviderInstance.ErrorCommand = Get-Command ${  functionNames  }.Error
			Set-Content -Path "function:\$(${  functionNames  }.End)" -Value $LoggingProviderInstance.Provider.EndEvent.ToString()
			$LoggingProviderInstance.EndCommand = Get-Command ${  functionNames  }.End
			Set-Content -Path "function:\$(${  functionNames  }.Final)" -Value $LoggingProviderInstance.Provider.FinalEvent.ToString()
			$LoggingProviderInstance.FinalCommand = Get-Command ${  functionNames  }.Final
			
			$ExecutionContext.SessionState.Module.PrivateData = @{
				Commands = ${  functionNames  }
			}
			Remove-Variable -Name 'event', '  functionNames  ', 'LoggingProviderInstance'
			
			Export-ModuleMember
		} -ErrorAction Stop
	}
	catch
	{
		$LoggingProviderInstance.Errors.Enqueue($_)
		$LoggingProviderInstance.Enabled = $false
	}
	if ($module)
	{
		$LoggingProviderInstance.Module = $module
	}
}

$scriptBlock = {
	try
	{
		$script:___ScriptName = 'PSFramework.Logging'
		
		Import-Module (Join-Path ([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot) 'PSFramework.psd1')
		
		while ($true)
		{
			# This portion is critical to gracefully closing the script
			if ([PSFramework.Runspace.RunspaceHost]::Runspaces[$___ScriptName].State -notlike "Running")
			{
				break
			}
			if (-not ([PSFramework.Message.LogHost]::LoggingEnabled)) { break }
			
			# Create instances as needed on cycle begin
			[PSFramework.Logging.ProviderHost]::UpdateAllInstances()
			
			#region Manage Begin Event
			#region V1 providers
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetEnabled())
			{
				if (-not $___provider.Initialized)
				{
					[PSFramework.Logging.ProviderHost]::LoggingState = 'Initializing'
					$___provider.LocalizeEvents()
					
					try
					{
						$ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.BeginEvent, $null, $null)
						$___provider.Initialized = $true
					}
					catch { $___provider.Errors.Push($_) }
				}
			}
			#endregion V1 providers
			
			#region V2 provider Instances
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetEnabledInstances())
			{
				if ($___instance.Initialized) { continue }
				
				[PSFramework.Logging.ProviderHost]::LoggingState = 'Initializing'
				
				try
				{
					& $___instance.BeginCommand
					$___instance.Initialized = $true
				}
				catch { $___instance.Errors.Enqueue($_)}
			}
			#endregion V2 provider Instances
			
			[PSFramework.Logging.ProviderHost]::LoggingState = 'Ready'
			#endregion Manage Begin Event
			
			#region Start Event
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
			{
				try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.StartEvent, $null, $null) }
				catch { $___provider.Errors.Push($_) }
			}
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
			{
				try { & $___instance.StartCommand }
				catch { $___instance.Errors.Enqueue($_) }
			}
			#endregion Start Event
			
			#region Message Event
			while ([PSFramework.Message.LogHost]::OutQueueLog.Count -gt 0)
			{
				$Entry = $null
				[PSFramework.Message.LogHost]::OutQueueLog.TryDequeue([ref]$Entry)
				if ($Entry)
				{
					[PSFramework.Logging.ProviderHost]::LoggingState = 'Writing'
					foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
					{
						if ($___provider.MessageApplies($Entry))
						{
							try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.MessageEvent, $null, $Entry) }
							catch { $___provider.Errors.Push($_) }
						}
					}
					
					foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
					{
						if ($___instance.MessageApplies($Entry))
						{
							try { & $___instance.MessageCommand $Entry }
							catch { $___instance.Errors.Enqueue($_) }
						}
					}
				}
				[PSFramework.Message.LogHost]::LastLogged = [DateTime]::Now
			}
			#endregion Message Event
			
			#region Error Event
			while ([PSFramework.Message.LogHost]::OutQueueError.Count -gt 0)
			{
				$Record = $null
				[PSFramework.Message.LogHost]::OutQueueError.TryDequeue([ref]$Record)
				
				if ($Record)
				{
					[PSFramework.Logging.ProviderHost]::LoggingState = 'Writing'
					foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
					{
						if ($___provider.MessageApplies($Record))
						{
							try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.ErrorEvent, $null, $Record) }
							catch { $___provider.Errors.Push($_) }
						}
					}
					
					foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
					{
						if ($___instance.MessageApplies($Record))
						{
							try { & $___instance.ErrorCommand $Record }
							catch { $___instance.Errors.Enqueue($_) }
						}
					}
				}
				[PSFramework.Message.LogHost]::LastLogged = [DateTime]::Now
			}
			#endregion Error Event
			
			#region End Event
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
			{
				try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.EndEvent, $null, $null) }
				catch { $___provider.Errors.Push($_) }
			}
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
			{
				try { & $___instance.EndCommand }
				catch { $___instance.Errors.Enqueue($_) }
			}
			#endregion End Event
			
			#region Finalize / Cleanup
			# Adding $true will cause it to also return disabled providers / instances that are intitialized
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized($true))
			{
				if ($___provider.Enabled) { continue }
				try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.FinalEvent, $null, $null) }
				catch { $___provider.Errors.Push($_) }
				$___provider.Initialized = $false
			}
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances($true))
			{
				if ($___instance.Enabled) { continue }
				try { & $___instance.FinalCommand }
				catch { $___instance.Errors.Enqueue($_) }
				$___instance.Initialized = $false
			}
			#endregion Finalize / Cleanup
			
			[PSFramework.Logging.ProviderHost]::LoggingState = 'Ready'
			
			# Skip sleeping if the next messages already await
			if ([PSFramework.Message.LogHost]::OutQueueLog.Count -gt 0) { continue }
			Start-Sleep -Milliseconds ([PSFramework.Message.LogHost]::NextInterval)
		}
	}
	catch
	{
		$wasBroken = $true
	}
	finally
	{
		#region Flush log on exit
		if (([PSFramework.Runspace.RunspaceHost]::Runspaces[$___ScriptName].State -like "Running") -and (-not [PSFramework.Configuration.ConfigurationHost]::Configurations["psframework.logging.disablelogflush"].Value))
		{
			#region Start Event
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
			{
				try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.StartEvent, $null, $null) }
				catch { $___provider.Errors.Push($_) }
			}
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
			{
				try { & $___instance.StartCommand }
				catch { $___instance.Errors.Enqueue($_) }
			}
			#endregion Start Event
			
			#region Message Event
			while ([PSFramework.Message.LogHost]::OutQueueLog.Count -gt 0)
			{
				$Entry = $null
				[PSFramework.Message.LogHost]::OutQueueLog.TryDequeue([ref]$Entry)
				if ($Entry)
				{
					[PSFramework.Logging.ProviderHost]::LoggingState = 'Writing'
					foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
					{
						if ($___provider.MessageApplies($Entry))
						{
							try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.MessageEvent, $null, $Entry) }
							catch { $___provider.Errors.Push($_) }
						}
					}
					
					foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
					{
						if ($___instance.MessageApplies($Entry))
						{
							try { & $___instance.MessageCommand $Entry }
							catch { $___instance.Errors.Enqueue($_) }
						}
					}
				}
			}
			#endregion Message Event
			
			#region Error Event
			while ([PSFramework.Message.LogHost]::OutQueueError.Count -gt 0)
			{
				$Record = $null
				[PSFramework.Message.LogHost]::OutQueueError.TryDequeue([ref]$Record)
				
				if ($Record)
				{
					[PSFramework.Logging.ProviderHost]::LoggingState = 'Writing'
					foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
					{
						if ($___provider.MessageApplies($Record))
						{
							try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.MessageEvent, $null, $Record) }
							catch { $___provider.Errors.Push($_) }
						}
					}
					
					foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
					{
						if ($___instance.MessageApplies($Record))
						{
							try { & $___instance.ErrorCommand $Record }
							catch { $___instance.Errors.Enqueue($_) }
						}
					}
				}
			}
			#endregion Error Event
			
			#region End Event
			foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
			{
				try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.EndEvent, $null, $null) }
				catch { $___provider.Errors.Push($_) }
			}
			foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
			{
				try { & $___instance.EndCommand }
				catch { $___instance.Errors.Enqueue($_) }
			}
			#endregion End Event
		}
		#endregion Flush log on exit
		
		#region Final Event
		foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
		{
			try { $ExecutionContext.InvokeCommand.InvokeScript($false, $___provider.FinalEvent, $null, $null) }
			catch { $___provider.Errors.Push($_) }
		}
		foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
		{
			try { & $___instance.FinalCommand }
			catch { $___instance.Errors.Enqueue($_) }
		}
		
		foreach ($___provider in [PSFramework.Logging.ProviderHost]::GetInitialized())
		{
			$___provider.Initialized = $false
		}
		foreach ($___instance in [PSFramework.Logging.ProviderHost]::GetInitializedInstances())
		{
			$___instance.Initialized = $false
		}
		foreach ($___provider in [PSFramework.Logging.ProviderHost]::Providers.Values)
		{
			if ($___provider.ProviderVersion -eq 'Version_1') { continue }
			
			$___provider.Instances.Clear()
		}
		#endregion Final Event
		
		if ($wasBroken) { [PSFramework.Logging.ProviderHost]::LoggingState = 'Broken' }
		else { [PSFramework.Logging.ProviderHost]::LoggingState = 'Stopped' }
		
		[PSFramework.Runspace.RunspaceHost]::Runspaces[$___ScriptName].SignalStopped()
	}
}

Register-PSFRunspace -ScriptBlock $scriptBlock -Name 'PSFramework.Logging' -NoMessage

$exemptedProcesses = 'CacheBuilder64', 'CacheBuilder', 'ImportModuleHelp'
# Do not start background Runspace if ...
if (
	-not (
		# ... run in the PowerShell Studio Cache Builder
		(($Host.Name -eq 'Default Host') -and ((Get-Process -Id $PID).ProcessName -in $exemptedProcesses)) -or
		# ... run in Azure Functions
		($env:AZUREPS_HOST_ENVIRONMENT -like 'AzureFunctions/*')
	)
)
{
	Start-PSFRunspace -Name 'PSFramework.Logging' -NoMessage
}

Register-PSFTeppScriptblock -Name 'PSFramework.Callback.Name' -ScriptBlock {
	(Get-PSFCallback).Name | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-config-fullname" -ScriptBlock {
	[PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object { -not $_.Hidden } | Select-Object -ExpandProperty FullName
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-config-module" -ScriptBlock {
	[PSFramework.Configuration.ConfigurationHost]::Configurations.Values.Module | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-config-name" -ScriptBlock {
	$moduleName = "*"
	if ($fakeBoundParameter.Module) { $moduleName = $fakeBoundParameter.Module }
	[PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object { -not $_.Hidden -and ($_.Module -like $moduleName) } | Select-Object -ExpandProperty Name
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-Config-Schema' -ScriptBlock {
	[PSFramework.Configuration.ConfigurationHost]::Schemata.Keys
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-config-validation' -ScriptBlock {
	[PSFramework.Configuration.ConfigurationHost]::Validation.Keys
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-dynamiccontentobject-name' -ScriptBlock {
	[PSFramework.Utility.DynamicContentObject]::List
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-Encoding" -ScriptBlock {
	'Unicode'
	'BigEndianUnicode'
	'UTF8'
	'UTF8Bom'
	'UTF8NoBom'
	'UTF7'
	'UTF32'
	'Ascii'
	'Default'
	'BigEndianUTF32'
	if (Get-PSFConfigValue -FullName 'PSFramework.Text.Encoding.FullTabCompletion')
	{
		[System.Text.Encoding]::GetEncodings().BodyName
	}
} -Global

Register-PSFTeppScriptblock -Name "PSFramework.Feature.Name" -ScriptBlock {
	(Get-PSFFeature).Name
} -Global

Register-PSFTeppScriptblock -Name PSFramework-Input-ObjectProperty -ScriptBlock {
	#region Utility Functions
	function Get-Property
	{
		[CmdletBinding()]
		param (
			$InputObject
		)
		
		if (-not $InputObject) { return @{ } }
		$properties = @{ }
		
		switch ($InputObject.GetType().FullName)
		{
			#region Variables or static input
			'System.Management.Automation.Language.CommandExpressionAst'
			{
				switch ($InputObject.Expression.GetType().Name)
				{
					'BinaryExpressionAst'
					{
						# Return an empty array. A binary expression ast means pure numbers as input, no properties
						return @{ }
					}
					'VariableExpressionAst'
					{
						$members = Get-Variable -Name $InputObject.Expression.VariablePath.UserPath -ValueOnly -ErrorAction Ignore | Write-Output | Select-Object -First 1 | Get-Member -MemberType Properties
						foreach ($member in $members)
						{
							try
							{
								$typeString = $member.Definition.Split(" ")[0]
								$memberType = [type]$typeString
								$typeKnown = $true
							}
							catch
							{
								$memberType = $null
								$typeKnown = $false
							}
							
							$properties[$member.Name] = [pscustomobject]@{
								Name = $member.Name
								Type = $memberType
								TypeKnown = $typeKnown
							}
						}
						return $properties
					}
					'MemberExpressionAst'
					{
						try { $members = Get-Variable -Name $InputObject.Expression.Expression.VariablePath.UserPath -ValueOnly -ErrorAction Ignore | Where-Object $InputObject.Expression.Member.Value -ne $null | Select-Object -First 1 -ExpandProperty $InputObject.Expression.Member.Value -ErrorAction Ignore | Get-Member -MemberType Properties }
						catch { return $properties }
						foreach ($member in $members)
						{
							try
							{
								$typeString = $member.Definition.Split(" ")[0]
								$memberType = [type]$typeString
								$typeKnown = $true
							}
							catch
							{
								$memberType = $null
								$typeKnown = $false
							}
							
							$properties[$member.Name] = [pscustomobject]@{
								Name = $member.Name
								Type = $memberType
								TypeKnown = $typeKnown
							}
						}
						return $properties
					}
					'ArrayLiteralAst'
					{
						# Not yet supported
						return @{ }
					}
				}
				#region Input from Variable
				if ($pipelineAst.PipelineElements[$inputIndex].Expression -and $pipelineAst.PipelineElements[0].Expression[0].VariablePath)
				{
					$properties += ((Get-Variable -Name $pipelineAst.PipelineElements[0].Expression[0].VariablePath.UserPath -ValueOnly) | Select-Object -First 1 | Get-Member -MemberType Properties).Name
				}
				#endregion Input from Variable
			}
			#endregion Variables or static input
			
			#region Input from Command
			'System.Management.Automation.Language.CommandAst'
			{
				$command = Get-Command $InputObject.CommandElements[0].Value -ErrorAction Ignore
				if ($command -is [System.Management.Automation.AliasInfo]) { $command = $command.ResolvedCommand }
				if (-not $command) { return $properties }
				
				foreach ($type in $command.OutputType.Type)
				{
					foreach ($member in $type.GetMembers("Instance, Public"))
					{
						# Skip all members except Fields (4) or Properties (16)
						if (-not ($member.MemberType -band 20)) { continue }
						
						$properties[$member.Name] = [pscustomobject]@{
							Name = $member.Name
							Type = $null
							TypeKnown = $true
						}
						if ($member.PropertyType) { $properties[$member.Name].Type = $member.PropertyType }
						else { $properties[$member.Name].Type = $member.FieldType }
					}
					
					foreach ($propertyExtensionItem in ([PSFramework.TabExpansion.TabExpansionHost]::InputCompletionTypeData[$type.FullName]))
					{
						$properties[$propertyExtensionItem.Name] = $propertyExtensionItem
					}
				}
				
				#region Command Specific Inserts
				foreach ($propertyExtensionItem in ([PSFramework.TabExpansion.TabExpansionHost]::InputCompletionCommandData[$command.Name]))
				{
					$properties[$propertyExtensionItem.Name] = $propertyExtensionItem
				}
				#endregion Command Specific Inserts
				
				return $properties
			}
			#endregion Input from Command
			
			# Unknown / Unexpected input
			default { return @{ } }
		}
	}
	
	function Update-Property
	{
		[CmdletBinding()]
		param (
			[Hashtable]
			$Property,
			
			$Step
		)
		
		$properties = @{ }
		#region Expand Property
		if ($Step.ExpandProperty)
		{
			if (-not ($Property[$Step.ExpandProperty])) { return $properties }
			
			$expanded = $Property[$Step.ExpandProperty]
			if (-not $expanded.TypeKnown) { return $properties }
			
			foreach ($member in $expanded.Type.GetMembers("Instance, Public"))
			{
				# Skip all members except Fields (4) or Properties (16)
				if (-not ($member.MemberType -band 20)) { continue }
				
				$properties[$member.Name] = [pscustomobject]@{
					Name = $member.Name
					Type = $null
					TypeKnown = $true
				}
				if ($member.PropertyType) { $properties[$member.Name].Type = $member.PropertyType }
				else { $properties[$member.Name].Type = $member.FieldType }
			}
			
			foreach ($propertyExtensionItem in ([PSFramework.TabExpansion.TabExpansionHost]::InputCompletionTypeData[$expanded.Type.FullName]))
			{
				$properties[$propertyExtensionItem.Name] = $propertyExtensionItem
			}
			
			return $properties
		}
		#endregion Expand Property
		
		# In keep input mode, the original properties will not be affected in any way
		if ($Step.KeepInputObject) { $properties = $Property.Clone() }
		$filterProperties = $Step.Properties | Where-Object Kind -eq "Property"
		
		#region Select What to keep
		if (-not $Step.KeepInputObject)
		{
			:main foreach ($propertyItem in $Property.Values)
			{
				#region Excluded Properties
				foreach ($exclusion in $Step.Excluded)
				{
					if ($propertyItem.Name -like $exclusion) { continue main }
				}
				#endregion Excluded Properties
				
				foreach ($stepProperty in $filterProperties)
				{
					if ($propertyItem.Name -like $stepProperty.Name)
					{
						$properties[$propertyItem.Name] = $propertyItem
						continue main
					}
				}
			}
		}
		#endregion Select What to keep
		
		#region Adding Content
		:main foreach ($stepProperty in $Step.Properties)
		{
			switch ($stepProperty.Kind)
			{
				'Property'
				{
					if ($stepProperty.Filter) { continue main }
					if ($properties[$stepProperty.Name]) { continue main }
					
					foreach ($exclusion in $Step.Excluded)
					{
						if ($stepProperty.Name -like $exclusion) { continue main }
					}
					
					$properties[$stepProperty.Name] = [PSCustomObject]@{
						Name = $stepProperty.Name
						Type = $null
						TypeKnown = $false
					}
					continue main
				}
				'CalculatedProperty'
				{
					if ($properties[$stepProperty.Name]) { continue main }
					
					$properties[$stepProperty.Name] = [PSCustomObject]@{
						Name = $stepProperty.Name
						Type = $null
						TypeKnown = $false
					}
					continue main
				}
				'ScriptProperty'
				{
					if ($properties[$stepProperty.Name]) { continue main }
					
					$properties[$stepProperty.Name] = [PSCustomObject]@{
						Name = $stepProperty.Name
						Type = $null
						TypeKnown = $false
					}
					continue main
				}
				'AliasProperty'
				{
					if ($properties[$stepProperty.Name]) { continue main }
					
					$properties[$stepProperty.Name] = [PSCustomObject]@{
						Name = $stepProperty.Name
						Type = $null
						TypeKnown = $false
					}
					if ($properties[$stepProperty.Target].TypeKnown)
					{
						$properties[$stepProperty.Name].Type = $properties[$stepProperty.Target].Type
						$properties[$stepProperty.Name].TypeKnown = $properties[$stepProperty.Target].TypeKnown
					}
					
					continue main
				}
			}
		}
		#endregion Adding Content
		$properties
	}
	
	function Read-SelectObject
	{
		[CmdletBinding()]
		param (
			[System.Management.Automation.Language.CommandAst]
			$Ast,
			
			[string]
			$CommandName = 'Select-Object'
		)
		
		$results = [pscustomobject]@{
			Ast			    = $Ast
			BoundParameters = @()
			Property	    = @()
			ExcludeProperty = @()
			ExpandProperty  = ''
			ScriptProperty  = @()
			AliasProperty   = @()
			KeepInputObject = $false
		}
		
		#region Process Ast
		if ($Ast.CommandElements.Count -gt 1)
		{
			$index = 1
			$parameterName = ''
			$position = 0
			while ($index -lt $Ast.CommandElements.Count)
			{
				$element = $Ast.CommandElements[$index]
				switch ($element.GetType().FullName)
				{
					'System.Management.Automation.Language.CommandParameterAst'
					{
						$parameterName = $element.ParameterName
						if ($parameterName -like "k*") { $results.KeepInputObject = $true }
						$results.BoundParameters += $element.ParameterName
						break
					}
					'System.Management.Automation.Language.StringConstantExpressionAst'
					{
						if (-not $parameterName)
						{
							switch ($position)
							{
								0 { $results.Property = $element }
								1 { $results.AliasProperty = $element }
								2 { $results.ScriptProperty = $element }
							}
							$position = $position + 1
						}
						
						if ($parameterName -like "pr*") { $results.Property = $element }
						if ($parameterName -like "exp*") { $results.ExpandProperty = $element.Value }
						if ($parameterName -like "exc*") { $results.ExcludeProperty = $element.Value }
						if ($parameterName -like "a*") { $results.AliasProperty = $element }
						if ($parameterName -like "scriptp*") { $results.ScriptProperty = $element }
						$parameterName = ''
						break
					}
					'System.Management.Automation.Language.ArrayLiteralAst'
					{
						if (-not $parameterName)
						{
							switch ($position)
							{
								0 { $results.Property = $element.Elements }
								1 { $results.AliasProperty = $element.Elements }
								2 { $results.ScriptProperty = $element.Elements }
							}
							$position = $position + 1
						}
						
						if ($parameterName -like "pr*") { $results.Property = $element.Elements }
						if ($parameterName -like "exp*") { $results.ExpandProperty = $element.Elements.Value }
						if ($parameterName -like "exc*") { $results.ExcludeProperty = $element.Elements.Value }
						if ($parameterName -like "a*") { $results.AliasProperty = $element.Elements }
						if ($parameterName -like "scriptp*") { $results.ScriptProperty = $element.Elements }
						
						$parameterName = ''
						break
					}
					'System.Management.Automation.Language.ConstantExpressionAst'
					{
						if (-not $parameterName)
						{
							switch ($position)
							{
								0 { $results.Property = $element }
								1 { $results.AliasProperty = $element }
								2 { $results.ScriptProperty = $element }
							}
							$position = $position + 1
						}
						
						if ($parameterName -like "pr*") { $results.Property = $element }
						if ($parameterName -like "exp*") { $results.ExpandProperty = $element.Value.ToString() }
						if ($parameterName -like "exc*") { $results.ExcludeProperty = $element.Value.ToString() }
						if ($parameterName -like "a*") { $results.AliasProperty = $element }
						if ($parameterName -like "scriptp*") { $results.ScriptProperty = $element }
						$parameterName = ''
						break
					}
					'System.Management.Automation.Language.HashtableAst'
					{
						if (-not $parameterName)
						{
							switch ($position)
							{
								0 { $results.Property = $element }
								1 { $results.AliasProperty = $element }
								2 { $results.ScriptProperty = $element }
							}
							$position = $position + 1
						}
						
						if ($parameterName -like "pr*") { $results.Property = $element }
						if ($parameterName -like "a*") { $results.AliasProperty = $element }
						if ($parameterName -like "scriptp*") { $results.ScriptProperty = $element }
						$parameterName = ''
						break
					}
					default
					{
						$parameterName = ''
					}
				}
				$index = $index + 1
			}
		}
		#endregion Process Ast
		
		#region Convert Results
		$resultsProcessed = [pscustomobject]@{
			HasIncludeFilter = $false
			RawResult	     = $results
			Properties	     = @()
			Excluded		 = $results.ExcludeProperty
			ExpandProperty   = $results.ExpandProperty
			KeepInputObject  = $results.KeepInputObject
		}
		
		switch ($CommandName)
		{
			#region Select-Object
			'Select-Object'
			{
				#region Properties
				foreach ($element in $results.Property)
				{
					switch ($element.GetType().FullName)
					{
						'System.Management.Automation.Language.HashtableAst'
						{
							try
							{
								$resultsProcessed.Properties += [pscustomobject]@{
									Name = ($element.KeyValuePairs | Where-Object Item1 -Match '^N$|^Name$|^L$|^Label$' | Select-Object -First 1).Item2.PipelineElements[0].Expression.Value
									Kind = "CalculatedProperty"
									Type = "Unknown"
									Filter = $false
								}
							}
							catch { }
						}
						default
						{
							if ($element.Value -match "\*") { $resultsProcessed.HasIncludeFilter = $true }
							
							$resultsProcessed.Properties += [pscustomobject]@{
								Name = $element.Value.ToString()
								Kind = "Property"
								Type = "Inherited"
								Filter = $element.Value -match "\*"
							}
						}
					}
				}
				#endregion Properties
			}
			#endregion Select-Object
			
			#region Select-PSFObject
			'Select-PSFObject'
			{
				#region Properties
				foreach ($element in $results.Property)
				{
					switch ($element.GetType().FullName)
					{
						'System.Management.Automation.Language.HashtableAst'
						{
							try
							{
								$resultsProcessed.Properties += [pscustomobject]@{
									Name = ($element.KeyValuePairs | Where-Object Item1 -Match '^N$|^Name$|^L$|^Label$' | Select-Object -First 1).Item2.PipelineElements[0].Expression.Value
									Kind = "CalculatedProperty"
									Type = "Unknown"
									Filter = $false
								}
							}
							catch { }
						}
						default
						{
							try { $parameterItem = ([PSFramework.Parameter.SelectParameter]$element.Value).Value }
							catch { continue }
							
							if ($parameterItem -is [System.String])
							{
								if ($parameterItem -match "\*") { $resultsProcessed.HasIncludeFilter = $true }
								
								$resultsProcessed.Properties += [pscustomobject]@{
									Name   = $parameterItem
									Kind   = "Property"
									Type   = "Inherited"
									Filter = $parameterItem -match "\*"
								}
							}
							else
							{
								$resultsProcessed.Properties += [pscustomobject]@{
									Name   = $parameterItem
									Kind   = "CalculatedProperty"
									Type   = "Unknown"
									Filter = $false
								}
							}
						}
					}
				}
				#endregion Properties
				
				#region Script Properties
				foreach ($scriptProperty in $results.ScriptProperty)
				{
					switch ($scriptProperty.GetType().FullName)
					{
						'System.Management.Automation.Language.HashtableAst'
						{
							foreach ($name in $scriptProperty.KeyValuePairs.Item1.Value)
							{
								$resultsProcessed.Properties += [pscustomobject]@{
									Name   = $name
									Kind   = "ScriptProperty"
									Type   = "Unknown"
									Filter = $false
								}
							}
						}
						default
						{
							try { $propertyValue = [PSFramework.Parameter.SelectScriptPropertyParameter]$scriptProperty.Value }
							catch { continue }
							
							$resultsProcessed.Properties += [pscustomobject]@{
								Name = $propertyValue.Value.Name
								Kind = "ScriptProperty"
								Type = "Unknown"
								Filter = $false
							}
						}
					}
				}
				#endregion Script Properties
				
				#region Alias Properties
				foreach ($scriptProperty in $results.AliasProperty)
				{
					switch ($scriptProperty.GetType().FullName)
					{
						'System.Management.Automation.Language.HashtableAst'
						{
							foreach ($aliasPair in $scriptProperty.KeyValuePairs)
							{
								$resultsProcessed.Properties += [pscustomobject]@{
									Name = $aliasPair.Item1.Value
									Kind = "AliasProperty"
									Type = "Alias"
									Filter = $false
									Target = $aliasPair.Item2.PipelineElements.Expression.Value
								}
							}
						}
						default
						{
							try { $propertyValue = [PSFramework.Parameter.SelectAliasParameter]$scriptProperty.Value }
							catch { continue }
							
							$resultsProcessed.Properties += [pscustomobject]@{
								Name = $propertyValue.Aliases[0].Name
								Kind = "AliasProperty"
								Type = "Alias"
								Filter = $false
								Target = $propertyValue.Aliases[0].ReferencedMemberName
							}
						}
					}
				}
				#endregion Alias Properties
			}
			#endregion Select-PSFObject
		}
		#endregion Convert Results
		
		$resultsProcessed
	}
	#endregion Utility Functions
	
	# Grab Pipeline and find starting index
	[System.Management.Automation.Language.PipelineAst]$pipelineAst = $commandAst.parent
	$index = $pipelineAst.PipelineElements.IndexOf($commandAst)
	
	# If it's the first item: Skip, no input to parse
	if ($index -lt 1) { return }
	
	$inputIndex = $index - 1
	$steps = @{ }
	
	#region Step backwards through the pipeline until the definitive object giver is found
	:outmain while ($true)
	{
		if ($pipelineAst.PipelineElements[$inputIndex].CommandElements)
		{
			# Resolve command and fail if it breaks
			$command = $null
			# Work around the ? alias for Where-Object being a wildcard
			if ($pipelineAst.PipelineElements[$inputIndex].CommandElements[0].Value -eq "?") { $command = Get-Alias -Name "?" | Where-Object Name -eq "?" }
			else { $command = Get-Command $pipelineAst.PipelineElements[$inputIndex].CommandElements[0].Value -ErrorAction Ignore }
			if ($command -is [System.Management.Automation.AliasInfo]) { $command = $command.ResolvedCommand }
			if (-not $command) { return }
			
			switch ($command.Name)
			{
				'Where-Object'
				{
					$steps[$inputIndex] = [pscustomobject]@{
						Index = $inputIndex
						Skip  = $true
						Type  = 'Where'
					}
					$inputIndex = $inputIndex - 1
					continue outmain
				}
				'Tee-Object'
				{
					$steps[$inputIndex] = [pscustomobject]@{
						Index = $inputIndex
						Skip  = $true
						Type  = 'Tee'
					}
					$inputIndex = $inputIndex - 1
					continue outmain
				}
				'Sort-Object'
				{
					$steps[$inputIndex] = [pscustomobject]@{
						Index = $inputIndex
						Skip  = $true
						Type  = 'Sort'
					}
					$inputIndex = $inputIndex - 1
					continue outmain
				}
				#region Select-Object
				'Select-Object'
				{
					$selectObject = Read-SelectObject -Ast $pipelineAst.PipelineElements[$inputIndex] -CommandName 'Select-Object'
					
					$steps[$inputIndex] = [pscustomobject]@{
						Index = $inputIndex
						Skip  = $false
						Type  = 'Select'
						Data  = $selectObject
					}
					
					if ($selectObject.HasIncludeFilter -or ($selectObject.Properties.Type -eq "Inherited") -or $selectObject.ExpandProperty)
					{
						$inputIndex = $inputIndex - 1
						continue outmain
					}
					break outmain
				}
				#endregion Select-Object
				#region Select-PSFObject
				'Select-PSFObject'
				{
					$selectObject = Read-SelectObject -Ast $pipelineAst.PipelineElements[$inputIndex] -CommandName 'Select-PSFObject'
					
					$steps[$inputIndex] = [pscustomobject]@{
						Index = $inputIndex
						Skip  = $false
						Type  = 'PSFSelect'
						Data  = $selectObject
					}
					
					if ($selectObject.HasIncludeFilter -or ($selectObject.Properties.Type -eq "Inherited") -or $selectObject.ExpandProperty)
					{
						$inputIndex = $inputIndex - 1
						continue outmain
					}
					break outmain
				}
				#endregion Select-PSFObject
				default { break outmain }
			}
		}
		
		else
		{
			break
		}
	}
	#endregion Step backwards through the pipeline until the definitive object giver is found
	
	# Catch moving through _all_ options in the pipeline
	if ($inputIndex -lt 0) { return }
	
	#region Process resulting / reaching properties
	$properties = Get-Property -InputObject $pipelineAst.PipelineElements[$inputIndex]
	$inputIndex = $inputIndex + 1
	
	while ($inputIndex -lt $index)
	{
		# Eliminate preliminary follies
		if (-not $steps[$inputIndex]) { $inputIndex = $inputIndex + 1; continue }
		if ($steps[$inputIndex].Skip) { $inputIndex = $inputIndex + 1; continue }
		
		# Process the current step, then move on unless done
		$properties = Update-Property -Property $properties -Step $steps[$inputIndex].Data
		
		$inputIndex = $inputIndex + 1
	}
	#endregion Process resulting / reaching properties
	
	$properties.Keys | Sort-Object
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-license-name' -ScriptBlock {
	(Get-PSFLicense).Product
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-LanguageNames' -ScriptBlock {
	[System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures).Name | Where-Object { $_ -and ($_.Trim()) }
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-LocalizedStrings-Names' -ScriptBlock {
	([PSFRamework.Localization.LocalizationHost]::Strings.Values | Where-Object Module -EQ $fakeBoundParameter.Module).Name
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-LocalizedStrings-Modules' -ScriptBlock {
	[PSFRamework.Localization.LocalizationHost]::Strings.Values.Module | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-logging-provider' -ScriptBlock {
	(Get-PSFLoggingProvider).Name
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-logging-instance-provider' -ScriptBlock {
	(Get-PSFLoggingProviderInstance).Provider.Name | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-logging-instance-name' -ScriptBlock {
	if ($fakeBoundParameters.ProviderName)
	{
		return (Get-PSFLoggingProviderInstance -ProviderName $fakeBoundParameters.ProviderName).Name
	}
	(Get-PSFLoggingProviderInstance).Name | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Message.Module' -ScriptBlock {
	Get-PSFMessage | Select-Object -ExpandProperty ModuleName | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Message.Function' -ScriptBlock {
	Get-PSFMessage | Select-Object -ExpandProperty FunctionName | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Message.Tags' -ScriptBlock {
	Get-PSFMessage | Select-Object -ExpandProperty Tags | Remove-PSFNull -Enumerate | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Message.Runspace' -ScriptBlock {
	Get-PSFMessage | Select-Object -ExpandProperty Runspace | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Message.Level' -ScriptBlock {
	Get-PSFMessage | Select-Object -ExpandProperty Level | Select-Object -Unique
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework.Utility.PathName' -ScriptBlock {
	(Get-PSFConfig "PSFramework.Path.*").Name -replace '^.+\.([^\.]+)$', '$1'
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-utility-psprovider' -ScriptBlock {
	(Get-PSProvider).Name
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-runspace-name' -ScriptBlock {
	(Get-PSFRunspace).Name
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-tepp-scriptblockname' -ScriptBlock {
	[PSFramework.TabExpansion.TabExpansionHost]::Scripts.Keys
} -Global

Register-PSFTeppScriptblock -Name 'PSFramework-tepp-parametername' -ScriptBlock {
	if ($fakeBoundParameter.Command)
	{
		$common = 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm'
		
		try
		{
			$command = Get-Command $fakeBoundParameter.Command
			if ($command -is [System.Management.Automation.AliasInfo]) { $command = $command.ResolvedCommand }
			$command.Parameters.Keys | Where-Object { $_ -notin $common }
		}
		catch { }
	}
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-Unregister-PSFConfig-FullName" -ScriptBlock {
	switch ("$($fakeBoundParameter.Scope)")
	{
		"UserDefault" { $path = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default" }
		"UserMandatory" { $path = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Enforced" }
		"SystemDefault" { $path = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default" }
		"SystemMandatory" { $path = "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Enforced" }
		default { $path = "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\PSFramework\Config\Default" }
	}
	
	if (Test-Path $path)
	{
		$properties = Get-ItemProperty -Path $path
		$common = 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider'
		$properties.PSObject.Properties.Name | Where-Object { $_ -notin $common }
	}
} -Global

Register-PSFTeppScriptblock -Name "PSFramework-Unregister-PSFConfig-Module" -ScriptBlock {
	[PSFramework.Configuration.ConfigurationHost]::Configurations.Values.Module | Select-Object -Unique
} -Global

#region Configuration
Register-PSFTeppArgumentCompleter -Command Export-PSFConfig -Parameter FullName -Name 'PSFramework-config-fullname'
Register-PSFTeppArgumentCompleter -Command Export-PSFConfig -Parameter Module -Name 'PSFramework-config-module'
Register-PSFTeppArgumentCompleter -Command Export-PSFConfig -Parameter Name -Name 'PSFramework-config-name'

Register-PSFTeppArgumentCompleter -Command Get-PSFConfig -Parameter FullName -Name 'PSFramework-config-fullname'
Register-PSFTeppArgumentCompleter -Command Get-PSFConfig -Parameter Module -Name 'PSFramework-config-module'
Register-PSFTeppArgumentCompleter -Command Get-PSFConfig -Parameter Name -Name 'PSFramework-config-name'

Register-PSFTeppArgumentCompleter -Command Import-PSFConfig -Parameter Schema -Name 'PSFramework-Config-Schema'

Register-PSFTeppArgumentCompleter -Command Set-PSFConfig -Parameter FullName -Name 'PSFramework-config-fullname'
Register-PSFTeppArgumentCompleter -Command Set-PSFConfig -Parameter Module -Name 'PSFramework-config-module'
Register-PSFTeppArgumentCompleter -Command Set-PSFConfig -Parameter Name -Name 'PSFramework-config-name'
Register-PSFTeppArgumentCompleter -Command Set-PSFConfig -Parameter Validation -Name 'PSFramework-config-validation'

Register-PSFTeppArgumentCompleter -Command Register-PSFConfig -Parameter FullName -Name 'PSFramework-config-fullname'
Register-PSFTeppArgumentCompleter -Command Register-PSFConfig -Parameter Module -Name 'PSFramework-config-module'
Register-PSFTeppArgumentCompleter -Command Register-PSFConfig -Parameter Name -Name 'PSFramework-config-name'

Register-PSFTeppArgumentCompleter -Command Get-PSFConfigValue -Parameter FullName -Name 'PSFramework-config-fullname'

Register-PSFTeppArgumentCompleter -Command Unregister-PSFConfig -Parameter FullName -Name 'PSFramework-Unregister-PSFConfig-FullName'
Register-PSFTeppArgumentCompleter -Command Unregister-PSFConfig -Parameter Module -Name 'PSFramework-Unregister-PSFConfig-Module'
#endregion Configuration

#region Features
Register-PSFTeppArgumentCompleter -Command Get-PSFFeature -Parameter Name -Name 'PSFramework.Feature.Name'
Register-PSFTeppArgumentCompleter -Command Set-PSFFeature -Parameter Name -Name 'PSFramework.Feature.Name'
Register-PSFTeppArgumentCompleter -Command Test-PSFFeature -Parameter Name -Name 'PSFramework.Feature.Name'
#endregion Features

#region Flow Control
Register-PSFTeppArgumentCompleter -Command Get-PSFCallback -Parameter Name -Name 'PSFramework.Callback.Name'
Register-PSFTeppArgumentCompleter -Command Unregister-PSFCallback -Parameter Name -Name 'PSFramework.Callback.Name'
#endregion Flow Control

#region License
Register-PSFTeppArgumentCompleter -Command Get-PSFLicense -Parameter Filter -Name 'PSFramework-license-name'
#endregion License

#region Localization
Register-PSFTeppArgumentCompleter -Command Import-PSFLocalizedString -Parameter Language -Name 'PSFramework-LanguageNames'
Register-PSFTeppArgumentCompleter -Command Get-PSFLocalizedString -Parameter Module -Name 'PSFramework-LocalizedStrings-Modules'
Register-PSFTeppArgumentCompleter -Command Get-PSFLocalizedString -Parameter Name -Name 'PSFramework-LocalizedStrings-Names'
#endregion Localization

#region Logging
Register-PSFTeppArgumentCompleter -Command Get-PSFLoggingProvider -Parameter Name -Name 'PSFramework-logging-provider'
Register-PSFTeppArgumentCompleter -Command Install-PSFLoggingProvider -Parameter Name -Name 'PSFramework-logging-provider'
Register-PSFTeppArgumentCompleter -Command Set-PSFLoggingProvider -Parameter Name -Name 'PSFramework-logging-provider'
Register-PSFTeppArgumentCompleter -Command Get-PSFLoggingProviderInstance -Parameter ProviderName -Name 'PSFramework-logging-instance-provider'
Register-PSFTeppArgumentCompleter -Command Get-PSFLoggingProviderInstance -Parameter Name -Name 'PSFramework-logging-instance-name'
#endregion Logging

#region Message
Register-PSFTeppArgumentCompleter -Command Get-PSFMessage -Parameter ModuleName -Name 'PSFramework.Message.Module'
Register-PSFTeppArgumentCompleter -Command Get-PSFMessage -Parameter FunctionName -Name 'PSFramework.Message.Function'
Register-PSFTeppArgumentCompleter -Command Get-PSFMessage -Parameter Tag -Name 'PSFramework.Message.Tags'
Register-PSFTeppArgumentCompleter -Command Get-PSFMessage -Parameter Runspace -Name 'PSFramework.Message.Runspace'
Register-PSFTeppArgumentCompleter -Command Get-PSFMessage -Parameter Level -Name 'PSFramework.Message.Level'
#endregion Message

#region Runspace
Register-PSFTeppArgumentCompleter -Command Get-PSFRunspace -Parameter Name -Name 'PSFramework-runspace-name'
Register-PSFTeppArgumentCompleter -Command Register-PSFRunspace -Parameter Name -Name 'PSFramework-runspace-name'
Register-PSFTeppArgumentCompleter -Command Stop-PSFRunspace -Parameter Name -Name 'PSFramework-runspace-name'
Register-PSFTeppArgumentCompleter -Command Start-PSFRunspace -Parameter Name -Name 'PSFramework-runspace-name'

Register-PSFTeppArgumentCompleter -Command Get-PSFDynamicContentObject -Parameter Name -Name 'PSFramework-dynamiccontentobject-name'
Register-PSFTeppArgumentCompleter -Command Set-PSFDynamicContentObject -Parameter Name -Name 'PSFramework-dynamiccontentobject-name'
#endregion Runspace

#region Serialization
Register-PSFTeppArgumentCompleter -Command Export-PSFClixml -Parameter Encoding -Name 'PSFramework-Encoding'
Register-PSFTeppArgumentCompleter -Command Import-PSFClixml -Parameter Encoding -Name 'PSFramework-Encoding'
#endregion Serialization

#region Tab Completion
Register-PSFTeppArgumentCompleter -Command Set-PSFTeppResult -Parameter TabCompletion -Name 'PSFramework-tepp-scriptblockname'
Register-PSFTeppArgumentCompleter -Command Register-PSFTeppArgumentCompleter -Parameter Name -Name 'PSFramework-tepp-scriptblockname'
Register-PSFTeppArgumentCompleter -Command Register-PSFTeppArgumentCompleter -Parameter Parameter -Name 'PSFramework-tepp-parametername'
#endregion Tab Completion

#region Utility
Register-PSFTeppArgumentCompleter -Command ConvertFrom-PSFArray -Parameter PropertyName -Name PSFramework-Input-ObjectProperty

Register-PSFTeppArgumentCompleter -Command ConvertTo-PSFHashtable -Parameter Include -Name PSFramework-Input-ObjectProperty
Register-PSFTeppArgumentCompleter -Command ConvertTo-PSFHashtable -Parameter Exclude -Name PSFramework-Input-ObjectProperty

Register-PSFTeppArgumentCompleter -Command Resolve-PSFPath -Parameter Provider -Name PSFramework-utility-psprovider
Register-PSFTeppArgumentCompleter -Command Get-PSFPath -Parameter Name -Name 'PSFramework.Utility.PathName'
Register-PSFTeppArgumentCompleter -Command Set-PSFPath -Parameter Name -Name 'PSFramework.Utility.PathName'

Register-PSFTeppArgumentCompleter -Command Select-PSFObject -Parameter Property -Name PSFramework-Input-ObjectProperty
Register-PSFTeppArgumentCompleter -Command Select-PSFObject -Parameter ExpandProperty -Name PSFramework-Input-ObjectProperty
Register-PSFTeppArgumentCompleter -Command Select-PSFObject -Parameter ExcludeProperty -Name PSFramework-Input-ObjectProperty
Register-PSFTeppArgumentCompleter -Command Select-PSFObject -Parameter ShowProperty -Name PSFramework-Input-ObjectProperty
Register-PSFTeppArgumentCompleter -Command Select-PSFObject -Parameter ShowExcludeProperty -Name PSFramework-Input-ObjectProperty
#endregion Utility


$mappings = @{
	"deserialized.microsoft.activedirectory.management.addomaincontroller" = @("HostName", "Name")
	"microsoft.activedirectory.management.addomaincontroller"			   = @("HostName", "Name")
	"microsoft.sqlserver.management.smo.server"						       = @("NetName", "DomainInstanceName")
	"deserialized.microsoft.sqlserver.management.smo.server"			   = @("NetName", "DomainInstanceName")
	"microsoft.sqlserver.management.smo.linkedserver"					   = @("Name")
	"deserialized.microsoft.sqlserver.management.smo.linkedserver"		   = @("Name")
	"microsoft.activedirectory.management.adcomputer"					   = @("DNSHostName", "Name")
	"deserialized.microsoft.activedirectory.management.adcomputer"		   = @("DNSHostName", "Name")
	"Microsoft.DnsClient.Commands.DnsRecord_A"							   = @("Name", "IPAddress")
	"Deserialized.Microsoft.DnsClient.Commands.DnsRecord_A"			       = @("Name", "IPAddress")
	"Microsoft.DnsClient.Commands.DnsRecord_AAAA"						   = @("Name", "IPAddress")
	"Deserialized.Microsoft.DnsClient.Commands.DnsRecord_AAAA"			   = @("Name", "IPAddress")
}


foreach ($key in $mappings.Keys)
{
	Register-PSFParameterClassMapping -ParameterClass 'Computer' -TypeName $key -Properties $mappings[$key]
}

#region Configuration Static Remove() Compatibility
Update-TypeData -TypeName "System.Collections.Concurrent.ConcurrentDictionary``2[[$([System.String].AssemblyQualifiedName)],[$([PSFramework.Configuration.Config].AssemblyQualifiedName)]]" -MemberType ScriptMethod -MemberName Remove -Value ([scriptblock]::Create(@'
param (
    $Item
)

$dummyItem = $null
$null = $this.TryRemove($Item, [ref] $dummyItem)
'@)) -Force
#endregion Configuration Static Remove() Compatibility

$scriptBlock = {
	$script:___ScriptName = 'psframework.taskengine'
	
	try
	{
		#region Main Execution
		while ($true)
		{
			# This portion is critical to gracefully closing the script
			if ([PSFramework.Runspace.RunspaceHost]::Runspaces[$___ScriptName].State -notlike "Running")
			{
				break
			}
			
			$task = $null
			$tasksDone = @()
			while ($task = [PSFramework.TaskEngine.TaskHost]::GetNextTask($tasksDone))
			{
				$task.State = 'Running'
				try
				{
					[PSFramework.Utility.UtilityHost]::ImportScriptBlock($task.ScriptBlock)
					$task.ScriptBlock.Invoke()
					$task.State = 'Pending'
				}
				catch
				{
					$task.State = 'Error'
					$task.LastError = $_
					Write-PSFMessage -EnableException $false -Level Warning -Message "[Maintenance] Task '$($task.Name)' failed to execute" -ErrorRecord $_ -FunctionName "task:TaskEngine" -Target $task -ModuleName PSFramework
				}
				$task.LastExecution = Get-Date
				if (-not $task.Pending -and ($task.Status -eq "Pending")) { $task.Status = 'Completed' }
				$tasksDone += $task.Name
			}
			
			# If there will no more tasks need executing in the future, might as well kill the runspace
			if (-not ([PSFramework.TaskEngine.TaskHost]::HasPendingTasks)) { break }
			
			Start-Sleep -Seconds 5
		}
		#endregion Main Execution
	}
	catch {  }
	finally
	{
		[PSFramework.Runspace.RunspaceHost]::Runspaces[$___ScriptName].SignalStopped()
	}
}

Register-PSFRunspace -ScriptBlock $scriptBlock -Name 'psframework.taskengine' -NoMessage

#region Handle Module Removal
$PSF_OnRemoveScript = {
	# Stop all managed runspaces ONLY on the main runspace's termination
	if ([runspace]::DefaultRunspace.Id -eq 1)
	{
		Wait-PSFMessage -Timeout 30s -Terminate
		Get-PSFRunspace | Stop-PSFRunspace
		[PSFramework.PSFCore.PSFCoreHost]::Uninitialize()
	}
	
	# Properly disconnect all remote sessions still held open
	$psframework_pssessions.Values | Remove-PSSession
	# Remove all Runspace-specific callbacks
	[PSFramework.FlowControl.CallbackHost]::RemoveRunspaceOwned()
}
$ExecutionContext.SessionState.Module.OnRemove += $PSF_OnRemoveScript
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $PSF_OnRemoveScript
#endregion Handle Module Removal

#region Declare runtime variable for the flow control component
$paramNewVariable = @{
	Name  = "psframework_killqueue"
	Value = (New-Object PSFramework.Utility.LimitedConcurrentQueue[int](25))
	Option = 'ReadOnly'
	Scope = 'Script'
	Description = 'Variable that is used to maintain the list of commands to kill. This is used by Test-PSFFunctionInterrupt. Note: The value tested is the hashcade from the callstack item.'
}

New-Variable @paramNewVariable
#endregion Declare runtime variable for the flow control component

#region Declare PSSession Cache
$paramNewVariable2 = @{
	Name  = "psframework_pssessions"
	Value = (New-Object PSFramework.ComputerManagement.PSSessionContainer)
	Option = 'ReadOnly'
	Scope = 'Script'
	Description = 'Variable containing the list of established powershell remoting sessions. This is used by Invoke-PSFCommand to track connections, disconnect expired sessions and reconnect sessions by name.'
}

New-Variable @paramNewVariable2
#endregion Declare PSSession Cache

#region Register Features
Register-PSFFeature -Name 'PSFramework.InheritEnableException' -NotGlobal -Owner PSFramework -Description 'Causes all PSFramework commands with the -EnableException parameter to check, whether the caller has that variable set (e.g. by having a parameter with the same name) and respect that as well.'
Register-PSFFeature -Name 'PSFramework.Stop-PSFFunction.ShowWarning' -Owner PSFramework -Description 'Causes calls to Stop-PSFFunction to always show warnings. By default, using "-EnableException $true" will only throw the exception but not show the warning.'
#endregion Register Features

# Load Session Registrations for the Session Container feature
# See: New-PSSessionContainer

Register-PSFSessionObjectType -DisplayName CimSession -TypeName Microsoft.Management.Infrastructure.CimSession
Register-PSFSessionObjectType -DisplayName PSSession -TypeName System.Management.Automation.Runspaces.PSSession
Register-PSFSessionObjectType -DisplayName SmoServer -TypeName Microsoft.SqlServer.Management.Smo.Server

[PSFramework.TabExpansion.TabExpansionHost]::InputCompletionTypeData['System.IO.FileInfo'] = @(
	[PSCustomObject]@{
		Name	  = 'PSChildName'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSDrive'
		Type	  = ([type]'System.Management.Automation.PSDriveInfo')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSIsContainer'
		Type	  = ([type]'System.Boolean')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSParentPath'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSPath'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSProvider'
		Type	  = ([type]'System.Management.Automation.ProviderInfo')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'BaseName'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'VersionInfo'
		Type	  = ([type]'System.Diagnostics.FileVersionInfo')
		TypeKnown = $true
	}
)

[PSFramework.TabExpansion.TabExpansionHost]::InputCompletionTypeData['System.IO.DirectoryInfo'] = @(
	[PSCustomObject]@{
		Name	  = 'PSChildName'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSDrive'
		Type	  = ([type]'System.Management.Automation.PSDriveInfo')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSIsContainer'
		Type	  = ([type]'System.Boolean')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSParentPath'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSPath'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'PSProvider'
		Type	  = ([type]'System.Management.Automation.ProviderInfo')
		TypeKnown = $true
	},
	[PSCustomObject]@{
		Name	  = 'BaseName'
		Type	  = ([type]'System.String')
		TypeKnown = $true
	}
)

#region Path Generic
Set-PSFScriptblock -Name 'PSFramework.Validate.Path' -Scriptblock {
	Test-Path -Path $_
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.Path.Container' -Scriptblock {
	Test-Path -Path $_ -PathType Container
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.Path.Leaf' -Scriptblock {
	Test-Path -Path $_ -PathType Leaf
} -Global
#endregion Path Generic

#region Path: File System
Set-PSFScriptblock -Name 'PSFramework.Validate.FSPath' -Scriptblock {
	if (-not (Test-Path -Path $_)) { return $false }
	if ((Get-Item $_).PSProvider.Name -ne 'FileSystem') { return $false }
	
	$true
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.FSPath.File' -Scriptblock {
	if (-not (Test-Path -Path $_)) { return $false }
	if ((Get-Item $_).PSProvider.Name -ne 'FileSystem') { return $false }
	
	Test-Path -Path $_ -PathType Leaf
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.FSPath.FileOrParent' -Scriptblock {
	try { Resolve-PSFPath -Path $_ -Provider FileSystem -NewChild -SingleItem }
	catch { $false }
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.FSPath.Folder' -Scriptblock {
	if (-not (Test-Path -Path $_)) { return $false }
	if ((Get-Item $_).PSProvider.Name -ne 'FileSystem') { return $false }
	
	Test-Path -Path $_ -PathType Container
} -Global
#endregion Path: File System

#region Uri
Set-PSFScriptblock -Name 'PSFramework.Validate.Uri.Absolute' -Scriptblock {
	$uri = $_ -as [uri]
	$uri.IsAbsoluteUri
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.Uri.Absolute.Https' -Scriptblock {
	$uri = $_ -as [uri]
	$uri.IsAbsoluteUri -and ($uri.Scheme -eq 'https')
} -Global

Set-PSFScriptblock -Name 'PSFramework.Validate.Uri.Absolute.File' -Scriptblock {
	$uri = $_ -as [uri]
	$uri.IsAbsoluteUri -and ($uri.Scheme -eq 'file')
} -Global
#endregion Uri

Set-PSFScriptblock -Name 'PSFramework.Validate.TimeSpan.Positive' -Scriptblock {
	if ($_ -is [PSFTimeSpan]) { $_.Value.Ticks -gt 0 }
	else { $_.Ticks -gt 0 }
} -Global

$license = New-PSFLicense -Product 'PSFramework' -Manufacturer 'Friedrich Weinmann' -ProductVersion $ModuleVersion -ProductType Module -Name MIT -Version "1.0.0.0" -Date (Get-Date -Year 2017 -Month 04 -Day 27 -Hour 0 -Minute 0 -Second 0) -Text @"
Copyright (c) Friedrich Weinmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@

#region Chris Dent
$null = New-PSFLicense -Product 'Import-PSCmdlet' -Manufacturer 'Chris Dent' -ProductVersion '1.0.0.0' -ProductType Script -Name MIT -Version '1.0.0.0' -Date (Get-Date -Year 2018 -Month 05 -Day 16).Date -Text @"
Copyright (c) Chris Dent

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ -Description @"
The PSFramework is happy to publish the Import-PSFCmdlet command, based on the
original work of Chris Dent's, 'Import-PSCmdlet'

Thank you for allowing its use :)
- Original Source: https://www.indented.co.uk/cmdlets-without-a-dll/
- Author blog: https://www.indented.co.uk/
"@ -Parent $license
#endregion Chris Dent

#region Joel Bennet
$null = New-PSFLicense -Product 'Configuration-ExportPaths' -Manufacturer 'Joel Bennet' -ProductVersion '1.3.0' -ProductType Script -Name MIT -Version '1.0.0.0' -Date (Get-Date -Year 2018 -Month 05 -Day 16).Date -Text @"
Copyright (c) 2015 Joel Bennett

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"@ -Description @"
The PSFramework is happy to base its internal path selection for configuration
exports on the original work of Joel Bennet's, 'Configuration' module.
Its implementation can be found in the internal script file:
internal/scripts/loadConfigurationPersisted.ps1

Thank you for allowing its use :)
- Original Source: https://github.com/PoshCode/Configuration
- Author blog: http://huddledmasses.org/blog/
- Author Twitter: https://twitter.com/jaykul?lang=en
"@ -Parent $license
#endregion Joel Bennet

#region Jason Shirk: Tab Expansion Plus Plus
$null = New-PSFLicense -Product 'TabExpansionPlusPlus' -Manufacturer 'Jason Shirk' -ProductVersion '1.2' -ProductType Module -Name BSD-2 -Version '2.0.0.0' -Date (Get-Date -Year 2013 -Month 05 -Day 8).Date -Text @'
Copyright (c) 2013, Jason Shirk
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'@ -Description @'
The PSFramework would like to thank Jason Shirk for his work on improving user experience.

We include major portions of his module "TabExpansionPlusPlus" which can be found on Github:
https://github.com/lzybkr/TabExpansionPlusPlus
The source we use can be found at:
internal/scripts/teppCoreCode.ps1

It is used to provide improved tab expansion experience on PowerShell versions 3 or 4.
'@ -Parent $license
#endregion Jason Shirk: Tab Expansion Plus Plus
#endregion Load compiled code