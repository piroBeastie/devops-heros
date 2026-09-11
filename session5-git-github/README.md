
## Git commit -a

`git commit -m` only commits the files that are already staged with `git add`.

`git commit -a -m` skips the staging step for files that are already tracked and have been modified or deleted. It does not include newly created files, so those still need to be added with `git add` first.

```
$ echo 'hello again' >> file1.txt
$ echo 'new file' > file2.txt

$ git status --short
 M file1.txt
?? file2.txt

$ git commit -m 'commit without add'
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   file1.txt

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	file2.txt

no changes added to commit (use "git add" and/or "git commit -a")

$ git commit -a -m 'commit with -a'
[main 949098c] commit with -a
 1 file changed, 1 insertion(+)

$ git status --short
?? file2.txt

$ git add file2.txt
$ git commit -m 'added file2'
[main 92dd325] added file2
 1 file changed, 1 insertion(+)
 create mode 100644 file2.txt

$ git log --oneline
92dd325 added file2
949098c commit with -a
9750f07 first commit
```

`git commit -m` didn't commit anything because nothing was added. `git commit -a -m` committed file1.txt (tracked file) but file2.txt was still untracked, so i had to `git add` it.

## Git cherry-pick

`git cherry-pick <commit>` applies the changes from a specific commit onto the current branch.

made 3 commits in main, then made a feature branch with 3 commits and cherry-picked only "feature commit b" into main.

```
$ git log --oneline
a810e00 main commit 3
a18e732 main commit 2
48c73f9 main commit 1

$ git checkout -b feature
Switched to a new branch 'feature'

$ echo 'feature a' > a.txt && git add . && git commit -q -m 'feature commit a'
$ echo 'feature b' > b.txt && git add . && git commit -q -m 'feature commit b'
$ echo 'feature c' > c.txt && git add . && git commit -q -m 'feature commit c'

$ git log --oneline
d0371f7 feature commit c
da7d309 feature commit b
159234c feature commit a
a810e00 main commit 3
a18e732 main commit 2
48c73f9 main commit 1

$ git checkout main
Switched to branch 'main'

$ git cherry-pick da7d309
[main b6fc8d4] feature commit b
 Date: Fri Sep 11 16:27:40 2026 +0000
 1 file changed, 1 insertion(+)
 create mode 100644 b.txt

$ git log --oneline
b6fc8d4 feature commit b
a810e00 main commit 3
a18e732 main commit 2
48c73f9 main commit 1

$ ls
b.txt
main.txt
```

only b.txt came into main, a.txt and c.txt are not there. the cherry-picked commit got a new hash (b6fc8d4) in main.
