#include "window_configuration.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

FlutterWindow::FlutterWindow(const std::wstring& title) : title_(title) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;

  RECT frame;
  GetClientRect(GetHandle(), &frame);
  int width = frame.right - frame.left;
  int height = frame.bottom - frame.top;

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      GetModuleHandle(nullptr), width, height);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() ||
      !flutter_controller_->view()) {
    return false;
  }
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  return true;
}

bool FlutterWindow::OnResize(const Size& new_size) {
  if (!Win32Window::OnResize(new_size)) return false;

  if (flutter_controller_) {
    SendMessage(flutter_controller_->view()->GetNativeWindow(),
                WM_FONTCHANGE, 0, 0);
  }
  return true;
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam, LPARAM const lparam) noexcept {
  switch (message) {
    case WM_FONTCHANGE: {
      if (flutter_controller_) {
        auto content_hwnd = flutter_controller_->view()->GetNativeWindow();
        SendMessage(content_hwnd, WM_FONTCHANGE, wparam, lparam);
      }
      break;
    }
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
