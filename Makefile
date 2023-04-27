# To do stuff with make, you type `make` in a directory that has a file called
# "Makefile".  You can also type `make -f <makefile>` to use a different filename.
#
# A Makefile is a collection of rules. Each rule is a recipe to do a specific
# thing, sort of like a grunt task or an npm package.json script.
#
# A rule looks like this:
#
# <target>: <prerequisites...>
# 	<commands>
#
# The "target" is required. The prerequisites are optional, and the commands
# are also optional, but you have to have one or the other.
#
# Type `make` to show the available targets and a description of each.
#
.DEFAULT_GOAL := help
.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Formatting

.PHONY: format-black
format-black: ## black (code formatter)
	@poetry run black .

.PHONY: format-isort
format-isort: ## isort (import formatter)
	@poetry run isort .

.PHONY: format
format: format-black format-isort ## run all formatters

##@ Linting

.PHONY: lint-black
lint-black: ## black in linting mode
	@poetry run black --check --diff .

.PHONY: lint-isort
lint-isort: ## isort in linting mode
	@poetry run isort --check --diff .

.PHONY: lint-flake8
lint-flake8: ## flake8 (linter)
	@poetry run flake8 .

.PHONY: lint-mypy
lint-mypy: ## mypy (static-type checker)
	@poetry run mypy --config-file pyproject.toml .

.PHONY: lint-mypy-report
lint-mypy-report: ## run mypy & create report
	@poetry run mypy --config-file pyproject.toml . --html-report ./mypy_html

lint: lint-black lint-isort lint-flake8 ## run all linters

##@ Running & Debugging

.PHONY: run
run: ## run the main script
	@poetry run sdwaddle

##@ Testing

.PHONY: tests
tests: ## run tests with pytest
	@poetry run pytest --doctest-modules

.PHONY: tests-cov
tests-cov: ## run tests with pytest and show coverage (terminal + html)
	@poetry run pytest --doctest-modules --cov=src --cov-report term-missing --cov-report=html

.PHONY: tests-cov-fail
tests-cov-fail: ## run unit tests with pytest and show coverage (terminal + html) & fail if coverage too low & create files for CI
	@poetry run pytest --doctest-modules --cov=src --cov-report term-missing --cov-report=html --cov-fail-under=80 --junitxml=pytest.xml | tee pytest-coverage.txt

##@ Jupyter-Book

book-build: ## build documentation locally
	@poetry run jupyter-book build book

book-build-all: ## build all documentation locally
	@poetry run jupyter-book build book --all

book-publish: ## publish documentation to "gh-pages" branch
	@poetry run ghp-import -n -p -f book/_build/html

book-deploy: ## build & publish documentation to "gh-pages" branch
	book-build book-publish

##@ Clean-up

clean-cov: ## remove output files from pytest & coverage
	@rm -rf .coverage
	@rm -rf htmlcov
	@rm -rf pytest.xml
	@rm -rf pytest-coverage.txt

clean-book-build: ## remove output files from mkdocs
	@rm -rf book/_build

clean-pycache: ## remove __pycache__ directories
	@find . -name __pycache__ -type d -exec rm -rf {} +

clean: clean-cov clean-book-build clean-pycache ## run all clean commands

##@ Releases

version: ## returns the current version
	@poetry run semantic-release print-version --current

next-version: ## returns the next version
	@poetry run semantic-release print-version --next

changelog: ## returns the current changelog
	@poetry run semantic-release changelog --released

next-changelog: ## returns the next changelog
	@poetry run semantic-release changelog --unreleased

release-noop: ## release without changing anything
	@poetry run semantic-release publish -v DEBUG --noop

release-ci: ## release in CI
	@poetry run semantic-release publish -v DEBUG -D commit_author="github-actions <action@github.com>"

prerelease-noop: ## release a pre-release without changing anything
	@poetry run semantic-release publish -v DEBUG --prerelease --noop

prerelease-ci: ## release a pre-release in CI
	@poetry run semantic-release publish --prerelease -v DEBUG -D commit_author="github-actions <action@github.com>"

build: ## build the package
	@poetry build

##@ Git Branches

show-branches: ## show all branches
	@git show-branch --list

dev-checkout: ## checkout the dev branch
	@branch=$(shell echo $${branch:-"dev"}) && \
	    git show-branch --list | grep -q $${branch} && \
		git checkout $${branch}

dev-checkout-upstream: ## create and checkout the dev branch, and set the upstream
	@branch=$(shell echo $${branch:-"dev"}) && \
		git checkout -B $${branch} && \
		git push --set-upstream origin $${branch} || true

main-checkout: ## checkout the main branch
	@git checkout main

##@ Utilities

large-files: ## show the 20 largest files in the repo
	@find . -printf '%s %p\n'| sort -nr | head -20

disk-usage: ## show the disk usage of the repo
	@du -h -d 2 .

git-sizer: ## run git-sizer
	@git-sizer --verbose

##@ Setup

install-pipx: ## install pipx (pre-requisite for external tools)
	@pipx --version &> /dev/null || pip install --user pipx || true

install-copier: install-pipx ## install copier (pre-requisite for init-project)
	@copier --version &> /dev/null || pipx install copier || true

install-poetry: install-pipx ## install poetry (pre-requisite for install)
	@poetry --version &> /dev/null || pipx install poetry || true

install-commitzen: install-poetry ## install commitzen (pre-requisite for commit)
	@cz version &> /dev/null || poetry add commitizen --group dev || true

install-precommit: install-commitzen ## install pre-commit
	@pre-commit --version &> /dev/null || poetry add pre-commit --group dev || true

install-precommit-hooks: install-precommit ## install pre-commit hooks
	@pre-commit install

install: ## install the package
	@poetry install --without dev

update: ## update the package
	@poetry update
	
install-dev: ## install the package in development mode
	@poetry install --with dev

initialize: install-precommit ## install pre-commit hooks
	@pre-commit install

remove-template: ## remove the template files (Warning: make sure you don't need them anymore!)
	@rm -rf .copier-template
	@rm -rf .copier.yaml

init-project: install-copier install-precommit-hooks remove-template ## initialize the project (Warning: do this only once!)
	@copier --answers-file .copier-config.yaml gh:entelecheia/hyperfast-python-template .

init-git: ## initialize git
	@git init

reinit-project: install-copier ## reinitialize the project (Warning: this may overwrite existing files!)
	@copier --answers-file .copier-config.yaml gh:entelecheia/hyperfast-python-template .

