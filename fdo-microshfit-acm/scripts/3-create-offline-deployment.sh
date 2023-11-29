#!/bin/bash

repo_server_ip=$(ip a show dev $(ip route | grep default | awk '{print $5}') | grep "inet " | awk '{print $2}' | awk -F / '{print $1}')
repo_server_port="8090"
simplified_installer=false
fdo_server=""
disk_device="vda"
baserelease=$(cat /etc/redhat-release | awk '{print $6}' | awk -F . '{print $1}')
basearch=$(arch)

############################################################
# Help                                                     #
############################################################

Help()
{
   # Display Help
   echo "This Script creates an ISO (by default for unattended installation) with the OSTree commit embedded to install a system without the need of external network resources (HTTP or PXE server)."
   echo
   echo "Syntax: $0 [-h <IP>|-p <port>]|-d <device>|-f <server>]"
   echo ""
   echo "options:"
   echo "h     Repo server IP (default=$repo_server_ip)."
   echo "p     Repo server port (default=$repo_server_port)."
   echo "d     Disk drive where to install the OS (default=vda). Required if not using complete automated install."
   echo "f     Use FDO and include a FDO manufacturing server URL"
   echo
   echo "Example: $0 -h 192.168.122.129 -p 8090"
   echo "Example: $0 -h 192.168.122.129 -p 8090 -f http://10.0.0.2:8083"
   echo "Example: $0 -h 192.168.122.129 -p 8090 -f http://10.0.0.2:8083 -d vda"
   echo ""
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":h:p:d:f:" option; do
   case $option in
      h)
         repo_server_ip=$OPTARG;;
      p)
         repo_server_port=$OPTARG;;
      d)
         disk_device=$OPTARG;;
      f)
         simplified_installer=true
         fdo_server=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         echo ""
         Help
         exit -1;;
   esac
done

if [ $simplified_installer = true ] && [ -z "$fdo_server" ]
then
   echo "Error: FDO server URL is required to build simplified installer"
   echo ""
   exit -1
fi

if [ $simplified_installer = false ]
then

cat <<EOF > blueprint-iso.toml
name = "blueprint-iso"
description = "Blueprint for ISOs"
version = "0.0.1"
modules = [ ]
groups = [ ]
EOF

iso_blueprint="blueprint-iso"

else

cat <<EOF > blueprint-fdo.toml
name = "blueprint-fdo"
description = "Blueprint for FDO"
version = "0.0.1"
packages = []
modules = []
groups = []
distro = ""

[customizations]
installation_device = "/dev/${disk_device}"

[customizations.fdo]
manufacturing_server_url = "${fdo_server}"
diun_pub_key_insecure = "true"
EOF

iso_blueprint="blueprint-fdo"

fi

################################################################################
######################################## CREATE ISO
################################################################################

echo ""
echo "Pushing ISO Blueprint..."
composer-cli blueprints delete ${iso_blueprint} 2>/dev/null
composer-cli blueprints push ${iso_blueprint}.toml

# $(!!) Not working in shell script so use tmp file
echo ""
echo "Creating ISO..."

if [ $simplified_installer = false ]
then
   composer-cli compose start-ostree ${iso_blueprint} edge-installer --ref rhel/${baserelease}/${basearch}/edge --url http://$repo_server_ip:$repo_server_port/repo/ > .tmp
else
   composer-cli compose start-ostree ${iso_blueprint} edge-simplified-installer --ref rhel/${baserelease}/${basearch}/edge --url http://$repo_server_ip:$repo_server_port/repo/ > .tmp
fi

rm -f ${iso_blueprint}.toml

image_commit=$(cat .tmp | awk '{print $2}')

# Wait until image is created
RESOURCE="$image_commit"
command="composer-cli compose status"
echo_finish="FINISHED"
echo_failed="FAILED"
while [[ $($command | grep "$RESOURCE" | grep $echo_finish > /dev/null ; echo $?) != "0" ]]
do 
   if [[ $($command | grep "$RESOURCE" | grep $echo_failed > /dev/null ; echo $?) != "1" ]]
   then
      echo ""
      echo "!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Error creating the image"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!"
      echo ""
      exit -1
   fi
   echo "Waiting for $RESOURCE" && sleep 60
done

# Wait until image is created
echo ""
echo "Downloading ISO $image_commit..."

mkdir -p images
cd images
composer-cli compose image $image_commit
cd ..

echo $image_commit > .lastimagecommit

echo ""
echo "************************************************"
echo "Install using this ISO with UEFI boot loader!!! "
echo "(otherwise you will get error code 0009)"
echo "************************************************"
echo ""
echo ""
