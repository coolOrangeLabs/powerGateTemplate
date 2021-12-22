[Menu](../README.md) [Home](./home.md)
### Advanced powerGate topics

+ If Bom Dialog shows no BOM and structured is on, need to check out the assembly and make a re-check in. Important re-checking all sub-components too!
+ Distribute same BOM Window layout to all users: https://support.coolorange.com/support/solutions/articles/22000231513-how-to-distribute-the-bom-window-layout-to-different-machines
+ ERP side requires us to provide for sure a function to retrieve also just one element (like 1 material) and NOT only a search or “GetAll” functions because this is important for the performance!
+ Inventor integration: Its important that the iProperty we shall write into are configured as bi-directional to a Vault UDP otherwise we cannot write it easily with Datstanard
+ Plugin standard 8080 but can be easly configured in the .addin file
+ If you transfer a special character from Client to Plugin via OData like “&” then the server receives the escaped character “&amp; “, see YT and the associated support ticket: https://youtrack.coolorange.com/youtrack/issue/PGS-291
+ 32-BIT SDKs from ERP are critical to handle in PGS
+ Plugin it can happen following ERROR: “Internal Server Error! The maximum message size quota for incoming messages (65536) has been exceeded. To increase the quota, use the MaxReceivedMessageSize property on the appropriate binding element.”
  + This may help: https://support.coolorange.com/a/tickets/2165
  + There should be a fix by changing the WCF config file of PGS

