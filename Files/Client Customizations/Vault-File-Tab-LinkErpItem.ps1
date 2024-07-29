#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the Link ERP Item tab for files, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Connectivity.VaultPro')) {
	return
}

Add-VaultTab -Name "Link $erpName Item" -EntityType File -Action {
	param($selectedFile)

	$xamlFile = [xml](Get-Content "$PSScriptRoot\Vault-Tab-LinkErpItem.xaml")
	$tab_control = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

	$tab_control.FindName('ButtonLinkItem').Content = "Link selected $erpName Item with file"

	#region prechecks
	$tab_control.FindName('ButtonLinkItem').Visibility = "Collapsed"
	$tab_control.FindName('SearchArea').Visibility = "Collapsed"
	if ($selectedFile._Extension -notin @('ipt','iam')) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "Please select a part or an assembly!"
		return $tab_control
	}

	if ($selectedFile.IsCheckedOut -eq $true) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The file is checked out! $erpName Item link not possible."
		return $tab_control
	}

	if ($selectedFile._ReleasedRevision -eq $true) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The file is released! $erpName Item link not possible."
		return $tab_control
	}

	if ($selectedFile._ItemLinked -eq $true) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The file is already linked with an $erpName Item! $erpName Item link not possible."
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
		$answer = [System.Windows.Forms.MessageBox]::Show("To link the $erpName Item '$number' with the file '$($selectedFile._Name)',`nthe Part Number of the file '$($selectedFile._Name)' will be changed from '$($selectedFile._PartNumber)' to '$number'.`n`nAre you sure you want to proceed?","powerGate - confirm operation", "YesNo" , "Warning" , "Button1")
		if($answer -eq "Yes"){
			$updatedVaultFile = Update-VaultFile -File $selectedFile._FullPath -Properties @{"_PartNumber"=$number}
			if (-not $updatedVaultFile) {
				[System.Windows.Forms.MessageBox]::Show("The file could not be updated","powerGate - update error", "OK" , "Error" , "Button1")
			}
			[System.Windows.Forms.SendKeys]::SendWait('{F5}')
			$null = [System.Windows.MessageBox]::Show("The $erpName Item '$number' was successfully linked to the file '$($selectedFile._Name)', `nthe Part Number of the file '$($selectedFile._Name)' got updated successfully!", "Link $erpName Item", "OK", "Information")
		}
	}.GetNewClosure())


	return $tab_control
}