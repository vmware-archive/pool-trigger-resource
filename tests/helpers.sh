#!/bin/bash

set -e



print_header() {
  local params=($@)
  local additional_params
  local flags

  while [ ${#params[@]} -gt 0 ]; do
    case ${params[0]} in
      -f|--flag)
        flags+=${params[1]}
        params=(${params[@]:2})
        ;;
      *)
        additional_params+=(${params[0]})
        params=(${params[@]:1})
    esac
  done

  local flag

  local print_it

  for flag in "${flags[@]}"; do
    if [ "$flag" == "don't" ]; then
      print_it=yes
    fi
  done

  if [ "$print_it" != "yes" ]; then
    return 0
  fi

  local header_message=${additional_params[*]}

  [ -n "$header_message" ]

  echo
  echo
  echo "####################################"
  echo "#"
  echo "# $header_message"
  echo "#"
  echo "####################################"
  echo
  echo
}

create_remote() {

  local remoteRepo="$TMPDIR"/remote
  mkdir "$remoteRepo"
  pushd "$remoteRepo"
  git init --bare
  popd

  export REPO_REMOTE="$remoteRepo"

  print_header "creating remote repo: $REPO_REMOTE"

  make_initial_commit
}

make_initial_commit() {
  clone_repo
  pushd "$REPO_CLONE"

  git \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit --allow-empty -m "init"

  mkdir my_pool
  mkdir my_pool/unclaimed
  mkdir my_pool/claimed

  mkdir my_other_pool
  mkdir my_other_pool/unclaimed
  mkdir my_other_pool/claimed

  touch my_pool/unclaimed/.gitkeep
  touch my_pool/claimed/.gitkeep

  touch my_other_pool/unclaimed/.gitkeep
  touch my_other_pool/claimed/.gitkeep

  git add .
  git \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit \
    -m "setup lock"

  git push 

  popd
}

clone_repo() {
  [ -n "$REPO_REMOTE" ]

  if [ -n "$REPO_CLONE" ]; then
    rm -rf "$REPO_CLONE"
  fi

  export REPO_CLONE
  REPO_CLONE=$(mktemp -d "$TMPDIR"/repo-XXXXXX)

  print_header "cloning repo: $REPO_CLONE"

  git clone "$REPO_REMOTE" "$REPO_CLONE" 
}

make_commit_to_file_on_branch() {
  print_header "committing file"

  local file=$1
  local branch=$2
  local msg=${3-x}

  clone_repo
  pushd "$REPO_CLONE"

  if ! git rev-parse --verify "$branch" >/dev/null; then
    git branch "$branch" master
  fi

  git checkout "$branch"

  echo "$msg" >> "$REPO_CLONE"/"$file"
  git add "$file"
  git \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -m "commit $(wc -l "$REPO_CLONE"/"$file") $msg"

  git push 

  popd
}

make_commit_to_file() {
  make_commit_to_file_on_branch "$1" master "${2-}"
}

remove_file() {
  remove_file_on_branch "$1" master "${2-}"
}

remove_file_on_branch() {
  print_header "removing file"

  local file=$1
  local branch=$2
  local msg=${3-x}

  clone_repo
  pushd "$REPO_CLONE"

  if ! git rev-parse --verify "$branch" >/dev/null; then
    git branch "$branch" master
  fi

  git checkout -q "$branch"

  git rm -q "$file"
  git \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit removed $file - $msg"

  git push

  popd
}

check_uri() {
  [ -n "$REPO_REMOTE" ]

  export LAST_CHECK_REF

  local refJsonFragment=""
  if [ -n "$LAST_CHECK_REF" ]; then
  	refJsonFragment=", version: { ref: $LAST_CHECK_REF }"
  fi

  local checkRequest
  checkRequest=$(jq -n "{
    source: {
      uri: $(echo "$REPO_REMOTE" | jq -R .),
      branch: \"master\",
      pool: \"my_pool\"
    }$refJsonFragment
  }")

  print_header -f really "executing check: $checkRequest"

  export CHECK_RESULT
  CHECK_RESULT=$(echo "$checkRequest" | "$RESOURCE_DIR"/assets/check  ) #| tee /dev/stderr

  print_header -f really "executed check: 
  $CHECK_RESULT"

  check_result_is_valid

  local checkRef=""
  checkRef=$(echo "$CHECK_RESULT" | 
    jq .[0].ref
  )

  if [ "$checkRef" != "null" ]; then
    print_header --flag really "checkRef is $checkRef"

    LAST_CHECK_REF=$checkRef
  fi

  print_header "check returned: $CHECK_RESULT"
}

check_uri_should_return_x_refs() {
  local numRefs=$1

  print_header "validating $numRefs refs"

  [ -n "$numRefs" ]

  for (( i = 0; i < numRefs; i++ )); do
    print_header "expecting ref on check $i"

    check_uri
    check_result_is_non_empty
  done
}

check_uri_should_return_x_refs_and_drain() {
  local numRefs=$1

  print_header "validating $numRefs refs then drained"

  [ -n "$numRefs" ]

  check_uri_should_return_x_refs "$numRefs"

  check_uri_should_be_drained
}

check_uri_should_be_drained() {
  print_header "validating drained"

  local drainThreshold=2

  local i
  for (( i = 0; i < drainThreshold; i++ )); do
    print_header "expecting empty on drain-check $i"

    check_uri

    check_result_is_empty
  done
}

check_result_is_empty() {
  print_header "validating result is empty: $CHECK_RESULT"

  local numElements
  numElements=$(echo "$CHECK_RESULT" | jq length)

  [ "$numElements" -eq "0" ]
}

check_result_is_non_empty() {
  print_header "validating result non-empty: $CHECK_RESULT"

  local numElements
  numElements=$(echo "$CHECK_RESULT" | jq length)

  [ "$numElements" -gt "0" ]
}

check_result_is_valid() {
  print_header "validating check result: $CHECK_RESULT"

  [ -n "$CHECK_RESULT" ]

  print_header "check result is non-nil"

  local resultType
  resultType=$(echo "$CHECK_RESULT" | jq type)

  print_header "check result type is $resultType"

  [ "$resultType" == "\"array\"" ]

  local numRefs
  numRefs=$(echo "$CHECK_RESULT" | jq length)

  print_header "check result has $numRefs elements"

  local i
  for (( i = 0; i < numRefs; i++ )); do
    local element
    element=$(echo "$CHECK_RESULT" | jq .[$i])

    print_header "check result element $i is $element"

    local elementType
    elementType=$(echo "$element" | jq type)

    print_header "check result element $i type is $elementType"

    [ "$elementType" == "\"object\"" ]

    local elementSize
    elementSize=$(echo "$element" | jq length)

    [ "$elementSize" -eq 1 ]

    local elementRef
    elementRef=$(echo "$element" | jq .ref )

    [ -n "$elementRef" ]

    #check for uniqueness

  done

  print_header "result is valid: $CHECK_RESULT"
}
