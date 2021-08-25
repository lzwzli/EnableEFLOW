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
# Check Hyper-V
#===============================================================
PrintHeader "Check Hyper-V State"
PrintStatus "Checking if Hyper-V is enabled..."
$hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
if($hyperv.State -eq "Enabled"){
    Write-Host "Hyper-V is enabled." -ForegroundColor Green -NoNewline
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

Start-Process -Wait msiexec -ArgumentList "/i","$([io.Path]::Combine($env:TEMP, 'AzureIoTEdge.msi'))","/qn"
Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Force
Deploy-Eflow -cpuCount 2 -memoryInMB 2048 -vswitchName 'EFLOWSwitch' -vswitchType 'External'

PrintStatus "Provision EFLOW VM..."
Write-Host "Please obtain the IoT Device connection string from your IoT Hub"
$devConnString = Read-Host "IoT Device Connection String:"
Provision-EflowVm -provisioningType ManualConnectionString -devConnString $devConnString

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

PrintStatus "EFLOW Installation Complete."