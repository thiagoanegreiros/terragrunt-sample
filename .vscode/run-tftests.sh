#!/bin/bash
find ./common-resources -type d -name "tests" | while read test_dir
do
  if [ -e "$test_dir"/*.tftest.hcl ]; then
    module_dir=$(dirname "$test_dir")
    echo "Executing terraform init and test in $module_dir"
    cd "$module_dir"
    terraform init
    terraform test
    cd - > /dev/null
  else
    echo "No .tftest.hcl file found in $test_dir, skiping folder."
  fi
done
