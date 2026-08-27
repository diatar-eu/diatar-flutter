#include "my_application.h"

namespace {

bool is_legacy_intel_gpu(const gchar* device_id) {
  return g_str_has_prefix(device_id, "0x29") ||
      g_str_has_prefix(device_id, "0x2a") ||
      g_str_has_prefix(device_id, "0x2e") ||
      g_str_has_prefix(device_id, "0x2f");
}

bool requires_software_gl() {
  g_autoptr(GDir) drm_dir = g_dir_open("/sys/class/drm", 0, nullptr);
  if (drm_dir == nullptr) {
    return false;
  }

  const gchar* entry = nullptr;
  while ((entry = g_dir_read_name(drm_dir)) != nullptr) {
    if (!g_str_has_prefix(entry, "card") ||
        !g_ascii_isdigit(entry[4]) ||
        entry[5] != '\0') {
      continue;
    }

    g_autofree gchar* vendor_path =
        g_build_filename("/sys/class/drm", entry, "device", "vendor", nullptr);
    g_autofree gchar* device_path =
        g_build_filename("/sys/class/drm", entry, "device", "device", nullptr);
    g_autofree gchar* vendor = nullptr;
    g_autofree gchar* device = nullptr;
    if (!g_file_get_contents(vendor_path, &vendor, nullptr, nullptr) ||
        !g_file_get_contents(device_path, &device, nullptr, nullptr)) {
      continue;
    }

    g_strstrip(vendor);
    g_strstrip(device);
    if (g_strcmp0(vendor, "0x8086") == 0 && is_legacy_intel_gpu(device)) {
      return true;
    }
  }

  return false;
}

void configure_graphics_fallback() {
  // This must happen before GTK/Flutter creates its first GL context. It also
  // applies to the secondary engine used by the projector window.
  if (g_getenv("LIBGL_ALWAYS_SOFTWARE") == nullptr &&
      requires_software_gl()) {
    g_setenv("LIBGL_ALWAYS_SOFTWARE", "1", FALSE);
  }
}

}  // namespace

int main(int argc, char** argv) {
  configure_graphics_fallback();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
