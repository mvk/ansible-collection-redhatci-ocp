<!-- DOCSIBLE START -->

# 📃 Role overview

## junit2json



Description: Scans folder for XML junit reports and converts them into into single JSON report file







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

  
  
  



</details>


### Defaults

**These are static variables with lower priority**

#### File: defaults/main.yml

| Var          | Type         | Value       |Required    | Title       |
|--------------|--------------|-------------|-------------|-------------|
| [junit2json_result_json_path](defaults/main.yml#L7)   | str   | `{{ junit2json_reports_path }}/report.junit.json` |    n/a  |  n/a |
| [junit2json_debug](defaults/main.yml#L8)   | bool   | `False` |    n/a  |  n/a |
| [junit2json_hash](defaults/main.yml#L9)   | str   | `sha256` |    n/a  |  n/a |





### Tasks


#### File: tasks/convert.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Ensure json data destination folder | ansible.builtin.file | True |
| Write json data to destination | ansible.builtin.copy | True |
| Write current hash to destination | ansible.builtin.copy | True |

#### File: tasks/merge.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Create helper empty list for XML data and filename | ansible.builtin.set_fact | False |
| Update helper list of XML file names | ansible.builtin.set_fact | False |
| Print XML filenames data | ansible.builtin.debug | True |
| Merge multiple junit xml files into consolidated report | ansible.builtin.shell | False |
| Write merge resulting file | ansible.builtin.copy | True |
| Generate content hash from the content | ansible.builtin.set_fact | False |
| Print merged XML report filename | ansible.builtin.debug | True |
| Obtain info on previous content checksum file | ansible.builtin.stat | False |
| Update junit2json_result_data_dict | ansible.builtin.set_fact | False |
| Update junit2json_old_hash | ansible.builtin.set_fact | True |

#### File: tasks/main.yml

| Name | Module | Has Conditions |
| ---- | ------ | --------- |
| Validate some variables | ansible.builtin.assert | False |
| Create helper variables | ansible.builtin.set_fact | False |
| Find archives | ansible.builtin.find | False |
| Merge multiple mini-reports to one XML | ansible.builtin.include_tasks | True |
| Convert XML to JSON | ansible.builtin.include_tasks | True |
| Fail now | ansible.builtin.fail | False |




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