﻿function Unregister-PSFConfig
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
