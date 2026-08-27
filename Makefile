API_BASE_URL ?= http://localhost:8080
MISSION_DEPLOY_TOKEN ?=
WEB_HOST ?= 0.0.0.0
WEB_PORT ?= 7357
SITL_RUNNER := ./tools/sitl-observer/sitl-observer.sh

.PHONY: web sitl-up sitl-status sitl-activate sitl-mission-deploy sitl-mission-run sitl-arm sitl-disarm sitl-demo-flight sitl-out-of-bounds sitl-return-in-bounds sitl-land sitl-complete sitl-console sitl-down

web:
	flutter run -d web-server --no-pub --web-hostname=$(WEB_HOST) --web-port=$(WEB_PORT) --dart-define=AERO_ARC_API_BASE_URL=$(API_BASE_URL) --dart-define=AERO_ARC_MISSION_DEPLOYMENT_TOKEN=$(MISSION_DEPLOY_TOKEN)

sitl-up:
	$(SITL_RUNNER) up

sitl-status:
	$(SITL_RUNNER) status

sitl-activate:
	$(SITL_RUNNER) activate

sitl-mission-deploy:
	$(SITL_RUNNER) deploy-mission

sitl-mission-run:
	$(SITL_RUNNER) mission-run

sitl-arm:
	$(SITL_RUNNER) aircraft-command arm

sitl-disarm:
	$(SITL_RUNNER) aircraft-command disarm

sitl-demo-flight:
	$(SITL_RUNNER) demo-flight

sitl-out-of-bounds:
	$(SITL_RUNNER) move-outside

sitl-return-in-bounds:
	$(SITL_RUNNER) move-inside

sitl-land:
	$(SITL_RUNNER) land

sitl-complete:
	$(SITL_RUNNER) complete

sitl-console:
	$(SITL_RUNNER) console

sitl-down:
	$(SITL_RUNNER) down
