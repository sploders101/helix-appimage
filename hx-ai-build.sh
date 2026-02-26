#!/bin/bash

ARCH="$(uname -m)"
case "$ARCH" in
	x86_64)
		NODE_ARCH="x64"
		;;
	aarch64)
		NODE_ARCH="arm64"
		;;
	*)
		echo "Your architecture is not supported"
		exit 1
esac

cd "$(dirname "$0")"
MAIN_DIR="$(pwd)"

mkdir -p approot/{bin,lib,opt,usr/lib/helix}

# Install nodejs
NODE_VER='v20.14.0'
rm -rf "approot/node-$NODE_VER-linux-$NODE_ARCH"
wget -O- "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-linux-$NODE_ARCH.tar.xz" | tar -JxvC approot

# Install helix
if [[ ! -d helix-editor ]]; then
	git clone --branch personal https://github.com/sploders101/helix-editor || exit
fi
(
	cd helix-editor/helix-term
	git pull
	cargo build --release || exit
	cd ..
	cp -r runtime ../approot/usr/lib/helix/runtime 
	cp -r ../config.toml ../approot/usr/lib/helix/config.toml
	cp -r ../languages.toml ../approot/usr/lib/helix/languages.toml
	rm -rf ../approot/usr/lib/helix/runtime/grammars/sources
	cp target/release/hx ../approot/bin/hx
	cp contrib/Helix.desktop ../approot/Helix.desktop
	cp contrib/helix.png ../approot/helix.png
)

(
	echo '#!/bin/bash'
	echo 'APPDIR="$(dirname "$(readlink -f "${0}")")"'
	echo "HELIX_RUNTIME=\"\$APPDIR/usr/lib/helix/runtime\" HELIX_CONFIG_DIR=\"$APPDIR/usr/lib/helix\" PATH=\"\$APPDIR/bin:\$APPDIR/node-$NODE_VER-linux-$NODE_ARCH/bin:\$PATH\" \"\$APPDIR/bin/hx\" \"\$@\""
) > approot/AppRun
chmod +x approot/AppRun


export PATH="$(pwd)/approot/bin:$(pwd)/approot/node-$NODE_VER-linux-$NODE_ARCH/bin:$PATH"
"./approot/node-$NODE_VER-linux-$NODE_ARCH/bin/npm" i --prefix "./approot/node-$NODE_VER-linux-$NODE_ARCH/" -g \
	pyright vscode-langservers-extracted typescript typescript-language-server \
	@vue/language-server yaml-language-server@next svelte-language-server \
	dockerfile-language-server-nodejs @microsoft/compose-language-service bash-language-server \
	@ansible/ansible-language-server perlnavigator-server intelephense awk-language-server emmet-ls
rm -r approot/node-$NODE_VER-linux-$NODE_ARCH/include

test -f approot/bin/rhai || \
	cargo install --git https://github.com/rhaiscript/rhai-lsp.git --rev 2f1fcd73f43b909d1d5e96123516e599b9aaaa88 rhai-cli --root approot
test -f approot/bin/ruff || \
	cargo install --git https://github.com/astral-sh/ruff.git --tag 0.9.4 ruff --root approot

if [[ ! -e "appimagetool-$ARCH.AppImage" ]]; then
	wget "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
	chmod +x "appimagetool-$ARCH.AppImage"
fi
"./appimagetool-$ARCH.AppImage" approot/ hx-ai
