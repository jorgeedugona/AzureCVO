# PoSH Script to deploy Cloud Volumes ONTAP (CVO) with vdbench for performance POCs. 

### Azure_CVO.ps1 Running <br />
<p align="center">
  <img src="https://github.com/jorgeedugona/AzureCVO/blob/master/Images/Image06_1.png" alt="Azure_CVO.ps1 Running"/>
</p>

### Volume Creation<br />
<p align="center">
<img src="https://github.com/jorgeedugona/AzureCVO/blob/master/Images/Image43_1.png" alt="Volume Creation"/>
</p>

### Diagram <br />
<p align="center">
  <img src="https://github.com/jorgeedugona/AzureCVO/blob/master/Images/Image50.PNG" alt="Diagram"/>
</p>


Please find below the prerequisites to run the script:  
• PowerShell 5.0 or 5.1.  
• PAYG Azure Subscription.  
• An Account with https://cloud.netapp.com  

The script can deploy vdbench with NFS for Cloud Volumes Ontap in Azure. After deployment the end user only needs to issue “vdbench -f < workload definitions >” to start the performance test (e.g vdbench -f 00-aff-basic-test-nfs).  
The script includes the following features:  

• Creation of Resource Group in Azure.  
• Creation of the networking requirements to run CVO:  
    • Private Subnet. (aka BackEnd Subnet)  
    • Public Subnet. (aka FrontEnd Subnet)  
    • Security Rules. (RDP, HTTP/S, SSH)  
    • Security Groups.  
    • Virtual Network.  
• Creation of a Windows JumpHost.  
• Creation of Linux Workers to execute vdbench.  
•	Creation of the NFS volumes which are spread between two data aggregates (e.g if 4 Volumes per Linux worker is selected, and 2 Linux workers are deployed, then 8 Volumes will be created).  
•	Mounting of the NFS volumes to the vdbench Workers. /etc/fstab file is also amended to make the NFS mountings permanent.   
•	DNS configuration on the VMs workers, /etc/hosts file is changed in each vdbench worker. DHCP server is not needed.    
•	Creation and mounting of an NFS export where all the configuration files of vdbench are kept.  
•	Import of the vdbench binaries – (the binaries can be downloaded from the Oracle website, an account with Oracle is needed).    
http://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html  
•	Configuration of the vdbench files (e.g for NFS  “aff-host-nfs” “aff-luns-nfs”).  
