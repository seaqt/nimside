import os
import seaqt/[qmetaobject, qpluginloader, qlibrary]

putEnv("QT_PLUGIN_PATH", splitFile(getAppFilename()).dir)

# QPLuginLoader looks for the plugin using OS-dependent library names, ie on
# linux, `lib` and `.so` are added automatically. Plugins are searched for in
# QT_PLUGIN_PATH as well as some magic system directories.

let plugin = QPluginLoader.create("plugin")
doAssert plugin.load(), plugin.errorString()

echo "Loaded ", plugin.fileName()

let instance = plugin.instance()

# Using reflection, we can call exported functions as usual, connect signals/slots etc
doAssert QMetaObject.invokeMethod(instance, "hello")

doAssert plugin.unload()
