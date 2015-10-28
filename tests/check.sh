#!/bin/sh

set -e

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)
git config --global push.default simple

. $(dirname $0)/helpers.sh

when_repo_initialized_without_unclaimed_locks_it_does_not_create_pending_triggers_and_returns_no_ref() {
  local repo=$(init_repo)

  check_uri $repo | jq -e "
    . == []
  "

  if [ -f $repo/my_pool/.pending_triggers ]; then 
  	exit 1
  fi
}

when_repo_initialized_with_unclaimed_locks_creates_pending_triggers_and_returns_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)

  check_uri $repo | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)}
    ]
  "

  cd $repo
  git reset --hard

  if [ ! -f $repo/my_pool/.pending-triggers ]; then
  	echo ".pending-triggers file was not written"
  	exit 1
  fi

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 1 ]; then
  	echo ".pending-triggers is not equal to 1"
  	exit 1
  fi
}

when_pending_triggers_is_zero_and_no_locks_exist_returns_no_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/.pending-triggers 0)

  check_uri $repo $ref1 | jq -e "
    . == []
  "

  cd $repo
  git reset --hard

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 0 ]; then
  	echo ".pending-triggers is not equal to 0"
  	exit 1
  fi
}

when_pending_triggers_is_zero_and_locks_exist_but_no_new_locks_added_returns_no_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 0)
  
  check_uri $repo $ref3 | jq -e "
    . == []
  "

  cd $repo
  git reset --hard

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 0 ]; then
  	echo ".pending-triggers is not equal to 0"
  	exit 1
  fi
}

when_pending_triggers_is_zero_and_new_files_added_adds_pending_triggers_and_returns_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/.pending-triggers 0)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref3=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  
  check_uri $repo $ref1 | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "

  cd $repo
  git reset --hard

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 1 ]; then
  	echo ".pending-triggers is not equal to 1"
  	exit 1
  fi
}

when_pending_triggers_is_positive_and_no_new_files_added_decrements_pending_and_returns_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 2)
  
  check_uri $repo $ref2 | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "

  cd $repo
  git reset --hard

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 1 ]; then
  	echo ".pending-triggers is not equal to 1"
  	exit 1
  fi
}

when_pending_triggers_is_positive_and_new_files_added_adds_pending_triggers_and_returns_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo my_pool/unclaimed/file-a)
  local ref2=$(make_commit_to_file $repo my_pool/unclaimed/file-b)
  local ref3=$(make_commit_to_file $repo my_pool/.pending-triggers 1)
  local ref4=$(make_commit_to_file $repo my_pool/unclaimed/file-c)
  local ref5=$(make_commit_to_file $repo my_pool/unclaimed/file-d)
  
  check_uri $repo $ref2 | jq -e "
    . == [
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "

  cd $repo
  git reset --hard

  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ $pending -ne 2 ]; then
  	echo ".pending-triggers is not equal to 2"
  	exit 1
  fi
}



run when_repo_initialized_without_unclaimed_locks_it_does_not_create_pending_triggers_and_returns_no_ref
run when_repo_initialized_with_unclaimed_locks_creates_pending_triggers_and_returns_ref
run when_pending_triggers_is_zero_and_no_locks_exist_returns_no_ref
run when_pending_triggers_is_zero_and_locks_exist_but_no_new_locks_added_returns_no_ref
run when_pending_triggers_is_zero_and_new_files_added_adds_pending_triggers_and_returns_ref
run when_pending_triggers_is_positive_and_no_new_files_added_decrements_pending_and_returns_ref
run when_pending_triggers_is_positive_and_new_files_added_adds_pending_triggers_and_returns_ref


rm -rf $TMPDIR_ROOT
