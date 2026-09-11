
## Git commit -a

`git commit -m` only commits the files that are already staged with `git add`.

`git commit -a -m` skips the staging step for files that are already tracked and have been modified or deleted. It does not include newly created files, so those still need to be added with `git add` first.

![Screenshot 1](Screenshot%202026-09-11%20221819.png)

`git commit -m` didn't commit anything because nothing was added. `git commit -a -m` committed file1.txt (tracked file) but file2.txt was still untracked, so i had to `git add` it.

## Git cherry-pick

`git cherry-pick <commit>` applies the changes from a specific commit onto the current branch.

made 3 commits in main, then made a feature branch with 3 commits and cherry-picked only "feature commit b" into main.

![Screenshot 2](Screenshot%202026-09-11%20221823.png)

only b.txt came into main, a.txt and c.txt are not there. the cherry-picked commit got a new hash in main.
