[Menu](../README.md) [Home](./home.md)

## Error: Connection to ".../coolOrange/ErpService" could not be established!!!

![image](https://user-images.githubusercontent.com/67685033/95969599-3a479480-0e0f-11eb-921a-d8951454040d.png)
The shown error is thrown if the client cannot connect to the powerGate Server.

### **Possible reasons:** 
* The most obvious reason is, that the **powerGateServe service is not running on your server machine**. Refer to [this](https://www.coolorange.com/wiki/doku.php?id=powergateserver:getting_started) article to find out, how to start/stop the service.
If this does not solve the problem, try to stop the service, as described in the link, and launch the powerGateServer console. It can be found in the when search for it in the windows search bar  (remember to start the application as admin)
* **The URI to the powerGateServer service is not correct**. The URI is displayed in the error message. You can change the URI in the file: "C:\ProgramData\coolOrange\powerGate\Modules\Communication.psm1".
 
  You can open the file with editor and **customize the variables $powerGateServerName and $powerGateServerPort**
* Make sure to follow the **instructions and requirements for your machine to support the powerGate products**.
 
  powerGate (client): [Instructions](https://www.coolorange.com/wiki/doku.php?id=powergate:installation)

  powerGateServer: [Instructions](https://www.coolorange.com/wiki/doku.php?id=powergateserver:installation)

  Pay close attention to the windows permissions:

   * [Add exception](http://lexisnexis.custhelp.com/app/answers/answer_view/a_id/1081611/~/adding-exceptions-to-the-windows-firewall) for powerGate in firewall configuration  
   * user requires permissions to **listen** and **register** HTTP bindings 

* Make sure to have valid licenses on your systems. You can find it out by following the information in this [link](https://www.coolorange.com/wiki/doku.php?id=powergateserver:activation_and_trial_limitations).
* Is the server machine reachable from a client? You can try to [ping](https://en.wikipedia.org/wiki/Ping_(networking_utility)) it from the client.
* The debugging proxy server program "Fiddler" can block your outgoing traffic, if it is installed. The solution is simply, to start and quit fiddler. This resets the interference. Execute these steps on both the client and powerGateServer machine.
* powerGate (client): By default, all the logs are stored in a logfile located in C:\Users\{USER}\AppData\Local\coolOrange\powerGate\Logs\powerGate.log and it contains only Warnings and Errors. Perhaps you can find backups of previous logfiles in this directory.

  powerGateServer: [[Logging| Server Logging]]

