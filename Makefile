SHELL := /bin/bash -o pipefail

APP_NAME     = Vaani
DERIVED_DIR  = .build
APP_DEBUG    = $(DERIVED_DIR)/debug/$(APP_NAME).app
APP_RELEASE  = $(DERIVED_DIR)/release/$(APP_NAME).app
VERSION     := $(shell tr -d '[:space:]' < VERSION)
DMG_NAME     = $(APP_NAME)-$(VERSION).dmg
DMG_DIR      = release
MODEL       ?= parakeet-v3
CLI          = $(DERIVED_DIR)/debug/VaaniCLI
NO_NET       = sandbox-exec -p '(version 1) (allow default) (deny network*)'
SAMPLES      = $(DERIVED_DIR)/samples
EVAL_CONFIG ?= local/evals.json
EVAL_OUTPUT ?= local/eval-runs/$(shell date +%Y%m%d-%H%M%S)

.PHONY: build release run dev clean lint test evals verify prepare-dependencies offline-test dmg version setup-notary ship help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

dev: run ## Run tests and accuracy/latency evals, then launch

setup-notary: ## Save Vaani notarization credentials in Keychain (once)
	@bash scripts/release.sh --setup-notary

ship: verify ## Validate, build, sign, notarize and staple a Vaani DMG
	@bash scripts/release.sh

build: ## Debug app bundle
	@echo "==> Building $(APP_NAME) (Debug)..."
	@./scripts/build-app.sh debug | tail -1

release: verify ## Validate accuracy/latency and build release app bundle
	@echo "==> Building $(APP_NAME) (Release)..."
	@./scripts/build-app.sh release | tail -1

run: verify ## Validate, build and launch (debug)
	@$(MAKE) build
	@echo "==> Launching $(APP_NAME)..."
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 1
	@open -n "$(abspath $(APP_DEBUG))"

test: prepare-dependencies ## Unit tests, evaluator and release script checks
	@swift build -Xswiftc -DDISABLE_APPLE_INTELLIGENCE 2>&1 | tail -1
	@bash scripts/test-swift.sh
	@python3 Tests/evaluate_check.py
	@python3 Tests/benchmark_dictation_check.py
	@python3 Tests/run_evals_check.py
	@python3 Tests/fluidaudio_patch_check.py
	@python3 Tests/release_check.py
	@python3 scripts/check-identity-migration.py
	@python3 Tests/cli_startup_check.py
	@bash scripts/check-dictation-evidence.sh
	@python3 scripts/check-microphone-startup.py

evals: prepare-dependencies ## Replay every configured local corpus and gate accuracy plus latency
	@swift build --product VaaniCLI -Xswiftc -DDISABLE_APPLE_INTELLIGENCE
	@python3 scripts/run_evals.py --config "$(EVAL_CONFIG)" --cli "$(CLI)" --output "$(EVAL_OUTPUT)"

prepare-dependencies: ## Verify and apply the pinned recognition-library fix
	@bash scripts/prepare-dependencies.sh

verify: ## Required local gate before installing or releasing pipeline changes
	@$(MAKE) test
	@$(MAKE) evals

lint: prepare-dependencies ## Check for compiler warnings
	@echo "==> Checking for warnings..."
	@swift build 2>&1 | grep -E "warning:|error:" || echo "No warnings."

offline-test: prepare-dependencies ## Download MODEL, then transcribe speech and silence with networking denied
	@swift build --product VaaniCLI 2>&1 | tail -1
	@$(CLI) --download-model $(MODEL)
	@mkdir -p $(SAMPLES)
	@test -f $(SAMPLES)/jfk.wav || curl -fsSL https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav -o $(SAMPLES)/jfk.wav
	@python3 -c 'import wave; w=wave.open("$(SAMPLES)/silence.wav","wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(bytes(64000)); w.close()'
	@echo "==> Speech ($(MODEL), offline)"
	@$(NO_NET) $(CLI) --transcribe-file $(SAMPLES)/jfk.wav --model $(MODEL) --language en
	@echo "==> Silence ($(MODEL), offline)"
	@$(NO_NET) $(CLI) --transcribe-file $(SAMPLES)/silence.wav --model $(MODEL) --language en

dmg: release ## Create unsigned DMG for local testing
	@bash scripts/create-dmg.sh "$(APP_RELEASE)" "$(DMG_DIR)/$(DMG_NAME)"

clean: ## Remove build artifacts
	@echo "==> Cleaning..."
	@swift package clean
	@rm -rf $(APP_DEBUG) $(APP_RELEASE) $(SAMPLES) $(DMG_DIR)
	@echo "==> Clean."

version: ## Print current version
	@echo "$(VERSION)"
