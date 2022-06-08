#!/bin/bash

DEFAULT_OUTPUT_DIR=""
DEFAULT_PREFIX="./"
DEFAULT_REPOS_FILE="go-doc-repos.txt"

# log prints the given arguments to STDOUT with a timestamp prefix
log()
{
	echo "$(date +"%F %T"): $*"
}

# usage prints helpful information about the script and exits
usage()
{
	echo -e "$(basename "$0") [-h] [-c <config>] [-d <directory>]
	[-p <prefix>] -- program to generate static Godoc HTML pages for
	multiple Git repositories. Repositories are expected to be in the format
	'<remote_url>/<user>/<repo>'. Paths to repositories are expected to be
	found at '<prefix>/<remote_url>/<user>/<repo>'.
Where:
	-h  show this help text
	-c  path to repository list; default is '${DEFAULT_REPOS_FILE}'
	-d  output directory prefix for static pages; default is \
'$DEFAULT_OUTPUT_DIR'
	-p  directory path prefix to repositories in the configuration file;
	    default is '${DEFAULT_PREFIX}'"
	exit
}


# clean_path cleans a given path and returns it
clean_path()
{
	local p=$1; shift;

	p="$(echo "${p}" | tr -s '/' | sed -e 's/\/$//')"

	echo "${p}"
}

# git_clone_or_pull checks if a given repository exists at <prefix>/<localrepo>,
# and either clones it if it doesn't exist or pulls the latest from remote on
# its current branch
git_clone_or_pull()
{
	local prefix=$1; shift;
	prefix=$(clean_path $prefix)
	local local_repo=$1; shift;
	local_repo=$(clean_path $local_repo)

	# Setup local variables
	local full_local_repo="${prefix}/${local_repo}"
	local dot_git_dir="${full_local_repo}/.git"

	# Setup remote variables
	local git_remote="$(echo $local_repo | cut -d'/' -f1)"
	local git_user="$(echo $local_repo | cut -d'/' -f2)"
	local git_repo="$(echo $local_repo | cut -d'/' -f3)"
	local remote_repo="git@${git_remote}:${git_user}/${git_repo}.git"

	# Either clone the remote repo or pull the latest
	if [ ! -d "${dot_git_dir}" ]; then
		log "Cloning ${remote_repo} into ${local_repo}"
		git clone -q $remote_repo $local_repo
	else
		local branch=$(git -C $full_local_repo branch | \
			sed -n -e 's/^\* \(.*\)/\1/p')
		log "From ${git_remote}:${git_user}/${git_repo} origin/${branch}"
		git -C $full_local_repo pull -q origin $branch
	fi
}

# generate_go_doc generates the static godoc pages in the output directory for
# the given repository under the prefix location
generate_go_doc()
{
	local repo=$1; shift;
	local prefix=$1; shift;
	local output_dir=$1; shift;
	local path_to="$(clean_path $repo)";
	local args="";

	[[ "x${prefix}" != "x" ]] && path_to="$(clean_path "${prefix}/${repo}")"
	[[ "x${output_dir}" != "x" ]] && args+="-d $(clean_path $output_dir)"

	log "Generating documentation for ${repo}"
	(cd $path_to && ./go-doc-gen $args)
}

# START #

output_dir=$DEFAULT_OUTPUT_DIR
prefix=$DEFAULT_PREFIX
repos_file=$DEFAULT_REPOS_FILE

while getopts "hc:d:p:" opt; do
	case "$opt" in
		[h?]) usage
			;;
                c) repos_file="${OPTARG}"
                        ;;
		d) output_dir="${OPTARG}"
                        ;;
                p) prefix="${OPTARG}"
                        ;;
	esac
done

while read repo; do
	git_clone_or_pull $prefix $repo
	generate_go_doc $repo $prefix $output_dir
done < $repos_file
