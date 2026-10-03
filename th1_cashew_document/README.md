# TH1 - Xây dựng ứng dụng Quản lý Tài liệu Học tập theo kiến trúc Cashew

## 1. Giới thiệu

Đây là bài thực hành TH1 môn Kiến trúc phần mềm, xây dựng ứng dụng quản lý tài liệu học tập và áp dụng kiến trúc Cashew để tổ chức, phân tách các thành phần trong hệ thống.

Ứng dụng cho phép người dùng:

- Thêm tài liệu học tập.
- Xem thông tin chi tiết tài liệu.
- Sửa thông tin tài liệu.
- Xóa tài liệu.
- Tìm kiếm tài liệu theo tên hoặc môn học.
- Lưu metadata của tài liệu trong SQLite.
- Lưu file tài liệu trong bộ nhớ cục bộ của ứng dụng.

Ứng dụng được triển khai và kiểm thử trên Windows.

---

## 2. Mục tiêu

Project tập trung vào các mục tiêu:

1. Phân tích yêu cầu chức năng của ứng dụng quản lý tài liệu.
2. Thiết kế luồng dữ liệu của hệ thống.
3. Tổ chức mã nguồn theo các lớp của kiến trúc Cashew.
4. Tách biệt giao diện, xử lý nghiệp vụ và truy cập dữ liệu.
5. Kiểm thử tính đúng đắn của việc phân tách logic giữa các lớp.
6. Xây dựng một ứng dụng CRUD đơn giản để minh họa kiến trúc.

---

## 3. Công nghệ sử dụng

| Công nghệ     | Mục đích                              |
| ------------- | ------------------------------------- |
| Flutter       | Xây dựng giao diện ứng dụng           |
| Dart          | Ngôn ngữ lập trình                    |
| Drift         | ORM / lớp truy cập SQLite             |
| SQLite        | Lưu trữ metadata tài liệu             |
| file_picker   | Chọn file từ máy tính                 |
| path_provider | Xác định thư mục lưu trữ của ứng dụng |
| path          | Xử lý đường dẫn file                  |
| flutter_test  | Kiểm thử                              |
| Git / GitHub  | Quản lý mã nguồn                      |

---

## 4. Kiến trúc hệ thống

Project tổ chức theo các lớp chính:

```text
Flutter UI
    ↓
Application / Business Logic
    ↓
Data Access Layer / DAO
    ↓
Drift
    ↓
SQLite
```
