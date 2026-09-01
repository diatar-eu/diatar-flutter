#include "my_application.h"

#include <cstring>

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "file_selector_linux/file_selector_plugin.h"
#include "flutter/generated_plugin_registrant.h"
#include "screen_retriever_linux/screen_retriever_linux_plugin.h"
#include "url_launcher_linux/url_launcher_plugin.h"
#include "window_manager/window_manager_plugin.h"
#include "pic_plc_worker.h"

namespace {

void set_default_window_icon() {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* executable_path =
      g_file_read_link("/proc/self/exe", &error);
  if (executable_path == nullptr) {
    g_warning("Unable to locate executable for window icon: %s",
              error == nullptr ? "unknown error" : error->message);
    return;
  }

  g_autofree gchar* executable_dir = g_path_get_dirname(executable_path);
  g_autofree gchar* icon_path = g_build_filename(
      executable_dir, "data", "flutter_assets", "assets", "icon", "icon.png",
      nullptr);
  if (!gtk_window_set_default_icon_from_file(icon_path, &error)) {
    g_warning("Unable to load window icon from %s: %s", icon_path,
              error == nullptr ? "unknown error" : error->message);
  }
}

// Secondary window engines are short-lived during projector toggle/restart.
// Excluding audioplayers there avoids native teardown crashes.
void register_secondary_window_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) desktop_multi_window_registrar =
    fl_plugin_registry_get_registrar_for_plugin(registry, "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar(desktop_multi_window_registrar);
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
    fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) screen_retriever_linux_registrar =
    fl_plugin_registry_get_registrar_for_plugin(registry, "ScreenRetrieverLinuxPlugin");
  screen_retriever_linux_plugin_register_with_registrar(screen_retriever_linux_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
    fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) window_manager_registrar =
    fl_plugin_registry_get_registrar_for_plugin(registry, "WindowManagerPlugin");
  window_manager_plugin_register_with_registrar(window_manager_registrar);
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* pic_plc_channel;
  PicPlcWorker* pic_plc_worker;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void pic_plc_method_call_handler(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "close") == 0) {
    self->pic_plc_worker->Close();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "buttonMask") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_int(
            self->pic_plc_worker->button_mask())));
  } else {
    FlValue* arguments = fl_method_call_get_args(method_call);
    if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "invalid-argument", "Arguments must be a map.", nullptr));
    } else if (g_strcmp0(method, "open") == 0) {
      FlValue* port_value =
          fl_value_lookup_string(arguments, "port");
      if (port_value == nullptr ||
          fl_value_get_type(port_value) != FL_VALUE_TYPE_STRING ||
          strlen(fl_value_get_string(port_value)) == 0) {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new(
            "invalid-argument", "A serial port is required.", nullptr));
      } else {
        std::string error;
        if (!self->pic_plc_worker->Open(fl_value_get_string(port_value),
                                        &error)) {
          response = FL_METHOD_RESPONSE(fl_method_error_response_new(
              "serial-open-failed", error.c_str(), nullptr));
        } else {
          response =
              FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
        }
      }
    } else if (g_strcmp0(method, "setLeds") == 0) {
      FlValue* led1 = fl_value_lookup_string(arguments, "led1");
      FlValue* led2 = fl_value_lookup_string(arguments, "led2");
      if (led1 == nullptr || led2 == nullptr ||
          fl_value_get_type(led1) != FL_VALUE_TYPE_BOOL ||
          fl_value_get_type(led2) != FL_VALUE_TYPE_BOOL) {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new(
            "invalid-argument", "Both LED states must be booleans.", nullptr));
      } else {
        self->pic_plc_worker->SetLeds(fl_value_get_bool(led1),
                                      fl_value_get_bool(led2));
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    }
  }
  fl_method_call_respond(method_call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "diatar_app");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "diatar_app");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  if (g_strcmp0(g_getenv("DIATAR_DISABLE_IMPELLER"), "1") == 0) {
    fl_dart_project_set_enable_impeller(project, FALSE);
  }
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  self->pic_plc_worker = new PicPlcWorker();
  self->pic_plc_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "diatar/pic_plc",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(
      self->pic_plc_channel, pic_plc_method_call_handler, self, nullptr);
  desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry){
    register_secondary_window_plugins(registry);
  });

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->pic_plc_worker != nullptr) {
    delete self->pic_plc_worker;
    self->pic_plc_worker = nullptr;
  }
  g_clear_object(&self->pic_plc_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  set_default_window_icon();

  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
