APP_NAME := NeonPointer

.PHONY: all project build dmg run clean

all: dmg

project:
	xcodegen generate

build:
	./scripts/build.sh

dmg: build
	./scripts/make-dmg.sh

run: build
	open dist/$(APP_NAME).app

clean:
	rm -rf .build dist $(APP_NAME).xcodeproj Support/Info.plist
