TMP ?= $(abspath tmp)

ANALYZE_FLAGS ?= -quiet
BUILD_FLAGS ?= -quiet
IOS_TEST_DEVICE ?= iPhone 16e
TEST_FLAGS ?= -quiet


arch := $(shell uname -m)
objc_files := $(shell find src -type f \( -name '*.h' -o -name '*.m' \))
scheme_files := $(wildcard mcmus.xcodeproj/xcshareddata/xcschemes/*.xcscheme)
scheme_files_hash := $(shell cat $(scheme_files) | md5)
ver := 1.0

project_files := \
		mcmus.xcodeproj/project.pbxproj \
		$(TMP)/scheme-files-$(scheme_files_hash).stamp

src_files := \
		 .git/hooks/pre-commit \
		$(shell find src -type f -not -name '.*') \
		$(project_files)


.SECONDEXPANSION :


# ----- phony targets -----


.PHONY : check
check : \
		$(TMP)/analyzed-iOS.stamp \
		$(TMP)/analyzed-macOS.stamp \
		$(TMP)/built-create-manifest.stamp \
		$(TMP)/built-share-test.stamp \
		$(TMP)/built-sync-test.stamp \
		$(TMP)/checked-format.stamp \
		$(TMP)/checked-iOS.stamp \
		$(TMP)/checked-macOS.stamp


.PHONY : analyze
analyze : \
		$(TMP)/analyzed-iOS.stamp \
		$(TMP)/analyzed-macOS.stamp


.PHONY : check-format
check-format : $(TMP)/checked-format.stamp


.PHONY : format
format :
	xcrun clang-format -i --style=file:.clang-format $(objc_files)


.PHONY : full-sync
full-sync : scripts/full-sync | $(TMP)/full-sync-work
	-rm -rf $(TMP)/full-sync-work/*
	scripts/full-sync \
		--extract \
		$(TMP)/full-sync-work


.PHONY : list-simulators
list-simulators :
	xcodebuild -project mcmus.xcodeproj -scheme app -showdestinations


.PHONY : release
release : $(TMP)/made-disk-image.stamp


.PHONY : create-manifest
create-manifest : \
		$(TMP)/built-create-manifest.stamp \
		| $(TMP)/create-manifest-work
	$(TMP)/create-manifest/create-manifest \
		functional-tests/music \
		--workdir=$(TMP)/create-manifest-work


.PHONY : share-test
share-test : $(TMP)/built-share-test.stamp | $(TMP)/share-test-work
	$(TMP)/share-test/share-test \
		functional-tests/music \
		--workdir=$(TMP)/share-test-work


.PHONY : sync-test
sync-test : \
		$(TMP)/built-sync-test.stamp \
		| $(TMP)/sync-test-music $(TMP)/sync-test-work
	$(TMP)/sync-test/sync-test \
		$(TMP)/sync-test-music \
		--workdir=$(TMP)/sync-test-work


.PHONY : clean
clean :
	rm -rf *.profraw
	rm -rf scripts/__pycache__
	rm -rf $(TMP)


# ----- file targets -----


.git/hooks/pre-commit : scripts/pre-commit
	cp $< $@


$(TMP)/ \
$(TMP)/app-release \
$(TMP)/create-manifest \
$(TMP)/create-manifest-work \
$(TMP)/full-sync-work \
$(TMP)/share-test \
$(TMP)/share-test-work \
$(TMP)/sync-test \
$(TMP)/sync-test-music \
$(TMP)/sync-test-work :
	mkdir -p $@


$(TMP)/analyzed-iOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild analyze \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=$(IOS_TEST_DEVICE)' \
		-derivedDataPath $(TMP)/analyze-iOS \
		$(ANALYZE_FLAGS)
	touch $@


$(TMP)/analyzed-macOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild analyze \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Debug \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(TMP)/analyze-macOS \
		$(ANALYZE_FLAGS)
	touch $@


# use a stamp file since the app bundle is a directory and thus doesn't have an
# `st_mtime` usable for change detection; also, the app bundle name contains a
# space and thus can't be a target name
$(TMP)/built-release.stamp : \
		$(TMP)/analyzed-iOS.stamp \
		$(TMP)/analyzed-macOS.stamp \
		$(TMP)/built-create-manifest.stamp \
		$(TMP)/built-share-test.stamp \
		$(TMP)/built-sync-test.stamp \
		$(TMP)/checked-format.stamp \
		$(TMP)/checked-iOS.stamp \
		$(TMP)/checked-macOS.stamp \
		| $(TMP)/app-release
	rm -rf $(TMP)/app-release
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-derivedDataPath $(TMP)/build-release \
		CONFIGURATION_BUILD_DIR=$(TMP)/app-release \
		$(BUILD_FLAGS)
	touch $@


$(TMP)/built-create-manifest.stamp : $(src_files) | $(TMP)/create-manifest
	rm -rf $(TMP)/create-manifest
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme create-manifest \
		-configuration Debug \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(TMP)/build-create-manifest \
		CONFIGURATION_BUILD_DIR=$(TMP)/create-manifest \
		$(BUILD_FLAGS)
	touch $@


$(TMP)/built-share-test.stamp : $(src_files) | $(TMP)/share-test
	rm -rf $(TMP)/share-test
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme share-test \
		-configuration Debug \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(TMP)/build-share-test \
		CONFIGURATION_BUILD_DIR=$(TMP)/share-test \
		$(BUILD_FLAGS)
	touch $@


$(TMP)/built-sync-test.stamp : $(src_files) | $(TMP)/sync-test
	rm -rf $(TMP)/sync-test
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme sync-test \
		-configuration Debug \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(TMP)/build-sync-test \
		CONFIGURATION_BUILD_DIR=$(TMP)/sync-test \
		$(BUILD_FLAGS)
	touch $@


$(TMP)/checked-format.stamp : $(objc_files) | $$(dir $$@)
	scripts/check-format --style=file:.clang-format --Werror --srcdir src
	touch $@


$(TMP)/checked-iOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild test \
		-project mcmus.xcodeproj \
		-scheme app \
		-destination 'platform=iOS Simulator,name=$(IOS_TEST_DEVICE)' \
		-derivedDataPath $(TMP)/check-iOS \
		$(TEST_FLAGS)
	touch $@


$(TMP)/checked-macOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild test \
		-project mcmus.xcodeproj \
		-scheme app \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(TMP)/check-macOS \
		$(TEST_FLAGS)
	touch $@


# use a stamp file since the disk image name contains a space and thus can't be
# a target name
$(TMP)/made-disk-image.stamp : \
		$(TMP)/built-release.stamp \
		scripts/make-disk-image
	scripts/make-disk-image "$(TMP)/app-release/MC Mus.app" $(TMP)
	touch $@


# Xcode touches the shared scheme files every time it opens
# so track changes using a hash of the contents
$(TMP)/scheme-files-$(scheme_files_hash).stamp : | $$(dir $$@)
	rm -rf $(TMP)/scheme-files-*.stamp
	touch $@
