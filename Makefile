.PHONY: setup run check format build

setup:
	flutter config --enable-web
	flutter pub get

run:
	flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

check:
	dart format --output=none --set-exit-if-changed lib test
	flutter analyze
	flutter test

format:
	dart format lib test

build:
	flutter build web
