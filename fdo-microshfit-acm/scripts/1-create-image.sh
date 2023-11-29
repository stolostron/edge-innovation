#!/bin/bash

blueprint_file=""
blueprint_name=""
repo_server_ip=$(ip a show dev $(ip route | grep default | awk '{print $5}') | grep "inet " | awk '{print $2}' | awk -F / '{print $1}')
repo_server_port="8090"
update=false
baserelease=$(cat /etc/redhat-release | awk '{print $6}' | awk -F . '{print $1}')
basearch=$(arch)

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "This Script creates a Blueprint and edge-container image"
   echo
   echo "Syntax: $0 [-b <TOML file>|-h <IP>|-p <port>|-u"
   echo ""
   echo "options:"
   echo "b     Blueprint file (required)."
   echo "h     Repo server IP (default=$repo_server_ip)."
   echo "p     Repo server port (default=$repo_server_port)."
   echo "u     Update. If selected it will use the last commit id on the existing repo as parent for the new ostree commit."
   echo
   echo "Example: $0 -b blueprint-demo.toml -h 192.168.122.129 -p 8090"
   echo "Example: $0 -b blueprint-demo.toml -h 192.168.122.129 -p 8090 -u"
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
while getopts ":b:h:p:u:" option; do
   case $option in
      b)
         blueprint_file=$OPTARG;;
      h)
         repo_server_ip=$OPTARG;;
      p)
         repo_server_port=$OPTARG;;
      u)
         update=true;;
     \?) # Invalid option
         echo "Error: Invalid option"
         echo ""
         Help
         exit -1;;
   esac
done

if [ -z "$blueprint_file" ]
then
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "You must define the Blueprint file with option -b"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        echo ""
        Help
        exit -1

fi

# assume that the name is the first entry in the file
blueprint_name=$(sed "/^$/d"  ${blueprint_file} | head -n1 | awk -F '"' '{print $2}')

############################################################
# Add RPM Repositories.                                    #
############################################################

echo ""
echo "Add RPM Repositories..."

cat <<EOF > rhocp-4.14.toml
id = "rhocp-4.14"
name = "Red Hat OpenShift Container Platform 4.14 for RHEL ${baserelease}"
type = "yum-baseurl"
url = "https://cdn.redhat.com/content/dist/layered/rhel${baserelease}/${basearch}/rhocp/4.14/os"
check_gpg = true
check_ssl = true
system = false
rhsm = true
EOF

composer-cli sources add rhocp-4.14.toml
composer-cli sources info rhocp-4.14
rm -f rhocp-4.14.toml

cat <<EOF > fast-datapath.toml
id = "fast-datapath"
name = "Fast Datapath for RHEL ${baserelease}"
type = "yum-baseurl"
url = "https://cdn.redhat.com/content/dist/layered/rhel${baserelease}/${basearch}/fast-datapath/os"
check_gpg = true
check_ssl = true
system = false
rhsm = true
EOF

composer-cli sources add fast-datapath.toml
composer-cli sources info fast-datapath
rm -f fast-datapath.toml

############################################################
# Create Blueprint and image.                              #
############################################################

echo ""
echo "Pushing Blueprint..."

composer-cli blueprints push ${blueprint_file}

# $(!!) Not working in shell script so use tmp file
echo ""
echo "Creating image..."

if [ $update = true ]
then
   # parent_id=$(curl http://${repo_server_ip}:${repo_server_port}/repo/refs/heads/rhel/${baserelease}/${basearch}/edge)
   # composer-cli compose start-ostree  --parent $parent_id $blueprint_name edge-container  > .tmp
   composer-cli compose start-ostree --url=http://${repo_server_ip}:${repo_server_port}/repo/ --ref=rhel/${baserelease}/${basearch}/edge $blueprint_name edge-container > .tmp

else
    composer-cli compose start-ostree ${blueprint_name} edge-container > .tmp
fi

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

echo ""
echo ""
echo "*********************************************************************************************"
echo "Blueprint ${blueprint_name} and edge-container image $image_commit created"
echo "*********************************************************************************************"
echo ""
echo ""
