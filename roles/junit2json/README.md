<!-- DOCSIBLE START -->

# 📃 Role overview

## junit2json

```
Role belongs to redhatci/ocp
Namespace - redhatci
Collection - ocp
Version - 0.23.0
Repository - https://github.com/redhatci/ansible-collection-redhatci-ocp
```

Description: Scans folder for XML junit reports and converts them into into single JSON report file


| Field                | Value           |
|--------------------- |-----------------|
| Readme update        | 16/12/2024 |




<details>
<summary><b>🧩 Argument Specifications in meta/argument_specs</b></summary>

#### Key: main 
**Description**: This is the main entrypoint for the role.
It finds all the XML reports under `junit2json_reports_path`
matching any of `junit2json_reports_path_patterns` patterns.
Then they are converted into single JSoN report.
The resulting JSON should have unified format for all the teams' and tests



  - **junit2json_reports_path**
    - **Required**: True
    - **Type**: str
    - **Default**: none
    - **Description**: ['The path to the folder containing XML report(s)']
  
  
  

  - **junit2json_result_json_path**
    - **Required**: False
    - **Type**: str
    - **Default**: {{ junit2json_reports_path }}/report.junit.json
    - **Description**: Resulting report JSON file path

  
  
  

  - **junit2json_do_merge**
    - **Required**: False
    - **Type**: bool
    - **Default**: True
    - **Description**: When `true` the merging of reports is done, and resulting json is `junit2json_result_json_path`.
Otherwise each report is converted to a corresponding json file,
and the value of the variable `junit2json_result_json_path` is ignored.

  
  
  



</details>


### Defaults

**These are static variables with lower priority**

#### File: defaults/main.yml

| Var          | Type         | Value       |Required    | Title       |
|--------------|--------------|-------------|-------------|-------------|
| [junit2json_hash](defaults/main.yml#L9)   | str   | `sha256` |    n/a  |  n/a |
| [junit2json_supported_archives](defaults/main.yml#L10)   | list   | `['zip']` |    n/a  |  n/a |
| [junit2json_result_json_path](defaults/main.yml#L12)   | str   | `{{ junit2json_reports_path }}/report.junit.json` |    n/a  |  n/a |
| [junit2json_do_merge](defaults/main.yml#L13)   | bool   | `True` |    n/a  |  n/a |
| [junit2json_result_xml_path](defaults/main.yml#L14)   | str   | `{{ junit2json_reports_path }}/report.merged.xml` |    n/a  |  n/a |
| [junit2json_debug](defaults/main.yml#L17)   | bool   | `False` |    n/a  |  n/a |





### Tasks


#### File: tasks/convert.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Read file content | ansible.builtin.set_fact | False |
| Generate content hash from the content | ansible.builtin.set_fact | False |
| Print curr XML report filename | ansible.builtin.debug | False |
| Obtain info on previous content checksum file | ansible.builtin.stat | False |
| Update junit2json_result_data [junit2json_do_merge: {{junit2json_do_merge }}] | ansible.builtin.set_fact | True |
| Convert junit XML to JSON and save in junit2json_result_data | ansible.builtin.set_fact | True |
| Setup JSoN report file name (with extension .xml) | ansible.builtin.set_fact | True |
| Setup JSoN report file name (with extension .xml) | ansible.builtin.set_fact | True |
| Update xml_old_hash | ansible.builtin.set_fact | True |
| Update global_json_reports_list | ansible.builtin.set_fact | False |
| Ensure json data destination folder | ansible.builtin.file | True |
| Write json data to destination | ansible.builtin.copy | True |
| Write current hash to destination | ansible.builtin.copy | True |

#### File: tasks/merge.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Generate XML files list | ansible.builtin.set_fact | False |
| Print XML reports' filenames data | ansible.builtin.debug | True |
| Merge multiple JUnit XML files into single consolidated report | ansible.builtin.shell | False |
| Write merge resulting file | ansible.builtin.copy | True |
| Update the xml files list for conversion | ansible.builtin.set_fact | False |

#### File: tasks/main.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Loop orientation at idx {{ loop_idx }} out of {{ _found_reports.files ¦ list ¦ length }} | ansible.builtin.debug | False |
| Validate some variables | ansible.builtin.assert | False |
| check whether the junit2json_reports_path is a directory | ansible.builtin.stat | False |
| Create helper variables | ansible.builtin.set_fact | False |
| Find JUnit XML reports | ansible.builtin.find | True |
| Setup the default list for conversion | ansible.builtin.set_fact | True |
| Setup the default list for conversion | ansible.builtin.set_fact | True |
| Merge multiple mini-reports to one XML | ansible.builtin.include_tasks | True |
| Convert XML to JSON | ansible.builtin.include_tasks | True |




## Playbook

```yml
---
- hosts: localhost
  roles:
    - name: junit2json
      vars:
        j2j_reports_path: "{{ roles_path }}/junit2json/tests/system-tests/reports_good"
        j2j_reports_path_patterns:
        - "*.xml"
        j2j_xml_parse_path: "{{ roles_path }}/junit2json/tests/system-tests/xml_parse.yml"
```


## Author Information
Max Kovgan

#### License

Apache-2.0

#### Minimum Ansible Version

2.9

#### Platforms

No platforms specified.
<!-- DOCSIBLE END -->