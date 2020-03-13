function GetSelectionList($section, $withBlank = $false) {
    [xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    $entries = Select-Xml -Xml $cfg -XPath "//$section" 
    $list = @()
    foreach ($entry in $entries.Node.ChildNodes) { 
        if ($entry.NodeType -eq "Comment") { continue }
        $list += New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @($entry.Key, $entry.Value)
    }
    $list = $list | Sort-Object -Property "Value" 
    if ($withBlank) { 
        $empty = New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @("", "")
        $list = , $empty + $list 
    }
    return $list
}

function GetUnitOfMeasuresList($withBlank = $false) {
    $list = GetSelectionList -section "UnitOfMeasures" -withBlank $withBlank
    return $list | Sort-Object -Property value
}

function GetMaterialTypeList($withBlank = $false) {
    $list = GetSelectionList -section "MaterialTypes" -withBlank $withBlank
    return $list | Sort-Object -Property value
}