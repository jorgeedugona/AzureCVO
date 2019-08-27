Function Create-VM
{
     param(

         [string] 
         [Parameter(Mandatory = $true, Position=1)] $VMLocalAdminUser,
         [string] 
         [Parameter(Mandatory = $true, Position=2)] $ComputerName,
         [string] 
         [Parameter(Mandatory = $true, Position=3)]
         [ValidateSet('Linux','Windows')] $VMType,
         [string] 
         [Parameter(Mandatory = $true, Position=4)] 
         [ValidateSet('Standard_B2s','Standard_B1ms')]$VMSize,
         [string] 
         [Parameter(Mandatory = $true, Position=5)] $ResourceGroupName,
         [string] 
         [Parameter(Mandatory = $true, Position=6)] $Location,
         [string] 
         [Parameter(Mandatory = $true, Position=7)] $VirtualNetworkName,
         [string]
         [Parameter(Mandatory = $false, Position=8)] $PrivateIPAddress,
         [string]
         [Parameter(Mandatory = $false, Position=9)] $ScriptPath,
         [string[]]
         [Parameter(Mandatory = $false, Position=10)] $IPLinuxVMs,
         [int]
         [Parameter(Mandatory = $false, Position=11)] $NumberLinuxVMs
         
         
         )
    
$VMName = $ComputerName
$NICName = $ComputerName+'NIC'
$PublicIPAddressName = $ComputerName+'PublicIPName'
$VMLocalAdminSecurePassword = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);
$VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName
$PublicIPAddress = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic


if($VMType -eq "Windows"){

$PublisherName = 'MicrosoftWindowsServer'
$Offer = 'WindowsServer'
$Skus = '2012-R2-Datacenter'
#$VMType = 'Standard_B2s'
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VirtualNetwork.Subnets[0].Id -PublicIpAddressId $PublicIPAddress.Id


}elseif($VMType -eq "Linux"){

$PublisherName = 'OpenLogic'
$Offer = 'CentOS'
$Skus = '7.5'
#$VMType = 'Standard_B1ms'
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $ComputerName -Credential $Credential
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VirtualNetwork.Subnets[0].Id -PublicIpAddressId $PublicIPAddress.Id -PrivateIpAddress $PrivateIPAddress

}else{

exit

}

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $PublisherName -Offer $Offer -Skus $Skus -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose

if($VMType -eq "Windows"){
#$env:RDPFileLocation = Get-Location
Write-Host "Current Script Path : " $ScriptPath -ForegroundColor Cyan
#Exporting RDP File
$LocalPath = $ScriptPath+'\'+$ComputerName+'.rdp'

Write-Host "Current Script Path : " $LocalPath -ForegroundColor Cyan
Write-Host "Current Computer Name : " $ComputerName -ForegroundColor Cyan
Write-Host "Current Resource Group Name : " $ResourceGroupName -ForegroundColor Cyan

Get-AzRemoteDesktopFile -ResourceGroupName $ResourceGroupName -Name $ComputerName -LocalPath $LocalPath


}elseif($VMType -eq "Linux"){

# Configure SSH Keys

$VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
$Path = '/home'+$VMLocalAdminUser+'/.ssh/authorized_keys'
Add-AzVMSshPublicKey -VM $VM -KeyData $sshPublicKey -Path $Path

}else{

exit

}

}

Function Create-Networks 
{

param(

         [string] 
         [Parameter(Mandatory = $true, Position=1)] $ResourceGroupName,
         [string] 
         [Parameter(Mandatory = $true, Position=2)] $Location,
         [string] 
         [Parameter(Mandatory = $true, Position=3)] $VirtualNetWorkName,
         [string] 
         [Parameter(Mandatory = $true, Position=4)] $SubnetAddressPrefix,
         [string] 
         [Parameter(Mandatory = $true, Position=5)] $FrontEndSubnetAddressPrefix,
         [string] 
         [Parameter(Mandatory = $true, Position=6)] $BackEndSubnetAddressPrefix
         
         )

Write-host "Creating a Resource Group $ResourceGroupName in $Location.... " -ForegroundColor Cyan
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

#Create Rule to allow RDP inbound traffic 

Write-host "Creating a Security Rule for RDP.... " -ForegroundColor Cyan
$RDPRULE = New-AzNetworkSecurityRuleConfig -Name RDP-Rule -Description "Allow RDP" `
                                           -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
                                           -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 3389
Write-host "Creating a Security Rule for HTTP.... " -ForegroundColor Cyan
$HTTPRULE = New-AzNetworkSecurityRuleConfig -Name HTTP-Rule -Description "Allow HTTP" `
                                           -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 `
                                           -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 80
Write-host "Creating a Security Rule for SSH.... " -ForegroundColor Cyan
$SSHRULE = New-AzNetworkSecurityRuleConfig -Name SSH-Rule -Description "Allow SSH" `
                                           -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 `
                                           -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 22
Write-host "Creating a Security Rule for HTTPs.... " -ForegroundColor Cyan
$HTTPSRULE = New-AzNetworkSecurityRuleConfig -Name HTTPS-Rule -Description "Allow HTTPS" `
                                           -Access Allow -Protocol Tcp -Direction Inbound -Priority 103 `
                                           -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * `
                                           -DestinationPortRange 443

Write-host "Creating a Network Security Group.... " -ForegroundColor Cyan
#Create FrontEnd Security Group
$FrontEndNetworkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
                                                           -Location $Location `
                                                           -Name "NSG-FrontEnd" `
                                                           -SecurityRules $RDPRULE,$HTTPRULE,$HTTPSRULE,$SSHRULE `
                                                           -WarningAction SilentlyContinue

Write-host "Creating a Network Security Group NSG-BackEnd.... " -ForegroundColor Cyan
#Create BackEnd Security Group
$BackEndNetworkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
                                                          -Location $Location `
                                                          -Name "NSG-BackEnd" `
                                                          -WarningAction SilentlyContinue

Write-host "Creating a Network Subnet FrontEndSubnet.... " -ForegroundColor Cyan
#Create a Front End Subnet
$FrontendSubnet = New-AzVirtualNetworkSubnetConfig -Name FrontEndSubnet `
                                                   -AddressPrefix $FrontEndSubnetAddressPrefix `
                                                   -NetworkSecurityGroup $FrontEndNetworkSecurityGroup -WarningAction SilentlyContinue

Write-host "Creating a Network Subnet BackEndSubnet.... " -ForegroundColor Cyan
#Create a Back End Subnet
$BackendSubnet = New-AzVirtualNetworkSubnetConfig -Name BackEndSubnet `
                                                  -AddressPrefix $BackEndSubnetAddressPrefix `
                                                  -NetworkSecurityGroup $BackEndNetworkSecurityGroup -WarningAction SilentlyContinue

Write-host "Creating a Virtual Network with the following configuration: `
            Virtual Network: $VirtualNetWorkName ` 
            Location: $Location`
            Subnet: $SubnetAddressPrefix`
            FrontEnd Subnet: $FrontEndSubnetAddressPrefix`
            BackEnd Subnet: $BackEndSubnetAddressPrefix" -ForegroundColor Cyan

#Create Virtual Network
New-AzVirtualNetwork -Name $VirtualNetWorkName -ResourceGroupName $ResourceGroupName `
                     -Location $Location -AddressPrefix $SubnetAddressPrefix `
                     -Subnet $FrontendSubnet,$BackendSubnet -WarningAction SilentlyContinue
#Get Virtual Network config
$VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetWorkName -ResourceGroupName $ResourceGroupName

}

Function Deployment
{

param(

         [string] 
         [Parameter(Mandatory = $true, Position=1)] $ONTAPClusterIP,
         [int]
         [Parameter(Mandatory = $true, Position=2)] $NumberVolumesPerVM,
         [string]
         [Parameter(Mandatory = $true, Position=3)] $VolumeSize,
         [string]
         [Parameter(Mandatory = $true, Position=4)] $FileSize,
         [string[]]
         [Parameter(Mandatory = $true, Position=5)] $IPLinuxVMs,
         [int] 
         [Parameter(Mandatory = $true, Position=6)] $NumberLinuxVMs,
         [string]
         [Parameter(Mandatory = $true, Position=7)] $PathVdbenchBinaries,
         [string]
         [Parameter(Mandatory = $true, Position=8)] $PathAFFToolkit


         )

# Importing Module Posh-SSH

$PSSHHVersion = Get-InstalledModule -Name Posh-SSH -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

if($PSSHHVersion){
    Write-Host "Current version of POSH-SSH is " $PSSHHVersion.Version "..." -ForegroundColor Cyan
    }else{
            
            do{
                Write-Host "Current version $PSSHHVersion of POSH-SSH is not supported or POSH-SSH is not even installed...." -ForegroundColor Cyan
                $Install = Read-Host "Do you want to install the lastest version? Yes/No "
                if($Install -eq "Yes"){
    
                     Install-Module -Name Posh-SSH -Scope CurrentUser -Force -RequiredVersion 1.7.7 -Confirm:$false
                     #Import Posh-SSH Module....
                     Import-Module -Name Posh-SSH -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

                 }elseif($Install -eq "No"){
            
                    Write-Host "POSH-SSH was not installed.... " -ForegroundColor Red
                    [void][System.Console]::ReadKey($true)
                    Exit

                 }else{
            
                    Write-Host "Incorrect option selected, please enter Yes or No..."  -ForegroundColor Red
            
                 }

             }While(!(($Install -like "No") -or ($Install -like "Yes") ))

        }

#Removing previous Trusted SSH certificates... 
Get-SSHTrustedHost | Remove-SSHTrustedHost -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

#Import ONTAP Module
Import-Module -Name DataONTAP

$ConnectionNetApp = Connect-NetApp $global:CurrentNcController -IPCluster $ONTAPClusterIP

if($ConnectionNetApp -eq "Stop"){
    
    Write-Error "We failed to connected to NetApp Controller $global:CurrentNcController"
    Return "FailConnection"
    Break
}

# Get ONTAP Information

# Data LIF
$DataNFSLIF = Get-NcNetInterface | ?{ $_.DataProtocols -eq 'nfs'}
$DataNFSLIFAddress = $DataNFSLIF[0].Address

# Cluster Name
$ONTAPCluster = Get-NcCluster 
$ONTAPClusterName = $ONTAPCluster.ClusterName

# SVM NAME
$SVMName = 'svm_'+$ONTAPClusterName
$SVM = Get-NcVserver -Name $SVMName

# Configuring Local DNS on VMs
Config-DNSVM -IPLinuxVMs $IPLinuxVMs -NumberLinuxVMs $NumberLinuxVMs

# Getting information Data Aggregate

$DataAggr = Get-NcAggr | ?{ $_.AggrRaidAttributes.HasLocalRoot -eq $false }
$DataAggrName = $DataAggr.Name

# Creating SharedVols VolS......
Shared-Files -IPLinuxVMs $IPLinuxVMs -ONTAPClusterName $ONTAPClusterName `
             -DataAggrName $DataAggrName -SVMName $SVMName `
             -DataNFSLIFAddress $DataNFSLIFAddress -PathVdbenchBinaries $PathVdbenchBinaries `
             -NumberLinuxVMs $NumberLinuxVMs -PathAFFToolkit $PathAFFToolkit

# Creating NFS VolS......"

do{
$DataAggr = Get-NcAggr | ?{ $_.AggrRaidAttributes.HasLocalRoot -eq $false }
$DataAggrName = $DataAggr.Name
$DataAggrNameLenght = $DataAggrName.Length

if($DataAggrNameLenght -eq 2){

Write-Host "Two Data Aggregates have been selected for this deployment..." -ForegroundColor Cyan

}else{

Write-Host "Please Create ONLY Two Aggregates for this deployment..." -ForegroundColor Red
Write-Host "Aggregates Configured: " $DataAggrName -ForegroundColor Red
Read-Host "After creating the new aggregate, Enter any key to continue ... "

}

}while($DataAggrNameLenght -ne 2)



if($DataAggrName.Length -eq 2){


Create-NFSVolumes -IPLinuxVMs $IPLinuxVMs -ONTAPClusterName $ONTAPClusterName `
                  -DataAggrName $DataAggrName -SVMName $SVMName `
                  -DataNFSLIFAddress $DataNFSLIFAddress -NumberVolumesPerVM $NumberVolumesPerVM `
                  -VolumeSize $VolumeSize -NumberLinuxVMs $NumberLinuxVMs                  

Mounting-NFSVolumes -IPLinuxVMs $IPLinuxVMs -SVMName $SVMName `
                    -DataNFSLIFAddress $DataNFSLIFAddress -DataAggrName $DataAggrName `
                    -NumberLinuxVMs $NumberLinuxVMs
sleep -s 10

Create-Files -IPLinuxVMs $IPLinuxVMs -SVMName $SVMName `
             -FileSize $FileSize -NumberLinuxVMs $NumberLinuxVMs


}else{

Write-Host "Deployment could not be completed, ONLY Two Aggregates are needed.... " -ForegroundColor Red
Write-Host "Volumes could not be created.... " -ForegroundColor Red

}
<#
# Write-Log "Changing Config Files NFS VolS......" -ForegroundColor Cyan

# NFS - vdbench config files.
Config-VMNFSFiles2

Write-host "Creating vdbench Files......" -ForegroundColor Cyan

vdbench-Files2($Protocol)

#>

}

Function Connect-NetApp 
{
     [CmdletBinding()]
     Param(

     [parameter(Mandatory=$false, 
     HelpMessage="NetApp Controller is connected...",
     ValueFromPipelineByPropertyName=$true)]
     [NetApp.Ontapi.Filer.C.NcController]$global:CurrentNcController,

     [parameter(Mandatory=$True)]
     [string]$IPCluster

     )

   if ($global:CurrentNcController){
                    Write-host "You are currently connected to " -ForegroundColor Cyan
                    $global:CurrentNcController
                  } else {
                            Do {
                                # Loop until we get a valid userid/password and can connect, or some other kind of error occurs
                                Write-Host "Connecting to NetApp Cluster .......  " -ForegroundColor Cyan
                                $Cluster = Connect-NcController $IPCluster -credential (Get-NcCredential) -WarningAction silentlyContinue -ErrorAction SilentlyContinue -ErrorVariable Err
                                         
                                If ($Err.Count -gt 0) {
                                                # Some kind of error, figure out if its a bad password
                                                If (($Err.Exception.GetType().Name -eq "NaConnectionException") -or ($Err.Exception.GetType().Name -eq "NaAuthException")) {
                                                    Write-Host "Incorrect user name or password, please try again... " -ForegroundColor Red
                                                    
                                                    }Else{
                                                     # Something else went wrong, just display the text and exit
                                                     $Error = $Err.Exception
                                                     Write-Host $Error -ForegroundColor Red
                                                     return "Stop"
                                                     break 
                                                   }
                                        }Else{
                                        Write-Host "User name and password are valid.." -ForegroundColor Cyan
                                        }
                                }
                          Until ($Err.Count -eq 0)
                        }


}

Function Config-DNSVM
{

param(

         [string[]] 
         [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
         [int] 
         [Parameter(Mandatory = $true, Position=2)] $NumberLinuxVMs
         
         )

# Adding Hosts Entries to each Linux VM
$I = 1

While ($I -le $NumberLinuxVMs){

$item = $IPLinuxVMs[$I]
                    
 if (Test-Connection -ComputerName $item -Quiet) {
   
   # Credentials must be here, otherwise $secpasswd will be deleted by Invoke-SSHStreamExpectSecureAction
   # https://github.com/darkoperator/Posh-SSH/issues/160

   $secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
   $mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)

   $SSHSesionVM = New-SSHSession -ComputerName $item -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
   $Stream = $SSHSesionVM.Session.CreateShellStream($item, 0, 0, 0, 0, 1000)

       if($SSHSesionVM){
            #Write-Host "Allowing Root SSH in $item......" -ForegroundColor Cyan
            $WaitingStream = "[sudo] password for netappcvo:"
            $Command = "sudo su -"
            Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null
            Write-Host "Adding DNS config in $item......" -ForegroundColor Cyan
            Adding-DNS -IPLinuxVMs $IPLinuxVMs -NumberLinuxVMs $NumberLinuxVMs -Stream $Stream           
            Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null
   
        }else{
                          
        Write-Host "SSH Connection could not be established with $ComputerName, IP Address $item" -ForegroundColor Cyan
                                                   
        }                                                                    
    }
$I++
}


}
 
Function Adding-DNS
{

param(

         [string[]] 
         [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
         [int] 
         [Parameter(Mandatory = $true, Position=2)] $NumberLinuxVMs,
         [Renci.SshNet.ShellStream]
         [Parameter(Mandatory = $true, Position=3)] $Stream

     )

# Adding Hosts Entries to each Linux VM
$I = 1

While ($I -le $NumberLinuxVMs){

    $ComputerName = "LinuxVM"+$I
    $IP = $IPLinuxVMs[$I]
    $DNSLINE = "echo '$IP $ComputerName' >> /etc/hosts"
    $Stream.WriteLine($DNSLINE)
    sleep -s 2
    $I++
 
}

}

Function Shared-Files
{

param(
         [string[]] 
         [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
         [string] 
         [Parameter(Mandatory = $true, Position=2)] $ONTAPClusterName,
         [string[]] 
         [Parameter(Mandatory = $true, Position=3)] $DataAggrName,
         [string] 
         [Parameter(Mandatory = $true, Position=4)] $SVMName,
         [string]
         [Parameter(Mandatory = $true, Position=5)] $DataNFSLIFAddress,
         [string]
         [Parameter(Mandatory = $true, Position=6)] $PathVdbenchBinaries,
         [string]
         [Parameter(Mandatory = $true, Position=7)] $PathAFFToolkit,
         [int]
         [Parameter(Mandatory = $true, Position=8)] $NumberLinuxVMs                                          

     )

$secpasswd = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("netappcvo", $secpasswd)
$DataAggr = $DataAggrName[0]
$NFSvol  = "SharedFiles"
$JunctionPath = "/"+$NFSvol
$SVMRootVolumeName = 'svm_'+$ONTAPClusterName+'_root'
        
#Export Policy for the Share NFS Vol. 
                
New-NcExportPolicy -Name $SVMName -VserverContext $SVMName -ErrorAction SilentlyContinue | Out-Null

#This is to change the policy on the root volume so that we can map the SharedFiles volume on the VMs
$attr = Get-NcVol -Template
Initialize-NcObjectProperty -Object $attr -Name VolumeExportAttributes | Out-Null
$attr.VolumeExportAttributes.Policy = $SVMName
$query = Get-NcVol -Template
$query.Name = $SVMRootVolumeName
$query.Vserver = $SVMName
Update-NcVol -Query $query -Attributes $attr -FlexGroupVolume:$false | Out-Null

#Create Volume to store all the config files of vdbench

New-NcVol -Name $NFSvol -Aggregate $DataAggrName[0] -Size 5GB `
          -JunctionPath $JunctionPath -ExportPolicy $SVMName `
          -SecurityStyle "Unix" -UnixPermissions "0777" `
          -State "online" -VserverContext $SVMName -ErrorAction SilentlyContinue | Out-Null

####################################################################################
##################### Configuring all Linux VMs with vdbench #######################
####################################################################################
$I = 1

While ($I -le $NumberLinuxVMs){
 $ComputerName = "LinuxVM"+$I
 $IP = $IPLinuxVMs[$I]     
 New-NcExportRule -Policy $SVMName -ClientMatch $IP -ReadOnlySecurityFlavor any `
                  -ReadWriteSecurityFlavor any -VserverContext $SVMName -SuperUserSecurityFlavor any | Out-Null
$I++
}

# Getting the vdbench Binaries

 if (!(Test-Path $PathVdbenchBinaries)) {

        Write-host "$PathVdbenchBinaries absent in the Path.... " -ForegroundColor Cyan
        Write-host "Please select the path for vdbench binaries.... " -ForegroundColor Cyan
        $Localfile_Array = Get-FileName $PSScriptRoot "zip"
        # $Localfile_Array is an array
        $PathVdbenchBinaries = $Localfile_Array[0]
                
}

$I = 1

While ($I -le $NumberLinuxVMs){
    
    $ComputerName = "LinuxVM"+$I
    $IPVMvalue = $IPLinuxVMs[$I] 


    if (Test-Connection -ComputerName $IPVMvalue -Quiet) {

            $secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)
            Write-host "Importing vdbench files in $IPVMvalue......" -ForegroundColor Cyan

            $SSHSesionVM = New-SSHSession -ComputerName $IPVMvalue -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
            $Stream = $SSHSesionVM.Session.CreateShellStream($IPVMvalue, 0, 0, 0, 0, 1000)

            if($SSHSesionVM){
                #Write-Host "Allowing Root SSH in $IPVMvalue......" -ForegroundColor Cyan
                $WaitingStream = "[sudo] password for netappcvo:"
                $Command = "sudo su -"
                Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null
                #Export Policies and Rules 
                New-NcExportPolicy -Name $ComputerName -VserverContext $SVMName -ErrorAction SilentlyContinue | Out-Null
                New-NcExportRule -Policy $ComputerName -ClientMatch $IPVMvalue `
                                    -ReadOnlySecurityFlavor any -ReadWriteSecurityFlavor any `
                                    -VserverContext "$SVMName" -SuperUserSecurityFlavor any `
                                    -ErrorAction SilentlyContinue | Out-Null
    
                #New SFTP Session
                New-SFTPSession -ComputerName $IPVMvalue -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120 | Out-Null
                #Upload the files to Centos VM....
                Write-host "Importing and Extracting vdbench binaries to $IPVMvalue......" -ForegroundColor Cyan                       
                Set-SFTPFile -SessionId 0 -LocalFile $PathVdbenchBinaries -RemotePath /home/netappcvo/ | Out-Null
                # Disconnect SFTP session
                Remove-SFTPSession -SessionId 0 | Out-Null

                #1. install NFS Utils
                Write-host "Installing NFS, RSH, Java 1.8 packages in $IPVMvalue....." -ForegroundColor Cyan
                $installing = "yum install nfs-utils -y" 
                $Stream.WriteLine($installing)
                sleep -s 15
                $installing = "yum install rsh rsh-server -y"
                $Stream.WriteLine($installing)
                sleep -s 15
                $installing = "yum install java-1.8.0-openjdk -y"
                $Stream.WriteLine($installing)
                sleep -s 15
                #2. Adding rsh to securetty
                $RSH = "rsh"
                $RSH = "echo '$RSH' >> /etc/securetty"
                $Stream.WriteLine($RSH)
                sleep -s 2
                #3. Adding rlogin to securetty
                $RSH = "rlogin"
                $RSH = "echo '$RSH' >> /etc/securetty"
                $Stream.WriteLine($RSH)
                sleep -s 2
                #4. Disable SELINUX
                $SELINUX = "s/SELINUX=enforcing/SELINUX=disable/g"
                $SELINUX = "sed -i '$SELINUX' /etc/selinux/config"
                $Stream.WriteLine($SELINUX)
                sleep -s 2
                #5. Disable Firewall
                $StopDisableFirewall = "systemctl stop firewalld ; systemctl disable firewalld"
                $Stream.WriteLine($StopDisableFirewall)
                sleep -s 2
                #6. Restart rsh socket
                $systemctl1 = "systemctl restart rsh.socket rlogin.socket rexec.socket"
                $Stream.WriteLine($systemctl1)
                sleep -s 2
                #7. Enable RSH. 
                $systemctl2 = "systemctl enable rsh.socket rlogin.socket rexec.socket"
                $Stream.WriteLine($systemctl2)
                sleep -s 2
                #8. Creating .rhost file Adding IP Address to .rhosts file
                $RHostFile = "touch /root/.rhosts"
                $Stream.WriteLine($RHostFile)
                sleep -s 2

                $J = 1
                While ($J -le $NumberLinuxVMs){
         
                        $IPVMvalue1 = $IPLinuxVMs[$J]

                        $rhostsfile = "echo '$IPVMvalue1 root' >> /root/.rhosts"
                        $Stream.WriteLine($rhostsfile)
                        sleep -s 2
                        #Invoke-SSHCommand -Index 0 -Command $rhostsfile | Out-Null
                        $J++
                }

                #8. Copying file to /root/
                $CopyFile = "cp -r /home/netappcvo/vdbench50407.zip /root/"
                $Stream.WriteLine($CopyFile)
                sleep -s 3
                #2. Creating the Folders Command
                #Invoke-SSHCommand -Index 0 -Command $Folder | Out-Null
                $Folder = "mkdir /root/$NFSvol"
                $Stream.WriteLine($Folder)
                sleep -s 3
                #Invoke-SSHCommand -Index 0 -Command $Folder1 | Out-Null
                $Folder1 = "mkdir /root/vdbench50407"
                $Stream.WriteLine($Folder1)
                sleep -s 3
                #3. adding the Permanent NFS mounting point
                #Invoke-SSHCommand -Index 0 -Command $PermanentMount | Out-Null
                $PermanentMount = "echo '$DataNFSLIFAddress`:/$NFSvol /root/$NFSvol nfs defaults        0 0' >> /etc/fstab"
                $Stream.WriteLine($PermanentMount)
                sleep -s 3
                #4. Mounting the NFS vol
                #Invoke-SSHCommand -Index 0 -Command $Mount | Out-Null
                $Mount = "mount -t nfs $DataNFSLIFAddress`:/$NFSvol /root/$NFSvol"
                $Stream.WriteLine($Mount)
                sleep -s 3
                #5. Extract zip file
                #Invoke-SSHCommand -Index 0 -Command $UnzipFile | Out-Null
                #Extract zip file....
                $UnzipFile = "unzip /root/vdbench50407.zip -d /root/vdbench50407"
                $Stream.WriteLine($UnzipFile)
                sleep -s 3
                #6. Making vdbench executable.
                #Invoke-SSHCommand -Index 0 -Command $chmodcommand | Out-Null
                #making vdbench executable
                $chmodCommand = "chmod +x /root/vdbench50407/vdbench"
                $Stream.WriteLine($chmodcommand)
                sleep -s 3
                #7. Adding vdbench folder to $PATH
                #Invoke-SSHCommand -Index 0 -Command $exportPATH | Out-Null
                $exportPATH = "echo 'export PATH=/root/vdbench50407:`$PATH' >>~/.bash_profile "
                $Stream.WriteLine($exportPATH)
                sleep -s 3
                Write-Host "Rebooting " $ComputerName -ForegroundColor Cyan
                $reboot = "reboot"
                $Stream.WriteLine($reboot)
                sleep -s 2

            Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null
        }else{
        
            Write-Host "SSH Connection could not be established with $ComputerName, IP Address $IPVMvalue" -ForegroundColor Cyan
        
            }

}

$I++
       
}
        

#Copy config Files to the Shared Folder

# Getting the vdbench Binaries

 if (!(Test-Path $PathAFFToolkit)) {

    Write-Host "$PathAFFToolkit absent in the Path.... " -ForegroundColor Cyan
    Write-Host "Please select the path for vdbench binaries.... " -ForegroundColor Cyan
    $Localfile_Array = Get-FileName $PSScriptRoot "zip"
    # $Localfile_Array is an array
    $PathAFFToolkit = $Localfile_Array[0]
                
}

$I = 1

While ($I -le $NumberLinuxVMs){
    #Checking Connectivity...
    $ComputerName = "LinuxVM"+$I
    $IP = $IPLinuxVMs[$I] 
    Write-Host "Testing Connectivity in $ComputerName....." -ForegroundColor Cyan
    if($NumberLinuxVMs -le 2){
    Start-Sleep 60
    }

 while(!(Test-Connection -ComputerName $IP -Count 2  -ErrorAction SilentlyContinue )){
    Write-Host "Failed Connectivity test in $ComputerName, Trying again....." -ForegroundColor Cyan
    Start-Sleep 15

    }
$I++

}



$secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)

#New SFTP Session
New-SFTPSession -ComputerName $IPLinuxVMs[1] -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120 | Out-Null
#Upload the files to Centos VM....
Write-host "Importing and Extracting ONTAP Toolkit to "$IPLinuxVMs[1]"......" -ForegroundColor Cyan                       
Set-SFTPFile -SessionId 0 -LocalFile $PathAFFToolkit -RemotePath '/home/netappcvo/' | Out-Null
# Disconnect SFTP session
Remove-SFTPSession -SessionId 0 | Out-Null

$SSHSesionVM = New-SSHSession -ComputerName $IPLinuxVMs[1] -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
$Stream = $SSHSesionVM.Session.CreateShellStream($IPLinuxVMs[1], 0, 0, 0, 0, 1000)

#Write-Host "Allowing Root SSH in " $IPLinuxVMs[1] "......" -ForegroundColor Cyan
$WaitingStream = "[sudo] password for netappcvo:"
$Command = "sudo su -"
Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null

Write-host "Importing and Extracting POC-Toolkit to $Linux01 ......" -ForegroundColor Cyan
#Extract zip file....
$UnzipFilePOC = "unzip /home/netappcvo/POC-Toolkit-1.5.zip -d /root/$NFSVol"
$Stream.WriteLine($UnzipFilePOC)
sleep -s 2
Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null      

}

Function Get-FileName($initialDirectory, [string]$ExtentionFile)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Select a $ExtentionFile file"
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "$ExtentionFile (*.$ExtentionFile)| *.$ExtentionFile"
    $OpenFileDialog.ShowDialog() | Out-Null
    #$show = $OpenFileDialog.ShowDialog()
    #This returns the Path of the config File to be imported 
    $OpenFileDialog.FileName
    
    $ConfigFile = $OpenFileDialog.FileName    
    #Extracting the name of the configuration file path
    $ConfigFileName = $ConfigFile.Split('\')[-1].split('.')[0]
    #Adding the .log extention
    $LogFileName = $ConfigFileName+'_LogFile.log'
    #This Returns the Log File Name 
    $LogFileName
    
    #This returns [Null]
    $LogFilePath = ""
    $LogFilePath
    

}
 
Function Create-NFSVolumes
{

param(
         [string[]] 
         [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
         [string] 
         [Parameter(Mandatory = $true, Position=2)] $ONTAPClusterName,
         [string[]] 
         [Parameter(Mandatory = $true, Position=3)] $DataAggrName,
         [string] 
         [Parameter(Mandatory = $true, Position=4)] $SVMName,
         [string]
         [Parameter(Mandatory = $true, Position=5)] $DataNFSLIFAddress,
         [int]
         [Parameter(Mandatory = $true, Position=6)] $NumberVolumesPerVM,
         [string]
         [Parameter(Mandatory = $true, Position=7)] $VolumeSize,
         [int] 
         [Parameter(Mandatory = $true, Position=8)] $NumberLinuxVMs                                          

     )

$VMCount = $NumberLinuxVMs
$numberVOLS = $VMCount*$NumberVolumesPerVM

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                   Creation of NFS Volumes                " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " " -ForegroundColor Cyan
Write-Host "$NumberVolumesPerVM NFS Volumes per VM will be created, and the distribution " -ForegroundColor Cyan
Write-Host "will be acrossed TWO Data Aggregates " -ForegroundColor Cyan
Write-Host "Number of vdbench VMs " $VMCount -ForegroundColor Cyan
Write-Host "Total number of NFS Vols: " $numberVOLS -ForegroundColor Cyan
            
            do{
            $Continue_NFSVOLS = read-host "Please press 'c' to continue, type 'exit' to return to the main menu... "
            if($Continue_NFSVOLS -eq "c"){
                       #Big for loop for each Host
                       # Adding Hosts Entries to each Linux VM
                       $I = 1
                       While ($I -le $NumberLinuxVMs){
                       $ComputerName = "LinuxVM"+$I
                       $IP = $IPLinuxVMs[$I]
                       #Loop for Each Aggregate
                                for($aggregate = 0 ; $aggregate -lt $DataAggrName.Length ; $aggregate++){
        
                                                for($Volume = 1 ; $Volume -le $NumberVolumesPerVM ; $Volume++){
                                                 #Loop for aggregate
                                                            if($Volume -gt $NumberVolumesPerVM/2){
                                                                     if($aggregate -eq ($DataAggrName.Length-1) ){
                                                                     
                                                                     }else{
                                                                      $aggregate++
                                                                     }
                                                              }
                                                 $VolumeName = $ComputerName+"_NFS_VD_vol_"+$Volume
                                                 $JunctionPath = "/"+$VolumeName
                                                 $AggrName = $DataAggrName[$aggregate]
                                                 Write-Host "Creating Volume $VolumeName in aggregate $AggrName -Size $VolumeSize" -ForegroundColor Cyan
                                                 New-NcVol -Name $VolumeName -Aggregate $DataAggrName[$aggregate] -Size $VolumeSize `
                                                           -JunctionPath $JunctionPath -ExportPolicy $ComputerName -SecurityStyle "Unix" `
                                                           -UnixPermissions "0777" -State "online" -VserverContext $SVMName -SnapshotPolicy 'none' `
                                                           -SnapshotReserve 0 `
                                                           -ErrorVariable +Err -ErrorAction SilentlyContinue | Out-Null
                                                  
                                                 }
                                     }
                        $I++
                        }
             }elseif($Continue_NFSVOLS -eq "exit"){
                 Write-Host "You can delete what was deployed up to this point by choosing " -ForegroundColor Red
                 Write-Host "the Delete option from the main Menu and selecting the config file. " -ForegroundColor Red
                 Return "CancelNFSVols"
                 Break
             }else{
                Write-Host "Incorrect option selected, please enter 'c' to continue or 'exit' to return to the main menu..." -ForegroundColor Yellow
             }
             }While(!(($Continue_NFSVOLS -eq "c") -or ($Continue_NFSVOLS -eq "exit") ))
}

Function Mounting-NFSVolumes
{
 
param(
         [string[]] 
         [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
         [string] 
         [Parameter(Mandatory = $true, Position=2)] $SVMName,
         [string]
         [Parameter(Mandatory = $true, Position=3)] $DataNFSLIFAddress,
         [string[]] 
         [Parameter(Mandatory = $true, Position=4)] $DataAggrName,
         [int] 
         [Parameter(Mandatory = $true, Position=5)] $NumberLinuxVMs                                          

     )

 #Creating the Folders at /mnt/vdbenchTest*


$I = 1

While ($I -le $NumberLinuxVMs){
    
    $ComputerName = "LinuxVM"+$I
    $IPVMvalue = $IPLinuxVMs[$I] 
    $NFSVolumes1 = Get-NcVol -Vserver $SVMName -Name "$ComputerName*"

    if (Test-Connection -ComputerName $IPVMvalue -Quiet) {

            $secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)

            $SSHSesionVM = New-SSHSession -ComputerName $IPVMvalue -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
            $Stream = $SSHSesionVM.Session.CreateShellStream($IPVMvalue, 0, 0, 0, 0, 1000)

        if($SSHSesionVM){
            
            #Write-Host "Allowing Root SSH in $IPVMvalue......" -ForegroundColor Cyan
            $WaitingStream = "[sudo] password for netappcvo:"
            $Command = "sudo su -"
            Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null
        
             foreach($NFSvol in $NFSVolumes1.Name){
 
                    Write-Host "Mounting NFS $NFSvol Volume in $ComputerName IP $IPVMvalue ......" -ForegroundColor Cyan
                    $PermanentMount = "echo '$DataNFSLIFAddress`:/$NFSvol /mnt/$NFSvol nfs defaults        0 0' >> /etc/fstab"
                    $Mount = "mount -t nfs $DataNFSLIFAddress`:/$NFSvol /mnt/$NFSvol"
                    $Folder = "mkdir /mnt/$NFSvol"
                    #1. Creating the Folders Command
                    $Stream.WriteLine($Folder)
                    sleep -s 3
                    #2. adding the Permanent NFS mounting point
                    $Stream.WriteLine($PermanentMount)
                    sleep -s 3
                    #3. Mounting the NFS vol
                    $Stream.WriteLine($Mount)
                    sleep -s 3
                }
             Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null

        }else{
                          
            Write-Host "SSH Connection could not be established with $ComputerName, IP Address $IPVMvalue " -ForegroundColor Cyan
                                                   
        }
}

$I++



}
      
 }

Function Create-Files
{

param(

    [string[]] 
    [Parameter(Mandatory = $true, Position=1)] $IPLinuxVMs,
    [string] 
    [Parameter(Mandatory = $true, Position=2)] $SVMName,
    [string]
    [Parameter(Mandatory = $true, Position=3)] $FileSize,
    [int] 
    [Parameter(Mandatory = $true, Position=4)] $NumberLinuxVMs                                          
)

$J = 1
$IPVMvalue = $IPLinuxVMs[$J]

if (Test-Connection -ComputerName $IPVMvalue -Quiet) {

#Open a session in one of the VM where Sharefolder has ben mounted
$secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)

$SSHSesionVM = New-SSHSession -ComputerName $IPVMvalue -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
$Stream = $SSHSesionVM.Session.CreateShellStream($IPVMvalue, 0, 0, 0, 0, 1000)

    if($SSHSesionVM){

        #Write-Host "Allowing Root SSH in " $IPVMvalue "......" -ForegroundColor Cyan
        $WaitingStream = "[sudo] password for netappcvo:"
        $Command = "sudo su -"
        Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null

        $Protocol = "NFS"   
        
        if($Protocol -eq "NFS"){
  
            # Modify Hostfile at /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-hosts-nfs.
            # hd=slave01,system=centos701,user=root
            # Delete the last 6 lines of the File
            $DeleteLine0 = "sed -i '37,42d' /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-hosts-nfs"
            $Stream.WriteLine($DeleteLine0)
            sleep -s 3
        
            # Delete all lines at /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfsaff-luns-nfs.
            $DeleteLine1 = "sed -i '15,45d' /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-luns-nfs"
            $Stream.WriteLine($DeleteLine1)
            sleep -s 3

            #Add the size of the file Line.
            $sizeFileLine = "echo 'sd=default,size=$FileSize,count=(1,5)' >> /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-luns-nfs"
            $Stream.WriteLine($sizeFileLine)
            sleep -s 3
            Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null
   
        
        }elseif($Protocol -eq "iSCSI"){
        
            # Modify Hostfile at /root/SharedFiles/vdbench/vmdk/aff-hosts-vmdk.
            # hd=slave01,system=centos701,user=root
            # Delete the last 6 lines of the File
            $DeleteLine0 = "sed -i '37,60d' /root/SharedFiles/vdbench/vmdk/aff-hosts-vmdk"    
            Invoke-SSHCommand -Index 0 -Command $DeleteLine0 | Out-Null
        
            # Delete all lines at /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk.
            $DeleteLine1 = "sed -i '12,45d' /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk"    
            Invoke-SSHCommand -Index 0 -Command $DeleteLine1 | Out-Null

            #size of the file Line is not needed for iSCSI/vmdks
            #$SizeFile = $Global:config.Other.FileSize
            #$sizeFileLine = "echo 'sd=default,size=$SizeFile,count=(1,5)' >> /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk"
            #Invoke-SSHCommand -Index 0 -Command $sizeFileLine | Out-Null
        
            Remove-SSHSession -SessionId 0 | Out-Null
            $SlaveNumber = 0
            }

}else{
                          
        Write-Host "SSH Connection could not be established with IP Address: " $IPVMvalue] -ForegroundColor Cyan
                                                   
    }

}

$SlaveNumber = 0
$I = 1

While ($I -le $NumberLinuxVMs){
    
    $ComputerName = "LinuxVM"+$I
    $IPVMvalue = $IPLinuxVMs[$I] 


    if (Test-Connection -ComputerName $IPVMvalue -Quiet) {

            $secpasswd = ConvertTo-SecureString 'Netapp1!' -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ('netappcvo', $secpasswd)
            Write-host "Creating vdbench Files in $IPVMvalue......" -ForegroundColor Cyan

            $SSHSesionVM = New-SSHSession -ComputerName $IPVMvalue -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120
            $Stream = $SSHSesionVM.Session.CreateShellStream($IPVMvalue, 0, 0, 0, 0, 1000)

        if($SSHSesionVM){
 
            #Write-Host "Allowing Root SSH in $ComputerName......" -ForegroundColor Cyan
            $WaitingStream = "[sudo] password for netappcvo:"
            $Command = "sudo su -"
            Invoke-SSHStreamExpectSecureAction -ShellStream $Stream -Command $Command -ExpectString $WaitingStream -SecureAction $secpasswd | Out-Null
         
        $Protocol = "NFS"
                
        if($Protocol -eq "NFS"){
                
            #FOR is each SlaveXX
            #Adding the new Lines at /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfsaff-hosts-nfs
            $SlaveLine = "hd=slave0$SlaveNumber,system=$ComputerName,user=root"
            $SlaveLine = "echo '$SlaveLine' >> /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-hosts-nfs"
            $Stream.WriteLine($SlaveLine)
            sleep -s 3

            #Adding the new Lines at /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfsaff-luns-nfs
            #sd=sd1-1,host=slave01,lun=/mnt/vdbenchTest00_NFS_VD_vol1/file1-*,openflags=o_direct
            #/vdbench_NFS00_NFS_VD_vol_1
            #sd=sd1-1,host=slave01,lun=/mnt/vdbench_NFS00_NFS_VD_vol1/file1-*,openflags=o_direct
            #sd=sd1-2,host=slave01,lun=/mnt/vdbench_NFS00_NFS_VD_vol2/file1-*,openflags=o_direct
            #sd=sd1-3,host=slave01,lun=/mnt/vdbench_NFS00_NFS_VD_vol3/file1-*,openflags=o_direct
            #sd=sd1-4,host=slave01,lun=/mnt/vdbench_NFS00_NFS_VD_vol4/file1-*,openflags=o_direct
           
                for($M=1; $M -lt ($NumberVolumesPerVM+1); $M++){
                    $VolumeLine = "sd=sd$SlaveNumber-$M,host=slave0$SlaveNumber,lun=/mnt/$ComputerName`_NFS_VD_vol_$M/file1-*,openflags=o_direct"
                    $VolumeLine = "echo '$VolumeLine' >> /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-luns-nfs"
                    $Stream.WriteLine($VolumeLine)
                    sleep -s 3
                    }
                
                    $VolumeLine1 = "      "
                    $VolumeLine1 = "echo '$VolumeLine1' >> /root/SharedFiles/POC-Toolkit-1.5/vdbench/nfs/aff-luns-nfs"
                    $Stream.WriteLine($VolumeLine1)
                    sleep -s 3                           
                    $SlaveNumber++
                
        }elseif($Protocol -eq "iSCSI"){
                
            #FOR is each SlaveXX
            #Adding the new Lines at /root/SharedFiles/vdbench/vmdk/aff-hosts-vmdk
            $ComputerName = $item1.Value.Name
            $SlaveLine = "hd=slave0$SlaveNumber,system=$ComputerName,user=root"
            $SlaveLine = "echo '$SlaveLine' >> /root/SharedFiles/vdbench/vmdk/aff-hosts-vmdk"
            Invoke-SSHCommand -Index 0 -Command $SlaveLine | Out-Null

            #Adding the new Lines at /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk
            #sd=sd1-1,host=slave01,lun=/dev/sdb,openflags=o_direct,offset=0
            #sd=sd1-2,host=slave01,lun=/dev/sdc,openflags=o_direct,offset=0
            #sd=sd1-3,host=slave01,lun=/dev/sdd,openflags=o_direct,offset=0
            #sd=sd1-4,host=slave01,lun=/dev/sde,openflags=o_direct,offset=0
                                
            $letters = [char[]]('b'[0]..'z'[0])

        for($M=1; $M -lt ($NumberVolumesPerVM+1); $M++){

        $letters1 = $letters[($M-1)]
        $VolumeLine = "sd=sd$SlaveNumber-$M,host=slave0$SlaveNumber,lun=/dev/sd$letters1,openflags=o_direct,offset=0"
        $VolumeLine = "echo '$VolumeLine' >> /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk"
        Invoke-SSHCommand -Index 0 -Command $VolumeLine | Out-Null

        }
                
        $VolumeLine1 = "      "
        $VolumeLine1 = "echo '$VolumeLine1' >> /root/SharedFiles/vdbench/vmdk/aff-luns-vmdk"
        Invoke-SSHCommand -Index 0 -Command $VolumeLine1 | Out-Null            
        $SlaveNumber++
        Remove-SSHSession -SessionId 0 | Out-Null
             
    }

        Remove-SSHSession -SSHSession $SSHSesionVM | Out-Null


        }else{
                          
        Write-Host "SSH Connection could not be established with IP Address: " $IPVMvalue -ForegroundColor Cyan
                                                   
        }
    }

$I++

}


<#
        if($Global:config.Other.Jumbo){
                ForEach($item1 in $Global:config.VMs.GetEnumerator() | Sort Key){
                New-SSHSession -ComputerName $item1.Value.IP -Credential $mycreds -AcceptKey -ConnectionTimeout 120 -OperationTimeout 120 | Out-Null
                #Changing the MTU to 9000 at /etc/sysconfig/network-scripts
                $MTULine = "MTU=9000"
                $MTULine = "echo '$MTULine' >> /etc/sysconfig/network-scripts/ifcfg-eno16777984"
                Invoke-SSHCommand -Index 0 -Command $MTULine | Out-Null
                #Reboot the network
                Invoke-SSHCommand -Index 0 -Command "systemctl restart network" | Out-Null
                Remove-SSHSession -SessionId 0 | Out-Null
             }
        }

#>
Write-host "Deployment has Finished......" -ForegroundColor Cyan
}
