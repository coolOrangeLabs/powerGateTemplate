function Verify-VaultRestrictionWhenSapChangeNumberIsNotOk {
    param (
        $VaultEntity,
        $ERPMaterial,
        [switch]$DIR,
        [switch]$Material
    )
    Log -Begin
    $ErpRevision = ""
    $ErpChangenumber = ""

    $leadingZeros = Test-ChangeNumberStartsWithZero -VaultEntity $VaultEntity
    if ($leadingZeros) {
        $message = " SAP Change Number code with leading zeros is not supported by SAP"
        Log -Message $message
        throw $message
    }

    if ($DIR) {
        $response = Get-ErpDir -VaultEntity $VaultEntity -DocumentInfoRecordData
        $ErpRevision = $response.Entity.DocumentInfoRecordData.RevisionLevel
        $ErpChangenumber = $response.Entity.DocumentInfoRecordData.ChangeNumber
        
    }
    elseif ($Material) {
        $response = GetErpMaterial -VaultEntity $VaultEntity -BasicData
        $ERPMaterial = $response.Entity
        $ErpRevision = $ERPMaterial.BasicData.RevisionLevel
        $ErpChangenumber = $ERPMaterial.BasicData.ChangeNumber
    }
    
    $VaultRevison = $VaultEntity._Revision
    $VaultChangenumber = $VaultEntity.'SAP ECO #'

    $validFrom = Get-date
    $validFrom = Get-Date $validFrom -Format yyyy-MM-ddTHH:mm:ss
        
    if ($VaultChangenumber -eq $ErpChangenumber -and $VaultRevison -ne $ErpRevision -and $ErpRevision -and $ErpChangenumber) {
        $message = "ERROR - Change number matches but rev. level is different between Vault and SAP Revision Level: Vault $VaultRevison <> SAP: $ErpRevision"
        #$ecn = New-ChangeNumber -Description $VaultEntity.'SAP ECO # DESC' -ValidFrom $validFrom -ChangeNumber ""
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