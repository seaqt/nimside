import nimside
import seaqt/qobject, seaqt/QtCore/qtcore_pkg

qobject:
  type Plugin = ref object of VirtualQObject

  proc hello(p: Plugin) {.slot.} =
    echo "Hello from the plugin"

when appType == "lib":
  Q_PLUGIN_METADATA(
    Plugin, QObject, "iid", uri = "https://github.com/seaqt/nimside", QtCoreCFlags
  )
else:
  {.error: "This module must be compiled as a shared library".}
