# git bisect: find the commit that broke it

Companion kit for [git bisect: Find the Commit That Broke It](https://sumguy.com/git-bisect-find-breaking-commit/).

## What it does

- `make-demo-repo.sh` builds a throwaway repo with 100 deterministic commits.
  - Commit 66 ("speed up total() calculation") introduces an off-by-one regression in `total()` in `app.sh`.
  - Commits 61 and 62 contain a syntax error, so they cannot be tested (exit code 125 / `git bisect skip`).
  - Commit 63 fixes the syntax error.
- `test.sh` is the `git bisect run` script. Exit 0 = good, 1 = bad, 125 = skip.

## Prerequisites and tested versions

- git 2.56.0
- bash 5.x

## Run it

```bash
./make-demo-repo.sh ./bisect-demo        # default path is ./bisect-demo
cd bisect-demo
git bisect start HEAD v1.0               # HEAD is bad, tag v1.0 (commit 1) is good
git bisect run "$OLDPWD/test.sh"         # test.sh lives OUTSIDE the repo on purpose
git bisect reset
```

Expected result: bisect reports `speed up total() calculation` as the first bad commit, after 8 test runs, one of which is skipped.

The script stays outside the repo so that checking out old commits never swaps it for an older version.
