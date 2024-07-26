#!/bin/bash

# pick the latest zip
# NOTE: this assumes that the latest built zip is the only zip in the directory
ZIP_FILE=`ls ./dist/ -1 | grep zip | sort -r | head -1`
unzip ./dist/$ZIP_FILE

# fetch deps
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# create AppRun
echo '#!/bin/sh
DIR="$(dirname "$(readlink -f "${0}")")"
"${DIR}"/sd-qt "$@"' > TTim/AppRun
chmod a+x ./TTim/AppRun

# build appimage
./linuxdeploy-x86_64.AppImage --appdir TTim --executable ./TTim/sd-qt --output appimage --desktop-file ./TTim/sd-qt.desktop --icon-file ./TTim/media/logo/logo.png --icon-filename TTim
APPIMAGE_FILE=`ls -1 | grep AppImage| grep -i TTim`
cp -v $APPIMAGE_FILE ./dist/TTim-linux-x86_64.AppImage
