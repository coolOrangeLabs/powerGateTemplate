#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

if ($processName -notin @('Connectivity.VaultPro', 'Inventor')) {
	return
}

Import-Module powerGate

function ConnectToConfiguredERPServices() {
	Disconnect-ERP
	Connect-ERP -UseSettingsFromVault
}

Register-VaultEvent -EventName LoginVault_Post -Action 'ConnectToConfiguredERPServices'

Add-VaultMenuItem -Location ToolsMenu -Name 'powerGate Settings...' -Action {
	if($ERPSettings.Editor.ShowDialog()) {
		ConnectToConfiguredERPServices
	}
}