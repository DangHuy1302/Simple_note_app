# simple_note_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Troubleshoot Calendar Sync

Mục này giúp team xử lý nhanh khi tính năng đồng bộ Google Calendar chưa chạy.

### 1) Checklist setup bắt buộc

- Bật `Google Sign-In` trong Firebase Authentication.
- Bật `Google Calendar API` trong Google Cloud project của Firebase.
- Cấu hình `OAuth consent screen` và thêm scope Calendar (`.../auth/calendar.events`).
- Nếu app ở chế độ `Testing`, thêm tài khoản test vào `Test users`.
- Thêm đúng `SHA-1` và `SHA-256` cho app Android trong Firebase.
- Sau khi thay đổi SHA, tải lại `google-services.json` và thay vào `android/app/google-services.json`.

### 2) Cách kiểm tra nhanh trong app

1. Đăng xuất, đăng nhập lại bằng **Google**.
2. Tạo note có `deadline` hoặc `time-block`.
3. Bấm lưu note.
4. Nếu chưa có quyền Calendar, app sẽ hiện dialog xin quyền.
5. Đồng ý cấp quyền và kiểm tra trên Google Calendar (lịch `Primary`).

### 3) Triệu chứng thường gặp và cách xử lý

- **Lưu note thành công nhưng không thấy event trên Calendar**  
  Kiểm tra `Google Calendar API` đã bật chưa, và tài khoản có nằm trong `Test users` không.

- **Không hiện dialog cấp quyền Calendar**  
  Kiểm tra bạn có đăng nhập Google chưa (email/password không có token Google để sync).

- **Có lỗi liên quan OAuth hoặc 403**  
  Mở lại `OAuth consent screen`, xác nhận scope Calendar đã thêm và app domain/email hỗ trợ hợp lệ.

- **Android build chạy nhưng Calendar sync không tạo event**  
  Kiểm tra lại `SHA-1/SHA-256` của bản đang chạy (debug/release) và cập nhật lại `google-services.json`.

### 4) Lệnh debug nhanh

```powershell
flutter pub get
flutter analyze lib
flutter run
```

### 5) Ghi chú quan trọng

- Local notification (nhắc trước hạn/đúng hạn) vẫn chạy độc lập với Google Calendar sync.
- Nếu user từ chối quyền Calendar, note vẫn lưu bình thường, chỉ bỏ qua bước sync event.
