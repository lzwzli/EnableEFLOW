#=============================================================================================================================
# This script is intended to assist in the set up of EFLOW to run IoTWorX containers on Windows. It will run through the following sequence:
# 1. Check if Hyper-V is enabled. If not enable Hyper-V
# 2. Create an external switch, called EFLOWSwitch to be used by the EFLOW VM
# 3. Download and install the EFLOW VM
#
# Author: Zhi Wei Li
# Version: 1.0
# Publish date: Aug 24th, 2021
#
#=============================================================================================================================

#Functions
function PrintHeader {
    [CmdletBinding()]
    param ([string]$ToPrint)
    write-host ('='*200)
    write-host $ToPrint
    write-host ('='*200)
}

function PrintStatus {
    [CmdletBinding()]
    param ([string]$ToPrint)
    write-host ('~~') -ForegroundColor Yellow -NoNewline
    write-host $ToPrint -NoNewline -ForegroundColor Yellow
    write-host ('~~') -NoNewline -ForegroundColor Yellow
    Write-Host " "
}
#===============================================================
# Introduction and information collecting
#===============================================================
write-host ('='*200)
Write-Host "This script installs the EFLOW VM and sets up the necessary pre-requisites like Hyper-V and Hyper-V switch."
write-host " "
Write-Host "The script first checks if Hyper-V is enabled. If not, Hyper-V is enabled."
Write-Host "Then, it checks if a Hyper-V switch called EFLOWSwitch exists. If not, it would create the switch, prompting the user for the desired adapter."
Write-Host "Then, it would setup the firewall in the EFLOW VM for ICONICS IoTWorX."
Write-Host "Lastly, it would provision the EFLOW VM as an IoT device of an IoT hub."
write-host ('='*200)

Write-Host "How many CPU's should the EFLOW VM have ?" -ForegroundColor Yellow
$CPUCount = Read-Host "CPU count"

Write-Host "How much memory (in MB) should the EFLOW VM have ?" -ForegroundColor Yellow
$MemoryInMB = Read-Host "Memory size (MB)"

while ($toProvision -ne "Y" -and $toProvision -ne "N"){
    Write-Host "Should the VM be provisioned as an IoT device ?" -ForegroundColor Yellow
    write-host "To provision the EFLOW VM as an IoT device, an IoT device connection string from IoT Hub is required." -ForegroundColor Yellow
    $toProvision = Read-Host "[Y]es  [N]o"
}

if($toProvision -eq "Y") {
    $devConnString = Read-Host "IoT Device Connection String"
}

#===============================================================
# Check Hyper-V
#===============================================================
PrintHeader "Check Hyper-V State"
PrintStatus "Checking if Hyper-V is enabled..."
$hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
if($hyperv.State -eq "Enabled"){
    Write-Host "Hyper-V is enabled." -ForegroundColor Yellow -NoNewline
    Write-Host " "
} else {
    Write-Host "Hyper-V is disabled." -ForegroundColor Red -NoNewline
    Write-Host " "
    PrintStatus "Enabling Hyper-V..."
    $OSType=Get-ComputerInfo
    if($OSType.WindowsProductName -like "*Server*"){
        Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
    } else {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
    }
    Write-Host "Please reboot and re-run this script."
    exit
}

#===============================================================
# Create External Switch
#===============================================================
PrintHeader "Create EFLOW external switch"
PrintStatus "Checking if EFLOWSwitch exists..."
$EFSwitch=Get-VMSwitch
if($EFSwitch.Name -eq "EFLOWSwitch"){
    Write-Host "EFLOWSwitch exists. Reusing existing switch."
} else {
    PrintStatus "Create EFLOWSwitch"
    PrintStatus "Select adapter to use for switch:"
    $NetAdapter = Get-NetAdapter
    For ($i=0; $i -lt $NetAdapter.Count;$i++){
        Write-Host "$($i+1):$($NetAdapter[$i].Name)"
    }
    $NetAdapterIndex = Read-Host "Enter index number of adapter to use"
    $NetAdapterName = $($NetAdapter[$NetAdapterIndex-1].Name)
    PrintStatus "Creating external switch with $NetAdapterName"
    New-VMSwitch -name EFLOWSwitch -NetAdapterName $NetAdapterName
}

#===============================================================
# Install EFLOW VM
#===============================================================
PrintHeader "Install EFLOW VM"
PrintStatus "Installing EFLOW VM..."
$msiPath = $([io.Path]::Combine($env:TEMP, 'AzureIoTEdge.msi'))
$ProgressPreference = 'SilentlyContinue'
try{
    PrintStatus "Attempting to download EFLOW msi..."
    Invoke-WebRequest https://aka.ms/AzEflowMSI -OutFile $msiPath
} catch {
    write-host "Error occured: " -NoNewline
    write-host $_ -ForegroundColor Red -NoNewline
    write-host " "
    exit
}
PrintStatus "EFLOW msi downloaded."
PrintStatus "Installing EFLOW..."
Start-Process -Wait msiexec -ArgumentList "/i","$([io.Path]::Combine($env:TEMP, 'AzureIoTEdge.msi'))","/qn"
Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Force
PrintStatus "Deploy EFLOW..."
Deploy-Eflow -cpuCount $CPUCount -memoryInMB $MemoryInMB -vswitchName 'EFLOWSwitch' -vswitchType 'External'

PrintStatus "Updating EFLOW VM firewall settings..."
write-host "Open TCP port 8443."
Invoke-EflowVmCommand "sudo iptables -A INPUT -p tcp --dport 8443 -j ACCEPT"
write-host "Open TCP port 8843."
Invoke-EflowVmCommand "sudo iptables -A INPUT -p tcp --dport 8843 -j ACCEPT"
write-host "Open TCP port 8080."
Invoke-EflowVmCommand "sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT"
write-host "Open TCP port 80."
Invoke-EflowVmCommand "sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
write-host "Open TCP port 47808."
Invoke-EflowVmCommand "sudo iptables -A INPUT -p udp --dport 47808 -j ACCEPT"
write-host "Save IPv4 settings"
Invoke-EflowVmCommand "sudo iptables-save | sudo tee /etc/systemd/scripts/ip4save"

if($toProvision -eq "Y"){
    PrintStatus "Provisioning EFLOW VM..."
    Provision-EflowVm -provisioningType ManualConnectionString -devConnString $devConnString
    PrintStatus "EFLOW VM installation complete and provisioned as IoT device."
} else {
    PrintStatus "EFLOW VM installation complete but not provisioned."
}

