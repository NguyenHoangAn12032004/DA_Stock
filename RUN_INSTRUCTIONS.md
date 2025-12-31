# Hướng dẫn chạy chương trình (Full Stack)

Để chạy toàn bộ hệ thống (Server AI + Ứng dụng Flutter), bạn cần mở 2 terminal riêng biệt.

## 1. Chạy Backend (Python Server)
Server này cung cấp API dự đoán và Chat AI.

1.  Mở terminal, di chuyển vào thư mục `DACN`:
    ```powershell
    cd d:\DA_Stock\DACN
    ```
2.  Kích hoạt môi trường ảo (nếu có) hoặc đảm bảo đã cài đủ thư viện.
3.  Chạy lệnh khởi động server:
    ```powershell
    python src/api/advice_server.py
    ```
    *Dấu hiệu thành công*: Bạn sẽ thấy thông báo `Uvicorn running on http://0.0.0.0:8001`.

## 2. Chạy Frontend (Flutter App)
Ứng dụng di động sẽ kết nối với server ở trên.

1.  Mở một terminal **MỚI**.
2.  Di chuyển vào thư mục `stock_app`:
    ```powershell
    cd d:\DA_Stock\stock_app
    ```
3.  Chạy ứng dụng trên máy ảo (Android Emulator):
    ```powershell
    flutter run
    ```

## Lưu ý quan trọng
*   **Địa chỉ IP**: Code Flutter đang được cấu hình để kết nối tới `http://10.0.2.2:8000` (đây là địa chỉ localhost của máy tính khi truy cập từ Android Emulator).
*   **API Key**: Để chức năng Chat hoạt động, hãy chắc chắn bạn đã cấu hình `GEMINI_API_KEY` trong file `.env` tại thư mục `DACN`.
