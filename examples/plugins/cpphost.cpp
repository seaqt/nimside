#include <QLibrary>
#include <QMetaObject>
#include <QPluginLoader>
#include <QTextStream>

#include <cstdlib>
#include <cstdio>

int main() {
  // We assume the application is run from the same path as the plugin
  setenv("QT_PLUGIN_PATH", "./", 1);
  QPluginLoader loader("plugin");
  if (!loader.load()) {
    return 1;
  }

  QTextStream(stdout) << "Loaded " << loader.fileName() << Qt::endl;

  auto instance = loader.instance();
  QMetaObject::invokeMethod(instance, "hello");

  loader.unload();

  return 0;
}
