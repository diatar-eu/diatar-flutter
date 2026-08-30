#ifndef RUNNER_PIC_PLC_WORKER_H_
#define RUNNER_PIC_PLC_WORKER_H_

#include <atomic>
#include <mutex>
#include <string>
#include <thread>

#include <windows.h>

class PicPlcWorker {
 public:
  PicPlcWorker() = default;
  ~PicPlcWorker();

  bool Open(const std::string& port, std::string* error);
  void Close();
  void SetLeds(bool led1, bool led2);
  int button_mask() const;

 private:
  void Poll();
  bool WriteAll(const unsigned char* data, DWORD length);
  bool ReadResponse(unsigned char* response);
  void SendLeds(unsigned char states);

  HANDLE port_ = INVALID_HANDLE_VALUE;
  std::atomic<bool> running_{false};
  std::atomic<unsigned char> led_states_{0};
  std::atomic<int> button_mask_{0};
  std::mutex port_mutex_;
  std::thread polling_thread_;
};

#endif  // RUNNER_PIC_PLC_WORKER_H_
