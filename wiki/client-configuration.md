[Menu](../README.md) [Home](./home.md)
## Configuration

The list values of the combo boxes are possible to change in the vault:
![image](https://user-images.githubusercontent.com/36075173/82907566-102c2d80-9f67-11ea-8cc8-f888b6b2196f.png)


### 1. Export powerGateConfiguration

1. Login to Vault
1. Click in the menu "Tools->powerGate->Edit powerGate configuration"
1. Then the windows explorer will be opened for `C:\temp\powerGateCfg\powerGateConfiguration.xml`

![image](https://user-images.githubusercontent.com/36075173/82907301-b9beef00-9f66-11ea-9920-fd9b86c7e5d0.png)

### 2. Change powerGateConfiguration

1. Open the exported XML file with a text editor
1. Find the appropriate section you want to change like `<UnitOfMeasures>`
1. Duplicate one line of `<Entry>`
1. Change the new `<Entry>`
   1. The value after `Key=` is used for communicating to the ERP
   1. The value after `Value=` is used to show in the combobox

#### Example

```XML
<Root>
  <UnitOfMeasures>
    <Entry Key="BOX" Value="Box" />
    <Entry Key="CAN" Value="Can" />
    <Entry Key="DAY" Value="Day" />
    <Entry Key="GR" Value="Gram" />
    <Entry Key="HOUR" Value="Hour" />
    <Entry Key="KG" Value="Kilogram" />
    <Entry Key="L" Value="Liter" />
    <Entry Key="MILES" Value="Miles" />
    <Entry Key="PCS" Value="Piece" />
    <Entry Key="PACK" Value="Pack" />
    <Entry Key="PAIR" Value="Pair" />
    <Entry Key="PALLET" Value="Pallet" />
  </UnitOfMeasures>
  <MaterialTypes>
    <Entry Key="Inventory" Value="Inventory" />
    <Entry Key="Service" Value="Service" />
  </MaterialTypes>
  <BomStates>
    <Entry Key="New" Value="New" />
    <Entry Key="Certified" Value="Certified" />
    <Entry Key="Under_Development" Value="Under Development" />
    <Entry Key="Closed" Value="Closed" />
  </BomStates>
  <!-- Key = binding Name & Vault = Lable Name -->
  <SearchFields>
    <Entry Key="Number" Value="Number" />
    <Entry Key="Description" Value="Description" />
    <Entry Key="UnitOfMeasure" Value="Unit of Measure" />
    <Entry Key="Type" Value="Type" />
    <Entry Key="IsBlocked" Value="Blocked" />
    <Entry Key="Weight" Value="Weight" />
    <Entry Key="Shelf" Value="Storage Area / Shelf" />
    <Entry Key="Dimensions" Value="Dimensions" />
  </SearchFields>
</Root>
```

### 3. Import powerGateConfiguration

1. Login to Vault
1. Click in the menu "Tools->powerGate->Import powerGate configuration"
   1. Then the file will be deleted: `C:\temp\powerGateCfg\powerGateConfiguration.xml`
1. Restart Vault and Inventor

