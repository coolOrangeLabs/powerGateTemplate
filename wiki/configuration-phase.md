[Menu](../README.md) [Home](./home.md)
## Details

+ Current overview: https://github.com/coolOrangeLabs/powerGateTemplate/issues/124
+ Github project: https://github.com/coolOrangeLabs/powerGateTemplate/projects/2

### What is included?

+ The ERP properties in the graphical user interface are changed:
  + Inventor and Vault "View ERP Item"
  + Inventor and Vault "Create/Update ERP Item"
  + Inventor and Vault "Link ERP Item":
    + Columns in the search results
    + Vault/Inventor Properties used for write back from ERP
+ List values in the graphical user interface:
  + Fix lists are OK
  + List values from ERP are part of business logic phase
+ ERP Item creation: The ERP Number is simple, manual text or generated from ERP automatically
+ Entities: Items, standard Bill of materials and Documents
  + If VendorService required, then we can integrate a fix list during the configuration phase

### What is **not** included?

+ Customer number generation
+ ERP integration, the client will talk to a fake ERP
+ No custom ERP entities like order-BOM, project-BOM, vendor-service and the like
+ No validations
+ NO new PowerShell logic

### Finished

+ coolOrange makes a DEMO presentation
+ New API requirements (new ERP fields) are communicated to the ERP Team

### Next phase

+ [[Integration phase|Integration-Phase]]
