Ansible Role - Intel Security Libraries - DC
=====================================

An ansible role that installs Intel® Security Libraries for Data Center (Intel® SecL-DC) on supported Linux OS. 

Table of Contents
-----------------
  
   * [Ansible Role - Intel Security Libraries - DC](#ansible-role---intel-security-libraries---dc)
      * [Table of Contents](#table-of-contents)
      * [Requirements](#requirements)
      * [Dependencies](#dependencies)
      * [Usecase and Playbook Support](#usecase-and-playbook-support)
      * [Supported Deployment Model](#supported-deployment-model)
      * [Packages &amp; Repos Installed by Role](#packages--repos-installed-by-role)
      * [Supported Usecases and  Corresponding Components](#supported-usecases-and--corresponding-components)
      * [Example Inventory and Vars](#example-inventory-and-vars)
      * [Using the Role in Ansible](#using-the-role-in-ansible)
      * [Example Playbook and CLI](#example-playbook-and-cli)
      * [Additional Examples and Tips](#additional-examples-and-tips)
      * [Intel® SecL-DC Services Details](#intel-secl-dc-services-details)
      * [Role Variables](#role-variables)
      * [License](#license)
      * [Author Information](#author-information)


Requirements
------------

This role requires the following as pre-requisites:

1. **Build Machine and Ansible Server**<br>
   
   - The Build machine is required to build Intel® SecL-DC repositories. More details on building repositories in [Quick Start Guide - Foundational & Workload Security](https://github.com/intel-secl/docs/blob/master/quick-start-guides/Quick%20Start%20Guide%20-%20Intel%C2%AE%20Security%20Libraries%20-%20Foundational%20%26%20Workload%20Security.md) and in [Quick Start Guide - Secure Key Caching](https://github.com/intel-secl/docs/blob/master/quick-start-guides/Quick%20Start%20Guide%20-%20Intel%C2%AE%20Security%20Libraries%20-%20Secure%20Key%20Caching.md)
   - The Ansible Server is required to use this role to deploy Intel® SecL-DC services based on the supported deployment   model. The Ansible server is recommended to be installed on the Build machine itself. 
   - The role has been tested with `Ansible Version 2.9.10`
   
2. **Repositories and OS**<br>

   * **Foundational and Workload Security Usecases**
     * `RHEL 8.3` OS
     * Repositories to be enabled are `rhel-8-for-x86_64-appstream-rpms` and `rhel-8-for-x86_64-baseos-rpms`<br>
   * **Secure Key Caching**
     * `RHEL 8.2` OS / `Ubuntu 18.04` OS
     * Repositories to be enabled for RHEL OS are `rhel-8-for-x86_64-appstream-rpms` and `rhel-8-for-x86_64-baseos-rpms` and `codeready-builder-for-rhel-8-x86_64-rpms`<br>

3. **User Access**<br>
   Ansible should be able to talk to the remote machines using the `root` user and the Intel® SecL-DC services need to be installed as `root` user as well<br>

4. **Physical Server Requirements**<br>

   a. **Foundational and Workload Security Usecases**
      * Intel® SecL-DC supports and uses a variety of Intel security features, but there are some key requirements to consider before beginning an installation. Most important among these is the Root of Trust configuration. This involves deciding what combination of TXT, Boot Guard, tboot, and UEFI Secure Boot to enable on platforms that will be attested using Intel® SecL.

        > **Note:** At least one "Static Root of Trust" mechanism must be used (TXT and/or BtG). For Legacy BIOS systems, tboot must be used. For UEFI mode systems, UEFI SecureBoot must be used* Use the chart below for a guide to acceptable configuration options.Only dTPM is supported on Intel® SecL-DC platform hardware.  

        ![hardware-options](./images/trusted-boot-options.PNG)

        > **Note:** A security bug related to UEFI Secure Boot and Grub2 modules has resulted in some modules required by tboot to not be available on RedHat 8 UEFI systems. Tboot therefore cannot be used currently on RedHat 8. A future tboot release is expected to resolve this dependency issue and restore support for UEFI mode.

   b. **Secure Key Caching, SGX Attestation and SGX Orchestration Usecases**
      * Supported Hardware: Intel® Xeon® SP products those support SGX
      * BIOS Requirements: Intel® SGX-TEM BIOS requirements are outlined in the latest Intel® SGX Platforms BIOS Writer's Guide, Intel® SGX should be enabled in BIOS menu (Intel® SGX is Disabled by default on Ice Lake), Intel® SGX BIOS requirements include exposing Flexible Launch Control menu.
      * OS Requirements (Intel® SGX does not supported on 32-bit OS): Linux RHEL 8.2 / Linux Ubuntu 18.04<br>

Dependencies
------------

None



Usecase and Playbook Support on RHEL
------------------------------------

| Usecase                                            | Playbook Support |
| -------------------------------------------------- | ---------------- |
| Host Attestation                                   | Yes              |
| Data Fencing and Asset Tags                        | Yes              |
| Trusted Workload Placement                         | Yes(partial*)    |
| Application Integrity                              | Yes              |
| Launch Time Protection - VM Confidentiality        | Yes(partial*)    |
| Launch Time Protection - Container Confidentiality with Docker runtime | Yes(partial*)    |
| Launch Time Protection - Container Confidentiality with CRIO runtime | Yes(partial*)    |
| Secure Key Caching                                 | Yes              |
| SGX Orchestration                                  | Yes(partial*)    |
| SGX Attestation                                    | Yes(partial*)    |
   > **Note:** *partial means orchestrator installation is not bundled with the role and need to be done independently. Also, components dependent on the orchestrator like `isecl-k8s-extensions` and `integration-hub` are installed either partially or not installed

Usecase and Playbook Support on Ubuntu
--------------------------------------

| Usecase                                            | Playbook Support |
| -------------------------------------------------- | ---------------- |
| Secure Key Caching                                 | Yes              |


Supported Deployment Model
---------------------------

![deployment-model](./images/isecl_deploy_model.PNG)

* Build + Deployment Machine
* CSP - ISecL Services Machine
* CSP - Physical Server as per supported configurations
* Enterprise - ISecL Services Machine



Packages & Repos Installed by Role on RHEL
------------------------------------------

* tar
* dnf-plugins-core
* https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm


The below is installed for only `Launch Time Protection - Container Confidentiality with Docker Runtime` Usecase on Enterprise and Compute Node
* docker-ce-19.03.13


The below is installed for only `Launch Time Protection - Container Confidentiality with CRIO Runtime` Usecase on Enterprise and Compute Node
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/cri-o-1.17.5-4.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-1.0.7-13.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-debuginfo-1.0.7-13.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-debugsource-1.0.7-13.el8.x86_64.rpm 
* docker-ce-19.03.13
* skopeo
* crio
> **Note** : As part of CRIO installation,  this role would also configure crio runtime to work with Intel® SecL-DC

Repo & Key Installed by Role on Ubuntu
--------------------------------------------

* https://apt.postgresql.org/pub/repos/apt
* https://www.postgresql.org/media/keys/ACCC4CF8.asc


Supported Usecases and  Corresponding Components
------------------------------------------------

The following usecases are supported and the respective variables can be provided directly in the playbook or `--extra-vars` in command line.

| Usecase                                            | Variable                                                     |
| -------------------------------------------------- | ------------------------------------------------------------ |
| Host Attestation                                   | `setup: host-attestation` in playbook or via `--extra-vars` as `setup=host-attestation` in CLI |
| Application Integrity                              | `setup: application-integrity` in playbook or via `--extra-vars` as `setup=application-integrity` in CLI |
| Data Fencing & Asset Tags                          | `setup: data-fencing` in playbook or via `--extra-vars` as `setup=data-fencing` in CLI |
| Trusted Workload Placement - VM            | `setup: trusted-workload-placement-vm` in playbook or via `--extra-vars` as `setup=trusted-workload-placement-vm` in CLI |
| Trusted Workload Placement - Containers            | `setup: trusted-workload-placement-containers` in playbook or via `--extra-vars` as `setup=trusted-workload-placement-containers` in CLI |
| Launch Time Protection - VM Confidentiality        | `setup: workload-conf-vm` in playbook or via `--extra-vars` as `setup=workload-conf-vm` in CLI |
| Launch Time Protection - Container Confidentiality with Docker Runtime | `setup: workload-conf-containers-docker` in playbook or via `--extra-vars` as `setup=workload-conf-containers-docker`in CLI |
| Launch Time Protection - Container Confidentiality with CRIO Runtime | `setup: workload-conf-containers-crio` in playbook or via `--extra-vars` as `setup=workload-conf-crio`in CLI |
| Secure Key Caching                                 | `setup: secure-key-caching` in playbook or via `--extra-vars` as `setup=secure-key-caching`in CLI |
| SGX Orchestration                                  | `setup: sgx-orchestration` in playbook or via `--extra-vars` as `setup=sgx-orchestration`in CLI |
| SGX Attestation                                    | `setup: sgx-attestation` in playbook or via `--extra-vars` as `setup=sgx-attestation`in CLI |


The ISecL services and scripts required w.r.t each use case is as follows. The binaries and scripts are generated when Intel® SecL-DC repositories are built.

> **Note**: The DB installation done as part of this role using `Bootstrap Database` task is a local installation and not a remote DB installation.

**Host Attestation**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Application Integrity**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Data Fencing & Asset Tags**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Trusted Workload Placement - VM**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Integration Hub
7. Trust Agent
> **Note**: `Trusted Workload Placement - VM` requires orchestrators `Openstack` and `integration-hub` to be configured to talk to Openstack. 
    The playbook will place the `integration-hub` installer and configure the env except for `Openstack` configuration in the `ihub.env`. 
    Once `Openstack` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Openstack and installation of `integration-hub`<br>

**Trusted Workload Placement - Containers**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Integration Hub
7. Trust Agent
> **Note**: `Trusted Workload Placement - Containers` requires orchestrator `Kubernetes` and `integration-hub` to be configured to talk to Kubernetes. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`. 
    Once `kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Kubernetes and installation of `integration-hub`<br>

**Launch Time Protection - VM Confidentiality**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Workload Service
7. Key Broker Service
8. Workload Policy Manager
9. Trust Agent
10. Workload Agent
> **Note**: `Trusted Workload Placement - VM` requires orchestrators `Openstack` and `integration-hub` to be configured to talk to Openstack. 
    The playbook will place the `integration-hub` installer and configure the env except for `Openstack` configuration in the `ihub.env`. 
    Once `Openstack` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Openstack and installation of `integration-hub`<br>

**Launch Time Protection - Container Confidentiality with Docker Runtime**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Workload Service
7. Key Broker Service
8. Workload Policy Manager
9. Docker(runtime)
10.  Trust Agent
11. Workload Agent
> **Note**: `Launch Time Protection - Container Confidentiality with Docker Runtime` requires `Kubernetes` orchestrator .
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `Kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed.
    Please refer product guide for supported versions of orchestrator and setup details for installing `integration-hub` 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes master. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**Launch Time Protection - Container Confidentiality with CRIO Runtime**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Workload Service
7. Key Broker Service
8. Docker(Runtime)
9. Skopeo
10. Workload Policy Manager
11. Trust Agent
12. Crio(Runtime)
13. Workload Agent
> **Note**: `Launch Time Protection - Container Confidentiality with CRIO Runtime` requires `Kubernetes` orchestrator .
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `Kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes master. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**Secure Key Caching**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SGX Quote Verfication Service
7. Key Broker Service
8. SGX Agent
9. SKC Library

**SGX Orchestration**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. Key Broker Service
9. SGX Agent
10. SKC Library
> **Note**: `SGX Orchestration` requires `kubernetes` orchestrator .
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes master. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**SGX Attestation**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. SGX Agent
9. SGX Dependencies
> **Note**: For`SGX Attestation` orchestration is optional. It requires `kubernetes` orchestrator.
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes master. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

Example Inventory and Vars
--------------------------

In order to deploy Intel® SecL-DC binaries, the following inventory can be used and the required inventory vars as below need to be set. The below example inventory can be created under `/etc/ansible/hosts`

On RHEL:
```
[CSP]
<machine1_ip/hostname>

[Enterprise]
<machine2_ip/hostname>

[Node]
<machine3_ip/hostname>

[CSP:vars]
isecl_role=csp
ansible_user=root
ansible_password=<password>

[Enterprise:vars]
isecl_role=enterprise
ansible_user=root
ansible_password=<password>

[Node:vars]
isecl_role=node
ansible_user=root
ansible_password=<password>
```

On Ubuntu:
```
[CSP]
<machine1_ip/hostname>

[Enterprise]
<machine2_ip/hostname>

[Node]
<machine3_ip/hostname>

[CSP:vars]
isecl_role=csp
ansible_user=<ubuntu_user>
ansible_password=<password>

[Enterprise:vars]
isecl_role=enterprise
ansible_user=<ubuntu_user>
ansible_password=<password>

[Node:vars]
isecl_role=node
ansible_user=<ubuntu_user>
ansible_password=<password>
```

> **Note:** Ansible requires `ssh` and `root` user access to remote machines. The following command can be used to ensure ansible can connect to remote machines with host key check `
  ```shell
  ssh-keyscan -H <ip_address> >> /root/.ssh/known_hosts
  ```

Using the Role in Ansible
-------------------------

The role can be cloned locally from git and the contents can be copied to the roles folder used by your ansible server <br>

```shell
#Create directory for using ansible deployment
mkdir -p /root/intel-secl/deploy/

#Clone the repository
cd /root/intel-secl/deploy/ && git clone https://github.com/intel-secl/utils.git

#Checkout to specific release version
cd utils/
git checkout <release-version of choice>
cd tools/ansible-role

#Update `roles_path` under `ansible.cfg` to point to /root/intel-secl/deploy/utils/tools/
```



Example Playbook and CLI
------------------------

The following are playbook and CLI example for deploying Intel® SecL-DC binaries based on the supported deployment models and usecases. The below example playbooks can be created as `site-bin-isecl.yml`

> **Note:** If running behind a proxy, update the proxy variables under `vars/main.yml` and run as below

> **Note:** Go through the `Additional Examples and Tips` section for specific workflow samples

Playbook

```yaml
- hosts: all
  any_errors_fatal: true
  gather_facts: yes
  vars:
    setup: <setup var from supported usecases>
    binaries_path: <path where built binaries are copied to>
  roles:   
  - ansible-role
  environment:
    http_proxy: "{{http_proxy}}"
    https_proxy: "{{https_proxy}}"
    no_proxy: "{{no_proxy}}"
```

and

```shell
ansible-playbook <playbook-name>
```

> **Note:** Update the `roles_path` under `ansible.cfg` to point to the cloned repository so that the role can be read by Ansible


or (skip `vars` from above playbook and provide using CLI of ansible)

Playbook

```yaml
- hosts: all
  any_errors_fatal: true 
  gather_facts: yes
  roles:   
  - ansible-role
  environment:
    http_proxy: "{{http_proxy}}"
    https_proxy: "{{https_proxy}}"
    no_proxy: "{{no_proxy}}"
```

and

```shell (on RHEL)
ansible-playbook <playbook-name> --extra-vars setup=<setup var from supported usecases> --extra-vars binaries_path=<path where built binaries are copied to>
```

```shell (on Ubuntu)
ansible-playbook <playbook-name> --extra-vars setup=<setup var from supported usecases> --extra-vars binaries_path=<path where built binaries are copied to> --extra-vars "ansible_sudo_pass=<password>"
```

> **Note:** Update the `roles_path` under `ansible.cfg` to point to the cloned repository so that the role can be read by Ansible


Additional Examples and Tips
----------------------------

#### TPM is already owned

If the Trusted Platform Module(TPM) is already owned, the owner secret(SRK) can be provided directly during runtime in the playbook:

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars tpm_secret=<tpm owner secret>
```
or

Update the following vars in `defaults/main.yml`

```yaml
# The TPM Storage Root Key(SRK) Password to be used if TPM is already owned
tpm_owner_secret: <tpm_secret>
```

#### UEFI SecureBoot enabled

If UEFI mode and UEFI SecureBoot feature is enabled, the following option can be used to during runtime in the playbook

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars uefi_secureboot=yes \
--extra-vars grub_file_path=<uefi mode grub file path>
```

or

Update the following vars in `defaults/main.yml`

```yaml
# Enable/disable for UEFI SecureBoot Mode
# [yes - UEFI SecureBoot mode, no - Legacy mode]
uefi_secureboot: 'yes'

# The grub file path for Legacy mode & UEFI Mode. Default is Legacy mode path. Update the below path for UEFI mode with UEFI SecureBoot
grub_file_path: <uefi mode grub file path>
```

#### Deploying for Workload Confidentiality with CRIO Runtime

If using for `Launch Time Protection - Workload Confidentiality with CRIO Runtime` , following option can be provided during runtime in playbook. By default, the playbook is configured to install for `Launch Time Protection - Workload Confidentiality with Docker Runtime`

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars skip_sdd=yes
```
or

Update the following vars in `defaults/main.yml`

```yaml
#Enable/disable container security for CRIO runtime
# [yes - Launch Time Protection with CRIO Containers, NA - others]
skip_secure_docker_daemon: <skip_sdd>
```

#### Using Docker Notary

If using Docker notary when working with `Launch Time Protection - Workload Confidentiality with Docker Runtime`, following options can be provided during runtime in the playbook

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars insecure_verify=<insecure_verify[TRUE/FALSE]> \
--extra-vars registry_ipaddr=<registry ipaddr> \
--extra-vars registry_scheme=<registry scheme[http/https]>
```
or

Update the following vars in `defaults/main.yml`

```yaml
# [TRUE/FALSE based on registry configured with http/https respectively]
# Required for Workload Integrity with containers
insecure_skip_verify: <insecure_skip_verify>

# The registry IP for the Docker registry from where container images are pulled
# Required for Workload Integrity with containers
registry_ip: <registry_ipaddr>

# The registry protocol for talking to the remote registry [http/https]
# Required for Workload Integrity with containers
registry_scheme_type: <registry_scheme>
```

#### In case of Misconfigurations 

If any service installation fails due to any misconfiguration, just uninstall the specific service manually , fix the misconfiguration in ansible and rerun the playbook. The successfully installed services wont be reinstalled.


Intel® SecL-DC Services Details
-------------------------------

The details for the file locations of Intel® SecL-DC services are as follows as per the installation done by the role

**Certificate Management Service**<br>

Installation log file: `/root/certificate_management_service-install.log`<br>
Service files: `/opt/cms`<br>
Configuration files: `/etc/cms`<br>
Log files: `/var/log/cms`<br>
Default Port: `8445`<br>
<br>

**Authentication and Authorization Service**<br>

Installation log file: `/root/authentication_authorization_service-install.log`<br>
Service files: `/opt/aas`<br>
Configuration files: `/etc/aas`<br>
Log files: `/var/log/aas`<br>
Default Port: `8444`<br>
<br>

**Host Verification Service**<br>

Installation log file: `/root/host_verification_service-install.log`<br>
Service files: `/opt/hvs`<br>
Configuration files: `/etc/hvs`<br>
Log files: `/var/log/hvs`<br>
Default Port: `8443`<br>
<br>

**Integration Hub**<br>

Installation log file: `/root/integration_hub-install.log`<br>
Service files: `/opt/ihub`<br>
Configuration files: `/etc/ihub`<br>
Log files: `/var/log/ihub`<br>
Default Port: `none`<br>

**Workload Service**<br>

Installation log file: `/root/workload_service-install.log`<br>
Service files: `/opt/workload-service`<br>
Configuration files: `/etc/workload-service`<br>
Log files: `/var/log/workload-service`<br>
Default Port: `5000`<br>
<br>

**Key Broker Service**<br>

Installation log file: `/root/key_broker_service-install.log`<br>
Service files: `/opt/kbs`<br>
Configuration files: `/opt/kbs/configuration`<br>
Log files: `/opt/kbs/logs`<br>
Default Port: `9443`<br>
<br>

**Workload Policy Manager**<br>

Installation log location: `/root/key_broker_service-install.log`<br>
Service files: `/opt/workload-policy-manager`<br>
Configuration files: `/etc//workload-policy-manager`<br>
Log files: `/var/log/workload-policy-manager`<br>
Default Port: `none`<br>
<br>

**Trust Agent**<br>

Installation log location: `/root/trust_agent-install.log`<br>
Service files: `/opt/trustagent`<br>
Configuration files: `/opt/trustagent/configuration`<br>
Log files: `/var/log/trustagent/`<br>
Default Port: `1443`<br>
<br>

**Workload Agent**<br>

Installation log location: `/root/workload_agent-install.log`<br>
Service files: `/opt/workload-agent`<br>
Configuration files: `/etc/workload-agent`<br>
Log files: `/var/log/workload-agent/`<br>
Default Port: `none`<br>

**SGX Caching Service**<br>

Installation log file: `/root/sgx_caching_service-install.log`<br>
Service files: `/opt/scs`<br>
Configuration files: `/etc/scs`<br>
Log files: `/var/log/scs`<br>
Default Port: `9000`<br>
<br>

**SGX Host Verification Service**<br>

Installation log file: `/root/sgx_host_verification_service-install.log`<br>
Service files: `/opt/shvs`<br>
Configuration files: `/etc/shvs`<br>
Log files: `/var/log/shvs`<br>
Default Port: `13000`<br>
<br>

**SGX Quote Verification Service**<br>

Installation log file: `/root/sgx_quote_verification_service-install.log`<br>
Service files: `/opt/sqvs`<br>
Configuration files: `/etc/sqvs`<br>
Log files: `/var/log/sqvs`<br>
Default Port: `12000`<br>
<br>

**SKC Integration Hub**<br>

Installation log file: `/root/integration_hub-install.log`<br>
Service files: `/opt/ihub`<br>
Configuration files: `/etc/ihub`<br>
Log files: `/var/log/ihub`<br>
Default Port: `none`<br>
<br>

**SGX Agent**<br>

Installation log file: `/root/sgx_agent-install.log`<br>
Service files: `/opt/sgx_agent`<br>
Configuration files: `/etc/sgx_agent`<br>
Log files: `/var/log/sgx_agent`<br>
Default Port: `none`<br>
<br>

**SKC Library**<br>

Installation log file: `/root/skc_library-install.log`<br>
Service files: `/opt/skc`<br>
Configuration files: `none`<br>
Log files: `none`<br>
Default Port: `none`<br>
<br>

**SGX Dependencies**<br>

Installation log file: `/root/sgx-dependency-installer.log`<br>
Service files: `none`<br>
Configuration files: `none`<br>
Log files: `none`<br>
Default Port: `none`<br>
<br>

Role Variables
--------------

The Default variables under `defaults/main.yml` need to be modified only if any specific changes are required, else they can be used as is to deploy Intel® SecL-DC libraries. 
The variables under `vars/main.yml` need to updated if running behind a proxy(defaults are emtpy), can be left as is if proxy is not required.

The description for default variables under `defaults/main.yml` for each service and other variables under `vars/main.yml` along with the required variables per usecase is given below.

**Certificate Management Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | --------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|-----------------|
| cms_installer_file_src               | The binary installer file src for Certificate Management Service | Yes              | Yes                   | Yes                       | Yes                                        | Yes                                                | Yes     | Yes    | Yes   |
| cms_installer_name                   | The name of the binary installer as per the release tag for Certificate Management Service | Yes              | Yes                   | Yes                       | Yes                                        | Yes                                                | Yes     | Yes    | Yes   |
| cms_port                             | The port to be used by Certificate Management Service        | Yes              | Yes                   | Yes                       | Yes                                        | Yes                                                | Yes     | Yes    | Yes   |
| authservice_port                     | The port to be used by Authentication & Authorization Service | Yes              | Yes                   | Yes                       | Yes                                        | Yes                                                | Yes     |  Yes    | Yes   |



**Bootstrap DB**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- | --------------- |
| isecl_pgdb_installer_file_src        | The shell script file src for installing postgres DB         | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| isecl_pgdb_create_db_file_src        | The shell script file src for creating DB tables for services | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| isecl_pgdb_repo_list                 | The repo list for postgres DB on Ubuntu                       | no              | no                    | no                       | no                                        | no                                                | Yes     | no    | no   |
| isecl_pgdb_port                      | The port to be used by postgres DB                           | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| isecl_pgdb_save_db_install_log       | Save postgres DB install logs [true/false]                   | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_db_name                          | The db name for Authentication and Authorization Service     | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_db_user                          | The db user for Authentication and Authorization Service     | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_db_password                      | The db password for Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| hvs_db_name                          | The db name for Verification Service                         | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| hvs_db_user                          | The db user for Verification Service                         | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| hvs_db_password                      | The db password for Verification Service                     | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| wls_db_name                          | The db name for Workload Service                             | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| wls_db_user                          | The db user for Workload Service                             | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| wls_db_password                      | The db password for Workload Service                         | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | Yes   |
| scs_db_hostname                          | The db hostname for SGX Caching Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| scs_db_name                          | The db name for SGX Caching Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| scs_db_user                          | The db user for SGX Caching Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| scs_db_password                      | The db password SGX Caching Service                         | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| shvs_db_hostname                          | The db hostname for SGX Host Verification Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| shvs_db_name                          | The db name for SGX Host Verification Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| shvs_db_user                          | The db user for SGX Host Verification Service                             | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |
| shvs_db_password                      | The db password SGX Host Verification Service                         | no              | no                    | no                       | no                                        | no                                                | Yes     | Yes    | Yes   |


**Authentication and Authorization Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- | --------------- |
| aas_installer_file_src               | The binary installer file src for Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_installer_name                   | The name of the binary installer as per the release tag for Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_port                             | The port to be used by Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_admin_username                   | The service account username for Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |
| aas_admin_password                   | The service password for Authentication and Authorization Service | yes              | yes                    | yes                       | yes                                        | yes                                                | Yes     | Yes    | Yes   |


**Host Verification Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- | --------------- |
| hvs_installer_file_src               | The binary installer file src for Host Verification Service  | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    | 
| hvs_installer_name                   | The name of the binary installer as per release tag for Host Verification Service | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |
| hvs_port                             | The port to be used by Host Verification Service             | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |
| hvs_service_username                 | The service account username for Host Verification Service   | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |
| hvs_service_password                 | The service account password for Host Verification Service   | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |

**Populate Users Script**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| populate_users_script_file_src       | The shell script file source for populating users in Auth Service DB | yes              | yes                    | yes                       | yes                                        | yes                                        | No     | No    | No    |
| global_admin_username                | The admin username for accessing all endpoints in each service | yes              | yes                    | yes                       | yes                                        | yes                                                                   | No     | No    | No    |
| global_admin_password                | The admin password for accessing all endpoints in each service | yes              | yes                    | yes                       | yes                                        | yes                                              | No     | No    | No    |
| install_admin_username               | The installer admin username for installing services based on usecases | yes              | yes                    | yes                       | yes                                        | yes                                      | No     | No    | No    |
| install_admin_password               | The installer admin password for installing services based on usecases | yes              | yes                    | yes                       | yes                                        | yes                                      | No     | No    | No    |


**Integration Hub**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| ihub_installer_file_src              | The binary installer file source for Integration Hub         | no               | no                     | yes                       | yes                                        | yes                                                 | No     | No    | No    |
| ihub_installer_file_name             | The name of the binary installer as per release tag  for Integration Hub | no               | no                     | yes                       | yes                                        | yes                                      | No     | No    | No    |
| ihub_http_port                       | The http port for running the Integration hub                | no               | no                     | yes                       | yes                                        | yes                                                 | No     | No    | No    |
| ihub_https_port                      | The https port for running the Integration hub               | no               | no                     | yes                       | yes                                        | yes                                                 | No     | No    | No    |
| ihub_service_username                | The service account username name for Integration hub        | no               | no                     | yes                       | yes                                        | yes                                                 | No     | Yes    | Yes    |
| ihub_service_password                | The service account password for Integration hub             | no               | no                     | yes                       | yes                                        | yes                                                 | No     | Yes    | Yes    |


**Workload Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------| --------------- |
| wls_installer_file_src               | The binary installer file source for Workload Service        | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wls_installer_file_name              | The name of the binary installer as per release tag for Workload Service | no               | no                     | no                        | yes                                        | yes                                                         | No     | No    | No    |
| wls_port                             | The port for running the Workload Service                    | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wls_service_username                 | The service account username name for Workload Service       | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wls_service_password                 | The service account password for Workload Service            | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |


**Key Broker Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality| Secure Key Caching | SGX Orchestration| SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | --------------------------------------------------| ------------------- | -----------------| --------------- |
| kbs_installer_file_src               | The binary installer file source for Key Broker Service      | no               | no                     | no                        | yes                                        | yes                                                | Yes     | Yes   | No    |
| kbs_installer_file_name              | The name of the binary installer as per release tag for Key Broker Service | no               | no                     | no                        | yes                                        | yes                                   | Yes     | Yes    | No    |
| kbs_port                             | The port for running the Key Broker Service                  | no               | no                     | no                        | yes                                        | yes                                                | Yes     | Yes    | No    |
| kbs_admin_username              | The service account username for SKC Key Broker Service | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | No    |
| kbs_admin_password                 | The service account password for SKC Key Broker Service       | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | No    |

**SKOPEO**

| Default variable (defaults/main.yml) | Description                                 | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------- | ---------------- | ---------------------- | ------------------------- | ------------------------------------------- | -------------------------------------------------- | ------------------ | ------------------|---------------- |
| skopeo_installer_file_src            | The binary installer file source for Skopeo | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No              |
| skopeo_installer_file_name           | The binary installer file source for Skopeo | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No              |

**Docker**

| Default variable (defaults/main.yml) | Description    | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | -------------- | ---------------- | ---------------------- | ------------------------- | ------------------------------------------- | -------------------------------------------------- | ------------------ | ------------------|---------------- |
| docker_version                       | Docker Version | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No              | 


**Workload Policy Manager**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- | --------------- |
| wpm_installer_file_src               | The binary installer file source for Workload Policy Manager | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wpm_installer_file_name              | The name of the binary installer as per release tag for Workload Policy Manager | no               | no                     | no                        | yes                                        | yes                                                  | No     | No    | No    |
| wpm_admin_username                   | The service account username name for Workload Policy Manager | no               | no                     | no                        | yes                                        | yes                                               | No     | No    | No    |
| wpm_admin_password                   | The service account password for Workload Policy Manager     | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wpm_container_security               | Enable/disable Workload Policy Manager Installation with container security [ yes - Launch Time Protection - Container Confidentiality, no - others] | no               | no                     | no       | yes     | yes            | No     | No    | No    |

**Trust Agent**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| ta_installer_file_src                | The binary installer file source for Trust Agent             | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |
| ta_installer_file_name               | The name of the binary installer as per release tag for  Trust Agent | yes              | yes                    | yes                       | yes                                        | yes                                                             | No     | No    | No    |
| grub_file                            | The grub.cfg path on the OS                                  | yes              | yes                    | yes                       | yes                                        | yes                                                | No     | No    | No    |
| tpm_owner_secret                     |                                                              | yes*             | yes*                   | yes*                      | yes*                                       | yes*                                               | No     | No    | No    |
| wa_with_container_security           | Enable/disable Trust Agent Installation with container security [yes - Launch Time Protection - Container Confidentiality, no - others] | no               | no                     | no       | no  | yes                             | No     | No    | No    |
| insecure_skip_verify                 |                                                              | no               | no                     | no                        | no                                         | yes                                                | No     | No    | No    |
| registry_ip                          | The registry IP for the registry from where Docker images are pulled | no               | no                     | no                        | no                                         | yes                                        | No     | No    | No    |
| https_proxy                          | Proxy details if running behind a proxy                      | no               | no                     | no                        | no                                         | yes                                                | No     | No    | No    |
| registry_scheme_type                 | The registry protocol for talking to the remote registry     | no               | no                     | no                        | no                                         | yes                                                | No     | No    | No    |
| skip_secure_docker_daemon            | Enable/disable container security for CRIO runtime           | no               | no                     | no                        | no                                         | yes                                                | No     | No    | No    |
> **NOTE: ** `*`Required if TPM is already owned  and not cleared

**CRIO**

| Default variable (defaults/main.yml) | Description                               | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ----------------------------------------- | ---------------- | ---------------------- | ------------------------- | ------------------------------------------- | -------------------------------------------------- | ------------------ | ----------------- |---------------- |
| crio_version                         | CRIO Version                              | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No                |
| crictl_version                       | crictl version                            | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No                |
| crio_installer_file_name             | The name of the binary installer for CRIO | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No                |
| crio_file_src                        | The binary installer file source for CRIO | no               | no                     | no                        | yes                                         | yes                                                | No                 | No                | No                |

**Workload Agent**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- |-----------------|
| wla_installer_file_src               | The binary installer file source for Workload Agent          | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wla_installer_file_name              | The name of the binary installer as per release tag for Workload Agent | no               | no                     | no                        | yes                                        | yes                                                           | No     | No    | No    |
| wla_service_username                 | The service account username name for Workload Agent         | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |
| wla_service_password                 | The service account password for Workload Agent              | no               | no                     | no                        | yes                                        | yes                                                | No     | No    | No    |


**SGX Caching Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration |SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|--------------- |
| scs_port               | The port for running the SGX Caching Service          | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| scs_admin_username              | The service account username for SGX Caching Service | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | Yes    |
| scs_admin_password                 | The service account password for SGX Caching Service        | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| scs_installer_name                 | The name of the binary installer as per the release tag for SGX Caching Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| scs_installer_file_src                 | The binary installer file source for SGX Caching Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| intel_provisioning_server_sandbox    | The URL for Intel Provisioning Server              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| intel_provisioning_server_api_key_sandbox | The API for Intel Provisioning Server              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |


**SGX Host Verification Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation  |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ----------------- |----------------- |
| shvs_port               | The port for running the SGX Host Verification Service          | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| shvs_admin_username              | The service account username for SGX Host Verification Service | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | Yes    |
| shvs_admin_password                 | The service account password for SGX Host Verification Service        | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| shvs_installer_name                 | The name of the binary installer as per the release tag for SGX Host Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| shvs_installer_file_src                 | The binary installer file source for SGX Host Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |


**SGX Quote Verification Service**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------| --------------- |
| sqvs_port               | The port for running the SGX Quote Verification Service          | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sqvs_admin_username              | The service account username for SGX Quote Verification Service | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | Yes    |
| sqvs_admin_password                 | The service account password for SGX Quote Verification Service        | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sqvs_installer_name                 | The name of the binary installer as per the release tag for SGX Quote Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sqvs_installer_file_src                 | The binary installer file source for SGX Quote Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sqvs_trusted_rootca_filename                 | The name of the trusted root ca file for SGX Quote Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sqvs_trusted_rootca_file_src                 | The trusted root ca file source for SGX Quote Verification Service              | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |


**SGX Agent**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| sgxagent_installer_name               | The name of the binary installer as per release tag for SGX Agent         | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sgxagent_installer_file_src              | The binary installer file source for SGX Agent | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | Yes    |
| sgxagent_admin_username               | The service account username for  SGX Agent         | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | Yes    |
| sgxagent_admin_password               | The service account password for  SGX Agent | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | Yes    |


**SKC Library**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| skclib_installer_name               | The name of the binary installer as per release tag for SKC Library         | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | No    |
| skclib_installer_file_src              | The binary installer file source for SKC Library | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | No    |
| skclib_admin_username               | The service account username for SKC Library         | no               | no                     | no                        | no                                        | no                                                | Yes     | Yes    | No    |
| skclib_admin_password              | The service account password for SKC Library | no               | no                     | no                        | no                                        | no                                                           | Yes     | Yes    | No    |

**SGX Dependencies**

| Default variable (defaults/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ------------------------------------ | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------ | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| sgxdep_installer_file_name             | The name of the binary installer as per release tag for SKC Library         | no               | no                     | no                        | no                                        | no                                                | No     | No    | Yes    |
| sgxdep_installer_file_src              | The binary installer file source for SKC Library | no               | no                     | no                        | no                                        | no                                                           | No     | No    | Yes    |


**Other Variables**

| variable(vars/main.yml) | Description                                                  | Host Attestation | Application  Integrity | Data Fencing & Asset Tags | Launch Time Protection - VM Confidentiality | Launch Time Protection - Container Confidentiality | Secure Key Caching | SGX Orchestration | SGX Attestation |
| ----------------------- | ------------------------------------------------------------ | ---------------- | ---------------------- | ------------------------- | ------------------------------------------- | -------------------------------------------------- | ------------------- | ------------------|---------------- |
| postgres_db_rpm         | The RPM download URL for postgresql                          | yes              | yes                    | yes                       | yes                                         | yes                                                | yes                 | yes               | yes             |
| postgres_rpm_name       | The postgresql RPM  file name                                | yes              | yes                    | yes                       | yes                                         | yes                                                | yes                 | yes               | yes             |
| postgres_db_apt_repo    | The apt repo for postgresql on Ubuntu OS                     | no               | no                     | no                        | no                                          | no                                                 | yes                 | no               | no             |
| postgres_db_apt_repo_signing_key       | The apt repo signing key for postgresql on Ubuntu OS                                | no              | no                    | no                       | no                                         | no                                                | yes                 | no               | no             |
| http_proxy              | The http_proxy for setting up Intel® SecL-DC libraries       | yes*             | yes*                   | yes*                      | yes*                                        | yes*                                               | yes                 | yes               | yes             |
| https_proxy             | The http_proxy for setting up Intel® SecL-DC libraries       | yes*             | yes*                   | yes*                      | yes*                                        | yes*                                               | yes                 | yes               | yes             |
| no_proxy                | The no_proxy (comma separated) for setting up Intel® SecL-DC libraries | yes*             | yes*                   | yes*                      | yes*                                        | yes*                                               | yes                 | yes               | yes             |

> **Note:** `*` required only if running behind a proxy



License
-------

BSD



Author Information
------------------

This role is developed by Intel® SecL-DC team