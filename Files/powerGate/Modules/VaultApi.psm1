function Get-PropertyDefinitionByName {
	param (
        [Parameter(Position=0)]
        $PropertyName, 
        [Parameter(Position=1,ParameterSetName="EntityClassId")]
        $EntityClassId,
        [Parameter(Position=1,ParameterSetName="PropDefs")]
        $PropDefs
	)    
	if(-not $PropDefs) { 
        $PropDefs = Get-PropertyDefinitions -EntityClassId $EntityClassId
    }

	foreach($propDef in $PropDefs) {
		if(($propDef.SysName -eq $PropertyName) -or ($propDef.DispName -eq $PropertyName)) {
			return $propDef
		}
	}
}

function Get-PropertyDefinitions {
    param (
        [ValidateSet('FLDR', 'FILE', 'CUSTENT', 'ITEM', 'ITEMRDES', 'CO', 'ROOT', 'LINK', 'FRMMSG')][string]$EntityClassId
    )
	return $vault.PropertyService.GetPropertyDefinitionsByEntityClassId($EntityClassId)
}

function Search-EntitiesByPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
		
		[string]$SearchValue,
		
		[Parameter(Mandatory = $true)]
        [ValidateSet('FLDR', 'ITEM', 'FILE')]
        [string]$EntityClassId,
		    
        [Parameter(Mandatory = $true)]
        [ValidateSet('Contains', 'DoesNotContain', 'IsExactly', 'IsEmpty', 'IsNotEmpty', 'GreaterThan', 'GreaterThanOrEqual', 'LessThan', 'LessThanOrEqual', 'NotEqualTo')]
        $SearchCondition
    )
    
    switch ($SearchCondition) {
        'Contains' {
            $SearchOp = 1
            $SearchValue = "*$SearchValue*"
            break
        }
        'DoesNotContain' {
            $SearchOp = 2
            $SearchValue = "*$SearchValue*"
            break
        }
        'IsExactly' {
            $SearchOp = 3
            break
        }
        'IsEmpty' {
            $SearchOp = 4
            $searchValue = $null
            break
        }
        'IsNotEmpty' {
            $SearchOp = 5
            $searchValue = $null
            break
        }
        'GreaterThan' {
            $SearchOp = 6
            break
        }
        'GreaterThanOrEqual' {
            $SearchOp = 7
            break
        }
        'LessThan' {
            $SearchOp = 8
            break
        }
        'LessThanOrEqual' {
            $SearchOp = 9
            break
        }
        'NotEqualTo' {
            $SearchOp = 10
            break
        }
    }
    $prop = Get-PropertyDefinitionByName -PropertyName $PropertyName -EntityClassId $EntityClassId
	
    $searchcond = New-Object Autodesk.Connectivity.WebServices.SrchCond
    $searchcond.PropDefId = $prop.Id
    $searchcond.SrchOper = $SearchOp
    $searchcond.SrchTxt = $SearchValue
    $searchcond.SrchRule = "Must"
    $searchcond.PropTyp = "SingleProperty"
    
    $bookmark = $null
    $searchStatus = New-Object Autodesk.Connectivity.WebServices.SrchStatus

    switch ($EntityClassId) {
        'ITEM' {
            $itemsApi = $vault.ItemService.FindItemRevisionsBySearchConditions(@($searchcond), $null, $true, [ref]$bookmark, [ref]$searchStatus)
			$items = foreach($itemApi in $itemsApi) {
				Get-VaultItem -Number $itemApi.ItemNum
			}
            break
        }        
        'FLDR' {
            $rootFolderId = $Vault.DocumentService.GetFolderRoot().Id
			$items = $vault.DocumentService.FindFoldersBySearchConditions(@($searchcond), $null, $rootFolderId, $true, [ref]$bookmark, [ref]$searchStatus)
            break
		}
		"FILE" {			
			$items = Get-VaultFiles -Properties @{ $PropertyName = $SearchValue }
		}
    }
    return $items
}