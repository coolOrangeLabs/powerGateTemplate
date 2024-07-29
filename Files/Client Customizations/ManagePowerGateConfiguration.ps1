#==============================================================================#
# (c) 2022 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the ToolsMenu items for downloading and uploading ERP Tab configuration, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Connectivity.VaultPro', 'Inventor')) {
    return
}

$global:erpName = "ERP"

$powerGateErpTabconfiguration = "$PSScriptRoot\PowerGateConfiguration.xml"

function GetPowerGateConfiguration($section) {
    Write-Host "Retrieving configuration for section: $section"

    if(-not (Test-Path $powerGateErpTabconfiguration)) {
        Write-Host "Configuration could not be retrieved from: '$powerGateErpTabconfiguration'"
        return
    }

    $configuration = [xml](Get-Content $powerGateErpTabconfiguration) 
    if ($null -eq $configuration -or $configuration.HasChildNodes -eq $false) {
        return
    }
    $configEntries = Select-Xml -xml $configuration -XPath "//$section"
    return @($configEntries.Node.ChildNodes | Sort-Object -Property value)
}