# Targets:
#    all        Build all styles in all formats (default)
#    all_ttf    Build all styles as TrueType
#    STYLE      Build STYLE in all formats (e.g. MediumItalic)
#    STYLE_ttf  Build STYLE as TrueType (e.g. MediumItalic_ttf)
#    zip        Build all styles as TrueType and package into a zip archive
#
all: all_web all_otf

VERSION := $(shell misc/version.py)

# generated.make is automatically generated by init.sh and defines depenencies for
# all styles and alias targets
include build/etc/generated.make

res_files := src/fontbuild.cfg src/diacritics.txt src/glyphlist.txt \
             src/features.fea src/glyphorder.txt

# UFO -> TTF & OTF (note that UFO deps are defined by generated.make)
build/tmp/InterUITTF/InterUI-%.ttf: $(res_files)
	misc/ufocompile --otf $*

build/tmp/InterUIOTF/InterUI-%.otf: build/tmp/InterUITTF/InterUI-%.ttf $(res_files)
	@true

# build/tmp/ttf -> build (generated.make handles build/tmp/InterUITTF/InterUI-%.ttf)
build/dist-unhinted/Inter-UI-%.ttf: build/tmp/InterUITTF/InterUI-%.ttf
	@mkdir -p build/dist-unhinted
	cp -a "$<" "$@"

# OTF
build/dist-unhinted/Inter-UI-%.otf: build/tmp/InterUIOTF/InterUI-%.otf
	@mkdir -p build/dist-unhinted
	cp -a "$<" "$@"

build/dist:
	@mkdir -p build/dist

# autohint
build/dist/Inter-UI-%.ttf: build/dist-unhinted/Inter-UI-%.ttf build/dist
	ttfautohint \
	  --hinting-limit=256 \
	  --hinting-range-min=8 \
	  --hinting-range-max=64 \
	  --fallback-stem-width=256 \
	  --strong-stem-width=D \
	  --no-info \
	  --verbose \
	  "$<" "$@"

# TTF -> WOFF2
build/%.woff2: build/%.ttf
	woff2_compress "$<"

# TTF -> WOFF
build/%.woff: build/%.ttf
	ttf2woff -O -t woff "$<" "$@"

# TTF -> EOT (disabled)
# build/%.eot: build/%.ttf
# 	ttf2eot "$<" > "$@"

ZIP_FILE_DIST := build/release/Inter-UI-${VERSION}.zip
ZIP_FILE_DEV  := build/release/Inter-UI-${VERSION}-$(shell git rev-parse --short=10 HEAD).zip

# zip intermediate
build/.zip.zip: all
	@rm -rf build/.zip
	@rm -f build/.zip.zip
	@mkdir -p \
		"build/.zip/Inter UI (web)" \
		"build/.zip/Inter UI (hinted TTF)" \
		"build/.zip/Inter UI (TTF)" \
		"build/.zip/Inter UI (OTF)"
	@cp -a build/dist/*.woff build/dist/*.woff2  "build/.zip/Inter UI (web)/"
	@cp -a build/dist/*.ttf                      "build/.zip/Inter UI (hinted TTF)/"
	@cp -a build/dist-unhinted/*.ttf             "build/.zip/Inter UI (TTF)/"
	@cp -a build/dist-unhinted/*.otf             "build/.zip/Inter UI (OTF)/"
	@cp -a misc/doc/install-*.txt                "build/.zip/"
	@cp -a LICENSE.txt                           "build/.zip/"
	cd build/.zip && zip -v -X -r "../../build/.zip.zip" * >/dev/null && cd ../..
	@rm -rf build/.zip

# zip
build/release/Inter-UI-%.zip: build/.zip.zip
	@mkdir -p "$(shell dirname "$@")"
	@mv -f "$<" "$@"
	@echo write "$@"

zip: ${ZIP_FILE_DEV}
zip_dist: ${ZIP_FILE_DIST}

pre_dist:
	@echo "Creating distribution for version ${VERSION}"
	@if [ -f "${ZIP_FILE_DIST}" ]; \
		then echo "${ZIP_FILE_DIST} already exists. Bump version or remove the zip file to continue." >&2; \
		exit 1; \
  fi
dist: pre_dist zip_dist glyphinfo copy_docs_fonts
	misc/versionize-css.py
	@echo "——————————————————————————————————————————————————————————————————"
	@echo ""
	@echo "Next steps:"
	@echo ""
	@echo "1) Commit & push changes"
	@echo ""
	@echo "2) Create new release with ${ZIP_FILE_DIST} at"
	@echo "   https://github.com/rsms/inter/releases/new?tag=v${VERSION}"
	@echo ""
	@echo "3) Bump version in src/fontbuild.cfg and commit"
	@echo ""
	@echo "——————————————————————————————————————————————————————————————————"

copy_docs_fonts:
	rm -rf docs/font-files
	mkdir docs/font-files
	cp -a build/dist/*.woff build/dist/*.woff2 build/dist-unhinted/*.otf docs/font-files/

install_ttf: all_ttf
	@echo "Installing TTF files locally at ~/Library/Fonts/Inter UI"
	rm -rf ~/'Library/Fonts/Inter UI'
	mkdir -p ~/'Library/Fonts/Inter UI'
	cp -va build/dist/*.ttf ~/'Library/Fonts/Inter UI'

install_otf: all_otf
	@echo "Installing OTF files locally at ~/Library/Fonts/Inter UI"
	rm -rf ~/'Library/Fonts/Inter UI'
	mkdir -p ~/'Library/Fonts/Inter UI'
	cp -va build/dist-unhinted/*.otf ~/'Library/Fonts/Inter UI'

install: all install_otf


glyphinfo: docs/lab/glyphinfo.json docs/glyphs/metrics.json

src/glyphorder.txt: src/Inter-UI-Regular.ufo/lib.plist src/Inter-UI-Black.ufo/lib.plist src/diacritics.txt misc/gen-glyphorder.py
	misc/gen-glyphorder.py src/Inter-UI-*.ufo > src/glyphorder.txt

docs/lab/glyphinfo.json: _local/UnicodeData.txt src/glyphorder.txt misc/gen-glyphinfo.py
	misc/gen-glyphinfo.py -ucd _local/UnicodeData.txt \
	  src/Inter-UI-*.ufo > docs/lab/glyphinfo.json

docs/glyphs/metrics.json: src/glyphorder.txt misc/gen-metrics-and-svgs.py $(Regular_ufo_d)
	misc/gen-metrics-and-svgs.py -f src/Inter-UI-Regular.ufo


# Download latest Unicode data
_local/UnicodeData.txt:
	@mkdir -p _local
	curl -s '-#' -o "$@" \
	  http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt

clean:
	rm -vrf build/tmp/* build/dist/Inter-UI-*.*

.PHONY: all web clean install install_otf install_ttf deploy zip zip_dist pre_dist dist glyphinfo copy_docs_fonts
