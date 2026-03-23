.PHONY: generate build test run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project OnAir.xcodeproj -scheme OnAir -configuration Debug -derivedDataPath build build

test: generate
	xcodebuild -project OnAir.xcodeproj -scheme OnAir -configuration Debug -derivedDataPath build test

run: build
	open build/Build/Products/Debug/OnAir.app

clean:
	xcodebuild -project OnAir.xcodeproj -scheme OnAir clean
	rm -rf build
