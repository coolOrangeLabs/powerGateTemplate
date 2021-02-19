﻿Register-PSFTeppScriptblock -Name "PSFramework-config-name" -ScriptBlock {
	$moduleName = "*"
	if ($fakeBoundParameter.Module) { $moduleName = $fakeBoundParameter.Module }
	[PSFramework.Configuration.ConfigurationHost]::Configurations.Values | Where-Object { -not $_.Hidden -and ($_.Module -like $moduleName) } | Select-Object -ExpandProperty Name
} -Global