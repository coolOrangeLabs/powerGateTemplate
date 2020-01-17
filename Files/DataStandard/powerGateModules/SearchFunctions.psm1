$materialEntityType = "Material"

function InitSearch {
    $searchCriteria = New-ERPObject -EntityType $materialEntityType
    $dsWindow.FindName("SearchCriteria").DataContext = $searchCriteria
    $dsWindow.FindName("NumberOfRecords").ItemsSource = @("100", "200", "500")
    $dsWindow.FindName("NumberOfRecords").SelectedValue = "100"
    SetSearchSelectionLists

    $dsWindow.FindName("SearchCriteria").Add_KeyUp({
        param ($sender, $e)
        if ($e.Key -eq "Return") { 
            SearchMaterials 
        }
    })
    
    $dsWindow.FindName("SearchResults").Add_CopyingRowClipboardContent({
        param ($sender, $e)
        $propName = $sender.CurrentCell.Column.SortMemberPath
        $value = $($sender.CurrentCell.Item.$propName)
        $curCell = $e.ClipboardRowContent[$sender.CurrentCell.Column.DisplayIndex];
        $clip = New-Object System.Windows.Controls.DataGridClipboardCellContent($curCell.Item, $curCell.Column, $value)
        $e.ClipboardRowContent.Clear()
        $e.ClipboardRowContent.Add($clip);
    })
    
    $dsWindow.FindName("SearchResults").add_MouseDoubleClick({
        param ($sender, $args)
        $dataGrid = $sender
        $key = $dataGrid.CurrentColumn.SortMemberPath
        $value = $dataGrid.SelectedItem.$key
        $dataSource = $dsWindow.FindName("SearchCriteria").DataContext
        if ($value -ne "" -and $null -ne $value -and $key -in $dataSource.PSObject.Properties.Name) {
            $dataSource.$key = $value;
            $dsWindow.FindName("SearchCriteria").DataContext = $null
            $dsWindow.FindName("SearchCriteria").DataContext = $dataSource
            SearchMaterials
        }
    })
}

function SearchMaterials {
    $dsDiag.Clear()
    $searchCriteria = $dsWindow.FindName("SearchCriteria").DataContext
    $CaseSensitive = $dsWindow.FindName("CaseSensitive").IsChecked
    $top = $dsWindow.FindName("NumberOfRecords").SelectedValue
    $filter = ConvertSearchCriteriaToFilter -SearchCriteria $searchCriteria -CaseSensitive $CaseSensitive
    $dsDiag.Trace("flilter = $filter")
    $results = SearchMaterialsBase -filter $filter -top $top
    if ($results) {
        $dsWindow.FindName("SearchResults").ItemsSource = @($results) #this is because PowerShell transforms one result into a single object instead of keeping it as a list of one element
        $dsWindow.FindName("RecordsFound").Content = "Results found: $($results.Count)"
    }
    else {
        $dsWindow.FindName("SearchResults").ItemsSource = $null
        $dsWindow.FindName("RecordsFound").Content = ""
        if ($results._ErrorMessage) {
            Show-MessageBox -message $results._ErrorMessage -icon "Error"
        }
    }
}

function ConvertSearchCriteriaToFilter ($SearchCriteria, $CaseSensitive) {
    $wildcardQuery = @()
    foreach ($criterion in $SearchCriteria.PSObject.Properties) {
        $valueIsSet = CheckIfValueIsSet -value $criterion.Value -type $criterion.TypeNameOfValue
        $dsDiag.Trace("criterion [$valueIsSet]: $($criterion.Name),$($criterion.Value),$($criterion.TypeNameOfValue)")
        if ($valueIsSet -eq $false) { continue }
        $wildcardQuery += ConvertValueToFilter -WildcardValue $criterion.Value -Property $criterion.Name -Type $criterion.TypeNameOfValue -CaseSensitive $CaseSensitive -WildCard "*"
    }
    $filter = $wildcardQuery -Join " and "
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