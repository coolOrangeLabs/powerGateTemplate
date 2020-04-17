$materialEntitySet = "Materials"
$materialEntityType = "Material"

function SearchErpMaterials ($filter, $top = 100) {
	$erpMaterials = Get-ERPObjects -EntitySet $materialEntitySet -Filter $filter -Top $top
	$erpMaterials = CheckResponse -entity $erpMaterials
	return $erpMaterials
}

function OpenErpSearchWindow {
    Log -Begin
    [xml]$searchWindowXaml = Get-Content "C:\ProgramData\coolOrange\powerGate\UI\SearchWindow.xaml"
    $reader = (New-Object System.Xml.XmlNodeReader $searchWindowXaml)
    $searchWindow = [Windows.Markup.XamlReader]::Load($reader) 
    $searchWindow.DataContext = $dsWindow.DataContext
    
    $searchCriteria = New-ERPObject -EntityType $materialEntityType

    $searchWindow.FindName("SearchCriteria").DataContext = $searchCriteria 
    $searchWindow.FindName("NumberOfRecords").ItemsSource = @("100", "200", "500")
    $searchWindow.FindName("NumberOfRecords").SelectedValue = "100"  
    $searchWindow.FindName("UomListSearch").ItemsSource = GetUnitOfMeasuresList -withBlank $true
    $searchWindow.FindName("MaterialTypeListSearch").ItemsSource = GetMaterialTypeList -withBlank $true

    $searchWindow.FindName("SearchCriteria").Add_KeyUp( {
        param ($sender, $e)
        if ($e.Key -eq "Return") { 
            ExecuteErpSearch 
        }
    })
    
    $searchWindow.FindName("SearchResults").Add_CopyingRowClipboardContent( {
        param ($sender, $e)
        $propName = $sender.CurrentCell.Column.SortMemberPath
        $value = $($sender.CurrentCell.Item.$propName)
        $curCell = $e.ClipboardRowContent[$sender.CurrentCell.Column.DisplayIndex];
        $clip = New-Object System.Windows.Controls.DataGridClipboardCellContent($curCell.Item, $curCell.Column, $value)
        $e.ClipboardRowContent.Clear()
        $e.ClipboardRowContent.Add($clip);
    })
    
    $searchWindow.FindName("SearchResults").add_MouseDoubleClick( {
        param ($sender, $args)
        $dataGrid = $sender
        $key = $dataGrid.CurrentColumn.SortMemberPath
        $value = $dataGrid.SelectedItem.$key
        $dataSource = $searchWindow.FindName("SearchCriteria").DataContext
        $searchableFields = GetSearchableFieldsList

        if ($value -ne "" -and $null -ne $value -and $key -in $searchableFields.Key) {
            $dataSource.$key = $value;
            $searchWindow.FindName("SearchCriteria").DataContext = $null
            $searchWindow.FindName("SearchCriteria").DataContext = $dataSource
            ExecuteErpSearch
        }
    })

    $searchWindow.FindName("Search").add_click( {
        ExecuteErpSearch
    })

    $searchWindow.FindName("Clear").add_click( {
        $searchCriteria = New-ERPObject -EntityType $materialEntityType
        $searchWindow.FindName("SearchCriteria").DataContext = $searchCriteria
        $searchWindow.FindName("SearchResults").ItemsSource = $null
        $searchWindow.FindName("RecordsFound").Content = ""
    })
    Log -End
    if ($searchWindow.ShowDialog() -eq "OK") {
        $material = $searchWindow.FindName("SearchResults").SelectedItem
        return $material
    } else {
        return $null
    }
}

function CloseErpSearchWindow {
    Log -Begin
    $material = $searchWindow.FindName("SearchResults").SelectedItem
    if ($material) {
        $searchWindow.DialogResult = "OK"
        $searchWindow.Close()        
    } else {
        Show-MessageBox -message "An item needs to be selected to proceed!" -icon "Hand"
    }
    Log -End
}

function ExecuteErpSearch {
    Log -Begin
    $dsDiag.Clear()
    $searchCriteria = $searchWindow.FindName("SearchCriteria").DataContext
    $CaseSensitive = $searchWindow.FindName("CaseSensitive").IsChecked
    $topa = $searchWindow.FindName("NumberOfRecords").SelectedValue
    $filter = ConvertSearchCriteriaToFilter -SearchCriteria $searchCriteria -CaseSensitive $CaseSensitive
    $dsDiag.Trace("flilter = $filter")
    $results = SearchErpMaterials -filter $filter -top $topa
    if ($results) {
        $searchWindow.FindName("SearchResults").ItemsSource = @($results) #this is because PowerShell transforms one result into a single object instead of keeping it as a list of one element
        $searchWindow.FindName("RecordsFound").Content = "Results found: $(@($results).Count)"
    }
    else {
        $searchWindow.FindName("SearchResults").ItemsSource = $null
        $searchWindow.FindName("RecordsFound").Content = "Results found: 0"
        if ($results._ErrorMessage) {
            #Show-MessageBox -message $results._ErrorMessage -icon "Error"
        }
    }
    Log -End
}

function ConvertSearchCriteriaToFilter ($SearchCriteria, $CaseSensitive) {
    Log -Begin
    $wildcardQuery = @()
    foreach ($criterion in $SearchCriteria.PSObject.Properties) {
        $valueIsSet = CheckIfValueIsSet -value $criterion.Value -type $criterion.TypeNameOfValue
        $dsDiag.Trace("criterion [$valueIsSet]: $($criterion.Name),$($criterion.Value),$($criterion.TypeNameOfValue)")
        if ($valueIsSet -eq $false) { continue }
        $wildcardQuery += ConvertValueToFilter -WildcardValue $criterion.Value -Property $criterion.Name -Type $criterion.TypeNameOfValue -CaseSensitive $CaseSensitive -WildCard "*"
    }
    $filter = $wildcardQuery -Join " and "
    Log -End
    return $filter
}

function CheckIfValueIsSet($value, $type) {
    $dsDiag.Trace("check: $value,$type")
    if ([String]::IsNullOrEmpty($value)) { return $false }
    if ($type -eq "System.DateTime" -and $value -eq [DateTime]::MinValue) { return $false }
    if ($value -eq 0) { return $false }
    return $true
}

function ConvertValueToODataFilter($Operator, $Property, $Value, $CaseSensitive = $false, $Type ) {
    $dsDiag.Trace("toOData: $Operator,$Property,$Value")
    $ODataFilter = ""
    switch ($Type) {
        "System.DateTime" { $ODataFilter = "$Property $Operator datetime'$Value'" }
        "System.Bool" { $Value = "$Property $Operator '$($Value.ToString().ToLower())'" }
        "System.String" { 
            if ([String]::IsNullOrEmpty($Value)) { return $ODataFilter }
            $Value = $Value.Trim()
            if ($CaseSensitive -eq $false) {
                $Property = "tolower($Property)"
                $Value = $Value.ToString().ToLower()
            }
            switch ($Operator) {
                "substringof" { $ODataFilter = "substringof('$Value',$Property) eq true" }
                "endswith" { $ODataFilter = "endswith($Property,'$Value') eq true" }
                "startswith" { $ODataFilter = "startswith($Property,'$Value') eq true" }
                Default { $ODataFilter = "$Property $Operator '$Value'" }
            }
        }
        Default { $ODataFilter = "$Property $Operator '$Value'" }
    }
    return $ODataFilter
}

function ConvertValueToFilter($WildcardValue, $Property, $Type, $CaseSensitive = $false, $WildCard = "*") {
    $dsDiag.Trace("convert: $WildcardValue,$Property,$Type")
    if ($Type -eq "System.String") {
        $value = $WildcardValue.Replace("*", "")
        if ($WildcardValue.StartsWith($WildCard) -and $WildcardValue.EndsWith($WildCard)) {
            $odataFilter = ConvertValueToODataFilter -Operator substringof -Value $value -Property $Property -CaseSensitive $CaseSensitive -Type $Type
        }
        elseif ($WildcardValue.StartsWith($WildCard)) {
            $odataFilter = ConvertValueToODataFilter -Operator endswith  -Value $value -Property $Property -CaseSensitive $CaseSensitive -Type $Type
        }
        elseif ($WildcardValue.EndsWith($WildCard)) {
            $odataFilter += ConvertValueToODataFilter -Operator startswith -Value $value -Property $Property -CaseSensitive $CaseSensitive -Type $Type
        }
        else {
            $odataFilter += ConvertValueToODataFilter -Operator eq -Value $value -Property $Property -CaseSensitive $CaseSensitive -Type $Type
        }
    }
    else {
        $odataFilter += ConvertValueToODataFilter -Operator eq -Value $value -Property $Property -CaseSensitive $CaseSensitive -Type $Type
    }
    return $odataFilter
}