$source = @"
public class MyKeyValue{
    public string Key { get; set; }
    public string Value { get; set; }
}
"@
Add-Type $source

function SetMaterialSelectionLists {
    $dsWindow.FindName("UomList").ItemsSource = GetUnitOfMeasuresList -withBlank $false
    $dsWindow.FindName("MaterialTypeList").ItemsSource = GetMaterialTypeList -withBlank $false 
}

function SetSearchSelectionLists {
    $dsWindow.FindName("UomListSearch").ItemsSource = GetUnitOfMeasuresList -withBlank $true
    $dsWindow.FindName("MaterialTypeListSearch").ItemsSource = GetMaterialTypeList -withBlank $true 
}

function SelectionIdToValue($section, $key) {
    $entriy = Get-ERPObjects -EntitySet "SectionsEntries" -Filter "Section eq '$section' and Key eq '$key'"
    return $entriy.Value
}

function GetSelectionList($section, $withBlank = $false) {
    [xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    $entries = Select-Xml -Xml $cfg -XPath "//$section" 
    $list = @()
    foreach ($entry in $entries.Node.ChildNodes) { 
        if ($entry.NodeType -eq "Comment") { continue }
        $list += New-Object MyKeyValue -Property @{Key = $entry.Key; Value = $entry.Value } 
    }
    $list = $list | Sort-Object -Property "Value" 
    if ($withBlank) { 
        $empty = New-Object MyKeyValue -Property @{Key = ""; Value = "" }
        $list = , $empty + $list 
    }
    return $list
}

# Extended Data
function GetUnitOfMeasuresList($withBlank = $false) {

    $list = GetSelectionList -section "UnitOfMeasures" -withBlank $withBlank
    return $list | Sort-Object -Property value
}

function GetMaterialTypeList($withBlank = $false) {
    $list = GetSelectionList -section "MaterialTypes" -withBlank $withBlank
    return $list | Sort-Object -Property value
}