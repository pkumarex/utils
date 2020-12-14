#!/bin/bash

SGX_AGENT_DIR=$PWD/sgx_agent
SGX_AGENT_BIN_DIR=$SGX_AGENT_DIR/bin

build_sgx_agent()
{
	pushd $PWD
	cd ../../
	make installer || exit 1
	mkdir -p $SGX_AGENT_BIN_DIR
	\cp -pf out/sgx_agent-*.bin $SGX_AGENT_BIN_DIR
	\cp -pf dist/linux/sgx_agent.env $SGX_AGENT_DIR
	popd
}

build_sgx_agent
