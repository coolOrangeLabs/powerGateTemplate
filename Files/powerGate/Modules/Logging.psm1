# WIKI
# https://github.com/PowershellFrameworkCollective/psframework


function Set-LogFilePath {
    param($Path)
    Write-Host "Start to change logging file to: $Path"
    Initialize-CoolOrangeLogging -LogPath $Path
}

function Initialize-CoolOrangeLogging {
    param(
        $LogPath,
        $DeleteLogFilesOlderThenDays = '4d' # Format example for 30 days: "30d"
    )
    # PSFramework Version 1.5.172
    $commonModulePath = "C:\ProgramData\coolOrange\powerGate\PSFramework\PSFramework"
    Import-Module -Name $commonModulePath -Global -Verbose
    
    $paramSetPSFLoggingProvider = @{
    
        # For all parameters of the "Logfile" provider read here: https://psframework.org/documentation/documents/psframework/logging/providers/logfile.html
        Name             = 'logfile'
        Enabled          = $true
    
        InstanceName     = 'MyTask'
        FilePath         = $logPath
        LogRotatePath    = $logPath
        #Encoding         = "UTF8"

        #FilePath         = "$logPath\Test-%Date%.log"
        #LogRotatePath    = "$logPath\Test-*.log"
    
        # XML, CSV, Json, Html, CMTrace
        # For CMTrace - Download Microsoft CM Viewer: https://www.microsoft.com/en-us/download/confirmation.aspx?id=50012
        FileType         = 'Json'
        JsonCompress     = $false
        JsonString       = $true
        JsonNoComma      = $false
    
        #Headers         = 'ComputerName', 'File', 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Username', 'Data'
        Headers          = 'Timestamp', 'Level', 'Message', 'Data', 'FunctionName', 'Line', 'ModuleName', 'Username', 'ComputerName', 'File'
        TimeFormat       = 'yyyy-MM-dd HH:mm:ss.fff'
    
        LogRetentionTime = $deleteLogFilesOlderThenDays
        LogRotateRecurse = $true
    }
    
    Set-PSFLoggingProvider @paramSetPSFLoggingProvider
    Set-LoggingAliases
    Write-Host -Message "Initialized logging to file: $($logPath)"
}

function Set-LoggingAliases {
    Set-Alias Write-Host Write-PSFMessageProxy -Scope Global
    Set-Alias Write-Warning Write-PSFMessageProxy -Scope Global
    Set-Alias Write-Error Write-PSFMessageProxy -Scope Global
    Set-Alias Write-Verbose Write-PSFMessageProxy -Scope Global
}

function Log {
    param(
        [Parameter(ValueFromPipeline = $True, Position = 1)]
        $Message,
        [switch]$Begin,
        [switch]$End        
    )
    [string[]]$log = @()


    $callStack = Get-PSCallStack

    if ($Begin) {
        if ($callStack -and $callStack.count -gt 1) {
            $log += ">> {0} >>" -f $callStack[1].Command 
            $log += "Parameters: {0} " -f $callStack[1].Arguments
        }
    }

    if ($End) { 
        if ($callStack -and $callStack.count -gt 1) {
            $log += "<< {0} <<" -f $callStack[1].Command 
        }
    }

    if ($Message) {
        $log += [string]$Message
    }
    
    if ($callStack -and $callStack.count -gt 1 ) {
        $lastMethod = $callStack[1] 
        $fileWhereFunctionIsExecuted = $lastMethod.ScriptName
        if (-not $fileWhereFunctionIsExecuted) {            
            $fileWhereFunctionIsExecuted = "<Executed in Runspace, no was File executed>"
        }
        $overrideLogArguments = @{
            "Message"      = ([string]$log)
            "FunctionName" = $lastMethod.Command
            "File"         = $fileWhereFunctionIsExecuted
            "Line"         = $lastMethod.ScriptLineNumber
            "ModuleName"   = $lastMethod.FunctionName
        }
        Write-PSFMessage @overrideLogArguments
    }
    else {
        Write-Host [string]$log
    }
}

function Remove-CoolOrangeLogging {
    # Fixes https://github.com/coolOrangeLabs/powerGateTemplate/issues/179
    Wait-PSFMessage
    Get-PSFRunspace | Stop-PSFRunspace
    [PSFramework.PSFCore.PSFCoreHost]::Uninitialize()
}

$generalLogPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\default.log"
Initialize-CoolOrangeLogging -LogPath $generalLogPath