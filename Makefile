APP := build/Scroll Wheel Mission Control.app
VERSION ?= $(shell cat VERSION)

.PHONY: app install zip art clean

## Build the universal app bundle into build/
app:
	VERSION=$(VERSION) ./scripts/build-app.sh

## Build and copy the app to /Applications
install: app
	rm -rf "/Applications/Scroll Wheel Mission Control.app"
	cp -R "$(APP)" /Applications/
	@echo "Installed to /Applications. Open it from Spotlight or Launchpad."

## Build and package a release zip into dist/
zip: app
	mkdir -p dist
	ditto -c -k --keepParent "$(APP)" "dist/ScrollWheelMissionControl-$(VERSION).zip"
	@echo "dist/ScrollWheelMissionControl-$(VERSION).zip"

## Re-render the icon and README images
art:
	swift scripts/generate-art.swift

clean:
	rm -rf .build build dist
