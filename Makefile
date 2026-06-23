APP_NAME = LocalPaste
BUILD_DIR = .build
RESOURCES = Sources/$(APP_NAME)/Resources

.PHONY: all build run run-background app install icon clean

all: build

build:
	swift build -c release --disable-sandbox

run: build
	.build/release/$(APP_NAME)

run-background: build
	.build/release/$(APP_NAME) &
	@echo "$(APP_NAME) launched in background. Use 'make kill' to stop."

app: build icon
	@echo "Creating $(APP_NAME).app..."
	@mkdir -p "$(APP_NAME).app/Contents/MacOS" "$(APP_NAME).app/Contents/Resources"
	cp .build/release/$(APP_NAME) "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_NAME).app/Contents/Info.plist"
	@if [ -f "Scripts/gen-icon.swift" ]; then \
		mkdir -p "$(APP_NAME).app/Contents/Resources" && \
		swift Scripts/gen-icon.swift "$(APP_NAME).app/Contents/Resources/icon.png" 2>/dev/null || true; \
	fi
	@echo "✅ $(APP_NAME).app created."
	@echo "   Drag to Applications folder or run: make install"

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

clean:
	rm -rf .build
	rm -rf "$(APP_NAME).app"
