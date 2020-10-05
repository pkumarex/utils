# Intel® Security Libraries for Data Center API Collections	

One click Postman API Collections for Intel® SecL-DC use-cases.


## Use Case Collections

| Use case               | Sub-Usecase                           | API Collection      |
| ---------------------- | ------------------------------------- | --------------------|
| Foundational Security  | Host Attestation                      | ✔️                  |
|                        | Data Fencing  with Asset Tags         | ✔️                  |
|                        | Trusted Workload Placement            | ✔️(Kubernetes Only) |
|                        | Application Integrity                 | ✔️                  |
| Launch Time Protection | VM Confidentiality                    | ❌                  |
|  | Container Confidentiality with Docker Runtime | ✔️ |
|  | Container Confidentiality with CRIO Runtime | ✔️ |
| Secure Key Caching |  | ✔️ |
| Security Aware Orchestration |  | ✔️(Kubernetes Only) |


## Requirements

* Intel® SecL-DC services installed and running as per chosen use case and deployment model supported as per [Product Guide]([https://01.org/intel-secl/documentation/intel%C2%AE-secl-dc-product-guide](https://01.org/intel-secl/documentation/intel®-secl-dc-product-guide)). Intel® SecL-DC also provides [Ansible playbooks]() to deploy services.
* Postman client [downloaded](https://www.postman.com/downloads/) and Installed or accessible via web



## Using the API Collections

### Downloading API Collections

* Postman API Network for latest release

  <TODO: add image>

  or 

* Github repo for older releases

  ```shell
  #Clone the github repo for api-collections
  git clone https://github.com/intel-secl/api-collections
  
  #Switch to specific release tag of choice
  git checkout <release-tag of choice>
  ```



### Running API Collections

* Import the collection into Postman API Client

  > **Note:** This step is required only when not using Postman API Network and downloading from Github

  ![importing-collection](./images/importing_collection.gif)

* Update env as per the deployment details for specific use case

  ![updating-env](./images/updating_env.gif)

* View Documentation

  ![view-docs](./images/view_documentation.gif)

* Run the workflow

  ![running-collection](./images/running_collection.gif)
