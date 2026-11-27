what is standart procedure: to create a .lint file in the root of git repo or use gha workflow for linting?

Comparing lint config files with CI workflow options.

They aren't alternatives. The standard setup uses both, and they do different jobs:

Config file in the repo defines what the rules are.
Workflow defines when and where the linter runs, and it blocks bad changes.

There is no standard file named .lint. Each linter has its own config name:

Tool	Config file in repo root
yamllint	.yamllint.yaml (or .yamllint)
actionlint	.github/actionlint.yaml (optional)
markdownlint	.markdownlint.yaml
shellcheck	.shellcheckrc
golangci-lint	.golangci.yml
pre-commit (runs all of them)	.pre-commit-config.yaml
The usual layering
Config file committed to the repo, so everyone (you, teammates, CI) uses identical rules.
Run locally, either manually (yamllint .) or automatically before each commit with pre-commit. This catches errors in seconds, before you push.
CI workflow runs the same linters on every push and pull request. This is the enforcement point, because local hooks can be skipped (git commit --no-verify) but CI can't.
Branch protection (optional) requires the lint job to pass before merging.
Why CI alone isn't ideal

If linting only happens in the workflow, you find out about typos after pushing and waiting for the runner. Local checks give fast feedback, and CI is the safety net.

A neat way to keep them in sync

Use pre-commit for both local and CI, so the rules live in one place:

yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: [-c, .yamllint.yaml]
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.1
    hooks:
      - id: actionlint

Locally: pre-commit install (runs on each commit).
In the workflow:

yaml
- uses: actions/setup-python@v5
- run: pip install pre-commit
- run: pre-commit run --all-files

This also sidesteps the apt/snap installation problems from earlier, since pre-commit downloads and pins each tool itself. Check the rev versions against the latest releases when you set it up.

For your homelab

Keep it simple: commit .yamllint.yaml (with the templates/ and dashboards/ ignores), keep your workflow running yamllint and actionlint, and add pre-commit later if you want local checks. For the Helm charts, add helm lint to the workflow, since yamllint can't parse the templates.