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
#RHEL

	dnf install -y bc wget tar git gcc-c++ make automake autoconf libtool yum-utils p11-kit-devel cppunit-devel openssl-devel

elif [ "$OS" == "ubuntu" ]
then
       #UBUNTU
       apt install -y build-essential ocaml ocamlbuild automake autoconf libtool cmake perl libcppunit-dev libssl-dev

# Download P11-Kit
       wget http://archive.ubuntu.com/ubuntu/pool/main/libt/libtasn1-6/libtasn1-6_4.14-3_amd64.deb
       wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit0_0.23.17-2_amd64.deb
       wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/p11-kit-modules_0.23.17-2_amd64.deb
       wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/p11-kit_0.23.17-2_amd64.deb
       wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit-dev_0.23.17-2_amd64.deb

# Install
       apt install -f ./libtasn1-6_4.14-3_amd64.deb
       apt install -f ./libp11-kit0_0.23.17-2_amd64.deb
       apt install -f ./p11-kit-modules_0.23.17-2_amd64.deb
       apt install -f ./p11-kit_0.23.17-2_amd64.deb
       apt install -f ./libp11-kit-dev_0.23.17-2_amd64.deb
# Remove
       rm -rf *.deb
fi

}

install_pre_requisites
