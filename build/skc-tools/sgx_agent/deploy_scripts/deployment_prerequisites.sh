#!/bin//bash

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

install_pre_requisites()
{
if [ "$OS" == "rhel" ]
then
# RHEL
	dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-9.el8.noarch.rpm
	dnf install -y yum-utils kernel-devel dkms tar make jq || exit 1
elif [ "$OS" == "ubuntu" ]
then
# UBUNTU
       apt install -y dkms tar make jq
fi
}

install_pre_requisites
