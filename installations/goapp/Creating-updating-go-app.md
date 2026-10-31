# Creating - updating - goapp

## First time: creating a new Go app

Run these once in the app folder (app/), with your .go files already written.

```bash
cd app

# 1. Create go.mod (module name = your app name)
docker run --rm --user $(id -u):$(id -g) \
  -e HOME=/tmp -e GOCACHE=/tmp/.cache \
  -v "$PWD":/app -w /app golang:1.26.2-alpine \
  sh -c "go mod init go-lxd-vm-dashboard && go mod tidy"
```

* go mod init <name> creates go.mod.
* go mod tidy reads your imports, downloads every dependency, and creates go.sum.

Then check it compiles and commit:

```bash
# 2. Check it builds and is formatted
docker run --rm --user $(id -u):$(id -g) \
  -e HOME=/tmp -e GOCACHE=/tmp/.cache \
  -v "$PWD":/app -w /app golang:1.26.2-alpine \
  sh -c "gofmt -l . ; go vet ./... && go build -o /tmp/test ."

# 3. Commit everything, including go.mod and go.sum
cd ..
git add app/
git commit -m "feat: initial go app"
git push
```

The Dockerfile, index.html, and Helm chart go in the same commit. The pipeline’s docker build does the real compile after that.

## Later: changing the source files

**Case A:** you only changed code, no new outside libraries
(edited functions, HTML, handlers, or used only the standard library)

``` bash
# optional quick check
cd app
docker run --rm --user $(id -u):$(id -g) \
  -e HOME=/tmp -e GOCACHE=/tmp/.cache \
  -v "$PWD":/app -w /app golang:1.26.2-alpine \
  sh -c "gofmt -l . ; go vet ./..."

cd ..
git add app/
git commit -m "fix: describe change"
git push
```
No go mod tidy needed.

**Case B:** you added, removed, or upgraded an outside library
(anything imported from github.com/... or golang.org/x/...)

Save your code changes first, then:

```bash
cd app
docker run --rm --user $(id -u):$(id -g) \
  -e HOME=/tmp -e GOCACHE=/tmp/.cache \
  -v "$PWD":/app -w /app golang:1.26.2-alpine \
  sh -c "go mod tidy"
```
Use go get **<package>@latest && go mod tidy** only if **tidy** alone can’t find a new package. Usually go mod tidy is enough, because it detects the new import by itself.

Then:

```bash
git status                      # go.mod and go.sum should show as modified
cd ..
git add app/
git commit -m "feat: add <library>"
git push
```
**Shortcut: make it one reusable command**

Put this in a Makefile at the repo root so you don’t retype the Docker line:

``` 
makefile
GO = docker run --rm --user $(shell id -u):$(shell id -g) \
  -e HOME=/tmp -e GOCACHE=/tmp/.cache \
  -v "$(PWD)/app":/app -w /app golang:1.26.2-alpine

tidy:
	$(GO) go mod tidy

check:
	$(GO) sh -c "gofmt -l . ; go vet ./... && go build -o /tmp/test ."
```

Then use make tidy after changing libraries and make check before every push. (Makefile recipe lines must start with a tab, not spaces.)

## Quick summary
What you did	                    Run	                                Commit
New app	                            go mod init + go mod tidy	        all files including go.mod, go.sum
Changed code only	                optional check	                    the changed files
Added or removed a library	        go mod tidy, then check	            code + go.mod + go.sum

Rule of thumb: if git status shows a new import in your code but go.mod hasn’t changed, run