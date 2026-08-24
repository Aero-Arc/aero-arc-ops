API_BASE_URL ?= http://localhost:8080
WEB_HOST ?= 0.0.0.0
WEB_PORT ?= 7357

.PHONY: web

web:
	flutter run -d web-server --no-pub --web-hostname=$(WEB_HOST) --web-port=$(WEB_PORT) --dart-define=AERO_ARC_API_BASE_URL=$(API_BASE_URL)
