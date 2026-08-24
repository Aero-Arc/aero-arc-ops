API_BASE_URL ?= http://localhost:8080
WEB_HOST ?= 0.0.0.0
WEB_PORT ?= 7357
SITL_RUNNER := ./tools/sitl-observer/sitl-observer.sh

.PHONY: web sitl-up sitl-status sitl-activate sitl-arm sitl-disarm sitl-demo-flight sitl-land sitl-complete sitl-console sitl-down

web:
	flutter run -d web-server --no-pub --web-hostname=$(WEB_HOST) --web-port=$(WEB_PORT) --dart-define=AERO_ARC_API_BASE_URL=$(API_BASE_URL)

sitl-up:
	$(SITL_RUNNER) up

sitl-status:
	$(SITL_RUNNER) status

sitl-activate:
	$(SITL_RUNNER) activate

sitl-arm:
	$(SITL_RUNNER) aircraft-command arm

sitl-disarm:
	$(SITL_RUNNER) aircraft-command disarm

sitl-demo-flight:
	$(SITL_RUNNER) demo-flight

sitl-land:
	$(SITL_RUNNER) land

sitl-complete:
	$(SITL_RUNNER) complete

sitl-console:
	$(SITL_RUNNER) console

sitl-down:
	$(SITL_RUNNER) down
