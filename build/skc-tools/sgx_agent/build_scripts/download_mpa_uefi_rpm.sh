#!/bin/bash
SGX_AGENT_DIR=$PWD/sgx_agent
DCAP_VERSION=1.8
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin
MP_RPM_VER=1.8.100.2-1
OS_FLAVOUR="rhel8.2-server"
MPA_URL="https://download.01.org/intel-sgx/sgx-dcap/$DCAP_VERSION/linux/tools/SGXMultiPackageAgent/$OS_FLAVOUR"

fetch_mpa_uefi_rpm() {
	wget -q $MPA_URL/sgx_rpm_local_repo.tgz -O - | tar -xz || exit 1
	\cp sgx_rpm_local_repo/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm $SGX_AGENT_BIN_DIR
	rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz
}

fetch_mpa_uefi_rpm

