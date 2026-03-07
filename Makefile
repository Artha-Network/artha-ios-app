.PHONY: setup generate clean open

# Install XcodeGen via Homebrew
setup:
	@which xcodegen > /dev/null 2>&1 || brew install xcodegen
	@echo "XcodeGen ready."

# Generate ArthaNetwork.xcodeproj from project.yml
generate:
	xcodegen generate

# Generate project and open in Xcode
open: generate
	open ArthaNetwork.xcodeproj

# Remove generated Xcode project (source files untouched)
clean:
	rm -rf ArthaNetwork.xcodeproj
