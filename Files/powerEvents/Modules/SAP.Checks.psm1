function Test-SapChangeNumbers {
    param(
        $VaultEntity
    )
    Log -Begin

    $extensionsForDocumentInforRecord = @("idw", "dwg", "docx", "pptx", "xlsx", "doc", "xls", "ppt")

    if ($VaultEntity._Extension -in $extensionsForDocumentInforRecord) { 
        # This function throws a error if the change number is not valid
        # We do not need the change number because we only verify if its valid!
        (Get-SapValidChangeNumberForDir -VaultEntity $VaultEntity) | Out-Null
    }

    $extensionsForSapMaterial = @("ipt", "iam")

    if ($VaultEntity._Extension -in $extensionsForSapMaterial) { 
        # This function throws a error if the change number is not valid
        # We do not need the change number because we only verify if its valid!
        (Get-SapValidChangeNumberForDir -VaultEntity $VaultEntity) | Out-Null
    }
    Log -End
}

function Get-SapValidChangeNumberForDir {
    param (
        $VaultEntity
    )
    Log -Begin

    $response = Get-ErpDir -VaultEntity $VaultEntity -DocumentInfoRecordData
    $ErpRevision = $response.Entity.DocumentInfoRecordData.RevisionLevel
    $ErpChangenumber = $response.Entity.DocumentInfoRecordData.ChangeNumber
    $result = New-Object PSObject -Property @{ 
        "SapRevision"     = $ErpRevision
        "SapChangenumber" = $ErpChangenumber
    }
    
    $validChangeNumber = Get-SapValidChangeNumber -VaultEntity $VaultEntity -SapRevisionChangeNumber $result
    Log -End
    return $validChangeNumber
}

function Get-SapValidChangeNumberForMaterial {
    param (
        $VaultEntity
    )
    Log -Begin

    $response = Get-SapMaterial -VaultEntity $VaultEntity -BasicData
    $ERPMaterial = $response.Entity
    $ErpRevision = $ERPMaterial.BasicData.RevisionLevel
    $ErpChangenumber = $ERPMaterial.BasicData.ChangeNumber
    
    $result = New-Object PSObject -Property @{ 
        "SapRevision"     = $ErpRevision
        "SapChangenumber" = $ErpChangenumber
    }
    $validChangeNumber = Get-SapValidChangeNumber -VaultEntity $VaultEntity -SapRevisionChangeNumber $result
    Log -End
    return $validChangeNumber
}

function Get-SapValidChangeNumber {
    param (
        $VaultEntity,
        [PSObject]$SapRevisionChangeNumber
    )
    Log -Begin
    $ErpRevision = ""
    $ErpChangenumber = ""

    $leadingZeros = Test-ChangeNumberStartsWithZero -VaultEntity $VaultEntity
    if ($leadingZeros) {
        $message = "SAP Change Number code with leading zeros is not supported by SAP"
        Log -Message $message
        throw $message
    }
    
    $VaultRevison = $VaultEntity._Revision
    $VaultChangenumber = $VaultEntity.'SAP ECO #'

    $validFrom = Get-Date $validFrom -Format yyyy-MM-ddTHH:mm:ss
        
    if ($VaultChangenumber -eq $ErpChangenumber -and $VaultRevison -ne $ErpRevision -and $ErpRevision -and $ErpChangenumber) {
        $message = "ERROR - Change number matches but rev. level is different between Vault and SAP Revision Level: Vault $VaultRevison <> SAP: $ErpRevision"
        Log -End -Message $message
        throw $message
    }
    elseif ($VaultChangenumber -ne $ErpChangenumber -and $VaultRevison -eq $ErpRevision -and $ErpRevision -and $ErpChangenumber) {        
        $message = "ERROR - Rev. level matches but Change Number is different between Vault and SAP Change Number: Vault: $VaultChangenumber <> SAP: $ErpChangenumber"
        Log -End -Message $message
        throw $message
    }
    elseif ($VaultChangenumber -eq $ErpChangenumber -and $VaultRevison -eq $ErpRevision -and $ErpRevision -and $ErpChangenumber) {
        $message = "SUCCESS - Updated existing revision level in SAP with same change number"
        Log -End -Message $message
        return $VaultChangenumber
    }
    else {
        Log -End
        return $VaultChangenumber
    } 
    Log -End
} 

function Test-ChangeNumberStartsWithZero {
    param (
        $VaultEntity
    )
    if (-not $VaultEntity.'SAP ECO #') { return $false }
    if ($VaultEntity.'SAP ECO #'.StartsWith("0")) {
        return $true
    }
    return $false    
}


function Get-ErpDir {
    param (
        $VaultEntity,
        [switch] $DocumentInfoRecordDescription,
        [switch] $DocumentInfoRecordData,
        [switch] $DocumentInfoRecordOriginals,
        [switch] $DocumentInfoRecordObjectLinks,
        [switch] $CharacteristicValues
    )
    Log -Begin
    
    if (-not $VaultEntity) { return }
    
    $expand = @()
    if ($DocumentInfoRecordDescription) { $expand += 'DocumentInfoRecordDescription' }
    if ($DocumentInfoRecordData) { $expand += 'DocumentInfoRecordData' }
    if ($DocumentInfoRecordOriginals) { $expand += 'DocumentInfoRecordOriginals' }
    if ($DocumentInfoRecordObjectLinks) { $expand += 'DocumentInfoRecordObjectLinks' }
    if ($CharacteristicValues) { $expand += 'CharacteristicValues' }

    $keys = Get-ErpKey -VaultEntity $VaultEntity -Type Dir
    if ($expand -and $expand.Count -gt 0) {
        $dir = Get-ERPObject -EntitySet "DocumentInfoRecordContextCollection" -Keys $keys -Expand $expand
    }
    else {
        $dir = Get-ERPObject -EntitySet "DocumentInfoRecordContextCollection" -Keys $keys
    }
    
    $response = Get-ErpResponse
    $response.Entity = $dir
    return $response
}


function Get-ErpKey {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Entity')]
        $VaultEntity,
        [ValidateSet('BasicMaterial', 'Material', 'Dir', 'Binary')] 
        $Type
    )
    Log -Begin
	
    #if(-not $VaultEntity) { return }

    if ($Type -ieq 'BasicMaterial') { return GetErpBasicMaterialKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Material') { return GetErpMaterialKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Dir') { return GetErpDirKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Binary') { return GetErpBinaryKey -VaultEntity $VaultEntity }
}

function GetErpBinaryKey {
    param (
        $VaultEntity
    )

    Log -Begin

    $key = @{
        Documentnumber  = $VaultEntity._PartNumber
        Documentversion = Get-SapValue -Table DirVersion -VaultValue $VaultEntity._Revision
        Documenttype    = Get-SapValue -Table DocumentType -VaultValue $VaultEntity.'Document Type'
        Documentpart    = '001'
        FileName        = $VaultEntity._Name
    }
    ($key.GetEnumerator() | ForEach-Object { Log -Message "$($_.Key) = $($_.Value)" }) 
    Log -End

    return $key
}

function GetErpBasicMaterialKey {
    param (
        $VaultEntity
    )

    Log -Begin
	
    $key = @{
        Material = (Get-SapMaterialNumber -VaultEntity $VaultEntity)
    }

    ($key.GetEnumerator() | ForEach-Object { Log -Message "$($_.Key) = $($_.Value)" }) 
    Log -End

    return $key
}

function GetErpMaterialKey {
    param (
        $VaultEntity
    )

    Log -Begin

    $key = @{
        Material      = (Get-SapMaterialNumber -VaultEntity $VaultEntity)
        Plant         = ''
        ValuationArea = ''
        ValuationType = ''
    }

    ($key.GetEnumerator() | ForEach-Object { Log -Message "$($_.Key) = $($_.Value)" }) 
    Log -End

    return $key
}

function GetErpDirKey {
    param (
        $VaultEntity
    )

    Log -Begin

    $key = @{
        Documentnumber  = (Get-SapMaterialNumber -VaultEntity $VaultEntity)
        Documentversion = Get-SapValue -Table DirVersion -VaultValue $VaultEntity._Revision
        Documenttype    = Get-SapValue -Table DocumentType -VaultValue $VaultEntity.'Document Type'
        Documentpart    = '001'
    }

    #($key.GetEnumerator() | ForEach-Object { Log -Message "$($_.Key) = $($_.Value)" }) 
    Log -End

    return $key
}
function Get-ErpKey {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Entity')]
        $VaultEntity,
        [Parameter(ParameterSetName = 'BomRow')]
        $BomHead,
        [Parameter(ParameterSetName = 'BomRow')]
        $BomRow,
        [ValidateSet('BasicMaterial', 'Material', 'Bom', 'BomRow', 'Dir', 'Binary')] 
        $Type
    )
    Log -Begin
	
    #if(-not $VaultEntity) { return }

    if ($Type -ieq 'BasicMaterial') { return GetErpBasicMaterialKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Material') { return GetErpMaterialKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Bom') { return GetErpBomKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Dir') { return GetErpDirKey -VaultEntity $VaultEntity }
    if ($Type -ieq 'Binary') { return GetErpBinaryKey -VaultEntity $VaultEntity }

    if ($BomHead -and $BomRow) {
        if ($Type -ieq 'BomRow') { return GetErpBomRowKey -BomHead $BomHead -BomRow $BomRow }
    }
}

function Get-PaddedOrUnchangedMaterialNumber {
    param ($number)

    $ret = ''
    if ($number) { 
        $number = $number.Trim()
        if ($number -match '^\d+$') {
            $ret = $number.PadLeft(18, "0")
        }
        else {
            $ret = $number
        }
    }
    return $ret
}

function Get-SapMaterialNumber {
    param ($VaultEntity)

    if ($VaultEntity._EntityTypeID -ieq 'FILE') {
        $number = $VaultEntity._PartNumber
    }
    else {
        $number = $VaultEntity._Number
    }

    if ($number) { $number = $number.ToUpper() }
    return Get-PaddedOrUnchangedMaterialNumber -number $number
}

function Get-SapMaterial {
    param (
        $VaultEntity,
        [switch] $Description,
        [switch] $PlantData,
        [switch] $BasicData,
        [switch] $ValuationData,
        [switch] $BasicDataText
    )
    Log -Begin

    $expand = @()
    if ($Description) { $expand += 'Description' }
    if ($PlantData) { $expand += 'PlantData' }
    if ($BasicData) { $expand += 'BasicData' }
    if ($ValuationData) { $expand += 'ValuationData' }
    if ($BasicDataText) { $expand += 'BasicDataText' }

    $keys = Get-ErpKey -VaultEntity $VaultEntity -Type Material
    if ($expand -and $expand.Count -gt 0) {
        $material = Get-ERPObject -EntitySet "MaterialContextCollection" -Keys $keys -Expand $expand
    }
    else {
        $material = Get-ERPObject -EntitySet "MaterialContextCollection" -Keys $keys
    }

    $response = Get-ErpResponse
    $response.Entity = $material

    Log -End
    return $response
}

function Get-SapValue {
    param (
        [MappingTableNames]$Table,
        $VaultValue
    )
    Log -Begin

    if (-not $VaultValue) { return $null }

    $textReplacementMappings = Get-TextReplacementMappings

    $mappingTable = $textReplacementMappings[$Table]

    $sapValue = $mappingTable.GetSapValue($VaultValue)

    if (-not $sapValue) {
        Log -Message "Couldn't find mapping for Vault value '$($VaultValue)' in table '$($Table)'"
        if ($Table -eq [MappingTableNames]::LabOffice) {
            $VaultValue = $VaultValue.Trim()
            return ($VaultValue -split " ")[0] #number of lab/office
        }
        if ($Table -eq [MappingTableNames]::StorageCategory) {
            # issue 154: Comment from 15.10.2020
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

function Get-TextReplacementMappings {
    Log -Begin

    if (-not (IAmRunningJobprocessor)) {
        $textReplacementMappings = [Appdomain]::CurrentDomain.GetData('TextReplacementMappings')
        if ($textReplacementMappings) { 
            return $textReplacementMappings 
        }
    }

    $textReplacementMappings = [Dictionary[[string], [TextReplacementMappingTable]]]::new()

    Push-Location $PSScriptRoot
    [System.IO.DirectoryInfo]$Path = (Resolve-Path '.\TextReplacementMappings').Path
    Pop-Location

    $mappingXmlFileInfos = Get-ChildItem -LiteralPath $Path.FullName | Where-Object { $_.Extension -ieq '.xml' }
    foreach ($xmlFileInfo in $mappingXmlFileInfos) {
        $mappingTable = [TextReplacementMappingTable]::new($xmlFileInfo)
        $textReplacementMappings.Add($mappingTable.GroupName, $mappingTable)
    }

    [Appdomain]::CurrentDomain.SetData('TextReplacementMappings', $textReplacementMappings)
    return $textReplacementMappings
}

enum MappingTableNames {
    BasicMaterial; DirVersion; DocumentType; ExtMaterialGroup; ItemCategory; LabOffice; MaterialGroup; MaterialType; PlantView; ProductHirarchy; RfcShortDescription; SalesOrg; SapEcoDescription; SapMaterialExists; SapUpdatePossible; StorageCategory; Units; XMatPlantStatus
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
        foreach ($mapping in $mappings.GetEnumerator()) {
            $null = $this.Mappings.Add([TextReplacementMapping]::new($mapping.Key, $mapping.Value))
        }
    }
    TextReplacementMappingTable([System.IO.FileInfo]$xmlFileInfo) {
        if (-not $xmlFileInfo.Exists) {
            throw "Error in .ctor TextReplacementMapping. The file '$($xmlFileInfo.FullName)' doesn't exist."
        }

        $xmlMappingGroup = [XmlMappingGroup]::new($xmlFileInfo)
        $this.Mappings = $xmlMappingGroup.ToTextReplacementList() 
        
        $this.GroupName = $xmlMappingGroup.GetGroupName()

    }
    [System.Collections.Generic.List[string]] GetSapValues() {
        $sapValues = [System.Collections.Generic.List[string]]::new()

        foreach ($mapping in $this.Mappings) {
            $null = $sapValues.Add($mapping.SapValue)
        }

        return $sapValues
    }
    [System.Collections.Generic.List[string]] GetVaultValues() {
        $vaultValues = [System.Collections.Generic.List[string]]::new()

        foreach ($mapping in $this.Mappings) {
            $null = $vaultValues.Add($mapping.VaultValue)
        }

        return $vaultValues
    }
    [string] GetSapValue($vaultValue) {
        Log -Message 'GetSapValue'

        foreach ($mapping in $this.Mappings) {
            if ($mapping.VaultValue -ieq $vaultValue) {
                $sapValue = $mapping.SapValue
                return $sapValue
            }
        }
        return $null
    }
    [string] GetVaultValue($sapValue) {
        Log -Message 'GetVaultValue'
        foreach ($mapping in $this.Mappings) {
            if ($mapping.SapValue -ieq $sapValue) {
                return $mapping.VaultValue
            }
        }
        return $null
    }
}