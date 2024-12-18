<!-- DOCSIBLE START -->

# 📃 Role overview

## ci_artifacts_unpack



Description: ci jobs' builds' artifacts unpacker


| Field                | Value           |
|--------------------- |-----------------|
| Readme update        | 18/12/2024 |




<details>
<summary><b>🧩 Argument Specifications in meta/argument_specs</b></summary>

#### Key: main 
**Description**: ['This is the companion role for `redhatci.ocp.ci_artifacts_download`.', 'It scans the download folder for archives, and unpacks them incl. internal archives.']


  - **cau_target_path**
    - **Required**: True
    - **Type**: str
    - **Default**: none
    - **Description**: ["Where reside jobs' archives"]
  
  
  

  - **cau_job_profile**
    - **Required**: False
    - **Type**: str
    - **Default**: functional-tests
    - **Description**: ['Team profile, determines which configuration key to use']
  
  
  

  - **cau_supported_archives**
    - **Required**: False
    - **Type**: list
    - **Default**: ['zip']
    - **Description**: ["Where to download jobs' archives"]
  
  
  



</details>


### Defaults

**These are static variables with lower priority**

#### File: defaults/main.yml

| Var          | Type         | Value       |Required    | Title       |
|--------------|--------------|-------------|-------------|-------------|
| [cau_job_profile](defaults/main.yml#L5)   | str   | `functional-tests` |    n/a  |  n/a |
| [cau_supported_archives](defaults/main.yml#L6)   | list   | `['zip']` |    n/a  |  n/a |
| [cau_reports_path_patterns](defaults/main.yml#L8)   | list   | `['*.xml']` |    n/a  |  n/a |





### Tasks


#### File: tasks/find.unpack.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Print variables | ansible.builtin.debug | False |
| Find artifact archives | ansible.builtin.find | False |
| Create folders for found archives | ansible.builtin.file | True |
| Unpack artifacts in their folder | ansible.builtin.unarchive | False |

#### File: tasks/main.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Print input parameters | ansible.builtin.debug | False |
| Create helper variables | ansible.builtin.set_fact | False |
| Create unarchive patterns list | ansible.builtin.set_fact | False |
| Update unarchive patterns list | ansible.builtin.set_fact | False |
| Find top archives | ansible.builtin.find | False |
| Create artifacts folders | ansible.builtin.file | True |
| Unpack artifact in folder | ansible.builtin.unarchive | False |
| Find and unpack internal artifact's archives | ansible.builtin.include_tasks | True |




## Playbook

```yml
# SPDX-License-Identifier: Apache-2.0
---
- hosts: localhost
  remote_user: root
  roles:
    - redhatci.ocp.ci_artifacts_unpack

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