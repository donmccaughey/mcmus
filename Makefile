TMP ?= $(abspath tmp)

IOS_CHECK_DEVICE ?= iPhone 16e

arch = $(shell uname -m)
product = MC Mus
project_files = \
		mcmus.xcodeproj/project.pbxproj \
		$(wildcard mcmus.xcodeproj/xcshareddata/xcschemes/*.xcscheme) \
		mcmus.xctestplan
release_dir = $(TMP)/Release
app = $(release_dir)/$(product).app
test_files = $(shell find mcmusTests -type f -not -name '.*')
src_files = \
		 .git/hooks/pre-commit \
		$(shell find src -type f -not -name '.*') \
		$(project_files) \
		$(test_files)
ver = 1.0


.SECONDEXPANSION :


# ----- phony targets -----


.PHONY : check
check : $(TMP)/checked-iOS.stamp $(TMP)/checked-macOS.stamp


.PHONY : release
release : $(TMP)/made-disk-image.stamp


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


# use a stamp file since the app bundle is a directory and thus doesn't have an
# `st_mtime` usable for change detection; also, the app bundle name contains a
# space and thus can't be a target name
$(TMP)/built-release.stamp : \
		$(TMP)/checked-iOS.stamp \
		$(TMP)/checked-macOS.stamp \
		| $(release_dir)
	rm -rf $(release_dir)
	xcodebuild build \
		-project mcmus.xcodeproj \
		-scheme app \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		CONFIGURATION_BUILD_DIR=$(release_dir) \
		-quiet
	touch $@


$(TMP)/checked-iOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild test \
		-project mcmus.xcodeproj \
		-scheme app \
		-destination 'platform=iOS Simulator,name=$(IOS_CHECK_DEVICE)' \
		-quiet
	touch $@


$(TMP)/checked-macOS.stamp : $(src_files) | $$(dir $$@)
	xcodebuild test \
		-project mcmus.xcodeproj \
		-scheme app \
		-destination 'platform=macOS,arch=$(arch)' \
		-quiet
	touch $@


# use a stamp file since the disk image name contains a space and thus can't be
# a target name
$(TMP)/made-disk-image.stamp : $(TMP)/built-release.stamp scripts/make-dmg.sh
	scripts/make-dmg.sh "$(app)" $(TMP)
	touch $@
