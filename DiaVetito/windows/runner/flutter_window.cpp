#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  HWND const window_handle = GetHandle();
  LONG window_style = GetWindowLong(window_handle, GWL_STYLE);
  window_style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                    WS_MAXIMIZEBOX | WS_SYSMENU);
  window_style |= WS_POPUP;
  SetWindowLong(window_handle, GWL_STYLE, window_style);

  MONITORINFO monitor_info = {0};
  monitor_info.cbSize = sizeof(monitor_info);
  HMONITOR monitor = MonitorFromWindow(window_handle, MONITOR_DEFAULTTONEAREST);
  if (GetMonitorInfo(monitor, &monitor_info)) {
    const RECT& monitor_rect = monitor_info.rcMonitor;
    SetWindowPos(window_handle, HWND_TOP, monitor_rect.left, monitor_rect.top,
                 monitor_rect.right - monitor_rect.left,
                 monitor_rect.bottom - monitor_rect.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  system_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.polyjoe.diavetito/system",
          &flutter::StandardMethodCodec::GetInstance());
  system_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "requestExit") {
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "requestShutdown") {
          std::wstring command = L"shutdown /s /t 0";
          STARTUPINFOW startup_info = {0};
          startup_info.cb = sizeof(startup_info);
          PROCESS_INFORMATION process_info = {0};
          const BOOL started = CreateProcessW(
              nullptr, command.data(), nullptr, nullptr, FALSE,
              CREATE_NO_WINDOW, nullptr, nullptr, &startup_info,
              &process_info);
          if (started == TRUE) {
            CloseHandle(process_info.hThread);
            CloseHandle(process_info.hProcess);
          }
          result->Success(flutter::EncodableValue(started == TRUE));
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (system_channel_) {
    system_channel_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
