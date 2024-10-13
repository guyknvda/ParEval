#!/bin/bash
python drivers/run-all.py outputs/generated_outputs.json -o outputs/driver_results.json --launch-configs drivers/launch-configs.json --problem-sizes drivers/problem-sizes.json --include-models cuda --log INFO --log-build-errors --yes-to-all 
