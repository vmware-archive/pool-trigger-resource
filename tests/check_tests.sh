#!/bin/sh

set -e

# shellcheck source=./helpers.sh
. $(dirname $0)/helpers.sh

list_check_tests() {
  echo when_initialized_without_unclaimed_locks_it_returns_no_refs
  echo when_initialized_with_locks_that_are_removed_before_first_it_returns_no_refs
  echo when_initialized_with_unclaimed_locks_should_return_one_ref_each
  echo when_initialized_empty_and_locks_added_later_should_return_one_ref_each
  echo when_initialized_empty_and_locks_added_and_removed_alternating_should_return_one_ref_each
  echo when_initialized_with_locks_and_some_are_removed_manually_should_not_over_drain
  echo when_initialized_with_locks_then_drained_then_locks_added_and_removed_should_still_be_drained
  echo when_other_pools_are_mucked_with_it_shouldnt_die
}

when_initialized_without_unclaimed_locks_it_returns_no_refs() {
  create_remote

  check_uri_should_be_drained
}

when_initialized_with_locks_that_are_removed_before_first_it_returns_no_refs() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a
  make_commit_to_file my_pool/unclaimed/file-b
  make_commit_to_file my_pool/unclaimed/file-c

  remove_file my_pool/unclaimed/file-a
  remove_file my_pool/unclaimed/file-b
  remove_file my_pool/unclaimed/file-c

  check_uri_should_be_drained
}

when_initialized_with_unclaimed_locks_should_return_one_ref_each() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a
  make_commit_to_file my_pool/unclaimed/file-b
  make_commit_to_file my_pool/unclaimed/file-c

  check_uri_should_return_x_refs_and_drain 3
}

when_initialized_empty_and_locks_added_later_should_return_one_ref_each() {
  create_remote

  check_uri_should_be_drained

  make_commit_to_file my_pool/unclaimed/file-a
  make_commit_to_file my_pool/unclaimed/file-b
  make_commit_to_file my_pool/unclaimed/file-c

  check_uri_should_return_x_refs_and_drain 3
}

when_initialized_empty_and_locks_added_and_removed_alternating_should_return_one_ref_each() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a "adding file-a"
  check_uri_should_return_x_refs_and_drain 1 
  remove_file my_pool/unclaimed/file-a "removing file-a"

  make_commit_to_file my_pool/unclaimed/file-b "adding file-b"
  check_uri_should_return_x_refs_and_drain 1
  remove_file my_pool/unclaimed/file-b "removing file-b"

  make_commit_to_file my_pool/unclaimed/file-c "adding file-c"
  check_uri_should_return_x_refs_and_drain 1
  remove_file my_pool/unclaimed/file-c "removing file-c"

  check_uri_should_be_drained
}

when_initialized_with_locks_and_some_are_removed_manually_should_not_over_drain() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a 
  make_commit_to_file my_pool/unclaimed/file-b 
  make_commit_to_file my_pool/unclaimed/file-c 

  check_uri_should_return_x_refs 1

  remove_file my_pool/unclaimed/file-a
  remove_file my_pool/unclaimed/file-b
  remove_file my_pool/unclaimed/file-c

  check_uri_should_be_drained
}

when_initialized_with_locks_then_drained_then_locks_added_and_removed_should_still_be_drained() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a 
  make_commit_to_file my_pool/unclaimed/file-b 

  check_uri_should_return_x_refs_and_drain 2

  remove_file my_pool/unclaimed/file-a
  remove_file my_pool/unclaimed/file-b

  make_commit_to_file my_pool/unclaimed/file-c 
  make_commit_to_file my_pool/unclaimed/file-d 

  remove_file my_pool/unclaimed/file-c
  remove_file my_pool/unclaimed/file-d

  check_uri_should_be_drained
}

when_other_pools_are_mucked_with_it_shouldnt_die() {
  create_remote

  make_commit_to_file my_pool/unclaimed/file-a 
  make_commit_to_file my_pool/unclaimed/file-b 

  check_uri_should_return_x_refs 1

  remove_file my_pool/unclaimed/file-a
  remove_file my_pool/unclaimed/file-b

  make_commit_to_file my_other_pool/unclaimed/file-a 
  make_commit_to_file my_other_pool/unclaimed/file-b 

  make_commit_to_file my_pool/unclaimed/file-c

  check_uri_should_return_x_refs 1

  remove_file my_other_pool/unclaimed/file-a
  remove_file my_other_pool/unclaimed/file-b

  make_commit_to_file my_other_pool/unclaimed/file-c 
  make_commit_to_file my_other_pool/unclaimed/file-d 

  check_uri_should_be_drained
}
