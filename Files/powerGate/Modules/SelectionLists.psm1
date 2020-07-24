function SetConfigFromVault {
    param(
        [string]$Content
    )
    Log -Begin
    # In order to support special characters like ö, Ü
    $encodedContentBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $encodedContentBase64 =[Convert]::ToBase64String($encodedContentBytes)
    $vault.KnowledgeVaultService.SetVaultOption("powerGateConfig", $encodedContentBase64)
    Log -End
}

function GetConfigFromVault {
    Log -Begin
    # In order to support special characters like ö, Ü
    $encodedContentBase64 = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    if($encodedContentBase64) {
        try {
            $encodedContentBytes =[Convert]::FromBase64String($encodedContentBase64)
            [System.Text.Encoding]::UTF8.GetString($encodedContentBytes)
        } catch { }        
    }
    Log -End
}

function GetSelectionList($section, $withBlank = $false) {
    Log -Begin
    $list = @()
    if (-not $vault) { return $list }
    
    [xml]$cfg = GetConfigFromVault
	if ($null -eq $cfg) {
		[xml]$cfg = Get-Content "C:\ProgramData\coolOrange\powerGate\powerGateConfigurationTemplate.xml"
        SetConfigFromVault -Content $cfg.InnerXml
    }
    
    $entries = Select-Xml -Xml $cfg -XPath "//$section"   
    if ($entries) {
        foreach ($entry in $entries.Node.ChildNodes) { 
            if ($entry.NodeType -eq "Comment") { continue }
            $list += New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @($entry.Key, $entry.Value)
        }
        $list = $list | Sort-Object -Property "Value" 
        if ($withBlank) { 
            $empty = New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @("", "")
            $list = , $empty + $list 
        }        
    }
    Log -End
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

function GetBOMStateList($withBlank = $false) {
    $list = GetSelectionList -section "BomStates" -withBlank $withBlank
    return $list | Sort-Object -Property value
}

function GetCategoryList($withBlank = $false) {
    $list = @()
    $categories = Get-ERPObjects -EntitySet "Categories"
    $categories = CheckResponse -entity $categories
    if (-not $categories -or $false -eq $categories) {
        return $list
    }

    foreach ($category in $categories) {
        $list += New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @($category.Key, $category.Value)
    }
    if ($withBlank) { 
        $empty = New-Object 'System.Collections.Generic.KeyValuePair[String,String]' -ArgumentList @("", "")
        $list = , $empty + $list 
    }
    return $list | Sort-Object -Property Value
}