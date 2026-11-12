TMP ?= $(abspath tmp)

ANALYZE_FLAGS ?= -quiet
BUILD_FLAGS ?= -quiet
IOS_TEST_DEVICE ?= iPhone 16e
TEST_FLAGS ?= -quiet


arch := $(shell uname -m)
derived_data_dir = $(TMP)/DerivedData
objc_files := $(shell find src -type f \( -name '*.h' -o -name '*.m' \))
project_files := \
		mcmus.xcodeproj/project.pbxproj \
		$(wildcard mcmus.xcodeproj/xcshareddata/xcschemes/*.xcscheme)
src_files := \
		 .git/hooks/pre-commit \
		$(shell find src -type f -not -name '.*') \
		$(project_files)
ver := 1.0


.SECONDEXPANSION :


# ----- phony targets -----


.PHONY : check
check : \
		$(TMP)/analyzed-iOS.stamp \
		$(TMP)/analyzed-macOS.stamp \
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


.PHONY : release
release: $(TMP)/made-disk-image.stamp


.PHONY : list-simulators
list-simulators :
	xcodebuild -project mcmus.xcodeproj -scheme app -showdestinations


.PHONY : clean
clean :
	rm -rf *.profraw
	rm -rf $(TMP)


# ----- file targets -----


.git/hooks/pre-commit : scripts/pre-commit
	cp $< $@


$(TMP)/ \
$(TMP)/Release :
	mkdir -p $@


$(TMP)/analyzed-iOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild analyze \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=$(IOS_TEST_DEVICE)' \
		-derivedDataPath $(derived_data_dir)/analyze-iOS \
		$(ANALYZE_FLAGS)
	touch $@


$(TMP)/analyzed-macOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild analyze \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Debug \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(derived_data_dir)/analyze-macOS \
		$(ANALYZE_FLAGS)
	touch $@


# use a stamp file since the app bundle is a directory and thus doesn't have an
# `st_mtime` usable for change detection; also, the app bundle name contains a
# space and thus can't be a target name
$(TMP)/built-release.stamp : \
		$(TMP)/checked-format.stamp \
		$(TMP)/checked-iOS.stamp \
		$(TMP)/checked-macOS.stamp \
		| $(TMP)/Release
	rm -rf $(TMP)/Release
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-derivedDataPath $(derived_data_dir)/build-release \
		CONFIGURATION_BUILD_DIR=$(TMP)/Release \
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
		-derivedDataPath $(derived_data_dir)/test-iOS \
		$(TEST_FLAGS)
	touch $@


$(TMP)/checked-macOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild test \
		-project mcmus.xcodeproj \
		-scheme app \
		-destination 'platform=macOS,arch=$(arch)' \
		-derivedDataPath $(derived_data_dir)/test-macOS \
		$(TEST_FLAGS)
	touch $@


# use a stamp file since the disk image name contains a space and thus can't be
# a target name
$(TMP)/made-disk-image.stamp : $(TMP)/built-release.stamp scripts/make-dmg.sh
	scripts/make-dmg.sh "$(TMP)/Release/MC Mus.app" $(TMP)
	touch $@
