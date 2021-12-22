[Menu](../README.md) [Home](./home.md)

## Bom Header

powerGate mask | Vault UDP| Inventor iProperty | Plugin field | API field | Notes|
-- | -- | -- | -- | -- | --
Number | Part Number | Part Number| Number | Number| 
Description | Description| Description | Description |Description| 
State| State| State| State|State| 
UnitOfMeasure| UnitOfMeasure| UnitOfMeasure| UnitOfMeasure|UnitOfMeasure| 
ModifiedDate| ModifiedDate| ModifiedDate| ModifiedDate|ModifiedDate|  This is a Date Field, Format DD/MM/YYYY


## Bom Row

powerGate mask | Vault UDP| Inventor iProperty | Plugin field | API field | Notes|
-- | -- | -- | -- | -- | --
Not displayed | Part Number of the parent| Part Number of the parent| ParentNumber| ParentNumber| 
Number | Part Number | Part Number| ChildNumber| ChildNumber| 
Position | - | Position _(directly from the CAD BOM)_ | Position |Position |  This is a integer
Type | Type | Type | Type |Type| 
UnitOfMeasure| UnitOfMeasure| UnitOfMeasure| UnitOfMeasure|UnitOfMeasure| 
Description | Description| Description | Description |Description| 
ModifiedDate| ModifiedDate| ModifiedDate| ModifiedDate|ModifiedDate|  This is a Date Field, Format DD/MM/YYYY

## Raw materials

Raw materials are [[inserted from Inventor|Inventor-Create-Assembly#insert-a-raw-material-from-erp]] for a part _(ipt file)_.
In ERP this raw material is transferred in an own BOM where:
+ The part is the BOM header
+ The raw material is the only BOM row and the `Position` is always set to 1

powerGate mask | Vault UDP| Inventor iProperty | Plugin field | API field | Notes|
-- | -- | -- | -- | -- | --
Number | Raw Number| Raw_Number| Number | Number | [[Inserted from Inventor|Inventor-Create-Assembly#insert-a-raw-material-from-erp]]
Quantity | Raw Quantity| Raw_Quantity| Quantity | Quantity | [[Inserted from Inventor|Inventor-Create-Assembly#insert-a-raw-material-from-erp]]
