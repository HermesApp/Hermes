XCB           = xcodebuild
CONFIGURATION = Debug
HERMES        = ./build/$(CONFIGURATION)/Hermes.app/Contents/MacOS/Hermes
DEBUGGER      = gdb

# For some reason the project's SYMROOT setting is ignored when we specify an
# explicit -project option. The -project option is required when using xctool.
COMMON_OPTS    = -project Hermes.xcodeproj SYMROOT=build

all: hermes

hermes:
	$(XCB) $(COMMON_OPTS) -configuration $(CONFIGURATION) -target Hermes

run: hermes
	$(HERMES)

dbg: hermes
	$(DEBUGGER) $(HERMES)

archive:
	$(XCB) $(COMMON_OPTS) -configuration Release -target 'Build Sparkle metadata'

clean:
	$(XCB) $(COMMON_OPTS) -target Hermes clean
	rm -rf build

.PHONY: all hermes run dbg archive clean
