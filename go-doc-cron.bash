#!/bin/bash

# Just a simple wrapper of the godoc generation manager so that the command in
# the cron file isn't so long
/opt/go-doc-generator/bin/go-doc-manage \
	-c "/opt/go-doc-generator/conf/repos.list" \
	-d "/opt/godoc" \
	-p "${HOME}/Development/golang/src"
