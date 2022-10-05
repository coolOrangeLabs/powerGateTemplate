
function Check-Permission()
{
    $err = $false
    $paths = @("coolOrange", "Autodesk")
    foreach ($path in $paths)
    {
        try
        {
            $Folder = $env:ProgramData + "\" + $path
            Write-Host "`nChecking for $Folder"
            $File = $Folder + "\writeTest.txt"
            Out-File -FilePath $File
            Write-Host "Created Text file"
            Set-Content -Path $File -Value 'Hello, World'
            Write-Host "Set content"
            $items = Get-ChildItem -Path $Folder
            Write-Host "Retrieved folder content"
            Remove-Item -Path $File
            Write-Host "Deleted File"
            Write-Host -ForegroundColor Green "Successfully verified Read-Write permission for $Folder"

        }
        catch
        {
            Write-Host -ForegroundColor Red "Failed to verify Read-Write permission for $Folder"
            $err = $true
        }
        
    }
    if (-not $err)
    {
        Download-Setups
    }
}
function Download-Setups()
{
    $products = @{
        "powerJobs" = @{
            "2020" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerJobsProcessor22.0_Vault2020.exe";
            "2021" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerJobsProcessor22.0_Vault2021.exe";
            "2022" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerJobsProcessor22.0_Vault2022.exe"
            };
        "powerGate" = @{
            "2020" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGate21.0.exe";
            "2021" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGate21.0.exe";
            "2022" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGate21.0.exe"
            };
        "powerGateServer" = @{
            "2020" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGateServer21.0_x64.msi";
            "2021" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGateServer21.0_x64.msi";
            "2022" = "https://coolorangedownloads.blob.core.windows.net/downloads/cO_powerGateServer21.0_x64.msi"
            }
        }
    Write-Host "`nEnter Vault Version Year:"
    $vaultVersion = ""
    while ($true)
    {
        if (-not $products[$vaultVersion])
        {
            [string]$vaultVersion = Read-Host
        }
        break
    }
    $installed = @()
    foreach($p in $products.Keys)
    {
        while ($true) {
            Write-Host "`nInstall $p`? ('y', 'n')" -ForegroundColor Blue
            $ins = Read-Host
            if ($ins -eq 'y')
            {
                $url = $products[$p][$vaultVersion]
                $prod = $url.Split("/")
                $prod = $prod[$prod.Length-1]
                $output = $env:USERPROFILE + "\Downloads\$prod"
                $start_time = Get-Date
                Write-Host "`nDownloading $p..."
                $progressPreference = 'silentlyContinue'
                Invoke-WebRequest -Uri $url -OutFile $output
                Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s) for $p"
                $installed += $p
                break
            }
            elseif ($ins -eq 'n')
            {
                break
            }
            else 
            {
                Write-Host -ForegroundColor Red "Invalid input"
            }
        }
    }

    Write-Host "`nInstall setups? ('y', 'n')" -ForegroundColor Blue
    $install = Read-Host

    while ($true)
    {
        if ($install.ToLower() -eq "y")
        {
            foreach($p in $installed)
            {
                $url = $products[$p][$vaultVersion]
                $prod = $url.Split("/")
                $prod = $prod[$prod.Length-1]
                $file = $env:USERPROFILE + "\Downloads\$prod"
                Write-Host "`Starting installation for $p..." 
                if ($file.Contains(".exe"))
                {
                    $process = Invoke-Command -ScriptBlock { Start-Process $file -ArgumentList "/q ACCEPT_EULA=1" -Wait -PassThru -Verb RunAs}
                }
                elseif ($file.Contains(".msi")) 
                {
                    $process = Invoke-Command -ScriptBlock { Start-Process msiexec.exe -Wait -ArgumentList "/I $file /quiet" -PassThru -Verb RunAs}
                }

                switch ($process.ExitCode) 
                {
                    0 { Write-Host "Finished installation for $prod" }
                    1603 { Write-Host -ForegroundColor Yellow "A version of $p might already be installed or Vault Version differs from $vaultVersion." }
                    default { Write-Host -ForegroundColor Red "Failed to install $prod" }
                }

            }
            break
        }
        elseif ($install.ToLower() -eq "n")
        {
            Write-Host "Cancelled installation"
            break
        }
        else 
        {
            Write-Host -ForegroundColor Red "Invalid input"
        }
    }
}



Check-Permission