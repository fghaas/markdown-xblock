.DEFAULT_GOAL := help

.PHONY: dev.clean dev.build dev.run

REPO_NAME := xblock-html
PACKAGE_NAME := html_xblock
EXTRACT_DIR := $(PACKAGE_NAME)/locale/en/LC_MESSAGES
EXTRACTED_DJANGO := $(EXTRACT_DIR)/django-partial.po
EXTRACTED_DJANGOJS := $(EXTRACT_DIR)/djangojs-partial.po
EXTRACTED_TEXT := $(EXTRACT_DIR)/text.po
JS_TARGET := public/js/translations
TRANSLATIONS_DIR := $(PACKAGE_NAME)/translations

help:
	@perl -nle'print $& if m{^[\.a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

dev.clean:
	-docker rm $(REPO_NAME)-dev
	-docker rmi $(REPO_NAME)-dev

dev.build:
	docker build -t $(REPO_NAME)-dev $(CURDIR)

dev.run: dev.clean dev.build ## Clean, build and run test image
	docker run -p 8000:8000 -v $(CURDIR):/usr/local/src/$(REPO_NAME) --name $(REPO_NAME)-dev $(REPO_NAME)-dev

## Localization targets

extract_translations: symlink_translations ## extract strings to be translated, outputting .po files
	cd $(PACKAGE_NAME) && i18n_tool extract
	mv $(EXTRACTED_DJANGO) $(EXTRACTED_TEXT)
	if [ -f "$(EXTRACTED_DJANGOJS)" ]; then cat $(EXTRACTED_DJANGOJS) >> $(EXTRACTED_TEXT); rm $(EXTRACTED_DJANGOJS); fi

compile_translations: symlink_translations ## compile translation files, outputting .mo files for each supported language
	cd $(PACKAGE_NAME) && i18n_tool generate
	python manage.py compilejsi18n --namespace $(PACKAGE_NAME)i18n --output $(JS_TARGET)

detect_changed_source_translations:
	cd $(PACKAGE_NAME) && i18n_tool changed

dummy_translations: ## generate dummy translation (.po) files
	cd $(PACKAGE_NAME) && i18n_tool dummy

build_dummy_translations: dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations

pull_translations: ## pull translations from transifex
	cd $(PACKAGE_NAME) && i18n_tool transifex pull

push_translations: extract_translations ## push translations to transifex
	cd $(PACKAGE_NAME) && i18n_tool transifex push

symlink_translations:
	if [ ! -d "$(TRANSLATIONS_DIR)" ]; then ln -s locale/ $(TRANSLATIONS_DIR); fi

clean: ## Remove generated byte code, coverage reports, and build artifacts
	@echo "--> Clean Python files ..."
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	rm -fr var/
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

selfcheck: ## Check that the Makefile is well-formed
	@echo "The Makefile is well-formed."

test_requirements: ## Install requirements needed by test environment
	pip install -q -r requirements/quality.txt --exists-action w
	pip install -q -r requirements/test.txt --exists-action w

requirements: test_requirements ## Installs all requirements needed by developmenent and test environments
	pip install -q -r requirements/base.txt --exists-action w
	pip install -e .
	@echo "Finished installing requirements."

quality:  ## Run quality tests and checks
	make selfcheck
	pylint html_xblock tests
	pycodestyle html_xblock tests --config=pylintrc
	pydocstyle html_xblock tests --config=pylintrc
	isort --check-only --diff --recursive tests html_xblock

unit-coverage: clean ## Run coverage and unit tests
	mkdir var/
	coverage run ./manage.py test
	coverage html
	coverage xml
	diff-cover coverage.xml --html-report diff-cover.html

unit: clean ## Run unit tests
	mkdir var/
	python manage.py test

test: clean quality unit-coverage ## Run tests and coverage report in the current virtualenv