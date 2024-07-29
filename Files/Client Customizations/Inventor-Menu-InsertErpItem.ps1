#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the button to Insert ERP Items via the Inventor Ribbon, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Inventor')) {
    return
}

Add-InventorMenuItem -Name "Insert $erpName Item..." -Action {
    
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
    
    $isAssembly = $document.DocumentType -eq [Inventor.DocumentTypeEnum]::kAssemblyDocumentObject

    $xamlFile = [xml](Get-Content "$PSScriptRoot\Inventor-Menu-InsertErpItem.xaml")
    $window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

    if ($isAssembly) {
        $window.FindName('ButtonLinkItem').Content = "Insert Virtual Component"
        $window.FindName('Title').Content = "Insert Virtual Component"
    }
    else {
        $window.FindName('ButtonLinkItem').Content = "Insert Raw Material"
        $window.FindName('Title').Content = "Insert Raw Material"
    }

    $searchCriteria = New-Object PsObject -Property @{"SearchTerm" = "" }
    $window.FindName('SearchCriteria').DataContext = $searchCriteria

    $window.FindName('ButtonSearch').Add_Click({
            if ($null -ne $searchCriteria.SearchTerm -and $searchCriteria.SearchTerm -ne "") {
                $results = Get-ERPObjects -EntitySet 'Items' -Filter "substringof('$($searchCriteria.SearchTerm.ToUpper())',toupper(Title)) eq true"
                $window.FindName('SearchResults').ItemsSource = $results
            }
        })

    $window.FindName('ButtonLinkItem').Add_Click({
            $selectedElement = $window.FindName('SearchResults').SelectedItems[0]
            $number = $selectedElement.Number
            $quantity = [int]$window.FindName('Quantity').Text
            $oldNumber = $document.PropertySets.Item('Design Tracking Properties')['Part Number'].Value
            if ($isAssembly) {
                $message = "By clicking Yes, a Virtual Component with the Number '$number' and Quantity $quantity will be added to the assembly"
            }
            else {
                $message = "By clicking Yes, a Raw Material with the Number '$number' and Quantity $quantity will be added to the part as custom iProperty"
            }
            $answer = [System.Windows.Forms.MessageBox]::Show("$message `n Do you want to proceed?", "powerGate - confirm operation", "YesNo" , "Warning" , "Button1")
            if ($answer -eq "Yes") {
                if ($isAssembly) {
                    $occur = $document.ComponentDefinition.Occurrences
                    foreach($oc in $occur){
                        if($oc.Definition.DisplayName -eq $number){
                            [System.Windows.Forms.MessageBox]::Show("This part has already been added!", "powerGate - Virtual Component already exists", "OK" , "Information" , "Button1")
                            return
                        }
                    }
                    $virtualComponent = $occur.AddVirtual($number, $inventor.TransientGeometry.CreateMatrix())
                    $BOM = $document.ComponentDefinition.BOM
                    if (-not $BOM.StructuredViewEnabled) {
                        $BOM.StructuredViewEnabled = $True
                    }
                    $structBomView = $BOM.BOMViews | Where-Object { $_.ViewType -eq [Inventor.BOMViewTypeEnum]::kStructuredBOMViewType } | Select-Object -First 1
                    $bomCom = $structBomView.BOMRows | Where-Object { ($_.ComponentDefinitions | Select-Object -First 1).DisplayName -eq $number }
                    $bomCom.TotalQuantity = $quantity
                    $null = [System.Windows.MessageBox]::Show("$erpName item '$number' was successfully inserted as Virtual Component!", "Insert $erpName Item", "OK", "Information")
                }
                else {
                    $customProp = $document.PropertySets.Item('Inventor User Defined Properties') | Where-Object { $_.Name -eq 'Raw Material Number' }
                    if ($customProp) { $customProp.Delete() }
                    $document.PropertySets.Item('Inventor User Defined Properties').Add($number, 'Raw Material Number') 
                    $customProp = $document.PropertySets.Item('Inventor User Defined Properties') | Where-Object { $_.Name -eq 'Raw Material Quantity' }
                    if ($customProp) { $customProp.Delete() }
                    $document.PropertySets.Item('Inventor User Defined Properties').Add($quantity, 'Raw Material Quantity')
                    $null = [System.Windows.MessageBox]::Show("$erpName item '$number' was successfully inserted as Raw Material!", "Insert $erpName Item", "OK", "Information")
                }
                $window.Close()
            }
        }.GetNewClosure())

    $window.FindName('ButtonCancel').Add_Click({
            $window.Close()
        }.GetNewClosure())

    $window.ShowDialog()

}