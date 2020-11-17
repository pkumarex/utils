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
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/s/softhsm-2.5.0-4.fc32.3.x86_64.rpm
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/l/libgda-5.2.9-4.fc32.x86_64.rpm
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/l/libgda-sqlite-5.2.9-4.fc32.x86_64.rpm

	dnf install -y yum-utils tar wget gcc-c++ kernel-devel kernel-headers dkms make jq protobuf jsoncpp jsoncpp-devel nginx

elif [ "$OS" == "ubuntu" ]
then
# Ubuntu
       apt install build-essential ocaml automake autoconf libtool tar wget python libssl-dev
       apt-get install libcurl4-openssl-dev libprotobuf-dev curl
       apt install -y dkms make jq libjsoncpp1 libjsoncpp-dev softhsm libgda-5.0-4
       apt install -y nginx
fi

if [ "$OS" == "rhel" ]
then
        \cp -rpf bin/pkcs11.so /usr/lib64/engines-1.1/
        \cp -rpf bin/libp11.so.3.4.3 /usr/lib64/
        ln -sf /usr/lib64/libp11.so.3.4.3 /usr/lib64/libp11.so
        ln -sf /usr/lib64/engines-1.1/pkcs11.so /usr/lib64/engines-1.1/libpkcs11.so
        ln -sf /usr/lib64/libjsoncpp.so /usr/lib64/libjsoncpp.so.0
elif [ "$OS" == "ubuntu" ]
then
        \cp -rpf bin/pkcs11.so /usr/lib/x86_64-linux-gnu/engines-1.1/
        \cp -rpf bin/libp11.so.3.4.3 /usr/lib/
        ln -sf /usr/lib/libp11.so.3.4.3 /usr/lib/libp11.so
        ln -sf /usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so /usr/lib/x86_64-linux-gnu/engines-1.1/libpkcs11.so
        ln -sf /usr/lib/libjsoncpp.so /usr/lib/libjsoncpp.so.0
fi
}

install_pre_requisites
