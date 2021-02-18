using namespace System.Collections.Generic

class TextReplacementMapping {
    [string] $VaultValue
    [string] $SapValue
    
    TextReplacementMapping($vaultValue, $sapValue) {
        $this.VaultValue = $vaultValue
        $this.SapValue = $sapValue
    }
}
class XmlMappingGroup {

    [Xml] $Xml

    XmlMappingGroup([System.IO.FileInfo]$xmlFileInfo) {
        if(-not $xmlFileInfo.Exists) {
            throw "Error in .ctor TextReplacementMapping. The file '$($xmlFileInfo.FullName)' doesn't exist."
        }

        try {
            $this.Xml = [Xml]::new()
            $this.Xml.Load($xmlFileInfo.FullName)
        } 
        catch {
            throw "Error while parsing Xml file '$($xmlFileInfo.FullName)'. Check the file for syntax errors.`r`n`r`n$($Error[0])"
        }
    }
    [string] GetGroupName() {
        $group = $this.Xml.SelectNodes('/MappingGroup')
        return $group.Name
    }
    [System.Collections.Generic.List[TextReplacementMapping]] ToTextReplacementList() {
        $textReplacementMappings = [System.Collections.Generic.List[TextReplacementMapping]]::new()

        foreach($node in $this.Xml.SelectNodes("//Mapping")) {
            $mapping = [TextReplacementMapping]::new($node.Vault, $node.Sap)
            $null = $textReplacementMappings.Add($mapping)
        }

        return $textReplacementMappings
    }
}
class TextReplacementMappingTable {
    [string] $GroupName
    [System.Collections.Generic.List[TextReplacementMapping]] $Mappings

    TextReplacementMappingTable() {
        $this.Mappings = [System.Collections.Generic.List[TextReplacementMapping]]::new()
    }
    TextReplacementMappingTable([System.Collections.Generic.List[TextReplacementMapping]]$mappings) {
        $this.Mappings = $mappings
    }
    TextReplacementMappingTable([Hashtable]$mappings) {
        $this.Mappings = [System.Collections.Generic.List[TextReplacementMapping]]::new()
        foreach($mapping in $mappings.GetEnumerator()) {
            $null = $this.Mappings.Add([TextReplacementMapping]::new($mapping.Key, $mapping.Value))
        }
    }
    TextReplacementMappingTable([System.IO.FileInfo]$xmlFileInfo) {
        if(-not $xmlFileInfo.Exists) {
            throw "Error in .ctor TextReplacementMapping. The file '$($xmlFileInfo.FullName)' doesn't exist."
        }

        $xmlMappingGroup = [XmlMappingGroup]::new($xmlFileInfo)
        $this.Mappings = $xmlMappingGroup.ToTextReplacementList() 
        
        $this.GroupName = $xmlMappingGroup.GetGroupName()

    }
    [System.Collections.Generic.List[string]] GetSapValues() {
        $sapValues = [System.Collections.Generic.List[string]]::new()

        foreach($mapping in $this.Mappings) {
            $null = $sapValues.Add($mapping.SapValue)
        }

        return $sapValues
    }
    [System.Collections.Generic.List[string]] GetVaultValues() {
        $vaultValues = [System.Collections.Generic.List[string]]::new()

        foreach($mapping in $this.Mappings) {
            $null = $vaultValues.Add($mapping.VaultValue)
        }

        return $vaultValues
    }
    [string] GetSapValue($vaultValue) {
        Log -Message 'GetSapValue'

        foreach($mapping in $this.Mappings) {
            if($mapping.VaultValue -ieq $vaultValue) {
                $sapValue = $mapping.SapValue
                return $sapValue
            }
        }
        return $null
    }
    [string] GetVaultValue($sapValue) {
        Log -Message 'GetVaultValue'
        foreach($mapping in $this.Mappings) {
            if($mapping.SapValue -ieq $sapValue) {
                return $mapping.VaultValue
            }
        }
        return $null
    }
}
function Get-TextReplacementMappings {
    Log -Begin

    if(-not (IAmRunningJobprocessor)) {
        $textReplacementMappings = [Appdomain]::CurrentDomain.GetData('TextReplacementMappings')
        if($textReplacementMappings) { 
            return $textReplacementMappings 
        }
    }

    $textReplacementMappings = [Dictionary[[string],[TextReplacementMappingTable]]]::new()

    Push-Location $PSScriptRoot
    [System.IO.DirectoryInfo]$Path = (Resolve-Path '.\TextReplacementMappings').Path
    Pop-Location

    $mappingXmlFileInfos = Get-ChildItem -LiteralPath $Path.FullName | Where-Object { $_.Extension -ieq '.xml' }
    foreach($xmlFileInfo in $mappingXmlFileInfos) {
        $mappingTable = [TextReplacementMappingTable]::new($xmlFileInfo)
        $textReplacementMappings.Add($mappingTable.GroupName, $mappingTable)
    }

    [Appdomain]::CurrentDomain.SetData('TextReplacementMappings', $textReplacementMappings)
    return $textReplacementMappings
}
enum MappingTableNames {
    BasicMaterial;DirVersion;DocumentType;ExtMaterialGroup;ItemCategory;LabOffice;MaterialGroup;MaterialType;PlantView;ProductHirarchy;RfcShortDescription;SalesOrg;SapEcoDescription;SapMaterialExists;SapUpdatePossible;StorageCategory;Units;XMatPlantStatus
}
function Get-VaultValue {
    param (
        [MappingTableNames]$Table,
        $SapValue
    )
    Log -Begin

    if(-not $SapValue) { return $null }

    $textReplacementMappings = Get-TextReplacementMappings

    $vaultValue = $textReplacementMappings[$Table].GetVaultValue($SapValue)
    if(-not $vaultValue) {
        Log -Message "Couln't find mapping for Vault value '$($SapValue)' in table '$($Table)'"
        return $SapValue
    }

    Log -End -Message $vaultValue
    return $vaultValue
}
function Get-SapValue {
    param (
        [MappingTableNames]$Table,
        $VaultValue
    )
    Log -Begin

    if(-not $VaultValue) { return $null }

    $textReplacementMappings = Get-TextReplacementMappings

    $mappingTable = $textReplacementMappings[$Table]

    $sapValue = $mappingTable.GetSapValue($VaultValue)

    if(-not $sapValue) {
        Log -Message "Couldn't find mapping for Vault value '$($VaultValue)' in table '$($Table)'"
        if($Table -eq [MappingTableNames]::LabOffice)
        {
            $VaultValue = $VaultValue.Trim()
            return ($VaultValue -split " ")[0] #number of lab/office
        }
        if($Table -eq [MappingTableNames]::StorageCategory)      # issue 154: Comment from 15.10.2020
        {
            $sapValue = "Z_HELSINKI"
            Log -Message "The default value ""Z_HELSINKI"" is used, because: Couldn't find mapping for Vault value '$($VaultValue)' in table '$($Table) "  
            Log -End -Message $sapValue 
            return $sapValue
        }
        return $VaultValue
    }

    Log -End -Message $sapValue
    return $sapValue
}
