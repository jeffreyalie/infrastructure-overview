#!/bin/bash
# [ -f "config.yaml" ]       # Is it a regular file?
# [ -d "terraform/env" ]     # Is it a directory?
# [ -e "config.yaml" ]       # Does the path exist?
# [ -z "$VM_NAME" ]          # Is the variable empty?
# [ -n "$VM_NAME" ]          # Is the variable non-empty?


if [ -f "j.sh" ]; then
    :
else
    echo "Error: j.sh file not found"
    exit 1
fi
echo "j.sh file found. Proceeding with initialization."

# if [ ! -f "j.sh" ]; then
#     echo "Error: j.sh file not found"
#     exit 1
# fi
# echo "j.sh file found. Proceeding with initialization."
