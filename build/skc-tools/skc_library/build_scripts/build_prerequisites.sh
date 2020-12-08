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
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
		dnf install -y bc wget tar git gcc-c++ make automake autoconf libtool yum-utils p11-kit-devel cppunit-devel openssl-devel
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" ]]; then
		apt install -y build-essential ocaml ocamlbuild automake autoconf libtool cmake perl libcppunit-dev libssl-dev
		wget http://archive.ubuntu.com/ubuntu/pool/main/libt/libtasn1-6/libtasn1-6_4.14-3_amd64.deb
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit0_0.23.17-2_amd64.deb
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/p11-kit-modules_0.23.17-2_amd64.deb
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/p11-kit_0.23.17-2_amd64.deb
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit-dev_0.23.17-2_amd64.deb

		apt install -f ./libtasn1-6_4.14-3_amd64.deb
		apt install -f ./libp11-kit0_0.23.17-2_amd64.deb
		apt install -f ./p11-kit-modules_0.23.17-2_amd64.deb
		apt install -f ./p11-kit_0.23.17-2_amd64.deb
		apt install -f ./libp11-kit-dev_0.23.17-2_amd64.deb

		rm -rf *.deb
	else
		echo "Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04"
		exit 1
	fi
}

install_pre_requisites
