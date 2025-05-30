#!/bin/bash
echo "Please type 'yes' to proceed: "
read input

# Check if the input is "yes"
if [ "$input" != "yes" ] || [ -z "$input" ]; then
  echo "Deployment aborted. Input not recognized."
  exit 1  # Force an error to stop Terraform from proceeding
fi
