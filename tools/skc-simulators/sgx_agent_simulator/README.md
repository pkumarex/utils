SGX Agent Simulator
===================

`SGX Agent Simulator` is primarily involved in SGX technology discovery and
collection of SGX attributes on a SGX enabled platform (Single
Socket/Multi socket).

Key features
------------

-   SGX agent simulator required for registering dummy host as per
    host count in env file.
-   Collects the SGX platform-specific values, explicitly Encrypted
    PPID, CPU SVN, ISV SVN, PCE ID, Manifest and QEID.
-   SGX Agent simulator provides dummy platform SGX-related information 
    to the SGX Host Verification Service.

System Requirements
-------------------

-   RHEL 8.2
-   Epel 8 Repo
-   Proxy settings if applicable
-   SHVS should be up and running

Software requirements
---------------------

-   git
-   makeself
-   Go 1.14.1 or newer

Step By Step Build Instructions
===============================

Install required shell commands
-------------------------------

### Install tools from `dnf`

``` {.shell}
sudo dnf install -y git wget makeself
```

### Install `go 1.14.1` or newer

The `Certificate Management Service` requires Go version 1.14 that has
support for `go modules`. The build was validated with version 1.14.1
version of `go`. It is recommended that you use a newer version of `go`
- but please keep in mind that the product has been validated with
1.14.1 and newer versions of `go` may introduce compatibility issues.
You can use the following to install `go`.

``` {.shell}
wget https://dl.google.com/go/go1.14.1.linux-amd64.tar.gz
tar -xzf go1.14.1.linux-amd64.tar.gz
sudo mv go /usr/local
export GOROOT=/usr/local/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

Build SGX Agent Simulator
-------------------------

-   Git clone the SGX Agent simulator and generate binary

``` {.shell}
git clone https://github.com/intel-secl/utils.git && cd utils
git checkout v3.3.1/develop
cd tools/skc-simulators/sgx_agent_simulator/sgx_agent_simulator_automation/build_scripts/
```
-   Run scripts to build the SGX Agent Simulator

``` {.shell}
#./sgxagent_build.sh
- This script will generate a tarball(sgx_agent.tar) and checksum file(sgx_agent.sha2).
- Copy sgx_agent.tar, sgx_agent.sha2 and agent_untar.sh(from sgx_agent directory) to a directory in the deployment machine.
- run agent_untar.sh to untar sgx_agent.tar
#./agent_untar.sh
- update HOST_COUNT in env file.
- update agent.conf
- To deploy SGX Agent Simulator
#./deploy_sgx_agent.sh.
```

### Manage service

-   Start service
    -   sgx\_agent start
-   Stop service
    -   sgx\_agent stop
-   Status of service
    -   sgx\_agent status

## Third Party Dependencies

- Certificate Management Service

- Authentication and Authorization Service

### Direct dependencies

  Name       Repo URL                            Minimum Version Required
  ---------- ----------------------------- ------------------------------------
  uuid       github.com/google/uuid                       v1.1.2
  cpuid      github.com/klauspost/cpuid                   v1.2.1
  handlers   github.com/gorilla/handlers                  v1.4.0
  mux        github.com/gorilla/mux                       v1.7.3
  errors     github.com/pkg/errors                        v0.9.1
  logrus     github.com/sirupsen/logrus                   v1.4.0
  testify    github.com/stretchr/testify                  v1.3.0
  yaml.v2    gopkg.in/yaml.v2                             v2.2.2
  clients    github.com/intel-secl/clients                v3.3.0
  common     github.com/intel-secl/common         	  v3.3.0


*Note: All dependencies are listed in go.mod*

Links
=====

<https://01.org/intel-secl/>
