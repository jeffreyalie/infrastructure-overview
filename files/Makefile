# Makefile
# Usage: make <target>

.PHONY: help show-files show-path
.DEFAULT_GOAL := help

# Default target
help:
	@echo "Available targets:"
	@echo "  show-files    - Show files in the current directory"
	@echo "  show-path     - Show the current path"

# Build Docker image
show-files:
	@echo "Files in the current directory:"
	ls -l

# Show current path
show-path:
	@echo "Current path:"
	pwd

# #-----------------------
# .RECIPEPREFIX = >
# .PHONY: init tidy fmt check all

# GO = docker run --rm --user $(shell id -u):$(shell id -g) \
#   -e HOME=/tmp -e GOCACHE=/tmp/.cache \
#   -v "$(CURDIR)/app":/app -w /app golang:1.26.2-alpine

# init:
# > $(GO) go mod init grafan-lxd-monitoring

# tidy:
# > $(GO) go mod tidy

# fmt:
# > $(GO) gofmt -w .

# check:
# > $(GO) sh -c "gofmt -l . ; go vet ./... && go build -o /tmp/test ."

# all:
# > $(GO) sh -c "go mod tidy && gofmt -w . && go vet ./... && go build -o /tmp/main ."