#!/bin/bash
sops --decrypt --input-type binary "$1" 2>/dev/null || cat "$1"
