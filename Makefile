# Makefile
# Usage: make <target>

.PHONY: help add commit push all
.DEFAULT_GOAL := help

# Default target
help:
	@echo "Available targets:"
	@echo "  add           - Add files to git repository"
	@echo "  commit        - Commit changes to git repository"
	@echo "  push          - Push changes to remote repository"
	@echo "  all           - Run all targets"


#  git repository update
add:
	@echo "Adding files to git repository..."
	git add .

commit:
	@echo "Committing changes to git repository..."
	fun1 ()	{
		git commit -m "$(1)" || echo "No changes to commit."
	}
	fun1

push:
	@echo "Pushing changes to remote repository..."
	git push origin main && git push github main

all: add commit push
