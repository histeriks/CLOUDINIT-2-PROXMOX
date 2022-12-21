#!/bin/bash 
###########################################################
#          Proxmox Cloud-Init Image Importer              #
# this tool downloads, customizes and imports cloud-init  #
#  images to Proxmox, for use with Terraform etc tools    #
###########################################################

echo -e "\e[93mYour Proxmox API URL (ie: https://pve.yourdomain.org:8006/api2/json)?\e[0m"; read PM_API_URL
echo -e "\e[93mYour API TOKEN ID (create in PVE, under Datacenter/Permissions)?\e[0m"; read PM_API_TOKEN
echo -e "\e[93mYour API TOKEN SECRET?\e[0m"; read PM_API_TOKEN_SECRET
echo -e "\e[93mPVE storage holding your VM's (local-lvm, local-zfs, zpool, rpool etc)?\e[0m"; read STORAGE_POOL

sleep 2
echo -e "\e[92mthanks! i am adding these to your .bashrc file for future use...\e[0m";

sleep 10
echo "export PM_API_URL=$PM_API_URL" >> ~/.bashrc
echo "export PM_API_TOKEN=$PM_API_TOKEN" >> ~/.bashrc
echo "export PM_API_TOKEN_SECRET=$PM_API_TOKEN_SECRET" >> ~/.bashrc
echo "export STORAGE_POOL=$STORAGE_POOL" >> ~/.bashrc
echo -e "\e[93msetting up terraform...\e[0m"
mkdir terraform && cd terraform && apt-get update -y && apt-get install -y gnupg software-properties-common -y
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y && apt-get install terraform -y
terraform -install-autocomplete
export VM_ID="10000"
export VM_NAME="ubuntu-20.04-cloudimg"

echo -e "\e[93mdownloading and customizing ubuntu cloud image...\e[0m"
sleep 2

wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
apt-get install libguestfs-tools -y
virt-customize -a focal-server-cloudimg-amd64.img --run-command "sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
virt-customize -a focal-server-cloudimg-amd64.img --install qemu-guest-agent

echo -e "\e[93mimporting changed image to proxmox VM & converting it into a template...\e[0m"
sleep 2

qm create $VM_ID --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk $VM_ID focal-server-cloudimg-amd64.img $STORAGE_POOL
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE_POOL:vm-$VM_ID-disk-0
qm set $VM_ID --agent enabled=1,fstrim_cloned_disks=1
qm set $VM_ID --name $VM_NAME
qm set $VM_ID --ide2 $STORAGE_POOL:cloudinit
qm set $VM_ID --boot c --bootdisk scsi0
qm set $VM_ID --serial0 socket --vga serial0
qm template $VM_ID

echo -e "\e[93mall done, you can now clone this template into new VM's, customizing cloud-init info BEFORE first boot!\e[0m"
sleep 5

exit 0
