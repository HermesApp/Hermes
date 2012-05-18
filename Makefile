XCB = xcodebuild
CONFIGURATION = Debug

all: hermes

hermes:
				$(XCB) -configuration $(CONFIGURATION)

run: hermes
				./build/$(CONFIGURATION)/Hermes.app/Contents/MacOS/Hermes
