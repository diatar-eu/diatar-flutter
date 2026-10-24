#include "my_application.h"

#include "graphics_fallback.h"

int main(int argc, char** argv) {
  // This must happen before GTK/Flutter creates its first GL context. It also
  // applies to the secondary engine used by the projector window.
  graphics_fallback_configure(&argc, &argv);
  g_autoptr(MyApplication) app = my_application_new();
  const int result = g_application_run(G_APPLICATION(app), argc, argv);
  graphics_fallback_cleanup_startup_marker();
  return result;
}
