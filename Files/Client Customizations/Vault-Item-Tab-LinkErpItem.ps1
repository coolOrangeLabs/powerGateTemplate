#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the Link ERP Item tab for items, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Connectivity.VaultPro')) {
	return
}

Add-VaultTab -Name "Link $erpName Item" -EntityType Item -Action {
	param($selectedItem)
	
	$partNumber = $selectedItem._Number
	$xamlFile = [xml](Get-Content "$PSScriptRoot\Vault-Tab-LinkErpItem.xaml")
	$tab_control = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

	$tab_control.FindName('ButtonLinkItem').Content = "Link selected $erpName Item with item"

	#region prechecks
	$tab_control.FindName('ButtonLinkItem').Visibility = "Collapsed"
	$tab_control.FindName('SearchArea').Visibility = "Collapsed"
	

	if ($null -eq $partNumber -or $partNumber -eq "") {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The Part Number is empty! A Part Number is required to create an $erpName Item."
		return $tab_control
	}
	$tab_control.FindName('ButtonLinkItem').Visibility = "Visible"
	$tab_control.FindName('SearchArea').Visibility = "Visible"
	#endregion prechecks
	
	$searchCriteria = New-Object PsObject -Property @{"SearchTerm"=""}
	$tab_control.FindName('SearchCriteria').DataContext = $searchCriteria

	$tab_control.FindName('ButtonSearch').Add_Click({
		if($null -ne $searchCriteria.SearchTerm -and $searchCriteria.SearchTerm -ne ""){
			$results = Get-ERPObjects -EntitySet 'Items' -Filter "substringof('$($searchCriteria.SearchTerm.ToUpper())',toupper(Title)) eq true"
			$tab_control.FindName('SearchResults').ItemsSource = $results
		}
	}.GetNewClosure())

	$tab_control.FindName('ButtonLinkItem').Add_Click({
		$selectedElement = $tab_control.FindName('SearchResults').SelectedItems[0]
		$number = $selectedElement.Number
		$answer = [System.Windows.Forms.MessageBox]::Show("To link the $erpName Item '$number' with the item '$($selectedItem._Number)',`nthe Item Number of the item will be changed from '$($selectedItem._Number)' to '$number'.`n`n Are you sure you want to proceed?","powerGate - confirm operation", "YesNo" , "Warning" , "Button1")
		if($answer -eq "Yes"){
			$updatedVaultItem = Update-VaultItem -Number $selectedItem._Number -NewNumber $number -ErrorAction Stop
			if (-not $updatedVaultItem) {
				[System.Windows.Forms.MessageBox]::Show("The item could not be updated","powerGate - update error", "OK" , "Error" , "Button1")
			}
			[System.Windows.Forms.SendKeys]::SendWait('{F5}')
			$null = [System.Windows.MessageBox]::Show("The $erpName Item '$number' was successfully linked to the file '$($selectedItem._Number)', `nthe Part Number of the file '$($selectedItem._Number)' got updated successfully!", "Link $erpName Item", "OK", "Information")
		}
	}.GetNewClosure())


	return $tab_control
}