#include "pic_plc_worker.h"

#include <chrono>

PicPlcWorker::~PicPlcWorker() {
  Close();
}

bool PicPlcWorker::Open(const std::string& port, std::string* error) {
  Close();

  std::string device = port;
  if (device.rfind(R"(\\.\)", 0) != 0) {
    device = R"(\\.\)" + device;
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         device.data(),
                                         static_cast<int>(device.size()),
                                         nullptr, 0);
  if (length == 0) {
    *error = "The serial port name is not valid UTF-8.";
    return false;
  }
  std::wstring wide_device(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, device.data(),
                      static_cast<int>(device.size()), wide_device.data(),
                      length);
  port_ = CreateFileW(wide_device.c_str(), GENERIC_READ | GENERIC_WRITE, 0,
                      nullptr, OPEN_EXISTING, 0, nullptr);
  if (port_ == INVALID_HANDLE_VALUE) {
    *error = "Unable to open the serial port.";
    return false;
  }

  DCB settings{};
  settings.DCBlength = sizeof(settings);
  if (!GetCommState(port_, &settings)) {
    *error = "Unable to read the serial port settings.";
    Close();
    return false;
  }
  settings.BaudRate = CBR_2400;
  settings.ByteSize = 8;
  settings.Parity = NOPARITY;
  settings.StopBits = ONESTOPBIT;
  settings.fBinary = TRUE;
  settings.fParity = FALSE;
  if (!SetCommState(port_, &settings)) {
    *error = "Unable to configure the serial port.";
    Close();
    return false;
  }

  COMMTIMEOUTS timeouts{};
  timeouts.ReadIntervalTimeout = MAXDWORD;
  timeouts.ReadTotalTimeoutConstant = 45;
  timeouts.WriteTotalTimeoutConstant = 45;
  if (!SetCommTimeouts(port_, &timeouts)) {
    *error = "Unable to configure the serial port timeouts.";
    Close();
    return false;
  }
  PurgeComm(port_, PURGE_RXABORT | PURGE_RXCLEAR | PURGE_TXABORT |
                       PURGE_TXCLEAR);
  running_ = true;
  polling_thread_ = std::thread(&PicPlcWorker::Poll, this);
  return true;
}

void PicPlcWorker::Close() {
  running_ = false;
  if (polling_thread_.joinable()) {
    polling_thread_.join();
  }
  std::lock_guard<std::mutex> lock(port_mutex_);
  if (port_ != INVALID_HANDLE_VALUE) {
    const unsigned char off[] = {0x21, 0, 0, 0};
    WriteAll(off, sizeof(off));
    CloseHandle(port_);
    port_ = INVALID_HANDLE_VALUE;
  }
  led_states_ = 0;
  button_mask_ = 0;
}

void PicPlcWorker::SetLeds(bool led1, bool led2) {
  led_states_ = (led1 ? 0x01 : 0) | (led2 ? 0x02 : 0);
}

int PicPlcWorker::button_mask() const {
  return button_mask_;
}

bool PicPlcWorker::WriteAll(const unsigned char* data, DWORD length) {
  DWORD written = 0;
  return WriteFile(port_, data, length, &written, nullptr) &&
         written == length;
}

bool PicPlcWorker::ReadResponse(unsigned char* response) {
  DWORD received = 0;
  while (received < 3 && running_) {
    DWORD count = 0;
    if (!ReadFile(port_, response + received, 3 - received, &count, nullptr)) {
      return false;
    }
    if (count == 0) {
      return false;
    }
    received += count;
  }
  return received == 3;
}

void PicPlcWorker::SendLeds(unsigned char states) {
  const unsigned char command[] = {0x21, 0, states, states};
  WriteAll(command, sizeof(command));
}

void PicPlcWorker::Poll() {
  unsigned char sent_led_states = 0xFF;
  while (running_) {
    const auto cycle_start = std::chrono::steady_clock::now();
    std::lock_guard<std::mutex> lock(port_mutex_);
    if (port_ == INVALID_HANDLE_VALUE) {
      return;
    }
    const unsigned char led_states = led_states_;
    if (led_states != sent_led_states) {
      SendLeds(led_states);
      sent_led_states = led_states;
    }
    const unsigned char request[] = {'D', 'I'};
    unsigned char response[3]{};
    const bool response_valid =
        WriteAll(request, sizeof(request)) && ReadResponse(response) &&
        static_cast<unsigned char>(response[0] + response[1]) == response[2];
    if (response_valid) {
      button_mask_ = response[0];
    } else {
      PurgeComm(port_, PURGE_RXABORT | PURGE_RXCLEAR);
    }
    const auto elapsed = std::chrono::steady_clock::now() - cycle_start;
    if (elapsed < std::chrono::milliseconds(50)) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50) - elapsed);
    }
  }
}
