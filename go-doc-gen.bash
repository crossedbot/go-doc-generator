#!/bin/bash

DEFAULT_GODOC_HTTP_LOCATION="localhost"
DEFAULT_GODOC_HTTP_PORT="6060"
DEFAULT_OUTPUT_DIR="godoc"
DEFAULT_TIMEOUT=60 # seconds

# log prints the given arguments to STDOUT with a timestamp prefix
log()
{
    echo "$(date +"%F %T"): $*"
}

# usage prints helpful information about the script and exits
usage()
{
	echo -e "$(basename "$0") [-h] [-d <directory>] [-l <address>]
	[-p <port>] [-t <timeout>] -- program to generate static Godoc HTML
	pages
Where:
	-h  show this help text
	-d  output directory prefix for static pages; default is \
'$DEFAULT_OUTPUT_DIR'
	-l  godoc HTTP host address; default is '${DEFAULT_GODOC_HTTP_LOCATION}'
	-p  godoc HTTP port address; default is '${DEFAULT_GODOC_HTTP_PORT}'
	-t  wait timeout for godoc server to become available; default is
	    ${DEFAULT_TIMEOUT} seconds"
	exit
}

# init intializes the environment for the generator
init()
{
	local output_dir=$1; shift;

	rm -rf "${output_dir}"
}

# get_go_module returns the go module set in the current go environment
get_go_module()
{
	local gomod_file="$(go env GOMOD)"
	local go_module=""

	if [ -f "${gomod_file}" ]; then
		go_module="$(grep -E "^module\s+\S+" "${gomod_file}" |
			tr -s ' ' |
			cut -d ' ' -f 2)"
	fi

	echo "${go_module}"
}

# wait_timeout(pid, seconds) waits for a given PID to exit or times out on the
# given timeout in seconds.
wait_timeout()
{
	local pid=$1; shift;
	local godoc_http=$1; shift;
	local timeout=$1; shift;

	for ((i = 0; i < $timeout; i += 1)); do
		local not_running=$(curl \
			--fail \
			--silent \
			"${godoc_http}" 2>&1 > /dev/null && \
			echo 0 || echo 1)
		kill -0 $pid && [[ $not_running -ne 0 ]] && sleep 1 || return 0
	done

	return 1
}

# START #

godoc_http_location=$DEFAULT_GODOC_HTTP_LOCATION
godoc_http_port=$DEFAULT_GODOC_HTTP_PORT
output_dir=$DEFAULT_OUTPUT_DIR
timeout=$DEFAULT_TIMEOUT

while getopts "hd:l:p:t:" opt; do
	case "$opt" in
		[h?]) usage
			;;
		d) output_dir="${OPTARG}"
			;;
		l) godoc_http_location="${OPTARG}"
			;;
		p) godoc_http_port="${OPTARG}"
			;;
		t) timeout="${OPTARG}"
			;;
	esac
done

godoc_http="${godoc_http_location}:${godoc_http_port}"

# Init (E.g. reset godoc directory)
#log "Initializing godoc resources"
#init

# Extract Go module name and construct URL
log "Extract Go module name"
go_module="$(get_go_module)"
if [ "x${go_module}" == "x" ]; then
	echo "Failed to retrieve go module. Does the go.mod file exist?" 1>&2
	exit 1
fi
gomodule_url="http://${godoc_http}/pkg/${go_module}"

# Start godoc server
log "Starting godoc server"
godoc -http="${godoc_http}" 2>&1 > /dev/null &
pid=$!
if ! wait_timeout $pid $godoc_http $timeout; then
	echo "Exceeded timeout (${timeout} secs) waiting on godoc (${pid})" 1>&2
	kill -0 $pid && kill -9 $pid
	exit 1
fi
log "Sleep for 30s to guarantee the go module is indexed"
sleep 30

# Get the files recursively and put under the godoc directory
log "Downloading Go code static files"
wget \
	--recursive \
	--no-verbose \
	--convert-links \
	--page-requisites \
	--adjust-extension \
	--execute=robots=off \
	--include-directories="/lib,/pkg/${go_module},/src/${go_module}" \
	--exclude-directories="*" \
	--directory-prefix="${output_dir}" \
	--no-host-directories \
	"${gomodule_url}"

log "Set ownership and permissions"
chown -R www-data:www-data $output_dir
chmod -R a-x+X $output_dir

# Kill the godoc server
kill -0 $pid && kill -9 $pid
echo "Go code documentation has been generated under ${output_dir}"
