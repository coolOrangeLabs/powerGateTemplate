function SetConfigFromVault {
    param(
        [byte[]]$Content
    )
    Log -Begin
    # In order to support special characters like ö, Ü, Convert from UTF-8 to Windows-1252
    [System.Text.Encoding]$srcEncoding = [System.Text.Encoding]::UTF8
    [System.Text.Encoding]$destEncoding = [System.Text.Encoding]::GetEncoding("Windows-1252")
    $encodedContentBytes = [System.Text.Encoding]::Convert($srcEncoding, $destEncoding, $cfg)
    $encodedContentString = $destEncoding.GetString($encodedContentBytes)

    $vault.KnowledgeVaultService.SetVaultOption("powerGateConfig", $encodedContentString)
    Log -End
}

function GetConfigFromVault {
    Log -Begin
    $xmlString = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
    if($xmlString) {
        try{
            $xmlObject = New-Object -TypeName System.Xml.XmlDocument
            $xmlObject.LoadXml($xmlString)
            return $xmlObject
        } catch{
            Log -message "Unable to parse XML-String to XML-Object!"
            return $null
         }
    }
    Log -End
}

function GetSelectionList($section, $withBlank = $false) {
    Log -Begin
    $list = @()
    if (-not $vault) { return $list }

    [xml]$cfg = GetConfigFromVault
    if ($null -eq $cfg) {
        [byte[]]$cfg = [System.IO.File]::ReadAllBytes("C:\ProgramData\coolOrange\powerGate\powerGateConfigurationTemplate.xml")
        SetConfigFromVault -Content $cfg
        [xml]$cfg = GetConfigFromVault
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