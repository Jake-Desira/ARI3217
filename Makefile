# The pipeline as a program (Session 5).
# Recipes must start with a TAB, not spaces.

# One version, in one place: pyproject.toml. Everything else reads it.
VERSION := $(shell python3 -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])")
IMAGE ?= shop-model

# Also tag each image with the commit it was built from.
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo nogit)

# GitHub Actions passes the repository URL as SOURCE. It defaults to empty
# when you build locally.
SOURCE ?=

# When SOURCE is set, add the repository URL to the image's metadata.
# This links the image published to GHCR back to the GitHub repo.
LABELS := $(if $(SOURCE),--label org.opencontainers.image.source=$(SOURCE))

GATE_SPLIT ?= holdout

# These names are commands you can ask Make to run. Include the new publish target.
.PHONY: install lint test validate gate build up version ci publish

install:
	python3 -m pip install -r requirements.txt
	python3 -m pip install --no-deps -e ".[dev]"

lint:
	ruff check src tests

test:
	pytest -q

validate:
	shop-validate

gate:
	shop-gate --split $(GATE_SPLIT)

# Build one image with two tags. $(LABELS) adds the source URL when supplied.
build:
	docker build --build-arg MODEL_VERSION=$(VERSION) \
		-t $(IMAGE):$(VERSION) \
		-t $(IMAGE):$(VERSION)-$(GIT_SHA) $(LABELS) .

# Upload the image built above under both tags. GitHub Actions signs in to
# GHCR first, then runs this target after make ci passes on main.
publish:
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(VERSION)-$(GIT_SHA)

up:
	MODEL_VERSION=$(VERSION) docker compose up -d --build

version:
	@echo $(VERSION)

# Run the whole pipeline with make ci.
ci: lint test validate gate build