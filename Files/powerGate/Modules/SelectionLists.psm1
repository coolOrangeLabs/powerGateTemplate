function Set-PowerGateConfigFromVault {
    param(
        [byte[]]$Content
    )
    Log -Begin
    # In order to support special characters like ö, Ü, Convert from UTF-8 to Windows-1252
    [System.Text.Encoding]$srcEncoding = [System.Text.Encoding]::UTF8
    [System.Text.Encoding]$destEncoding = [System.Text.Encoding]::GetEncoding("Windows-1252")
    $encodedContentBytes = [System.Text.Encoding]::Convert($srcEncoding, $destEncoding, $Content)
    $encodedContentString = $destEncoding.GetString($encodedContentBytes)

    $vault.KnowledgeVaultService.SetVaultOption("powerGateConfig", $encodedContentString)
    Log -End
}

function Get-PowerGateConfigFromVault {
    Log -Begin
    $xmlString = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")

    if (-not $xmlString) {
        $xmlTemplatePath = "C:\ProgramData\coolOrange\powerGate\powerGateConfigurationTemplate.xml"
        [byte[]]$cfg = [System.IO.File]::ReadAllBytes($xmlTemplatePath)
        Set-PowerGateConfigFromVault -Content $cfg
        $xmlString = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
        if (-not $xmlString) {
            throw "PowerGateConfiguration is not saved in the Vault options! An administrator must import the XML via the command 'powerGate->Save Configuration' in the Vault Client."
        }
    }

    try{
        $byteOrderMarkUtf8 = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::UTF8.GetPreamble())
        if ($xmlString.StartsWith($byteOrderMarkUtf8)) {
            $xmlString = $xmlString.Remove(0, $byteOrderMarkUtf8.Length);
        }

        $xmlObject = New-Object -TypeName System.Xml.XmlDocument
        $xmlObject.LoadXml($xmlString)
        return $xmlObject
    } catch {
        throw "Unable to parse powerGateConfiguration from the Vault Options to a valid XML-Object! An administrator must import a new XML via the command 'powerGate->Save Configuration' in the Vault Client.`n $($_.Exception.Message)"
    }
    Log -End
}

function GetSelectionList($section, $withBlank = $false) {
    Log -Begin
    $list = @()
    if (-not $vault) { return $list }

    [xml]$cfg = Get-PowerGateConfigFromVault

    try {
        $entries = Select-Xml -Xml $cfg -XPath "//$section"
    } catch {
        throw "Failed to find XML node '$section' in the powerGateConfiguration! An administrator must edit and import the XML via the command 'powerGate->Save Configuration' in the Vault Client!"
    }
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
    $categories = Edit-ResponseWithErrorMessage -entity $categories
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