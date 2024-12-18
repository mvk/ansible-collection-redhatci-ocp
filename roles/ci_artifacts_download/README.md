<!-- DOCSIBLE START -->

# 📃 Role overview

## ci_artifacts_download



Description: Downloader role for CI job artifacts







<details>
<summary><b>🧩 Argument Specifications in meta/argument_specs</b></summary>

#### Key: main 
**Description**: The role downloads builds artifacts from CI server.
It puts all the builds artifacts under '{{ cad_target_path }}/{{ global_ci_type }}'



  - **global_ci_server_url**
    - **Required**: True
    - **Type**: str
    - **Default**: none
    - **Description**: CI Server URL

  
  
  

  - **global_ci_type**
    - **Required**: True
    - **Type**: str
    - **Default**: none
    - **Description**: CI server type. supported: ["jenkins"]

  
  
  

  - **cad_job_profile**
    - **Required**: False
    - **Type**: str
    - **Default**: functional-tests
    - **Description**: Team profile, determines which cad_jobs_map configuration key to use

  
  
  

  - **global_last_builds**
    - **Required**: False
    - **Type**: list
    - **Default**: []
    - **Description**: List of job information to fetch. List of dicts: ``` global_last_builds:
  - path: /job/bla-compute-4.16
    builds: 2
  - path: /view/ABC/job/DEF/job/bla-storage-4.17
    builds: 15
``` will ensure last 2 of the 1st and 15 of the 2nd will be downloaded

  
  
  
    
  

  - **cad_target_path**
    - **Required**: False
    - **Type**: str
    - **Default**: {{ playbook_dir }}/downloads
    - **Description**: Where to download jobs' archives

  
  
  



</details>


### Defaults

**These are static variables with lower priority**

#### File: defaults/main.yml

| Var          | Type         | Value       |Required    | Title       |
|--------------|--------------|-------------|-------------|-------------|
| [cad_job_profile](defaults/main.yml#L5)   | str   | `functional-tests` |    n/a  |  n/a |
| [cad_target_path](defaults/main.yml#L6)   | str   | `{{ playbook_dir }}/downloads` |    n/a  |  n/a |
| [global_last_builds](defaults/main.yml#L7)   | list   | `[]` |    n/a  |  n/a |
| [cad_timeout](defaults/main.yml#L8)   | int   | `15` |    n/a  |  n/a |





### Tasks


#### File: tasks/jenkins.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Setup cad_jobs map | ansible.builtin.set_fact | False |
| Sanity jenkins access check | ansible.builtin.uri | False |
| Fail if the connectivity to jenkins is broken | ansible.builtin.fail | False |
| Get list of last cad_jobs jenkins builds | ansible.builtin.uri | False |
| Download artifacts list in an organized manner | ansible.builtin.include_tasks | False |

#### File: tasks/dci.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| DCI is not supported yet | ansible.builtin.debug | False |

#### File: tasks/jenkins.download_builds_list.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Ensure builds artifacts containing folder | ansible.builtin.file | False |
| Download builds artifacts | ansible.builtin.get_url | False |

#### File: tasks/main.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Validate variables have loaded properly from vars file | ansible.builtin.assert | False |
| Validate global_ci_type | ansible.builtin.assert | False |
| Get artifacts of jobs from {{ global_ci_type }} | ansible.builtin.include_tasks | False |




## Playbook

```yml
---
# SPDX-License-Identifier: Apache-2.0

- hosts: localhost
  remote_user: root
  roles:
    - redhatci.ocp.ci_artifacts_download

```


## Author Information
Max Kovgan

#### License

Apache License, Version 2.0

#### Minimum Ansible Version

2.9

#### Platforms

No platforms specified.
<!-- DOCSIBLE END -->