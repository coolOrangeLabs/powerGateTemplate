Import-Module powerVault

function Test-IsAdmin {
	#See https://justonesandzeros.typepad.com/blog/2012/03/whats-wrong-with-this-code-admin-check.html
	$userId = $vaultConnection.UserId
	if ($userId -le 0) {
		return $false
	}

	$permissions = $vault.AdminService.GetPermissionsByUserId($userId)
	#ID 82 is "Administrator User Read"
	$adminRead = $permissions | Where-Object { $_.Id -eq 82 }

	if (-not $adminRead) {
		return $false
	}

	return $true
}


function Set-ButtonEvents() {
	param(
		$Window, 
		$vault
	)
	
	$global:window = $Window
	$global:_vault_ = $vault

	$global:window.FindName("CancelButton").add_Click({
			$global:Window.Close()
		})
	$global:window.FindName("ConfirmButton").add_Click({
			$newUserName = $global:window.FindName("UserNameBox").Text
			$newPassword = $global:window.FindName("PasswordBox").Password

			if ((-not $newUserName) -or (-not $newPassword)) {
				Log -Message "Both user name and password need to be set" -MessageBox
			}
			else {
				try {
					$crypter = new-object CryptoService.CryptoService
					$encryptedPassword = $crypter.Encrypt($newPassword)
	
					$global:_vault_.KnowledgeVaultService.SetVaultOption("10001_FxParameters", "afdsda=123;2123=lfs")
					$global:_vault_.KnowledgeVaultService.GetVaultOption("10001_FxParameters")

					$global:_vault_.KnowledgeVaultService.SetVaultOption($global:VaultOptionerpUserNameKey, $newUserName)
					$global:_vault_.KnowledgeVaultService.SetVaultOption($global:VaultOptionerpEncryptedPasswordKey, $encryptedPassword)
	
					Log -Message "The settings have successfully been saved. They are applied after a Vault restart" -MessageBox
					$global:Window.Close()
				}
				catch {
					Log -Message "Error in setting new ERP settings: $($_)" -MessageBox
				}			
			}
		})
}


if (-not (Test-IsAdmin)) {
	Log -Message "Only Administrator users can edit the ERP connection settings" -MessageBox
	return
}


[xml]$xamlContent = Get-Content "C:\ProgramData\Autodesk\Vault 2020\Extensions\DataStandard\Vault.Custom\addinVault\Menus\ErpConnectionDialog.xaml"
$erpConnectionDialogWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader -ArgumentList @($xamlContent)))

$existingUserName = $vault.KnowledgeVaultService.GetVaultOption($global:VaultOptionerpUserNameKey)
$erpConnectionDialogWindow.FindName("UserNameBox").Text = $existingUserName

Set-ButtonEvents -Window $erpConnectionDialogWindow -Vault $vault
$erpConnectionDialogWindow.ShowDialog() | Out-Null