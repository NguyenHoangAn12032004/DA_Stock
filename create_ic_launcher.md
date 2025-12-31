# Bài tập 8: Tạo ic_launcher (Android) – Hướng dẫn từng bước

### Mục tiêu

- Cấu hình app icon Android chuẩn: Adaptive Icon (foreground/background) và Monochrome (Android 13+ Themed icons).
- Sinh icon tự động bằng gói `flutter_launcher_icons` và xác minh trực quan trên thiết bị/emulator Android 13+.
- Nộp bài: chỉ cần screenshots (không cần README, không cần iOS).

### Yêu cầu trước khi bắt đầu

- Flutter SDK hoạt động, có thể build Android.
- Emulator/thiết bị Android API 33+ (Android 13) để kiểm tra Themed icons.

### Bước 1 — Chuẩn bị ảnh nguồn

Tạo thư mục `assets/icons/` và đặt 3 tệp PNG:

- `base_app_icon.png` (1024×1024) — nguồn chung.
- `android_foreground.png` — lớp nội dung (có vùng trong suốt); nội dung nằm trong safe zone (đừng chạm mép để tránh bị crop/bo góc).
- `android_monochrome.png` — phiên bản đơn sắc (một màu, nền trong suốt) cho Themed icons.

Gợi ý nhanh:

- Foreground nên ít chi tiết, dễ nhận diện ở kích thước nhỏ.
- Nền adaptive nên là màu thuần (khuyến nghị) để hiển thị đồng nhất.

### Bước 2 — Cấu hình `pubspec.yaml`

Thêm/thay cấu hình (khối tối thiểu gợi ý):

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_icons:
  android: true
  image_path: assets/icons/base_app_icon.png
  adaptive_icon_foreground: assets/icons/android_foreground.png
  adaptive_icon_background: "#FFFFFF"  # có thể đổi màu nền phù hợp thương hiệu
  adaptive_icon_monochrome: assets/icons/android_monochrome.png
```

Ghi chú:

- Có thể dùng ảnh nền thay cho màu: `adaptive_icon_background: assets/icons/android_background.png`.
- Nếu dự án đã có cấu hình khác, hãy hợp nhất cẩn thận, giữ nguyên các mục không liên quan.

### Bước 3 — Sinh icon bằng lệnh (PowerShell)

Chạy các lệnh sau ở thư mục project:

```powershell
flutter pub get;
dart run flutter_launcher_icons;
```

Nếu chưa cài `dart` trong PATH, dùng:

```powershell
flutter pub run flutter_launcher_icons;
```

### Bước 4 — Cài và kiểm tra trên Android

1) Cài/chạy app trên Android 13+ (API 33+). Quay về màn hình Home xem icon adaptive hiển thị đúng (không bị crop, bo góc mượt).
2) Bật Themed icons:
   - Vào Settings → Wallpaper & style → bật "Themed icons".
   - Trở về Home, kiểm tra icon chuyển sang phiên bản đơn sắc đúng theo `android_monochrome.png`.

Nếu icon không cập nhật, thử:

```powershell
flutter clean;
flutter pub get;
dart run flutter_launcher_icons;
flutter run;
```

Hoặc gỡ cài đặt app rồi cài lại. Có thể kiểm tra các tệp đã sinh tại `android/app/src/main/res/mipmap-*`.

### Bài nộp (Screenshots)

- 01 ảnh: Màn hình Home (Themed icons OFF) hiển thị icon adaptive bình thường.
- 01 ảnh: Màn hình Home (Themed icons ON) hiển thị icon đơn sắc đúng.

