#include "flutter_window.h"

#include <optional>
#include <vector>

#include <flutter/standard_method_codec.h>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "file_selector_windows/file_selector_windows.h"
#include "flutter/generated_plugin_registrant.h"
#include "screen_retriever_windows/screen_retriever_windows_plugin_c_api.h"
#include "url_launcher_windows/url_launcher_windows.h"
#include "window_manager/window_manager_plugin.h"
#include "pic_plc_worker.h"

namespace {

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
      static_cast<int>(utf8.size()), nullptr, 0);
  if (length == 0) {
    return L"";
  }
  std::wstring utf16(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                      static_cast<int>(utf8.size()), utf16.data(), length);
  return utf16;
}

// Secondary window engines are short-lived during projector toggle/restart.
// Excluding audioplayers there avoids native teardown crashes.
void RegisterSecondaryWindowPlugins(flutter::PluginRegistry* registry) {
  DesktopMultiWindowPluginRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("DesktopMultiWindowPlugin"));
  FileSelectorWindowsRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("FileSelectorWindows"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  WindowManagerPluginRegisterWithRegistrar(
    registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
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
  RegisterSystemShutdownChannel();
  RegisterPicPlcChannel();
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterSecondaryWindowPlugins(registry);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterSystemShutdownChannel() {
  system_shutdown_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "diatar/system_shutdown",
          &flutter::StandardMethodCodec::GetInstance());
  system_shutdown_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "setExitCommand") {
          result->NotImplemented();
          return;
        }
        if (call.arguments() == nullptr) {
          result->Error("invalid-argument",
                        "The exit command must be a string.");
          return;
        }
        const auto* command = std::get_if<std::string>(&*call.arguments());
        if (command == nullptr) {
          result->Error("invalid-argument",
                        "The exit command must be a string.");
          return;
        }
        system_shutdown_command_ = Utf16FromUtf8(*command);
        result->Success();
      });
}

void FlutterWindow::RegisterPicPlcChannel() {
  pic_plc_worker_ = std::make_unique<PicPlcWorker>();
  pic_plc_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "diatar/pic_plc",
          &flutter::StandardMethodCodec::GetInstance());
  pic_plc_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "close") {
          pic_plc_worker_->Close();
          result->Success();
          return;
        }
        if (call.method_name() == "buttonMask") {
          result->Success(flutter::EncodableValue(
              pic_plc_worker_->button_mask()));
          return;
        }
        if (call.arguments() == nullptr) {
          result->Error("invalid-argument", "Arguments are required.");
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(&*call.arguments());
        if (arguments == nullptr) {
          result->Error("invalid-argument", "Arguments must be a map.");
          return;
        }
        if (call.method_name() == "open") {
          const auto iterator =
              arguments->find(flutter::EncodableValue("port"));
          if (iterator == arguments->end()) {
            result->Error("invalid-argument", "A serial port is required.");
            return;
          }
          const auto* port = std::get_if<std::string>(&iterator->second);
          if (port == nullptr || port->empty()) {
            result->Error("invalid-argument", "A serial port is required.");
            return;
          }
          std::string error;
          if (!pic_plc_worker_->Open(*port, &error)) {
            result->Error("serial-open-failed", error);
            return;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setLeds") {
          const auto led1 = arguments->find(flutter::EncodableValue("led1"));
          const auto led2 = arguments->find(flutter::EncodableValue("led2"));
          if (led1 == arguments->end() || led2 == arguments->end()) {
            result->Error("invalid-argument", "Both LED states are required.");
            return;
          }
          const auto* led1_value = std::get_if<bool>(&led1->second);
          const auto* led2_value = std::get_if<bool>(&led2->second);
          if (led1_value == nullptr || led2_value == nullptr) {
            result->Error("invalid-argument", "LED states must be booleans.");
            return;
          }
          pic_plc_worker_->SetLeds(*led1_value, *led2_value);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::RunSystemShutdownCommand() {
  if (system_shutdown_command_.empty()) {
    return;
  }

  std::wstring command_line = L"cmd.exe /d /s /c ";
  command_line += system_shutdown_command_;
  std::vector<wchar_t> mutable_command_line(command_line.begin(),
                                             command_line.end());
  mutable_command_line.push_back(L'\0');

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  if (CreateProcessW(nullptr, mutable_command_line.data(), nullptr, nullptr,
                     FALSE, DETACHED_PROCESS | CREATE_NO_WINDOW, nullptr,
                     nullptr, &startup_info, &process_info)) {
    CloseHandle(process_info.hThread);
    CloseHandle(process_info.hProcess);
  }
}

void FlutterWindow::OnDestroy() {
  pic_plc_channel_.reset();
  pic_plc_worker_.reset();
  system_shutdown_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_QUERYENDSESSION) {
    if (!session_ending_) {
      session_ending_ = true;
      RunSystemShutdownCommand();
    }
    return TRUE;
  }

  auto force_redraw = [&]() {
    if (flutter_controller_) {
      flutter_controller_->ForceRedraw();
    }
  };

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
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case WM_WINDOWPOSCHANGED:
      // Win10 alatt az átlátszóság/fókusz váltás után előfordulhat, hogy
      // a surface képe nem frissül azonnal. Kényszerített redraw stabilizálja.
      force_redraw();
      break;
    case WM_SIZE:
    case WM_SHOWWINDOW:
    case WM_EXITSIZEMOVE:
      force_redraw();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
