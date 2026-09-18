#!/bin/sh
set -eu

OUT="${1:-$HOME/kde-plasma-settings.tar.gz}"

cd "$HOME"

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT

# Core KDE/Plasma settings
for path in \
  .config/kdeglobals \
  .config/kcminputrc \
  .config/kwinrc \
  .config/kwinrulesrc \
  .config/kscreenlockerrc \
  .config/ksmserverrc \
  .config/kxkbrc \
  .config/kcmfonts \
  .config/klaunchrc \
  .config/khotkeysrc \
  .config/kglobalshortcutsrc \
  .config/knotifyservicerc \
  .config/mimeapps.list \
  .config/plasma-org.kde.plasma.desktop-appletsrc \
  .config/konsolerc \
  .config/dolphinrc \
  .config/arkrc \
  .config/spectaclerc \
  .config/discoverrc \
  .config/systemsettingsrc \
  .config/okularrc \
  .config/gwenviewrc \
  .config/katecaterc \
  .config/kwriterc \
  .config/yakurc \
  .config/krusaderrc \
  .config/autostart \
  .config/gtk-3.0/settings.ini \
  .config/gtk-4.0/settings.ini \
  .config/xdg-desktop-portal \
  .config/plasma-workspace/env \
  .local/share/konsole \
  .local/share/plasma \
  .local/share/color-schemes \
  .local/share/kscreen \
  .local/share/user-places.xbel \
  .local/share/applications \
  .local/share/icons \
  .icons \
  .Xresources
do
  if [ -e "$path" ]; then
    printf '%s\n' "$path" >> "$LIST"
  fi
done

if [ ! -s "$LIST" ]; then
  echo "No KDE configuration files found to export." >&2
  exit 1
fi

tar -czf "$OUT" -T "$LIST"

echo "Saved KDE settings to: $OUT"
