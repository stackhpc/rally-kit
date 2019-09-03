import yaml
import sys
import re
import subprocess

input_file = sys.argv[1]

with open(input_file, 'r') as stream:
    try:
        regexes = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)
        exit(-1)

all_tests = subprocess.check_output(['rally', 'verify', 'list-verifier-tests']).splitlines()
result = {}

for regex, reason in regexes.items():
    for line in all_tests:
        m = None
        try:
          r = re.compile(regex)
          m = r.search(line)
          if m:
            result[line] = reason
        except re.error:
          result[regex] = reason
          
yaml.dump(result, sys.stdout, default_flow_style=False)

