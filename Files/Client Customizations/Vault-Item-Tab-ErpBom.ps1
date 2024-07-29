#==============================================================================#
# (c) 2022 coolOrange s.r.l.                                                   #
#                                                                              #
# THIS SCRIPT/CODE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER    #
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES  #
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.   #
#==============================================================================#

# To disable the ERP BOM tab for items, move this script to the %ProgramData%/coolorange/Client Customizations/Disabled directory

if ($processName -notin @('Connectivity.VaultPro')) {
	return
}

Add-VaultTab -Name "$erpName BOM" -EntityType Item -Action {
	param($selectedItem)

	$partNumber = $selectedItem._Number
	$xamlFile = [xml](Get-Content "$PSScriptRoot\Vault-Tab-ErpBom.xaml")
	$tab_control = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xamlFile) )

	#region prechecks
	$tab_control.FindName('ButtonTransferBom').Visibility = "Collapsed"
	$tab_control.FindName('BomRowsTable').Visibility = "Collapsed"
	if ($null -eq $partNumber -or $partNumber -eq "") {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_error.png'
		$tab_control.FindName('Title').Content = "The Part Number is empty! A Part Number is required to create an $erpName BOM."
		return $tab_control
	}
	$tab_control.FindName('ButtonTransferBom').Visibility = "Visible"
	#endregion prechecks

	$erpBom = Get-ERPObject -EntitySet 'BomHeaders' -Keys @{ Number = $partNumber } -Expand 'Children/Item'
	if ($? -eq $false) { return }
	$tab_control.FindName('ButtonTransferBom').IsEnabled = $true
	$tab_control.FindName('ButtonTransferBom').add_Click({
			Show-BomWindow -Entity $selectedItem
			[System.Windows.Forms.SendKeys]::SendWait('{F5}')
		}.GetNewClosure())

	if (-not $erpBom) {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_new.png'
		$tab_control.FindName('Title').Content = "$erpName BOM '$partNumber' does not exist. Would you like to create it?"
		$tab_control.FindName('ButtonTransferBom').Content = "Create new $erpName BOM..."
	}
	else {
		$tab_control.FindName('StatusIcon').Source = 'pack://application:,,,/powerGate.UI;component/Resources/status_identical.png'
		$tab_control.FindName('Title').Content = "$erpName BOM '$partNumber'"
		$tab_control.FindName('ButtonTransferBom').Content = "Update $erpName BOM..."
		$sortByColumn = New-object System.componentmodel.SortDescription 'Position','Ascending'
		$tab_control.FindName('BomRowsTable').Items.SortDescriptions.Add($sortByColumn)
		$tab_control.FindName('BomRowsTable').Visibility = "Visible"
		$tab_control.DataContext = $erpBom
	}

	#region Required BOM Window functions, see "https://doc.coolorange.com/projects/powergate/en/stable/code_reference/commandlets/show-bomwindow/required-functions/"
	function global:Get-BomRows($item) {
		return (Get-VaultItemBom -Number $item._Number)
	}

	function global:Check-Items($items) {
		foreach ($vaultItem in $items) {
			$erpItem = Get-ERPObject -EntitySet 'Items' -Keys @{ Number = $vaultItem._Number } 
			if ($? -eq $false) {continue}

			if (-not $erpItem) {
				$vaultItem | Update-BomWindowEntity -Status New -StatusDetails "Item does not exist in $erpName and will be created"
			}
			else {
				if ($erpItem.Description -ne $vaultItem.'_Description(Item,CO)') {
					$vaultItem | Update-BomWindowEntity -Status Different -StatusDetails "Item has different Description in $erpName and will be updated. $erpName : $($erpItem.Description) <> Vault: $($vaultItem.'_Description(Item,CO)')"
					continue
				}
				
				$vaultItem | Update-BomWindowEntity -Status Identical -StatusDetails "Item is identical between Vault and $erpName "
			}
		}
	}

	function global:Transfer-Items($items) {
		foreach ($vaultItem in $items) {
			if ($vaultItem._Status -eq 'New') {
				$erpItem = $vaultItem | New-ERPObject -EntityType 'Item'
				#TODO:Validation
				Add-ErpObject -EntitySet 'Items' -Properties $erpItem
				if ($? -eq $false) {continue}
				$vaultItem | Update-BomWindowEntity -Status Identical
			}
			elseif ($vaultItem._Status -eq 'Different') {
				Update-ERPObject -EntitySet 'Items' -Key @{ Number = $vaultItem._Number } -Properties @{
					'Description' = $vaultItem.'_Description(Item,CO)'
				}
				if ($? -eq $false) {continue}
				$vaultItem | Update-BomWindowEntity -Status Identical
			}
			else {
				$vaultItem | Update-BomWindowEntity -Status $vaultItem._Status
			}
		}
	}

	function global:Check-Boms($boms) {
		foreach ($vaultBom in $boms) {
			$erpBom = Get-ERPObject -EntitySet 'BomHeaders' -Keys @{ Number = $vaultBom._Number } -Expand 'Children'
			if ($? -eq $false) {
				foreach ($vaultBomRow in $vaultBom.Children) {
					$vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails $vaultBom._StatusDetails
				}
				continue
			}

			if (-not $erpBom) {
				# if BOM does not exist, then simply put header and rows to new
				$vaultBom | Update-BomWindowEntity -Status New -StatusDetails "BOM does not exist in $erpName and will be created"
				foreach ($vaultBomRow in $vaultBom.Children) {
					$vaultBomRow | Update-BomWindowEntity -Status New -StatusDetails "Row does not exist in $erpName and will be created"
				}
			}
			else {
				# if BOM exists, check header and rows
				# let's assume the Vault and ERP BOMs are identical
				$vaultBom | Update-BomWindowEntity -Status Identical -StatusDetails "BOM is identical between Vault and $erpName "
				foreach ($vaultBomRow in $vaultBom.Children) {
					$vaultBomRow | Update-BomWindowEntity -Status Identical -StatusDetails "Row is identical between Vault and $erpName "
				}

				$vaultBom.Children | Where-Object { $_._Status -eq 'Remove' } | ForEach-Object { $_ | Remove-BomWindowEntity }
				# let's compare the Vault BOM with the ERP BOM
				foreach ($vaultBomRow in $vaultBom.Children) {
					$erpBomRow = $erpBom.Children | Where-Object { $_.ChildNumber -eq $vaultBomRow._Number }
					if ($erpBomRow) {
						if ($vaultBomRow.Bom_Quantity -ne $erpBomRow.Quantity) {
							$vaultBomRow | Update-BomWindowEntity -Status Different -StatusDetails "Row has different Quantity in $erpName and will be updated. $erpName : $($erpBomRow.Quantity) <> Vault: $($vaultBomRow.Bom_Quantity)"
							$vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOM has differences between Vault and $erpName "
						}
					}
					else {
						$vaultBomRow | Update-BomWindowEntity -Status New -StatusDetails "Row does not exist in $erpName and will be added"
						$vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOM has differences between Vault and $erpName "
					}
				}
			}
			# let's compare the ERP BOM with the Vault BOM
			foreach ($erpBomRow in $erpBom.Children) {
				$vaultBomRow = $vaultBom.Children | Where-Object { $_._Number -eq $erpBomRow.ChildNumber }
				if($null -eq $vaultBomRow) {
					$bomRow = Add-BomWindowEntity -Parent $vaultBom -Type BomRow -Properties @{
						"_Name"            = $erpBomRow.ChildNumber
						"Name"            = $erpBomRow.ChildNumber
						"Part Number"      = $erpBomRow.ChildNumber
						"_PartNumber"      = $erpBomRow.ChildNumber
						Bom_Number         = $erpBomRow.ChildNumber
						Bom_PositionNumber = $erpBomRow.Position
						Bom_Quantity       = $erpBomRow.Quantity
					}
					$bomRow | Update-BomWindowEntity -Status Remove -StatusDetails 'Row does not exist in Vault BOM and will be deleted'
					$vaultBom | Update-BomWindowEntity -Status Different -StatusDetails "BOM has differences between Vault and $erpName "
				}
			}
		}
	}

	function global:Transfer-Boms($boms) {
		[array]::Reverse($boms)
		#region WORKAROUND - block 'Transfer' if BOM has errors
  		# downside of this workaround: a second message will be displayed anyways, saying "Transfer completed" eventhough nothing was transferred
		  foreach ($vaultBom in $boms) {
			if ($vaultBom._Status -eq "Error" -or $vaultBom.Children | Where-Object { $_._Status -eq "Error" }) {
				[System.Windows.MessageBox]::Show("BOM transfer cancelled. One or more positions of the BOM has the 'Error' status!", "BOM Transfer cancelled", "OK", "Warn")
				return
			}
		}
		#endregion WORKAROUND
		foreach ($vaultBom in $boms) {
			if ($vaultBom._Status -eq 'New') {
				$erpBom = New-ERPObject -EntityType 'BomHeader' -Properties @{
					Number = $vaultBom._Number
					Children     = @()
				}
				foreach ($vaultBomRow in $vaultBom.Children) {
					$erpBomRow = New-ERPObject -EntityType 'BomRow' -Properties @{
						ParentNumber = $vaultBom._Number
						Position     = [int]$vaultBomRow.Bom_PositionNumber
						ChildNumber  = $vaultBomRow._Number
						Quantity     = [double]$vaultBomRow.Bom_Quantity
					}
					$erpBom.Children += $erpBomRow
				}
				Add-ERPObject -EntitySet 'BomHeaders' -Properties $erpBom
				if ($? -eq $false) {
					foreach ($vaultBomRow in $vaultBom.Children) {
						$vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails $vaultBom._StatusDetails
					}
					continue
				}
				$vaultBom | Update-BomWindowEntity -Status Identical
				foreach ($vaultBomRow in $vaultBom.Children) {
					$vaultBomRow | Update-BomWindowEntity -Status Identical
				}
				continue
			}
			elseif ($vaultBom._Status -eq 'Different') {
				$vaultBom | Update-BomWindowEntity -Status Identical
				foreach ($vaultBomRow in $vaultBom.Children) {
					if ($vaultBomRow._Status -eq 'New') {
						Add-ERPObject -EntitySet 'BomRows' -Properties @{
							ParentNumber = $vaultBom._Number
							Position     = [int]$vaultBomRow.Bom_PositionNumber
							ChildNumber  = $vaultBomRow._Number
							Quantity     = [double]$vaultBomRow.Bom_Quantity
						}
						if ($? -eq $false) {
							$vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "Error while processing BOM row. See BOM rows for more information."
							continue
						}
						$vaultBomRow | Update-BomWindowEntity -Status Identical -StatusDetails "Row has been added to $erpName "
						continue
					}
					elseif ($vaultBomRow._Status -eq 'Different') {
						Update-ERPObject -EntitySet 'BomRows' -Keys @{ ParentNumber = $vaultBom._Number; ChildNumber = $vaultBomRow._Number; } -Properties @{
							Quantity = [double]$vaultBomRow.Bom_Quantity
						}
						if ($? -eq $false) {
							$vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "Error while processing BOM row. See BOM rows for more information."
							continue
						}
						$vaultBomRow | Update-BomWindowEntity -Status Identical -StatusDetails "Row has been updated in $erpName "
						continue
					}
					elseif ($vaultBomRow._Status -eq 'Remove') {
						Remove-ERPObject -EntitySet 'BomRows' -Keys @{ParentNumber = $vaultBom._Number; ChildNumber = $vaultBomRow.Bom_Number; }
						if ($? -eq $false) {
							$vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "Error while processing BOM row. See BOM rows for more information."
							continue
						}
						$vaultBomRow | Remove-BomWindowEntity
						continue
					}
					else {
						$vaultBomRow | Update-BomWindowEntity -Status Identical -StatusDetails $vaultBomRow._StatusDetails
					}
				}
			}
			else {
				$vaultBom | Update-BomWindowEntity -Status $vaultBom._Status
				foreach ($vaultBomRow in $vaultBom.Children) {
					$vaultBomRow | Update-BomWindowEntity -Status $vaultBomRow._Status
				}
			}
		}
	}
	#endregion Required BOM Window functions, see "https://doc.coolorange.com/projects/powergate/en/stable/code_reference/commandlets/show-bomwindow/required-functions/"

	return $tab_control

}