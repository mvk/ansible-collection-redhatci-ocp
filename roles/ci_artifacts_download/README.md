<!-- DOCSIBLE START -->

# 📃 Role overview

## ci_artifacts_download



Description: downloader for job artifacts


| Field                | Value           |
|--------------------- |-----------------|
| Readme update        | 16/12/2024 |




<details>
<summary><b>🧩 Argument Specifications in meta/argument_specs</b></summary>

#### Key: main 
**Description**: ['This is the main entrypoint for the redhat.ocp.ci_artifacts_download role.', 'It downloads last `jobs` of ci jobs of type `job_type` and unpacks them.']


  - **cad_jobs_map**
    - **Required**: True
    - **Type**: dict
    - **Default**: none
    - **Description**: ['The map of ci_artifacts_downloader configuration.']
  
  
  

  - **cad_job_profile**
    - **Required**: False
    - **Type**: str
    - **Default**: functional-tests
    - **Description**: ['Team profile, determines which cad_jobs_map configuration key to use']
  
  
  

  - **cad_target_path**
    - **Required**: False
    - **Type**: str
    - **Default**: {{ playbook_dir }}/{{ role_name }}/downloads
    - **Description**: ["Where to download jobs' archives"]
  
  
  

  - **cad_last_builds**
    - **Required**: False
    - **Type**: int
    - **Default**: 10
    - **Description**: ['How many job last builds artifacts to download']
  
  
  



</details>


### Defaults

**These are static variables with lower priority**

#### File: defaults/main.yml

| Var          | Type         | Value       |Required    | Title       |
|--------------|--------------|-------------|-------------|-------------|
| [cad_target_path](defaults/main.yml#L5)   | str   | `{{ playbook_dir }}/{{ role_name }}/downloads` |    n/a  |  n/a |
| [cad_last_builds](defaults/main.yml#L6)   | int   | `5` |    n/a  |  n/a |
| [cad_job_profile](defaults/main.yml#L7)   | str   | `functional-tests` |    n/a  |  n/a |





### Tasks


#### File: tasks/jenkins.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Setup cad_jobs map | ansible.builtin.set_fact | False |
| Print jobs map | ansible.builtin.debug | True |
| Setup jobs list | ansible.builtin.set_fact | False |
| Print jobs map | ansible.builtin.debug | True |
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
| Setup fact cad_curr_jobs_map | ansible.builtin.set_fact | False |
| Fail upon unsupported CI type | ansible.builtin.fail | True |
| Get artifacts of jobs from {{ cad_curr_jobs_map.type }} | ansible.builtin.include_tasks | True |




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