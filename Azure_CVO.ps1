. ./Variables.ps1

$ModuleFunctions = Get-Module -Name Azure_CVO_Functions
       if($ModuleFunctions){
        Remove-Module -Name Azure_CVO_Functions -ErrorAction SilentlyContinue -WarningAction silentlyContinue
        Import-Module .\Azure_CVO_Functions.psm1 -ErrorAction SilentlyContinue -WarningAction silentlyContinue
       }else{
        Import-Module .\Azure_CVO_Functions.psm1 -ErrorAction SilentlyContinue -WarningAction silentlyContinue
       }

Connect-AzAccount
$Subscription = Get-AzSubscription | Select | Out-GridView -OutputMode Single -Title "Select one PAYG subscription"
Set-AzContext -SubscriptionObject $Subscription

# Networking Defaults #
$IPLinuxVMs = '10.0.1.10', '10.0.1.11','10.0.1.12','10.0.1.13','10.0.1.14','10.0.1.15','10.0.1.16','10.0.1.17','10.0.1.18','10.0.1.19','10.0.1.20'
$SubnetAddressPrefix = '10.0.0.0/16'
$FrontEndSubnetAddressPrefix = '10.0.1.0/24'
$BackEndSubnetAddressPrefix = '10.0.2.0/24'
$VirtualNetWorkName = 'NetApp-VNet-vdbench'

# Create Network Enviroment
$VirtualNetwork = Create-Networks -ResourceGroupName $ResourceGroupName -Location $Location `
                  -VirtualNetWorkName $VirtualNetWorkName -SubnetAddressPrefix $SubnetAddressPrefix `
                  -FrontEndSubnetAddressPrefix $FrontEndSubnetAddressPrefix `
                  -BackEndSubnetAddressPrefix $BackEndSubnetAddressPrefix

$VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetWorkName -ResourceGroupName $ResourceGroupName

$VirtualNetworkName = $VirtualNetWork.Name


# Create VMs
Get-Job | Remove-Job
$env:WhereAmI = Get-Location
$Path = Get-Location

Start-Job -Name JumpHost `
          -InitializationScript {
            Import-Module $env:WhereAmI\Azure_CVO_Functions.psm1 -WarningAction SilentlyContinue
           } `
           -ScriptBlock {
                param([string]$ResourceGroupName,[string]$VirtualNetworkName,[string]$Location,[string]$Path,[string[]]$IPLinuxVMs,[int]$NumberLinuxVMs)
                # Windows use Standard_B1ms, Linux use Standard_B2s
                Create-VM -VMLocalAdminUser 'netappcvo' -ComputerName 'JHvdbench' -VMType Windows `
                          -VMSize Standard_B1ms -ResourceGroupName $ResourceGroupName -Location $Location `
                          -VirtualNetworkName $VirtualNetworkName -ScriptPath $Path             
          } `
          -ArgumentList $ResourceGroupName,$VirtualNetworkName,$Location,$Path,$IPLinuxVMs,$NumberLinuxVMs | Out-Null
# Windows use Standard_B1ms, Linux use Standard_B2s

# Create Linux VMs
$I = 1

While ($I -le $NumberLinuxVMs){

$JobName = "Linux "+$I
$ComputerName = "LinuxVM"+$I
$PrivateIPAddress = $IPLinuxVMs[$I]

Start-Job -Name $JobName `
          -InitializationScript {
            Import-Module $env:WhereAmI\Azure_CVO_Functions.psm1 -WarningAction SilentlyContinue
           } `
          -ScriptBlock {
               param([string]$ResourceGroupName,[string]$VirtualNetworkName,[string]$Location,[string]$PrivateIPAddress,[string]$ComputerName,[string[]]$IPLinuxVMs,[int]$NumberLinuxVMs)
               # Windows use Standard_B1ms, Linux use Standard_B2s
               Create-VM -VMLocalAdminUser 'netappcvo' -ComputerName $ComputerName -VMType Linux `
                         -VMSize Standard_B2s -ResourceGroupName $ResourceGroupName -Location $Location `
                         -VirtualNetworkName $VirtualNetworkName -PrivateIPAddress $PrivateIPAddress `
                         -IPLinuxVMs $IPLinuxVMs -NumberLinuxVMs $NumberLinuxVMs
                       } `
           -ArgumentList $ResourceGroupName,$VirtualNetworkName,$Location,$PrivateIPAddress,$ComputerName,$IPLinuxVMs,$NumberLinuxVMs | Out-Null
$I++

}

Remove-Item env:\WhereAmI 
