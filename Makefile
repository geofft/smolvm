features ?= ui cd

features_filenames := $(foreach feature,${features},${feature}.swift)
features_defines := $(foreach feature,${features},-D${feature})

smolvm: main.swift entitleme.plist ${features_filenames}
	swiftc -o smolvm -framework Virtualization main.swift ${features_filenames} ${features_defines}
	codesign --sign - --entitlements entitleme.plist smolvm

clean:
	rm -f smolvm
