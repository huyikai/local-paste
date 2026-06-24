APP_NAME = LocalPaste
BUILD_DIR = .build
RESOURCES = Sources/$(APP_NAME)/Resources
BIN_PATH := $(shell swift build --show-bin-path -c release 2>/dev/null || echo ".build/release")
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "0.0.0")

.PHONY: all build build-universal run run-background app dmg install icon clean version

all: build

build:
	swift build -c release --disable-sandbox

build-universal:
	swift build -c release --arch arm64 --arch x86_64 --disable-sandbox

run: build
	$(BIN_PATH)/$(APP_NAME)

run-background: build
	$(BIN_PATH)/$(APP_NAME) &
	@echo "$(APP_NAME) launched in background. Use 'make kill' to stop."

app: build icon
	@echo "Creating $(APP_NAME).app..."
	@mkdir -p "$(APP_NAME).app/Contents/MacOS" "$(APP_NAME).app/Contents/Resources"
	cp $(BIN_PATH)/$(APP_NAME) "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_NAME).app/Contents/Info.plist"
	@swift Scripts/gen-icon.swift "$(APP_NAME).app/Contents/Resources/icon.png" 2>/dev/null || \
		echo "  (icon generation skipped, app will use default icon)"
	@echo "  Signing..."
	codesign --force --sign - "$(APP_NAME).app" 2>/dev/null || true
	@echo "✅ $(APP_NAME).app created."
	@echo "   Drag to Applications folder or run: make install"

app-universal: build-universal icon
	@echo "Creating $(APP_NAME).app (universal)..."
	@mkdir -p "$(APP_NAME).app/Contents/MacOS" "$(APP_NAME).app/Contents/Resources"
	cp $(BIN_PATH)/$(APP_NAME) "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_NAME).app/Contents/Info.plist"
	@swift Scripts/gen-icon.swift "$(APP_NAME).app/Contents/Resources/icon.png" 2>/dev/null || \
		echo "  (icon generation skipped, app will use default icon)"
	@echo "  Signing..."
	codesign --force --sign - "$(APP_NAME).app" 2>/dev/null || true
	@echo "✅ $(APP_NAME).app (universal) created."

dmg: app-universal
	@echo "Creating $(APP_NAME)-$(VERSION).dmg..."
	@mkdir -p .dmg-staging
	@cp -R "$(APP_NAME).app" .dmg-staging/
	@ln -s /Applications .dmg-staging/Applications 2>/dev/null || true
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder .dmg-staging \
		-ov -format UDZO \
		"$(APP_NAME)-$(VERSION).dmg"
	@rm -rf .dmg-staging
	@echo "✅ $(APP_NAME)-$(VERSION).dmg created."

icon:
	@echo "Generating app icon..."
	@mkdir -p "$(APP_NAME).app/Contents/Resources" 2>/dev/null || true
	@swift Scripts/gen-icon.swift "$(APP_NAME).app/Contents/Resources/icon.png" 2>/dev/null || \
		echo "  (icon generation skipped, app will use default icon)"

install: app
	cp -r "$(APP_NAME).app" /Applications/
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

kill:
	-pkill -x $(APP_NAME) 2>/dev/null; true

version:
	@echo $(VERSION)

clean:
	rm -rf .build .dmg-staging
	rm -rf "$(APP_NAME).app"
	rm -f "$(APP_NAME)"*.dmg
