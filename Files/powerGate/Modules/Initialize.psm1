
function Initialize-CoolOrange {
    $global:ErrorActionPreference = "Stop"
    Import-CoolOrangeModules
}

function Import-CoolOrangeModules {
    $commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"

    $validModuleFiles = @('*.dll', '*.ps1', '*.psm1', '*.psd1', '*.cdxml', '*.xaml')
    $ignoreSubPath = "PSFramework" # This external module is imported by the Logging.psm1

    $foldersForModules = Get-ChildItem -path $commonModulePath -Exclude $ignoreSubPath
    $modules = $foldersForModules | Get-ChildItem -Include $validModuleFiles -Recurse -Verbose
    $modules | ForEach-Object { Import-Module -Name $_.FullName -Global -Verbose }
}

function ShowMessageBox {
    param(
        [string]
        $Message,
        [string]
        $Title = "powerGate ERP Integration",
        [System.Windows.Forms.MessageBoxButtons]
        $Button = "OK", # OK, OKCancel, AbortRetryIgnore, YesNoCancel, YesNo, RetryCancel
        [System.Windows.Forms.MessageBoxIcon]
        $Icon = "Information" #icons: Error, Exclamation, Hand, Information, Question, Stop, Warning
    )
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Button, $Icon)
}