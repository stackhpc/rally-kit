# Rally tempest config generator

Generates tempest configuration overrides for rally

## Installation

### for python 3:

```
python -m venv venv
source venv/bin/activate
pip install requirements.txt
```

### for python 2:

```
virtualenv venv
source venv/bin/activate
pip install requirements.txt
```

## Usage

```
ansible-playbook template.yml -e@recipes/candidate/baremetal-fix-ip.yml
```
