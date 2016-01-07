#!/bin/sh

set -e -u

set -o pipefail

resource_dir=/opt/resource

run() { (
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)

  echo -e 'running \e[33m'"$@"$'\e[0m...'
  eval "$@" 2>&1  # | sed -e 's/^/  /g'
  echo ""
  )
  return $?
}

create_remote() {
  (
    set -e

    local remoteRepo=$TMPDIR/remote
    mkdir "$remoteRepo"
    cd "$remoteRepo"
    git init -q --bare
    cd - > /dev/null # pipe to dev null to prevent output

    local repoDir
    repoDir=$(clone_repo "$remoteRepo") 2>/dev/null
    cd "$repoDir"
    # start with an initial commit
    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q --allow-empty -m "init"

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
    git commit -q -m "setup lock"

    git push --quiet > /dev/null
    # print resulting repo
    # echo "TEE " | tee /dev/stderr
    echo "$remoteRepo"
  )
}

# clone a remote repo and return its path
clone_repo() {
    local remoteRepo=$1 
    local repoDir=$(mktemp $TMPDIR/repo-XXXXXX)
    rm -rf $repoDir
    git clone $remoteRepo $repoDir --quiet
    cd $repoDir
    pwd
}

make_commit_to_file_on_branch() {
  local repo=$(clone_repo $1)
  local file=$2
  local branch=$3
  local msg=${4-x}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  echo $msg >> $repo/$file
  git -C $repo add $file
  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit $(wc -l $repo/$file) $msg"

  git -C $repo push --quiet > /dev/null
  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file() {
  make_commit_to_file_on_branch $1 $2 master "${3-}"
}

remove_file() {
  remove_file_on_branch $1 $2 master "${3-}"
}
remove_file_on_branch() {
  local repo=$(clone_repo $1)
  local file=$2
  local branch=$3
  local msg=${4-x}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  git -C $repo rm -q $file
  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit removed $file - $msg"

  git -C $repo push --quiet > /dev/null
  # output resulting sha
  git -C $repo rev-parse HEAD
}

check_uri() {
  local ref=${2-}
  local refjson=""

  if [ -n "$ref" ]; then
  	refjson=", version: { ref: \"$ref\" }"
  fi

  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\",
      pool: \"my_pool\"
    }$refjson
  }" | ${resource_dir}/check | tee /dev/stderr
}

check_uri_should_match_ref() {
  local repo=$1
  local suppliedRef=$2
  local expectedRef=$3

  local checkUriResult
  checkUriResult=$(check_uri $repo $suppliedRef)

  local refMatches
  refMatches=$(echo "$checkUriResult" |
   jq "
    . == [
      {ref: $(echo "$expectedRef" | jq -R .)}
    ]
  ")

  if [ "$refMatches" = "false" ]; then
    echo "Output $checkUriResult did not match expected ref $expectedRef"
    exit 1
  fi
}

check_pending_triggers_equal() {
  local repo=$(clone_repo $1)
  local expectedPending=${2-0}
  local pending=$(cat $repo/my_pool/.pending-triggers)

  if [ ! -f $repo/my_pool/.pending-triggers ]; then
    echo ".pending-triggers file was not written"
    exit 1
  fi

  if [ $pending -ne $expectedPending ]; then
    echo ".pending-triggers $pending is not equal to $expectedPending"
    exit 1
  fi
}

pending_triggers_should_not_exist() {
  local repo=$(clone_repo $1)
  if [ -f $repo/my_pool/.pending_triggers ]; then 
    exit 1
  fi
}