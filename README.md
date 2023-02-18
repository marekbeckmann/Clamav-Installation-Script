# How to use

Because of the CVE-2023-20032 vulnerability, it is recommended to upgrade Clamav to version 1.0.1. This Script will remove any existing Clamav installation and install the newest version. Please note, that this script has only been tested on Debian 11
## 1. Download

```bash
git clone https://github.com/marekbeckmann/Clamav-Installation-Script-.git ~/clamav-installation-script
cd ~/clamav-installation-script && chmod +x install-clamav.sh
``` 

## 2. Running the script

To run the script, simply issue the following with root privileges:

```bash
sudo bash install-clamav.sh
```

**Important:** Some of the installation steps take a while. Please be patient and wait for the script to finish.