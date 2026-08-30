#include "pic_plc_worker.h"

#include <chrono>
#include <cerrno>
#include <cstring>
#include <thread>

#include <fcntl.h>
#include <poll.h>
#include <termios.h>
#include <unistd.h>

PicPlcWorker::~PicPlcWorker() {
  Close();
}

bool PicPlcWorker::Open(const std::string& port, std::string* error) {
  Close();
  port_ = open(port.c_str(), O_RDWR | O_NOCTTY | O_SYNC);
  if (port_ < 0) {
    *error = std::string("Unable to open the serial port: ") + strerror(errno);
    return false;
  }

  termios settings{};
  if (tcgetattr(port_, &settings) != 0) {
    *error = "Unable to read the serial port settings.";
    Close();
    return false;
  }
  cfmakeraw(&settings);
  cfsetispeed(&settings, B2400);
  cfsetospeed(&settings, B2400);
  settings.c_cflag = (settings.c_cflag & ~CSIZE) | CS8 | CLOCAL | CREAD;
  settings.c_cflag &= ~(PARENB | CSTOPB | CRTSCTS);
  settings.c_cc[VMIN] = 0;
  settings.c_cc[VTIME] = 0;
  if (tcsetattr(port_, TCSANOW, &settings) != 0) {
    *error = "Unable to configure the serial port.";
    Close();
    return false;
  }

  tcflush(port_, TCIOFLUSH);
  running_ = true;
  polling_thread_ = std::thread(&PicPlcWorker::Poll, this);
  return true;
}

void PicPlcWorker::Close() {
  running_ = false;
  if (polling_thread_.joinable()) {
    polling_thread_.join();
  }
  if (port_ >= 0) {
    const unsigned char off[] = {0x21, 0, 0, 0};
    WriteAll(off, sizeof(off));
    close(port_);
    port_ = -1;
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

bool PicPlcWorker::WriteAll(const unsigned char* data, size_t length) {
  size_t written = 0;
  while (written < length) {
    const ssize_t count = write(port_, data + written, length - written);
    if (count <= 0) {
      return false;
    }
    written += static_cast<size_t>(count);
  }
  return true;
}

bool PicPlcWorker::ReadResponse(unsigned char* response) {
  size_t received = 0;
  const auto deadline = std::chrono::steady_clock::now() +
                        std::chrono::milliseconds(45);
  while (received < 3 && running_) {
    const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
        deadline - std::chrono::steady_clock::now());
    if (remaining.count() <= 0) {
      return false;
    }
    pollfd descriptor{port_, POLLIN, 0};
    if (poll(&descriptor, 1, static_cast<int>(remaining.count())) <= 0) {
      return false;
    }
    const ssize_t count = read(port_, response + received, 3 - received);
    if (count <= 0) {
      return false;
    }
    received += static_cast<size_t>(count);
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
      tcflush(port_, TCIFLUSH);
    }
    const auto elapsed = std::chrono::steady_clock::now() - cycle_start;
    if (elapsed < std::chrono::milliseconds(50)) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50) - elapsed);
    }
  }
}
