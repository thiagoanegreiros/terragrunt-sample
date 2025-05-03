#!/bin/bash

cd ./common-resources/

tflint --recursive --init --config=$(realpath ../.tflint.hcl)

tflint --config=$(realpath ../.tflint.hcl) "--minimum-failure-severity=error" --recursive
