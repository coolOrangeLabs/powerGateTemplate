[Menu](../README.md) [Home](./home.md)
## Inventor create workflow

Here we will show you:
1. How to create a simple assembly with Inventor
1. Create a new ERP item for the assembly
1. Link an existing ERP item to a sub-part
1. Insert a virtual component from ERP
1. Insert a raw material from ERP
1. [Read here for the BOM Workflow](https://github.com/coolOrangeLabs/powerGateTemplate/wiki/BOM-Workflow)

### Open the ERP integration with Datastandard

1. Create a new IAM file with Inventor
1. Click in the ribbon "Data Standard -> Save"

![image](https://user-images.githubusercontent.com/36075173/82910240-af065900-9f6a-11ea-8100-96310845322b.png)

### Important: Select the right category

First, in the Data Standard dialog you need to select the Vault Category:
+ The ERP integration from coolOrange uses certain iProperties/Vault UDPs
+ The selected category must show on the right side those properties, otherwise, the integration can **NOT** write back other properties then shown on the right side

![image](https://user-images.githubusercontent.com/36075173/84364125-fb3ed380-abcf-11ea-85f0-b158b0ee8755.png)

### Create an ERP item for the assembly

1. Click on "ERP Item..."
1. The "ERP: Create Material" dialog will appear
1. Fill in all the required data
1. Hit the "Create" Button
1. When successfully, [the iProperties are filled](https://github.com/coolOrangeLabs/powerGateTemplate/wiki/ERP-Item-Mapping)
1. Click "OK"

![image](https://user-images.githubusercontent.com/36075173/82911969-ce05ea80-9f6c-11ea-8993-2089886ffa2a.png)

### Place an existing vault part and link to an existing ERP item

1. Place an existing part in Inventor
1. Open the Data Standard dialog
1. Click on "ERP Item..."
1. The "ERP: Create Material" dialog will appear
1. Click on the button "Link..."
1. Click "Search..."
1. Select the needed ERP item
1. Click "OK"
1. The [iProperties are filled](https://github.com/coolOrangeLabs/powerGateTemplate/wiki/ERP-Item-Mapping)

![image](https://user-images.githubusercontent.com/36075173/82912213-19b89400-9f6d-11ea-8799-3fbac6aaffed.png)

### Insert a virtual component from ERP

1. Open/Focus the assembly in Inventor
1. Open the Data Standard dialog
1. Click on "Insert Virtual Component..."
1. Click "Search..."
1. Select the needed ERP item
1. Click "OK"
1. Then, a virtual component is added to the assembly

### Insert a raw material from ERP

1. Open/Focus the part in Inventor
1. Open the Data Standard dialog
1. Click on "Insert Raw Material..."
1. Click "Search..."
1. Select the needed ERP item
1. Click "OK"
1. Then, [the raw materials iProperties are filled from ERP](https://github.com/coolOrangeLabs/powerGateTemplate/wiki/ERP-Item-Mapping)

