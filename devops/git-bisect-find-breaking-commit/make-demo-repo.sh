#!/usr/bin/env bash
# Builds a throwaway repo with 100 commits. Commit 66 breaks total() (the regression).
# Commits 61 and 62 have a syntax error (unbuildable), to demo exit code 125.
set -euo pipefail

dir="${1:-./bisect-demo}"
[ -e "$dir" ] && { echo "$dir already exists, remove it first" >&2; exit 1; }
mkdir -p "$dir"
cd "$dir"

export GIT_AUTHOR_NAME=Demo GIT_AUTHOR_EMAIL=demo@example.com
export GIT_COMMITTER_NAME=Demo GIT_COMMITTER_EMAIL=demo@example.com
git init -q -b main

write_app() {  # $1 = body of total()
  cat > app.sh <<APP
#!/usr/bin/env bash
# total <unit_price> <qty>: prints the line total
total() {
  $1
}
APP
}

for i in $(seq 1 100); do
  case $i in
    1)       write_app 'echo $(( $1 * $2 ))' ;;
    61|62)   write_app 'echo $(( $1 * $2 )' ;;      # missing paren: does not parse
    63)      write_app 'echo $(( $1 * $2 ))' ;;      # fixed again
    66)      write_app 'echo $(( $1 * ($2 - 1) ))' ;; # the regression: off by one
  esac
  echo "change $i" >> CHANGELOG
  git add -A
  export GIT_AUTHOR_DATE="2026-01-01T00:00:00 +0000"
  GIT_AUTHOR_DATE="$(date -u -d "2026-01-01 + $i hours" +%FT%T) +0000"
  export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
  case $i in
    61) msg="wip: refactor total()" ;;
    62) msg="wip: refactor total() part 2" ;;
    63) msg="finish refactor of total()" ;;
    66) msg="speed up total() calculation" ;;
    *)  msg="change $i" ;;
  esac
  git commit -q -m "$msg"
done
git tag v1.0 HEAD~99   # first commit, known good
echo "Created $(git rev-list --count HEAD) commits in $dir"
