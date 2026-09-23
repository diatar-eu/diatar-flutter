#include "flutter_window.h"

#include <iostream>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#include <X11/Xlib.h>
#endif

#include "multi_window_manager.h"
#include "window_channel_plugin.h"

FlutterWindow::FlutterWindow(const std::string& id,
                             const std::string& argument,
                             GtkWidget* window)
    : id_(id), window_argument_(argument), window_(window) {
  gtk_widget_add_events(window_, GDK_BUTTON_PRESS_MASK);
  g_signal_connect(
      window_, "button-press-event",
      G_CALLBACK(+[](GtkWidget* widget, GdkEventButton* event,
                     gpointer data) -> gboolean {
        auto* self = static_cast<FlutterWindow*>(data);
        if (self->click_target_window_id_.empty()) {
          return FALSE;
        }
        FlutterWindow* target = MultiWindowManager::Instance()->GetWindow(
            self->click_target_window_id_);
        if (target) {
          const std::string channel =
              "mixin.one/window_controller/" +
              self->click_target_window_id_;
          window_channel_plugin_invoke_registered_method(
              channel.c_str(), "showControl", nullptr);
          target->Focus();
        }
        return static_cast<gboolean>(1);
      }),
      this);
}

FlutterWindow::~FlutterWindow() = default;

void FlutterWindow::SetChannel(FlMethodChannel* channel) {
  channel_ = channel;
}

void FlutterWindow::NotifyWindowEvent(const gchar* event, FlValue* data) {
  if (channel_) {
    fl_method_channel_invoke_method(channel_, event, data, nullptr, nullptr, nullptr);
  }
}

void FlutterWindow::Show() {
  if (window_) {
    gtk_widget_show(GTK_WIDGET(window_));
  }
}

void FlutterWindow::Hide() {
  if (window_) {
    gtk_widget_hide(GTK_WIDGET(window_));
  }
}

void FlutterWindow::Focus() {
  if (window_) {
    gtk_widget_show(GTK_WIDGET(window_));
    gtk_window_present(GTK_WINDOW(window_));
#ifdef GDK_WINDOWING_X11
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window_));
    if (gdk_window && GDK_IS_X11_WINDOW(gdk_window)) {
      Display* display = gdk_x11_display_get_xdisplay(
          gdk_window_get_display(gdk_window));
      const Window xid = gdk_x11_window_get_xid(gdk_window);
      XRaiseWindow(display, xid);
      XSetInputFocus(display, xid, RevertToParent, CurrentTime);
      XFlush(display);
    }
#endif
    GtkWidget* child = gtk_bin_get_child(GTK_BIN(window_));
    if (child) {
      gtk_widget_grab_focus(child);
    }
  }
}

void FlutterWindow::Raise() {
  if (window_) {
    gtk_widget_show(GTK_WIDGET(window_));
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window_));
    if (gdk_window) {
      gdk_window_raise(gdk_window);
    }
  }
}

void FlutterWindow::SetClickTarget(const std::string& target_window_id) {
  click_target_window_id_ = target_window_id;
  if (window_) {
    gtk_window_set_accept_focus(GTK_WINDOW(window_),
                                click_target_window_id_.empty());
  }
}

void FlutterWindow::HandleWindowMethod(const gchar* method,
                                       FlValue* arguments,
                                       FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "window_show") == 0) {
    Show();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "window_hide") == 0) {
    Hide();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "window_focus") == 0) {
    Focus();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "window_raise") == 0) {
    Raise();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "window_set_click_target") == 0) {
    FlValue* target_value =
        fl_value_lookup_string(arguments, "targetWindowId");
    if (target_value == nullptr ||
        fl_value_get_type(target_value) != FL_VALUE_TYPE_STRING) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "-1", "targetWindowId is required", nullptr));
    } else {
      SetClickTarget(fl_value_get_string(target_value));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
  } else {
    g_autofree gchar* error_msg = g_strdup_printf("unknown method: %s", method);
    response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("-1", error_msg, nullptr));
  }

  fl_method_call_respond(method_call, response, nullptr);
}
