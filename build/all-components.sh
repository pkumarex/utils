#!/bin/bash

echo "Installing Foundational Security pre-reqs..."
cd foundational-security/
./fs-prereqs.sh -s
cd ..

echo "Installing Workload Security pre-reqs"
cd workload-security/

#VM-C
./ws-prereqs.sh -v

#Container-Conf-Docker
./ws-prereqs.sh -d

#Container-Conf-CRIO
./ws-prereqs.sh -c

