#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the button to Link ERP Items via the Inventor Ribbon, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Inventor')) {
    return
}

Add-InventorMenuItem -Name "Link $erpName Item..." -Action {

    $document = $inventor.ActiveEditDocument

    #region prechecks
    if ($document.IsModifiable -eq $false) {
        $null = [System.Windows.MessageBox]::Show("The current document is not editable. Please re-open the file as editable for creating a link to an $erpName Item!", "Document not editable", "OK", "Information")
        return
    }

    if ($document.DocumentType -notin @([Inventor.DocumentTypeEnum]::kAssemblyDocumentObject, [Inventor.DocumentTypeEnum]::kPartDocumentObject)) {
        $null = [System.Windows.MessageBox]::Show("This function is available only on parts or assemblies!", "Document type not supported", "OK", "Information")
        return
    }
    #endregion prechecks

    $xamlFile = [xml](Get-Content "$PSScriptRoot\Inventor-Menu-LinkErpItem.xaml")
	$window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

    $window.FindName('ButtonLinkItem').Content = "Link with file"

    $searchCriteria = New-Object PsObject -Property @{"SearchTerm"=""}
	$window.FindName('SearchCriteria').DataContext = $searchCriteria

	$window.FindName('ButtonSearch').Add_Click({
		if($null -ne $searchCriteria.SearchTerm -and $searchCriteria.SearchTerm -ne ""){
			$results = Get-ERPObjects -EntitySet 'Items' -Filter "substringof('$($searchCriteria.SearchTerm.ToUpper())',toupper(Title)) eq true"
			$window.FindName('SearchResults').ItemsSource = $results
		}
	})

	$window.FindName('ButtonLinkItem').Add_Click({
		$selectedElement = $window.FindName('SearchResults').SelectedItems[0]
		$number = $selectedElement.Number
        $oldNumber = $document.PropertySets.Item('Design Tracking Properties')['Part Number'].Value
		$answer = [System.Windows.Forms.MessageBox]::Show("To link the item '$number' with the current file, the Part Number of the file will be changed from '$oldNumber' to '$number'. `n Are you shure you want to proceed?","powerGate - confirm operation", "YesNo" , "Warning" , "Button1")
		if($answer -eq "Yes"){
            $document.PropertySets.Item('Design Tracking Properties')['Part Number'].Value = $number
            $null = [System.Windows.MessageBox]::Show("This item was successfully linked to $erpName item '$number'!", "Link $erpName Item", "OK", "Information")
			$window.Close()
		}
	}.GetNewClosure())

    $window.FindName('ButtonCancel').Add_Click({
        $window.Close()
    }.GetNewClosure())

    $window.ShowDialog()

}