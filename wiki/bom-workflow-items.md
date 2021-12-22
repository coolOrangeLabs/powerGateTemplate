[Menu](../README.md) [Home](./home.md)
# Bill of material workflow: Items


Here we will show you how to:
1. Verify all items included in the BOM
1. Fix all situations of the item

**First, read the [[basics|BOM-Workflow]]!**

## Verify all items included in the BOM

1. Click on an assembly in Vault
1. Click on the tab "ERP BOM"
1. The "ERP: Bill of Material" dialog will appear
1. Hit the "BOM Transfer.." Button
1. The [BOM Dialog](https://www.coolorange.com/wiki/doku.php?id=powergate:bom_window) will show the Inventor structured BOM
1. **Click on the "Items" tab**
1. Click on "Check" to verify if all items are in the correct state for using it in the ERP BOM
1. If items are on "Error" state, then hover with the mouse on the error icon and fix it manually

For the [[items mapping, see here.|ERP-Item-Mapping]]

`Different` is displayed if the following properties are different:
+ Description

`Error` is displayed if the following properties are not set:
+ ToDo1 from Template (needs to replaced in the project)
+ ToDo2 from Template (needs to replaced in the project)

Solving an `Error`:
1. Hover with the mouse over the error icon
1. Read the tooltip message
1. Fix manually, for instance, set mandatory Vault UDPs

#### Example after pressing "Check".
![check_items](https://user-images.githubusercontent.com/36075173/51521881-33e9db80-1e28-11e9-9d16-913d630970cd.png)

### Fix all situations of the item

#### Requirments:

+ Check of items was executed
+ No items on `Error`

1. After verifying all items of the BOM _(above steps)_
1. Click on "Transfer" to fix the states in "New" and "Different" automatically
1. If everything is green on `Identical` then the items are ready for [[transferring its BOM|BOM-Workflow-Items]]

Items with the state:
+ `New` are transferred with the [[items mapping, see here.|ERP-Item-Mapping]]
+ `Different` are updated with the following properties:
  + Description

