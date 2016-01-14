#!/bin/bash

set -e

params=$*

main() {
	setup

	run_tests
}

setup() {
	export TMPDIR_ROOT
	TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)

	git config --global push.default simple

	# shellcheck source=./check_tests.sh
	source $(dirname "$0")/check_tests.sh

	total_tests=0
	failed_tests=""
}

teardown() {
	rm -rf $TMPDIR_ROOT
}

run() {
  total_tests=$((total_tests+1))

  set +e
  run_internal $@ 

  if [ "$?" -ne 0 ]; then
	failed_tests="$failed_tests
	  $@"
  fi

  set -e
}

run_internal() {
  (
  	set -e
		export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)
		export RESOURCE_DIR=$TMPDIR/resource
		mkdir $RESOURCE_DIR

		cp -r /opt/resource/* $RESOURCE_DIR

		echo
		echo "*************************************************"
		echo
		echo -e 'running \e[33m'"$@"$'\e[0m...'
		echo
		echo "*************************************************"
		echo
		# eval "$@" 2>&1  # | sed -e 's/^/  /g'
		# echo ""

		eval "$@"
  )
  return $?
}

run_tests() {
	if [ -n "$params" ] ; then
		test_names="$params"
	else
		test_names="$(list_check_tests)"
	fi

	for test_name in $test_names
	do
    	run "$test_name"
	done

	echo
	echo
	echo "COMPLETED $total_tests TESTS"
	echo

	if [ -n "$failed_tests" ]; then
	    echo -e "failed tests: $failed_tests"
	    exit 1
	fi
}

# trap teardown EXIT

main
