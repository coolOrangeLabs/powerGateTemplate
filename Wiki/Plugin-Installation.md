# ERP Integration for the [powerGateServer](https://www.coolorange.com/wiki/doku.php?id=powergateserver)

![powergate_workflow](https://user-images.githubusercontent.com/36075173/46526371-59110900-c88e-11e8-8073-e38e963bbb12.png)

## Requirements

+ Operating System: Windows 7, Windows 8.1, Windows 10 / Windows Server 2012
+ .Net Framework 4.5 or higher
+ [powerGateServer v19](http://download.coolorange.com/products/cO_powerGateServer19.0_x64.msi)
  + [Installation Instruction](https://www.coolorange.com/wiki/doku.php?id=powergateserver:installation)

## Install ERP Plugin

![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: Link to the Github Releases!!** Then remove this text and image here!

### Download

The latest version of the installer _([MSI file](https://docs.microsoft.com/en-us/windows/desktop/msi/windows-installer-portal))_ is located under [Releases on Github.]()

### Install

1. Download the installer as mentioned above
1. Run the just downloaded setup
1. **Important:** Restart the Windows Service "powerGateServer"
1. Check the [[configuration of the installed Plugin|Server-Configuration]] and may adjust it

Install locations:
+ The powerGateServer Plugin will be installed to: `C:\ProgramData\coolOrange\powerGateServer\Plugins`


### Updates

To install a newer version just execute the setup file of the new version. This will automatically update the files in the existing installation.

### Uninstall

In case you want to remove the ERP Plugin from your computer you can:
+ Execute the setup file again. This will give you the option to repair or remove powerGateServer. Click on “Remove” to uninstall the program.
+ Go to “Control Panel - Programs and Features”, find **"powerGate Standard - Server Plugin"** and run “Uninstall”.