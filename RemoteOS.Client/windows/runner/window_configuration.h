#ifndef RUNNER_WINDOW_CONFIGURATION_H_
#define RUNNER_WINDOW_CONFIGURATION_H_

#include <flutter/flutter_view_controller.h>
#include <chrono>
#include <memory>
#include "win32_window.h"

// A Win32Window subclass that wraps a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a FlutterView that renders the given Flutter project and attaches
  // it to a Win32 window.
  explicit FlutterWindow(const std::wstring& title);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  bool OnResize(const Size& new_size) override;
  LRESULT MessageHandler(HWND window, UINT const message,
                         WPARAM const wparam, LPARAM const lparam) noexcept override;

 private:
  // Flutter controller for the view.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::wstring title_;
};

#endif  // RUNNER_WINDOW_CONFIGURATION_H_
