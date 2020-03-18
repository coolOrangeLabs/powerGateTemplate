# powerGateServer Konfiguration für das ERP

Die folgenden Einstellungen können einfach auf der Server-seite eingestellt werden und müssen somit **nicht** auf jeder Client Maschine angepasst werden! 


## Konfigurationsdatei <img src="https://user-images.githubusercontent.com/36075173/46526478-9ffefe80-c88e-11e8-9620-2ca213003828.png" height="80" width="100" alt="Configuration" align="middle">

![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: Path of the PLUGIN below!!** Then remove this text and image her

In der Konfigurationsdatei vom ERP Plugin ist es möglich viele Einstellungen sehr einfach zu verändern;
+ Die Konfigurationsdatei ist ein [XML](https://en.wikipedia.org/wiki/XML) - Dokument
+ Diese befindet sich auf der Maschine nach der [[ERP Integration Installation für den Server|Installationsanleitung]]
  + Pfad: `C:\ProgramData\coolOrange\powerGateServer\Plugins\PLUGIN NAMEN EINFÜGEN\PLUGIN NAMEN EINFÜGEN.dll.config`

## Konfiguriere

Um in der Konfigurationsdatei selbst Änderungen vorzunehmen ist es notwendig den Wert vom [XML Attribute](https://www.w3schools.com/xml/xml_attributes.asp) `value` zu ändern, sprich das was nach dem Gleichheitszeichen _(=)_ kommt.

**Wichtig:** Der Wert muss zwischen doppelten Hochkommas stehen: `value="Mein Neuer Wert"`

### Änderungen übernehmen

Nach dem Ändern der Konfigurationsdatei muss der **powerGateServer neugestartet(!)** werden und dann werden die Änderungen übernommen.

## Veränderbare Werte für das Plugin

![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: XML Examples of the PLUGIN below!!** Then remove this text and image her

### SQL Daten für das Lesen von den Datensätzen

``` XML
    <add key="SqlInstance" value="BMDTEST\BMD"/>
    <add key="SqlDatabase" value="BMD_CAD_TEST"/>
    <add key="SqlUsername" value="bmdreader"/>
    <add key="SqlPassword" value="cad4inocon!."/>
```

### ERP Connection Informationen

``` XML
    <add key="BMD-IP" value="127.0.0.1"/>
    <add key="BMD-Port" value="5008"/>
```
