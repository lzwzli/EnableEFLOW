# Enable EFLOW
This script enables the Azure IoT Edge for Linux on Windows (EFLOW) VM and sets it up to be ready to install ICONICS IoTWorX.  

The script goes through these series of steps:

1. Check if Hyper-V is enabled on the host machine. If Hyper-V is not enabled, it would enable it.

1. Check if an external switch called EFLOWSwitch exists. If it exists, then it would reuse the switch. If the switch doesn't exist, then it would create the switch, prompting the user for a desired adapter to use for the switch.

1. Download the EFLOW VM from Microsoft

1. Install EFLOW

1. Deploy EFLOW with user defined VM sizing

1. Setup the firewall to allow the ports necessary for ICONICS IoTWorX

1. Register the EFLOW VM as an IoT device of an IoT Hub with user provided IoT device connection string