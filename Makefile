# Do not mind me. I'm just a nice wrapper around xcodebuild(1).

XCB           = xcodebuild
CONFIGURATION = Debug
HERMES        = ./build/$(CONFIGURATION)/Hermes.app/Contents/MacOS/Hermes
DEBUGGER      = lldb

# For some reason the project's SYMROOT setting is ignored when we specify an
# explicit -project option. The -project option is required when using xctool.
COMMON_OPTS   = -project Hermes.xcodeproj SYMROOT=build

all: hermes

hermes:
	$(XCB) $(COMMON_OPTS) -configuration $(CONFIGURATION) -scheme Hermes

run: hermes
	$(HERMES)

dbg: hermes
	$(DEBUGGER) $(HERMES)

install:
	$(XCB) $(COMMON_OPTS) -configuration Release -scheme Hermes
	rm -rf /Applications/Hermes.app
	cp -a ./build/Release/Hermes.app /Applications/

archive:
	# Create an archive to share (for beta testing purposes).
	$(XCB) $(COMMON_OPTS) -configuration Release -scheme 'Archive Hermes'

upload-release:
	# Used to be called 'archive'. Upload Hermes and update the website.
	$(XCB) $(COMMON_OPTS) -configuration Release -scheme 'Upload Hermes Release'

clean:
	$(XCB) $(COMMON_OPTS) -scheme Hermes clean
	rm -rf build

.PHONY: all hermes run dbg archive clean install archive upload-release
