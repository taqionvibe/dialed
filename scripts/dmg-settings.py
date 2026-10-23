# dmgbuild settings for Dialed.dmg. Used by scripts/build-dmg.sh:
#   dmgbuild -s scripts/dmg-settings.py -D app=build/Dialed.app "Dialed" build/Dialed.dmg
# Positions match the artwork drawn by scripts/make-dmg-background.swift.
import os.path

app = defines.get("app", "build/Dialed.app")  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(app)

format = "UDZO"            # compressed, read-only
filesystem = "HFS+"
size = None                # auto
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extension = [app_name]

icon = "Resources/AppIcon.icns"        # volume icon
background = "Resources/dmg-background.png"  # dmgbuild picks up the @2x file automatically

window_rect = ((200, 160), (660, 420))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    app_name: (170, 205),
    "Applications": (490, 205),
}
