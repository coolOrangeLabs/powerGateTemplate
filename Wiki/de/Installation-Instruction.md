# ERP Integration für den powerGateServer

![powergate_workflow](https://user-images.githubusercontent.com/36075173/46526371-59110900-c88e-11e8-8073-e38e963bbb12.png)

## Vorraussetzungen

+ Betriebssystem: Windows 7, Windows 8.1, Windows 10 / Windows Server 2012
+ .Net Framework 4.7 oder höher
+ [powerGateServer v20](http://download.coolorange.com/products/cO_powerGateServer19.0_x64.msi)
  + [Installationsanleitung](https://www.coolorange.com/wiki/doku.php?id=powergateserver:installation)

## ERP Plugin Installieren


![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: Link to the Github Releases!!** Then remove this text and image here!

### Download

Die akutellste Version des Installers _([MSI Datei](https://docs.microsoft.com/en-us/windows/desktop/msi/windows-installer-portal))_ befindet sich unter den [Releases auf Github.](https://github.com/coolOrangeProjects/!!!INSERT!!!/releases)

### Installieren

1. Den Installer wie oben beschrieben herunterladen
1. Das gerade heruntergeladene Setup auszuführen
1. **Wichtig:** Den powerGateServer Service in Windows Neustarten
1. Die [[Einstellungen in der Konfigurationsdatei|Server-Konfiguration]] überprüfen und gegebenenfalls ändern

Installiert wird:
+ Ein powerGateServer Plugin unter `C:\ProgramData\coolOrange\powerGateServer\Plugins`


### Updates

Um eine neuere Version zu installieren, kann das Setup wieder ausgeführt werden und dabei werden automatisch die Dateien von der existierenden Installation aktualisiert.

### Deinstallieren

Zum Deinstallieren gibt es 2 Möglichkeiten:
+ Das gleiche Setup auszuführen und im Fenster die Option "Entfernen" auswählen
+ In die _Systemsteuerung -> Programs and Features_ die Software **"powerGate Standard - Server Plugin"** finden und "Deinstallieren" drücken