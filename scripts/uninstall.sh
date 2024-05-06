#!/bin/bash

modules=$(pip3 list --format=legacy | grep 'sd-' | grep -o '^sd-[^ ]*')

for module in $modules; do
    pip3 uninstall -y $module
done

