VERSION ?= $(shell echo $$1)
RELEASE_TYPE ?= $(shell echo $$2)
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

all: check_args update_version generate_changelog commit_changes tag_release push_changes switch_branch rebase_and_push api_e2e

release: check_args update_version generate_changelog commit_changes tag_release push_changes switch_branch rebase_and_push

api_e2e: run_api run_e2e docker_down

check_args:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make <version> <release_type>"; exit 1; fi
	@if [ -z "$(RELEASE_TYPE)" ]; then echo "Usage: make <version> <release_type>"; exit 1; fi
	@if [ "$(RELEASE_TYPE)" != "alpha" ] && [ "$(RELEASE_TYPE)" != "release" ]; then echo "Invalid release type. Valid release types are 'alpha' and 'release'"; exit 1; fi
	@if [ "$(CURRENT_BRANCH)" != "main" ]; then echo "You must be on the main branch to release a new version"; exit 1; fi

update_version:
	@echo "Releasing version $(VERSION)"
	@sed -i "s/\"version\": \".*\"/\"version\": \"$(VERSION)\"/g" package.json

generate_changelog:
	@echo "Generating CHANGELOG.md"
	@pnpm run changelog

commit_changes:
	@echo "Committing the changes"
	@git add CHANGELOG.md package.json
	@git commit -m "chore(release): $(VERSION)"

tag_release:
	@echo "Tagging the release"
	@git tag $(VERSION)

push_changes:
	@echo "Pushing the changes to main"
	@git push origin main --tags

switch_branch:
	@echo "Switching to $(RELEASE_TYPE) branch"
	@git checkout $(RELEASE_TYPE)

rebase_and_push:
	@echo "Rebasing main branch"
	@git rebase main
	@echo "Pushing the changes to $(RELEASE_TYPE)"
	@git push origin $(RELEASE_TYPE) --tags


# -----------------------_E2E TESTS----------------------- #

docker_up:
	@echo "Starting docker containers"
	@docker compose up -d

run_api: docker_up
	@echo "Running API"
	@DATABASE_URL="postgresql://prisma:prisma@localhost:5433/tests" pnpm run dev:api&

run_e2e:
	@sleep 10
	@echo "Running tests"
	@nx run api-e2e:e2e

docker_down: run_e2e
	@echo "Stopping docker containers"
	@docker compose down
	@kill -9 $(shell lsof -t -i:4200)