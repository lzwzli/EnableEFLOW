# Enable EFLOW
This script enables the Azure IoT Edge for Linux on Windows (EFLOW) VM and sets it up to be ready to install ICONICS IoTWorX.  

The script goes through these series of steps:

1. Check if Hyper-V is enabled on the host machine. If Hyper-V is not enabled, it would enable it.

2. Check if an external switch called EFLOWSwitch exists. If it exists, then it would reuse the switch. If the switch doesn't exist, then it would create the switch, prompting the user for a desired adapter to use for the switch.

3. Download the EFLOW VM from Microsoft

4. Install EFLOW

5. Register the EFLOW VM as an IoT device of an IoT Hub by prompting for the IoT device connection string

6. Setup the firewall to allow the ports necessary for ICONICS IoTWorX