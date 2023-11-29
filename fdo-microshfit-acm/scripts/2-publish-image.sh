#!/bin/bash

image_commit=""
blueprint_name=""
repo_server_ip=$(ip a show dev $(ip route | grep default | awk '{print $5}') | grep "inet " | awk '{print $2}' | awk -F / '{print $1}')
repo_server_port="8090"
http_boot_mode=false
http_boot_port="8091"
fdo_server=""
disk_device="vda"
baserelease=$(cat /etc/redhat-release | awk '{print $6}' | awk -F . '{print $1}')
basearch=$(arch)

scripts_dir=$(dirname "$0")

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "This Script creates a container with the ostree repo from an edge-container image"
   echo ""
   echo "Syntax: $0 [-i <image ID>|-h <IP>|-p <port>|-d <device>|-f <server>|-x <port>]"
   echo ""
   echo "options:"
   echo "i     Image ID to be published (required)."
   echo "h     Repo server IP (default=$repo_server_ip)."
   echo "p     Repo server port (default=$repo_server_port)."
   echo "d     Disk drive where to install the OS (default=vda). Required if not using complete automated install"
   echo "f     Use FDO and include a FDO manufacturing server URL"
   echo "x     Create UEFI HTTP Boot server on this port, it creates an ISO and publish it on this server."
   echo ""
   echo "Example: $0 -i 125c1433-2371-4ae9-bda3-91efdbb35b92"
   echo "Example: $0 -i 125c1433-2371-4ae9-bda3-91efdbb35b92 -h 192.168.122.129 -p 8090"
   echo "Example: $0 -i 125c1433-2371-4ae9-bda3-91efdbb35b92 -h 192.168.122.129 -p 8090 -f http:example.fdo.com -x 8091 -d vda"
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
while getopts ":i:h:p:d:f:x:" option; do
   case $option in
      i)
         image_commit=$OPTARG;;
      h)
         repo_server_ip=$OPTARG;;
      p)
         repo_server_port=$OPTARG;;
      d)
         disk_device=$OPTARG;;
      f)
         fdo_server=$OPTARG;;
      x)
         http_boot_mode=true
         http_boot_port=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         echo ""
         Help
         exit -1;;
   esac
done

if [ -z "$image_commit" ]
then
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "You must define the Commit ID with option -i"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        echo ""
        Help
        exit -1
fi

blueprint_name=$(composer-cli compose status | grep $image_commit | awk '{print $8}')

if [ $http_boot_mode = true ] && [ -z "$fdo_server" ]
then
   echo ""
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo "Error: FDO server URL is required in http boot mode"
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo ""
   echo ""
   exit -1
fi

############################################################
# Download the image.
############################################################

echo ""
echo "Downloading image $image_commit..."

mkdir -p images
cd images
composer-cli compose image $image_commit
cd ..

# load image
image_id=$(podman load -i images/$image_commit-container.tar | tail -1 | cut -d ":" -f3)
podman tag $image_id localhost/$blueprint_name:$image_commit

echo $image_commit > .lastimagecommit

############################################################
# Publish the image.
############################################################

# Stop previous container
running_container_id=$(podman ps | grep 0.0.0.0:$repo_server_port | awk '{print $1}')
if [ -z "$running_container_id" ]
then
   echo ""
   echo "No running container"
   echo ""
else
   echo ""
   echo "Stopping previous container... ($running_container_id)"
   echo ""
   podman stop $running_container_id 2>/dev/null
fi

previous_container_name=$(podman ps -a | grep $image_commit | awk '{print $2}')
previous_container_id=$(podman ps -a | grep $image_commit | awk '{print $1}')

if [ "$previous_container_name" == "${blueprint_name}-repo-$image_commit" ]
then
   echo ""
   echo "Deleting previous container... ($previous_container_name) "
   echo ""
   podman rm $previous_container_id 2>/dev/null
fi

# Start repo container
echo ""
echo "Building and running the container serving the image..."

podman run --name ${blueprint_name}-repo-$image_commit -d -p $repo_server_port:8080 localhost/$blueprint_name:$image_commit

# Wait for container to be running
until [ "$(sudo podman inspect -f '{{.State.Running}}' ${blueprint_name}-repo-$image_commit)" == "true" ]; do
    sleep 1;
done;

if [ $http_boot_mode = true ]
then

############################################################
# UEFI HTTP Boot server
############################################################

# info about the setup on libvirt:  https://www.redhat.com/sysadmin/uefi-http-boot-libvirt

# libvirt network example:

# <network xmlns:dnsmasq="http://libvirt.org/schemas/network/dnsmasq/1.0">
#   <name>default</name>
#   <uuid>3328ebe7-2202-4e3b-9ca3-9ddf357db576</uuid>
#   <forward mode="nat">
#     <nat>
#       <port start="1024" end="65535"/>
#     </nat>
#   </forward>
#   <bridge name="virbr0" stp="on" delay="0"/>
#   <mac address="52:54:00:16:0e:63"/>
#   <ip address="192.168.122.1" netmask="255.255.255.0">
#     <tftp root="/var/lib/tftpboot"/>
#     <dhcp>
#       <range start="192.168.122.2" end="192.168.122.254"/>
#       <bootp file="pxelinux.0"/>
#     </dhcp>
#   </ip>
#   <dnsmasq:options>
#     <dnsmasq:option value="dhcp-vendorclass=set:efi-http,HTTPClient:Arch:00016"/>
#     <dnsmasq:option value="dhcp-option-force=tag:efi-http,60,HTTPClient"/>
#     <dnsmasq:option value="dhcp-boot=tag:efi-http,&quot;http://192.168.122.128:8091/EFI/BOOT/BOOTX64.EFI&quot;"/>
#   </dnsmasq:options>
# </network>

# Create VM:
# sudo virt-install   --name=edge-node-uefi-boot   --ram=2048   --vcpus=1   --os-type=linux   --os-variant=rhel8.5   --graphics=vnc   --pxe   --disk size=20,bus=sata  --check path_in_use=off   --network=network=default,model=virtio   --boot=uefi

# dhcpd example

#   class "pxeclients" {
#      match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
#      next-server 192.168.111.1;
#      filename "/bootx64.efi";
#    }
#    class "httpclients" {
#      match if substring (option vendor-class-identifier, 0, 10) = "HTTPClient";
#      option vendor-class-identifier "HTTPClient";
#      filename "http://192.168.122.128:8091/EFI/BOOT/BOOTX64.EFI";
#    }

echo ""
echo ""
echo "Creating UEFI HTTP boot server..."
echo ""

# offline fully automated ISO could be used too
${scripts_dir}/3-create-offline-deployment.sh -h $repo_server_ip -p $repo_server_port -f $fdo_server -d $disk_device > /dev/null
install_image_commit=$(cat .lastimagecommit)
iso_file="${install_image_commit}-simplified-installer.iso"

mkdir -p mnt/rhel-install/
mount -o loop,ro -t iso9660 images/$iso_file mnt/rhel-install/

mkdir -p tmp/boot-server/var/www/html/

cp -R mnt/rhel-install/* tmp/boot-server/var/www/html/

chmod -R +r tmp/boot-server/var/www/html/*

# Changes on simplified ISO
sed -i 's/linux \/images\/pxeboot\/vmlinuz/linuxefi \/images\/pxeboot\/vmlinuz/g' tmp/boot-server/var/www/html/EFI/BOOT/grub.cfg
sed -i 's/initrd \/images\/pxeboot\/initrd.img/initrdefi \/images\/pxeboot\/initrd.img/g' tmp/boot-server/var/www/html/EFI/BOOT/grub.cfg
sed -i "s/coreos.inst.image_file=\/run\/media\/iso\/image.raw.xz/coreos.inst.image_url=http:\/\/${repo_server_ip}:$http_boot_port\/image.raw.xz/g" tmp/boot-server/var/www/html/EFI/BOOT/grub.cfg
sed -i "s/inst.stage2=.* /inst.stage2=http:\/\/${repo_server_ip}:${http_boot_port} /g" tmp/boot-server/var/www/html/EFI/BOOT/grub.cfg

echo ""
echo ""
echo "Updating UEFI Http Boot Server Configuration..."
echo ""
cat tmp/boot-server/var/www/html/EFI/BOOT/grub.cfg
echo ""
echo ""

cat <<EOF > nginx.conf
events {
}
http {
    server{
        listen 8080;
        root /usr/share/nginx/html;
        location / {
            autoindex on;
            }
        }
     }
pid /run/nginx.pid;
daemon off;
EOF

cat <<EOF > dockerfile-http-boot
FROM registry.access.redhat.com/ubi8/ubi
RUN yum -y install nginx && yum clean all
ARG content
COPY \$content/ /usr/share/nginx/html/
ADD nginx.conf /etc/
EXPOSE 8080
CMD ["/usr/sbin/nginx", "-c", "/etc/nginx.conf"]
EOF

running_container_id=$(podman ps | grep 0.0.0.0:$http_boot_port | awk '{print $1}')
if [ -z "$running_container_id" ]
then
   echo ""
   echo "No running container"
   echo ""
else
   echo ""
   echo "Stopping previous container... ($running_container_id)"
   echo ""
   podman stop $running_container_id 2>/dev/null
fi

previous_container_name=$(podman ps -a | grep $install_image_commit | awk '{print $2}')
previous_container_id=$(podman ps -a | grep $install_image_commit | awk '{print $1}')

if [ "$previous_container_name" == "http-boot-${install_image_commit}" ]
then
   echo ""
   echo "Deleting previous container... ($previous_container_name) "
   echo ""
   podman rm $previous_container_id 2>/dev/null
fi

podman build -f dockerfile-http-boot -t localhost/http-boot:${install_image_commit} --build-arg content="tmp/boot-server/var/www/html" .
podman run --name http-boot-${install_image_commit} -d -p $http_boot_port:8080 localhost/http-boot:${install_image_commit}

# Clean up files
rm -f dockerfile-http-boot nginx.conf

# Wait for container to be running
until [ "$(sudo podman inspect -f '{{.State.Running}}' http-boot-${install_image_commit})" == "true" ]; do
    sleep 1;
done;

umount mnt/rhel-install/
rm -rf mnt
rm -rf tmp

echo "******************************************************************************"
echo "You have activated UEFI HTTP boot, be sure that you have your DHCP configured!"
echo "DHCP-boot:  http://$repo_server_ip:$http_boot_port/EFI/BOOT/BOOTX64.EFI"
echo ""
echo "Remember to use UEFI boot (instead legacy BIOS) and NIC as first boot device"
echo ""
echo "Remember that it takes time until boot reaches UEFI HTTP boot (first tries PXE)"
echo ""
echo "Your edge system must have at least 2GB of memory"
echo "******************************************************************************"
echo ""
echo ""

fi
