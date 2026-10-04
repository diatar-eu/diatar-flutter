#include "graphics_fallback.h"

#include <errno.h>
#include <signal.h>
#include <unistd.h>

#include <cstring>

#include <glib.h>
#include <glib/gstdio.h>

namespace {

constexpr char kSoftwareRenderingArgument[] = "--software-rendering";
constexpr char kHardwareRenderingArgument[] = "--hardware-rendering";
constexpr char kStartupMarkerPrefix[] = "startup-";
constexpr char kStartupMarkerSuffix[] = ".pending";
constexpr char kCompositorSetupFailure[] =
    "Failed to setup compositor shaders, unable to make OpenGL context "
    "current";
constexpr guint kStartupSuccessDelaySeconds = 10;

gchar* startup_marker_path = nullptr;
gchar* software_marker_path = nullptr;

bool is_legacy_intel_gpu(const gchar* device_id) {
  // Intel Gen2-Gen4 and Pineview IDs from Linux's include/drm/intel/pciids.h.
  // These devices expose at most OpenGL 2.1 and cannot satisfy Impeller's
  // framebuffer requirements reliably.
  constexpr const char* kLegacyIntelDeviceIds[] = {
      "0x7121", "0x7123", "0x7125", "0x1132", "0x3577", "0x2562",
      "0x3582", "0x358e", "0x2572", "0x2582", "0x258a", "0x2592",
      "0x2772", "0x27a2", "0x27ae", "0x2972", "0x2982", "0x2992",
      "0x29a2", "0x29b2", "0x29c2", "0x29d2", "0x2a02", "0x2a12",
      "0x2a42", "0x2e02", "0x2e12", "0x2e22", "0x2e32", "0x2e42",
      "0x2e92", "0xa001", "0xa011",
  };
  for (const char* legacy_id : kLegacyIntelDeviceIds) {
    if (g_ascii_strcasecmp(device_id, legacy_id) == 0) {
      return true;
    }
  }
  return false;
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
    if (g_ascii_strcasecmp(vendor, "0x8086") == 0 &&
        is_legacy_intel_gpu(device)) {
      return true;
    }
  }

  return false;
}

void remove_argument(int* argc, char*** argv, int index) {
  for (int i = index; i < *argc; ++i) {
    (*argv)[i] = (*argv)[i + 1];
  }
  --(*argc);
}

void parse_renderer_arguments(int* argc,
                              char*** argv,
                              bool* force_software,
                              bool* force_hardware) {
  for (int i = 1; i < *argc;) {
    if (std::strcmp((*argv)[i], kSoftwareRenderingArgument) == 0) {
      *force_software = true;
      *force_hardware = false;
      remove_argument(argc, argv, i);
    } else if (std::strcmp((*argv)[i], kHardwareRenderingArgument) == 0) {
      *force_hardware = true;
      *force_software = false;
      remove_argument(argc, argv, i);
    } else {
      ++i;
    }
  }
}

bool process_is_running(gint64 pid) {
  if (pid <= 0) {
    return false;
  }
  if (kill(static_cast<pid_t>(pid), 0) == 0) {
    return true;
  }
  return errno == EPERM;
}

bool consume_stale_startup_markers(const gchar* marker_directory) {
  g_autoptr(GDir) directory = g_dir_open(marker_directory, 0, nullptr);
  if (directory == nullptr) {
    return false;
  }

  bool found_stale_marker = false;
  const gchar* entry = nullptr;
  while ((entry = g_dir_read_name(directory)) != nullptr) {
    if (!g_str_has_prefix(entry, kStartupMarkerPrefix) ||
        !g_str_has_suffix(entry, kStartupMarkerSuffix)) {
      continue;
    }

    const gchar* pid_start = entry + std::strlen(kStartupMarkerPrefix);
    gchar* pid_end = nullptr;
    const gint64 pid = g_ascii_strtoll(pid_start, &pid_end, 10);
    if (pid_end == pid_start ||
        std::strcmp(pid_end, kStartupMarkerSuffix) != 0 ||
        process_is_running(pid)) {
      continue;
    }

    g_autofree gchar* marker_path =
        g_build_filename(marker_directory, entry, nullptr);
    if (g_remove(marker_path) == 0) {
      found_stale_marker = true;
    }
  }
  return found_stale_marker;
}

bool write_marker(const gchar* path) {
  g_autoptr(GError) error = nullptr;
  if (g_file_set_contents(path, "", 0, &error)) {
    return true;
  }
  g_warning("Unable to write graphics fallback marker %s: %s", path,
            error->message);
  return false;
}

void graphics_log_handler(const gchar* log_domain,
                          GLogLevelFlags log_level,
                          const gchar* message,
                          gpointer user_data) {
  if ((log_level & G_LOG_LEVEL_WARNING) != 0 &&
      g_strcmp0(message, kCompositorSetupFailure) == 0 &&
      software_marker_path != nullptr &&
      !g_file_test(software_marker_path, G_FILE_TEST_EXISTS) &&
      write_marker(software_marker_path)) {
    g_message(
        "OpenGL compositor initialization failed; software rendering will be "
        "used on the next start");
  }

  g_log_default_handler(log_domain, log_level, message, user_data);
}

gboolean remove_startup_marker(gpointer data) {
  const gchar* path = static_cast<const gchar*>(data);
  if (g_remove(path) != 0 && errno != ENOENT) {
    g_warning("Unable to remove graphics startup marker %s", path);
  }
  return G_SOURCE_REMOVE;
}

}  // namespace

void graphics_fallback_configure(int* argc, char*** argv) {
  bool force_software = false;
  bool force_hardware = false;
  parse_renderer_arguments(argc, argv, &force_software, &force_hardware);

  g_autofree gchar* marker_directory = g_build_filename(
      g_get_user_cache_dir(), APPLICATION_ID, "graphics", nullptr);
  const bool marker_directory_ready =
      g_mkdir_with_parents(marker_directory, 0700) == 0;
  if (!marker_directory_ready) {
    g_warning("Unable to create graphics fallback directory %s",
              marker_directory);
  }

  g_autofree gchar* software_marker = g_build_filename(
      marker_directory, "software-rendering", nullptr);
  software_marker_path = g_strdup(software_marker);
  g_log_set_default_handler(graphics_log_handler, nullptr);

  bool previous_startup_failed = false;
  if (marker_directory_ready) {
    previous_startup_failed =
        consume_stale_startup_markers(marker_directory);
    if (force_hardware) {
      if (g_remove(software_marker) != 0 && errno != ENOENT) {
        g_warning("Unable to clear graphics fallback marker %s",
                  software_marker);
      }
    } else if (force_software || previous_startup_failed) {
      write_marker(software_marker);
    }
  }

  const bool saved_software_mode =
      marker_directory_ready &&
      g_file_test(software_marker, G_FILE_TEST_EXISTS);
  const bool legacy_hardware = requires_software_gl();
  const gchar* existing_software_gl = g_getenv("LIBGL_ALWAYS_SOFTWARE");
  const bool externally_requested_software =
      existing_software_gl != nullptr &&
      existing_software_gl[0] != '\0' &&
      g_strcmp0(existing_software_gl, "0") != 0;
  const bool use_software =
      force_software ||
      (!force_hardware &&
       (saved_software_mode || legacy_hardware ||
        externally_requested_software));

  if (use_software) {
    if (existing_software_gl == nullptr) {
      g_setenv("LIBGL_ALWAYS_SOFTWARE", "1", FALSE);
    }
    g_setenv("DIATAR_DISABLE_IMPELLER", "1", TRUE);
    if (previous_startup_failed) {
      g_message("Previous graphics startup failed; using software rendering");
    } else if (legacy_hardware) {
      g_message("Legacy Intel GPU detected; using software rendering");
    } else if (saved_software_mode) {
      g_message("Saved graphics fallback active; using software rendering");
    } else {
      g_message("Software rendering requested");
    }
  } else if (force_hardware) {
    g_unsetenv("LIBGL_ALWAYS_SOFTWARE");
    g_unsetenv("DIATAR_DISABLE_IMPELLER");
    g_message("Hardware rendering explicitly requested");
  }

  if (marker_directory_ready) {
    g_autofree gchar* marker_name = g_strdup_printf(
        "%s%d%s", kStartupMarkerPrefix, static_cast<int>(getpid()),
        kStartupMarkerSuffix);
    startup_marker_path =
        g_build_filename(marker_directory, marker_name, nullptr);
    if (!write_marker(startup_marker_path)) {
      g_clear_pointer(&startup_marker_path, g_free);
    }
  }
}

void graphics_fallback_schedule_startup_success() {
  if (startup_marker_path == nullptr) {
    return;
  }
  g_timeout_add_seconds_full(
      G_PRIORITY_DEFAULT, kStartupSuccessDelaySeconds, remove_startup_marker,
      g_strdup(startup_marker_path), g_free);
}

void graphics_fallback_cleanup_startup_marker() {
  if (startup_marker_path != nullptr &&
      g_remove(startup_marker_path) != 0 && errno != ENOENT) {
    g_warning("Unable to remove graphics startup marker %s",
              startup_marker_path);
  }
  g_clear_pointer(&startup_marker_path, g_free);
  g_clear_pointer(&software_marker_path, g_free);
}
