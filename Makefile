.PHONY: generate build run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -quiet -project GraphCodex.xcodeproj -scheme GraphCodex -configuration Debug -derivedDataPath .build build

run: build
	open .build/Build/Products/Debug/GraphCodex.app

clean:
	rm -rf .build GraphCodex.xcodeproj
