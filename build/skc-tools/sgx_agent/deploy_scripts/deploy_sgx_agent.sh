#!/bin/bash
SGX_DRIVER_VERSION=1.36
KDIR=/lib/modules/$(uname -r)/build
SGX_INSTALL_DIR=/opt/intel
MP_RPM_VER=1.8.100.2-1
SGX_AGENT_BIN=bin

cat $KDIR/.config | grep "CONFIG_INTEL_SGX=y" > /dev/null
INKERNEL_SGX=$?
/sbin/modinfo intel_sgx &> /dev/null
SGX_DRIVER_INSTALLED=$?

install_prerequisites()
{
        source deployment_prerequisites.sh
        if [[ $? -ne 0 ]]
        then
                echo "sgx agent pre-requisite package installation failed. exiting"
                exit 1
        fi
}

install_dcap_driver()
{
	chmod u+x $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	echo "$INKERNEL_SGX"
	echo "$SGX_DRIVER_INSTALLED"
	if [[ "$INKERNEL_SGX" -ne 0 && "$SGX_DRIVER_INSTALLED" -ne 0 ]]; then
		sh $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
		echo "sgx dcap driver installed"
	else
		echo "found inbuilt sgx driver, skipping dcap driver installation"
	fi
}

install_psw_qgl()
{
	tar -xf $SGX_AGENT_BIN/sgx_rpm_local_repo.tgz 
	yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo
	yum-config-manager --save --setopt=tmp_sgx_sgx_rpm_local_repo.gpgcheck=0
	dnf install -y --nogpgcheck libsgx-dcap-ql || exit 1
	rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
}
	
install_multipackage_agent_rpm()
{
	rpm -ivh $SGX_AGENT_BIN/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm
}

install_pckretrieval_tool()
{
	dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/m/msr-tools-1.3-13.fc32.x86_64.rpm
	\cp -pf $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so /usr/sbin/
	\cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool /usr/sbin/
}

install_sgx_agent() { 
	\cp -pf sgx_agent.env ~/sgx_agent.env

	source agent.conf
	CMS_URL=https://$CMS_IP:$CMS_PORT/cms/v1
	AAS_URL=https://$AAS_IP:$AAS_PORT/aas
	SHVS_URL=https://$SHVS_IP:$SHVS_PORT/sgx-hvs/v1
	SCS_URL=https://$SCS_IP:$SCS_PORT/scs/sgx
	sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sgx_agent.env
	sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sgx_agent.env
	sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SGX_AGENT_IP/" ~/sgx_agent.env
	sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sgx_agent.env
	sed -i "s/^\(SGX_AGENT_USERNAME\s*=\s*\).*\$/\1$AGENT_USER/" ~/sgx_agent.env
	sed -i "s/^\(SGX_AGENT_PASSWORD\s*=\s*\).*\$/\1$AGENT_PASSWORD/" ~/sgx_agent.env
	
	./sgx_agent_create_roles.sh
	if [ $? -ne 0 ];then
		echo "sgx_agent user/role creation failed. exiting"
		exit 1
	fi

	sgx_agent uninstall --purge
	$SGX_AGENT_BIN/sgx_agent-v*.bin
}

install_prerequisites
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
install_sgx_agent
