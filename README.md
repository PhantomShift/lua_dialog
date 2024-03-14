# lua_dialog
Simple set of [Lune](https://github.com/lune-org/lune) scripts for interacting with dialog boxes on Linux. Currently interfaces with [zenity](https://gitlab.gnome.org/GNOME/zenity) and [kdialog](https://invent.kde.org/utilities/kdialog).

Additionally contains a wrapper around [notify-send](https://man.archlinux.org/man/notify-send.1.en) for more useful functionality around notifications.

The main module will attempt to automatically identify which interface (kdialog or zenity) the system would prefer, but can be overridden using the `dialog.overridePreferredInterface` function or setting the environment variable `LUA_DIALOG_PREFERRED` to one of the two.

Have fun?