#!/bin/sh

set -e -u

set -o pipefail

resource_dir=/opt/resource

run() {
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)

  echo -e 'running \e[33m'"$@"$'\e[0m...'
  eval "$@" 2>&1  # | sed -e 's/^/  /g'
  echo ""
}

init_repo() {
  (
    set -e

    cd $(mktemp -d $TMPDIR/repo.XXXXXX)

    git init -q

    # allow pushes to this repo
    git config receive.denyCurrentBranch ignore

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

    # print resulting repo
    pwd
  )
}

make_commit_to_file_on_branch() {
  local repo=$1
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

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file() {
  make_commit_to_file_on_branch $1 $2 master "${3-}"
}

check_uri() {
  local ref=${2-}
  local refjson=""

  if [ $ref ]; then
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
