
# To Download Powershell 5.1
# https://www.microsoft.com/en-us/download/details.aspx?id=54616

# To Download NetApp Powershell toolkit 
# https://mysupport.netapp.com/tools/download/ECMLP2310788DT.html?productID=61926&pcfContentID=ECMLP2310788

. ./Variables.ps1

$ModuleFunctions = Get-Module -Name Azure_CVO_Functions
       if($ModuleFunctions){
        Remove-Module -Name Azure_CVO_Functions -ErrorAction SilentlyContinue -WarningAction silentlyContinue
        Import-Module .\Azure_CVO_Functions.psm1 -ErrorAction SilentlyContinue -WarningAction silentlyContinue
       }else{
        Import-Module .\Azure_CVO_Functions.psm1 -ErrorAction SilentlyContinue -WarningAction silentlyContinue
       }

# Defaults 
$IPLinuxVMs = '10.0.1.10', '10.0.1.11','10.0.1.12','10.0.1.13','10.0.1.14','10.0.1.15','10.0.1.16','10.0.1.17','10.0.1.18','10.0.1.19','10.0.1.20'
$ONTAPClusterIP = '10.0.2.5'
$PathvdbenchBinaries = 'C:\Users\netappcvo\Desktop\vdbench50407.zip'
$PathAFFToolkit = 'C:\Users\netappcvo\Desktop\POC-Toolkit-1.5.zip'


$FileSize = $FileSize+'GB'
$VolumeSize = $VolumeSize+'GB'

Deployment -ONTAPClusterIP $ONTAPClusterIP -NumberVolumesPerVM $NumberVolumesPerVM `
           -VolumeSize $VolumeSize -IPLinuxVMs $IPLinuxVMs -NumberLinuxVMs $NumberLinuxVMs `
           -FileSize $FileSize `
           -PathVdbenchBinaries $PathvdbenchBinaries `
           -PathAFFToolkit $PathAFFToolkit