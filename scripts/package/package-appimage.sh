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
"${DIR}"/sd-qt "$@"' > Sundial/AppRun
chmod a+x ./Sundial/AppRun

# build appimage
./linuxdeploy-x86_64.AppImage --appdir Sundial --executable ./Sundial/sd-qt --output appimage --desktop-file ./Sundial/sd-qt.desktop --icon-file ./Sundial/media/logo/logo.png --icon-filename Sundial
APPIMAGE_FILE=`ls -1 | grep AppImage| grep -i Sundial`
cp -v $APPIMAGE_FILE ./dist/Sundial-linux-x86_64.AppImage
