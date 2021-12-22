[To the Wiki](./wiki/_sidebar.md)

# powergate-generic-sample

[![Windows](https://img.shields.io/badge/Platform-Windows-lightgray.svg)](https://www.microsoft.com/en-us/windows/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5-blue.svg)](https://microsoft.com/PowerShell/)
[![.NET](https://img.shields.io/badge/.NET%20Framework-4.7-blue.svg)](https://dotnet.microsoft.com/)
[![Vault](https://img.shields.io/badge/Autodesk%20Vault-2020-yellow.svg)](https://www.autodesk.com/products/vault/)
[![Vault VDS](https://img.shields.io/badge/Autodesk%20Vault%20DataStandard-2020-yellow.svg)](https://www.autodesk.com/products/vault/)

[![powerGate](https://img.shields.io/badge/coolOrange%20powerGate-20-orange.svg)](https://www.coolorange.com/en-eu/connect.html#powerGate)
[![powerGate Server](https://img.shields.io/badge/coolOrange%20powerGate%20Server-20-orange.svg)](https://www.coolorange.com/en-eu/connect.html#powerGate)
[![powerJobs](https://img.shields.io/badge/coolOrange%20powerJobs-20-orange.svg)](https://www.coolorange.com/en-eu/enhance.html#powerJobs)
[![powerEvents](https://img.shields.io/badge/coolOrange%20powerEvents-20-orange.svg)](https://www.coolorange.com/en-eu/enhance.html#powerEvents)

## Disclaimer

THE SAMPLE CODE ON THIS REPOSITORY IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

THE USAGE OF THIS SAMPLE IS AT YOUR OWN RISK AND **THERE IS NO SUPPORT** RELATED TO IT.

## Description

This sample demonstrates an ERP integration for Autodesk Vault Professional/Workgroup and Autodesk Inventor by using the coolOrange products powerGate, powerGate Server, powerJobs and powerEvents. It not only adds live views on ERP data to Vault and Inventor but also improves Vault workflows by resticting state changes when ERP data is incomplete and by creating and uploading PDF files to the ERP system when a Vault file or Vault item is released.

It is highly customizable and at the same time it works out-of-the-box with a built-in mockup-ERP system. However, this sample can be extended to work with any ERP system.

**NOTE: This template is not prepared and supported for Vault/Inventor 2022!**

## Screenshots

![Sample Inventor](Images/Readme_Inventor.png)
![Sample Vault BOM](Images/Readme_Vault_BOM.png)

## Features

TBD!

## Prerequisites

### Autodesk Software
Autodesk Vault 2021 Professional, Autodesk Inventor 2021 and Autodesk Vault DataStandard for Vault and Inventor needs to be installed.

### coolOrange Software 
coolOrange powerGate, coolOrange powerGate Server, coolOrange powerJobs and coolOrange powerEvents needs to be installed.  
coolOrange software can be obtained from the [coolOrange Download Portal](https://download.coolorange.com)

## Installation
Install the latest version from the repository [Releases](https://github.com/coolOrangeLabs/powerGateTemplate/releases/latest) page. The following installers are available: 

### powerGate Server plugin
This setup contains a powerGate Server plugin. It needs to be installed on the machine that hosts coolOrange powerGate Server.

### Vault DataStandard customizations & powerEvents
This setup contains Autodesk Vault DataStandard customizations and coolOrange powerEvents workflow enhancements. It needs to be installed on all Vault client machines. Autodesk Vault DataStandard and coolOrange powerEvents are required on these machines, too.

### powerJobs
This setup contains powerJobs jobs. It needs to be installed on the machine that hosts a Autodesk Vault JobProcessor and coolOrange powerJobs.

## Usage

The script located [createGithubRepository.ps1](https://github.com/coolOrangeProjects/PowerShell.Extensions/tree/master/Others/Automated%20Repository%20Creation) allows a dynamic creation of a new repository in `https://www.github.com/`. The repository copies source code, issues, labels, projects, cards and wiki from this template.

Detailed information on which componentes are taken to the new repo:
- All projects with state `closed` and their cards
- All issues with the label `automation` and state `closed`
  - {REPO_OWNER} is replaced with the Github organization
  - {REPO_NAME} is replaced with the Github repository name 
- All wiki files (the string {REPO_NAME} and {YEAR} will be overwritten with the input from the script)
- labes are taken from the `labels.csv` which is located as a hidden file in the wiki. Can be modified by cloning wiki locally, changing contents and pushing again to this repo.

Run the script as administrator.
Information on how to execute the script can be found when executing `Get-Help .\createGithubRepository.ps1 -full`


## Product Documentation

[coolOrange powerGate](https://www.coolorange.com/wiki/doku.php?id=powergate)  
[coolOrange powerGate Server](https://www.coolorange.com/wiki/doku.php?id=powergateserver)  
[coolOrange powerJobs Processor](https://www.coolorange.com/wiki/doku.php?id=powerjobs)  
[coolOrange powerEvents](https://www.coolorange.com/wiki/doku.php?id=powerevents)


## Author
coolOrange s.r.l.  

![coolOrange](https://i.ibb.co/NmnmjDT/Logo-CO-Full-colore-RGB-short-Payoff.png)


