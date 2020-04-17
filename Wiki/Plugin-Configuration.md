# powerGateServer configuration for the ERP

The following settings can be easily configured on the server-side and therefore they **don't need** to be changed on every client machine!

## Configuration file <img src="https://user-images.githubusercontent.com/36075173/46526478-9ffefe80-c88e-11e8-9620-2ca213003828.png" height="80" width="100" alt="Configuration" align="middle">

![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: Path of the PLUGIN below!!** Then remove this text and image her

It's very easy to change the existing configuration file:
+ The configuration file is a [XML](https://en.wikipedia.org/wiki/XML) - document
+ The file is located on the Machine after the [[ERP Integration Installation for the Server|Installation-Instruction]]
  + Path: `C:\ProgramData\coolOrange\powerGateServer\Plugins\PLUGIN NAMEN EINFÜGEN\PLUGIN NAMEN EINFÜGEN.dll.config`

## Configure

If you want to change the settings, then you have to change the value after the [XML attribute](https://www.w3schools.com/xml/xml_attributes.asp) `value`, this means after the equal sign _(=)_.

**Important:** The new value must be inserted between the double quotes like: `value="My new value"`

### Apply new changes

After you have changed the configuration file you must **restart the powerGateServer Service**, then the new changes will be applied.

## Changeable values for the ERP Plugin

![WAIT](https://placehold.it/150/f03c15/FFFFFF?text=WAIT) - **Change the: XML Examples of the PLUGIN below!!** Then remove this text and image her

### SQL Credentials for the read operations

``` XML
    <add key="SqlInstance" value="BMDTEST\BMD"/>
    <add key="SqlDatabase" value="BMD_CAD_TEST"/>
    <add key="SqlUsername" value="bmdreader"/>
    <add key="SqlPassword" value="cad4inocon!."/>
```

### ERP Connection Information

``` XML
    <add key="BMD-IP" value="127.0.0.1"/>
    <add key="BMD-Port" value="5008"/>
```
