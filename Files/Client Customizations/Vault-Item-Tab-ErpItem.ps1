#==============================================================================#
# (c) 2022 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the ERP Item tab for items, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Connectivity.VaultPro')) {
	return
}

Add-VaultTab -Name "$erpName Item" -EntityType Item -Action {
	param($selectedItem)

	$partNumber = $selectedItem._Number
	$xamlFile = [xml](Get-Content "$PSScriptRoot\Vault-Tab-ErpItem.xaml")
	$tab_control = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

	#region prechecks
	$tab_control.FindName('ButtonErpItem').Visibility = "Collapsed"
	$tab_control.FindName('ItemData').Visibility = "Collapsed"
	if ($null -eq $partNumber -or $partNumber -eq "") {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The Part Number is empty! A Part Number is required to create an $erpName Item."
		return $tab_control
	}
	$tab_control.FindName('ButtonErpItem').Visibility = "Visible"
	#endregion prechecks

	$erpItem = Get-ERPObject -EntitySet 'Items' -Keys @{ Number = $partNumber } 
	if ($? -eq $false) { return }
	if (-not $erpItem) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_new.png'
		$tab_control.FindName('Title').Content = "$erpName Item '$partNumber' does not exist. Would you like to create it?"

		$tab_control.FindName('ButtonErpItem').IsEnabled = $true
		$tab_control.FindName('ButtonErpItem').Content = "Create new $erpName Item..."
		$tab_control.FindName('ButtonErpItem').Add_Click({
				CreateNewErpItem -selectedItem $selectedItem 
				[System.Windows.Forms.SendKeys]::SendWait('{F5}')
			}.GetNewClosure())
	}
	else {
		$tab_control.FindName('ItemData').Visibility = "Visible"
		$tab_control.FindName('ItemData').DataContext = $erpItem
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_identical.png'
		$tab_control.FindName('Title').Content = "$erpName Item '$partNumber' - '$($erpItem.Title)'"

		$tab_control.FindName('UnitOfMeasureCombobox').ItemsSource = (GetPowerGateConfiguration 'UnitOfMeasures')

		$tab_control.FindName('ButtonErpItem').IsEnabled = $true
		$tab_control.FindName('ButtonErpItem').Content = "Change $erpName Item..."
		$tab_control.FindName('ButtonErpItem').Add_Click({
				UpdateErpItem -erpItem $erpItem
				[System.Windows.Forms.SendKeys]::SendWait('{F5}')
			}.GetNewClosure())
	}

	function global:CreateNewErpItem($selectedItem) {
		$xamlFile = [xml](Get-Content "$PSScriptRoot\ErpItemCreate.xaml")
		$window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

		$window.FindName('UnitOfMeasureCombobox').ItemsSource = (GetPowerGateConfiguration 'UnitOfMeasures')

		$erpItem = $selectedItem | New-ERPObject -EntityType 'Item'
		#TODO:Validation
		$window.FindName('ItemData').DataContext = $erpItem

		$window.FindName('ButtonSubmit').Add_Click({
			Add-ErpObject -EntitySet 'Items' -Properties $erpItem
			if ($? -eq $false) { return }
			$null = [System.Windows.MessageBox]::Show("$erpName Item '$partNumber' was successfully created!", "Create $erpName Item", "OK", "Information")
			$window.Close()
		})
		$window.FindName('ButtonCancel').Add_Click({ $window.Close() })

		$window.ShowDialog()
	}

	function global:UpdateErpItem($erpItem) {
		$xamlFile = [xml](Get-Content "$PSScriptRoot\ErpItemUpdate.xaml")
		$window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

		$window.FindName('UnitOfMeasureCombobox').ItemsSource = (GetPowerGateConfiguration 'UnitOfMeasures')

		$window.FindName('ItemData').DataContext = $erpItem

		$window.FindName('ButtonSubmit').Add_Click({
			Update-ErpObject -EntitySet 'Items' -Keys $erpItem._Keys -Properties $erpItem._Properties
			if ($? -eq $false) { return }
			$null = [System.Windows.MessageBox]::Show("$erpName Item '$partNumber' was successfully updated!", "Update $erpName Item", "OK", "Information")
			$window.Close()
		})
		$window.FindName('ButtonCancel').Add_Click({ $window.Close() })

		$window.ShowDialog()
	}

	return $tab_control
}