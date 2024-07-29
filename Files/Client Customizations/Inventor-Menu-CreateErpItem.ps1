#==============================================================================#
# (c) 2023 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the button to Create/Update ERP Items via the Inventor Ribbon, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Inventor')) {
    return
}

Add-InventorMenuItem -Name "Create/Update $erpName Item..." -Action {
    
    $document = $inventor.ActiveEditDocument

    #region prechecks
    if ($document.DocumentType -notin @([Inventor.DocumentTypeEnum]::kAssemblyDocumentObject, [Inventor.DocumentTypeEnum]::kPartDocumentObject)) {
        $null = [System.Windows.MessageBox]::Show("This function is available only on parts or assemblies!", "Document type not supported", "OK", "Information")
        return
    }
    
    if ($document.FileSaveCounter -eq 0) {
        $null = [System.Windows.MessageBox]::Show("The current document is not saved. Please save it before creating an $erpName Item!", "Save document", "OK", "Information")
        return
    }
    #endregion prechecks

    $partNumber = $document.PropertySets.Item('Design Tracking Properties')['Part Number'].Value
    
    $erpItem = Get-ERPObject -EntitySet 'Items' -Keys @{ Number = $partNumber } 

    if (-not $erpItem) {
        $xamlFile = [xml](Get-Content "$PSScriptRoot\ErpItemCreate.xaml")
        $window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )
    
        $window.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_new.png'
        $window.FindName('Title').Content = "Create new $erpName Item with number '$partNumber'"
    
        $window.FindName('UnitOfMeasureCombobox').ItemsSource = (GetPowerGateConfiguration 'UnitOfMeasures')

        $title = $document.PropertySets.Item('Inventor Summary Information')['Title'].Value
        $description = $document.PropertySets.Item('Design Tracking Properties')['Description'].Value
        $material = $document.PropertySets.Item('Design Tracking Properties')['Material'].Value

        $erpItem = New-ErpObject -EntityType 'Item' -Properties @{
            'Number'        = $partNumber
            'UnitOfMeasure' = 'Each'
            'Material'      = $material
            'Title'         = $title
            'Description'  = $description
        }
        $window.FindName('ItemData').DataContext = $erpItem

        $window.FindName('ButtonSubmit').Add_Click({
            Add-ErpObject -EntitySet 'Items' -Properties $erpItem
            if ($? -eq $false) { return }
            $null = [System.Windows.MessageBox]::Show("$erpName Item '$partNumber' was successfully created!", "Create $erpName Item", "OK", "Information")
            $window.Close()
        })
    }
    else {
        $xamlFile = [xml](Get-Content "$PSScriptRoot\ErpItemUpdate.xaml")
        $window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

        $window.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_different.png'
        $window.FindName('Title').Content = "Update $erpName Item with number '$partNumber'"

        $window.FindName('UnitOfMeasureCombobox').ItemsSource = (GetPowerGateConfiguration 'UnitOfMeasures')

        $window.FindName('ItemData').DataContext = $erpItem

        $window.FindName('ButtonSubmit').Add_Click({
                Update-ErpObject -EntitySet 'Items' -Keys $erpItem._Keys -Properties $erpItem._Properties
                if ($? -eq $false) { return }
                $null = [System.Windows.MessageBox]::Show("$erpName Item '$partNumber' was successfully updated!", "Update $erpName Item", "OK", "Information")
                $window.Close()
            })
    }

    $window.FindName('ButtonCancel').Add_Click({ $window.Close() })

    $window.ShowDialog()

}