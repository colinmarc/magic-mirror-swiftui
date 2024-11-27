mm_build_dir := "MMClientCommon/build"
mm_clone_dir := mm_build_dir / "mm"
rust_target_dir := mm_clone_dir / "mm-client-common/target"

mm_origin := "git@github.com:colinmarc/magic-mirror"
mm_tag := "integrations"
framework_name := "MMClientCommon"

build_dir := `mktemp -d`

clean:
	rm -rf {{mm_build_dir}}

_clone-mm:
	#!/usr/bin/env bash
	set -euxo pipefail
	mkdir -p {{mm_build_dir}}/mm
	cd {{mm_build_dir}}/mm
	git init
	git remote add origin {{mm_origin}} || git remote set-url origin {{mm_origin}}
	git fetch origin {{mm_tag}}
	git reset --hard origin/{{mm_tag}}

_build-mm $MACOSX_DEPLOYMENT_TARGET="10.15": _clone-mm
	cd {{mm_clone_dir}}/mm-client-common && cargo build -q --release \
		--target aarch64-apple-darwin \
		--target x86_64-apple-darwin

build-common-xcframework: _build-mm
	@rm -rf {{mm_build_dir}}/{{framework_name}}.xcframework
	@mkdir -p {{mm_build_dir}}/uniffi

	cd {{mm_clone_dir}}/mm-client-common && cargo run -q --release \
		--bin uniffi-bindgen -- generate --language swift --no-format \
		--out-dir {{invocation_dir()}}/{{mm_build_dir}}/uniffi \
		--library target/aarch64-apple-darwin/release/libmm_client_common.a

	# Copy swift sources to where the package expects them.
	@mkdir -p {{mm_build_dir}}/Sources
	cp {{mm_build_dir}}/uniffi/mm_client_common.swift \
		{{mm_build_dir}}/Sources/MMClientCommon.swift
	cp {{mm_build_dir}}/uniffi/mm_protocol.swift \
		{{mm_build_dir}}/Sources/MMProtocol.swift
	swift format -i {{mm_build_dir}}/Sources/*.swift

	# The headers and a 'module.modulemap' file have to be together.
	@mkdir -p {{mm_build_dir}}/uniffi/include
	cp {{mm_build_dir}}/uniffi/*.h {{mm_build_dir}}/uniffi/include/
	cat {{mm_build_dir}}/uniffi/*.modulemap > {{mm_build_dir}}/uniffi/include/module.modulemap

	# Create a "universal" ar with both arches in it.
	lipo -create -output {{mm_build_dir}}/libmm_client_common-universal.a \
		{{rust_target_dir}}/aarch64-apple-darwin/release/libmm_client_common.a \
		{{rust_target_dir}}/x86_64-apple-darwin/release/libmm_client_common.a \

	xcodebuild -create-xcframework \
		-library {{mm_build_dir}}/libmm_client_common-universal.a \
		-headers {{mm_build_dir}}/uniffi/include \
		-output {{mm_build_dir}}/{{framework_name}}.xcframework

build: build-common-xcframework
	xcode-build-server config -scheme MagicMirror -workspace *.xcworkspace
	tuist generate --no-open
	tuist build --build-output-path {{build_dir}}

run: build
	open {{build_dir}}/Debug/MagicMirror.app

quickrun:
	tuist build --build-output-path {{build_dir}}
	build/Debug/MagicMirror.app/Contents/MacOS/MagicMirror

dev: build
	reflex -r '\.swift' -R 'build\/' -s -- just quickrun