#=============================================================================#
# PowerShell script sample for coolOrange powerEvents                         #
# Restricts the state to release, if the Vault and ERP BOMs do not match      #
#                                                                             #
# Copyright (c) coolOrange s.r.l. - All rights reserved.                      #
#                                                                             #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER   #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  #
#=============================================================================#

#TODO manni; relativer pfad geht nicht, oder? brauchts connect?
Connect-ToErpServer
Get-ChildItem -path ($env:ProgramData+'\Autodesk\Vault 2020\Extensions\DataStandard\powerGate\Modules') -Filter BomFunctions.psm1 | foreach { Import-Module -Name $_.FullName -Global -Force}

Register-VaultEvent -EventName UpdateFileStates_Restrictions -Action 'RestrictReleaseStateBOM'

function RestrictReleaseStateBOM($files) {

    $IamFiles = $files | Where-Object { $_._Extension -eq 'iam'} 

    foreach($file in $IamFiles){
        if($file._NewState -eq 'Freigegeben'){
            $bomRows = Get-VaultBomRowsForEntity -Entity $file
			Add-Member -InputObject $file -Name "Children" -Value $bomRows -MemberType NoteProperty -Force      
            try{
				Check-VaultBom -bomHeader $file
            }
            catch{
			   $message = "Stücklisten sind zwischen Vault und ERP unterschiedlich: $($_)! Öffne den Stücklisten-Dialog"
			   Add-VaultRestriction -EntityName $file._Name -Message $message
			   break;
            }            
        }
    }
}

function Check-VaultBom {
	param(
		$bomHeader
    )

    $bomHeaders = @($bomHeader)
    $differences = Get-VaultToErpBomsDifferences -VaultBomHeaders $bomHeaders
	foreach($diff in $differences){
		if ($diff.Status -ne "Identical" -and $diff.IsHeader) {
			throw $diff.Message
		}
	}
}
