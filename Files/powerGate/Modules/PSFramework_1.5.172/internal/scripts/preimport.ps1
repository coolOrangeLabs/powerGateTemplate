﻿$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

# Load "Environment" variables within the module
"$($moduleRoot)\internal\scripts\environment.ps1"

# Load Tab Expansion Plus Plus code (PS4 or older)
"$($moduleRoot)\internal\scripts\teppCoreCode.ps1"