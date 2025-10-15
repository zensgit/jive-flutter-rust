#!/bin/bash

# Navigate to test-automation directory
cd "$(dirname "$0")"

# Make run-test.sh executable
chmod +x run-test.sh

# Run the test
./run-test.sh
