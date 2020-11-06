#!/bin//bash
install_pre_requisites()
{
	dnf install -y https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/e/epel-release-8-8.el8.noarch.rpm
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/s/softhsm-2.5.0-4.fc32.3.x86_64.rpm
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/l/libgda-5.2.9-4.fc32.x86_64.rpm
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/l/libgda-sqlite-5.2.9-4.fc32.x86_64.rpm

	dnf install -y yum-utils tar wget gcc-c++ kernel-devel kernel-headers dkms make jq protobuf jsoncpp jsoncpp-devel nginx
	\cp -rpf bin/pkcs11.so /usr/lib64/engines-1.1/
	\cp -rpf bin/libp11.so.3.4.3 /usr/lib64/
	ln -sf /usr/lib64/libp11.so.3.4.3 /usr/lib64/libp11.so
	ln -sf /usr/lib64/engines-1.1/pkcs11.so /usr/lib64/engines-1.1/libpkcs11.so
        ln -sf /usr/lib64/libjsoncpp.so /usr/lib64/libjsoncpp.so.0
}

install_pre_requisites
