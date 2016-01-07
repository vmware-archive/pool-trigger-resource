#!/bin/sh

set -e

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)
git config --global push.default simple

# shellcheck source=/dev/null
. $(dirname $0)/helpers.sh

when_repo_initialized_without_unclaimed_locks_it_does_not_create_pending_triggers_and_returns_no_ref() {
  local repo=$(create_remote)
  echo 'REPO MADE';
  echo $repo
  check_uri $repo | jq -e "
    . == []
  "

  $(pending_triggers_should_not_exist)
}

when_repo_initialized_with_unclaimed_locks_creates_pending_triggers_and_returns_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)

  check_uri_should_match_ref $repo "" $ref2

  check_pending_triggers_equal $repo 1
}

when_pending_triggers_is_zero_and_no_locks_exist_returns_no_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/.pending-triggers 0)
  check_uri $repo $ref1 | jq -e "
    . == []
  "

  check_pending_triggers_equal $repo 0
}

when_pending_triggers_is_zero_and_locks_exist_but_no_new_locks_added_returns_no_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 0)
  
  check_uri $repo $ref3 | jq -e "
    . == []
  "

  check_pending_triggers_equal $repo 0
}

when_pending_triggers_is_zero_and_new_files_added_adds_pending_triggers_and_returns_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/.pending-triggers 0)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref3=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  
  check_uri_should_match_ref $repo $ref1 $ref3

  check_pending_triggers_equal $repo 1
}

when_pending_triggers_is_positive_and_no_new_files_added_decrements_pending_and_returns_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 2)
  
  check_uri_should_match_ref $repo $ref2 $ref3

  check_pending_triggers_equal $repo 1
}

when_pending_triggers_is_positive_and_new_files_added_adds_pending_triggers_and_returns_ref() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 1)
  local ref4=$(make_commit_to_file $repo my_pool/unclaimed/file-c)
  local ref5=$(make_commit_to_file $repo my_pool/unclaimed/file-d)
  
  check_uri_should_match_ref $repo $ref2 $ref5

  check_pending_triggers_equal $repo 2
}

when_an_environment_has_been_removed_manually() {
  local repo=$(create_remote)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/unclaimed/file-c)

  check_uri_should_match_ref $repo "" $ref3

  local ref4=$(remove_file $repo my_pool/unclaimed/file-a)
  local ref5=$(remove_file $repo my_pool/unclaimed/file-b)

  check_uri_should_match_ref $repo $ref3 $ref5

  check_pending_triggers_equal $repo 0
}


run when_repo_initialized_without_unclaimed_locks_it_does_not_create_pending_triggers_and_returns_no_ref
run when_repo_initialized_with_unclaimed_locks_creates_pending_triggers_and_returns_ref
run when_pending_triggers_is_zero_and_no_locks_exist_returns_no_ref
run when_pending_triggers_is_zero_and_locks_exist_but_no_new_locks_added_returns_no_ref
run when_pending_triggers_is_zero_and_new_files_added_adds_pending_triggers_and_returns_ref
run when_pending_triggers_is_positive_and_no_new_files_added_decrements_pending_and_returns_ref
run when_pending_triggers_is_positive_and_new_files_added_adds_pending_triggers_and_returns_ref
run when_an_environment_has_been_removed_manually

rm -rf $TMPDIR_ROOT
