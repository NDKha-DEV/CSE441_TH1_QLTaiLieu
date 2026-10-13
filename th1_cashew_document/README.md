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

## 5. Tích hợp Firebase và Supabase

Ứng dụng giữ dữ liệu SQLite cục bộ hiện có; dữ liệu này không tự động được
chuyển lên cloud. Trên Web, Android và iOS, người dùng đăng nhập Google qua
Firebase Authentication. Metadata cloud nằm trong Supabase (`users`,
`documents`, `permissions`); tệp nằm trong bucket Supabase Storage private
`documents`. Windows/Linux/macOS tiếp tục dùng luồng SQLite cục bộ.

**Khác biệt so với câu chữ checklist 2:** theo lựa chọn đã thống nhất để không
phải nâng cấp Firebase Billing, ứng dụng dùng Supabase Storage thay cho Firebase
Storage. Chức năng lưu/truy xuất tệp cloud và liên kết metadata vẫn được triển
khai, nhưng không nên báo cáo rằng tệp đang nằm trên Firebase Storage.

### Cấu hình trước khi chạy

1. Trong Firebase Console, bật Google provider. Với Web, thêm hostname đang
   chạy ứng dụng vào Authentication → Settings → Authorized domains. Với
   Android, kiểm tra package `com.example.th1_cashew_document` và đăng ký
   SHA-1/SHA-256 của signing key nếu cấu hình Google yêu cầu.
2. Trong Supabase Dashboard → SQL Editor, trước khi áp dụng migration, xem
   tất cả policy đang tồn tại trên `storage.objects`:

   ```sql
   select policyname, roles, cmd, qual, with_check
   from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
   order by policyname;
   ```

   Xác nhận không có policy permissive ngoài phạm vi làm rộng quyền bucket
   `documents`. Không xóa policy chưa xác định mục đích; migration chỉ thay
   các policy có tên riêng của ứng dụng. Sau khi rà soát, chạy nội dung
   `supabase/migrations/20261013120000_cloud_documents.sql` trong SQL Editor.
   Migration chưa được xác minh là đã chạy trên project thật.
3. Mỗi Firebase UID cần claim `role=authenticated` để Supabase áp dụng quyền
   role `authenticated`. Công cụ quản trị nằm trong `tools/firebase-admin`;
   chạy `npm test` trước khi sử dụng. Chỉ cấp claim cho UID đã xác minh và làm
   mới ID token bằng cách đăng nhập lại.
4. Chạy ứng dụng với URL project và publishable key (không dùng secret/service
   role key ở client):

   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=<SUPABASE_URL> `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=<SUPABASE_PUBLISHABLE_KEY>
   ```

   Android có thể chạy bằng `flutter run -d android` với cùng hai
   `--dart-define`. Không đưa service-role/secret key vào ứng dụng.

### Kịch bản kiểm thử phân quyền

#### Chuẩn bị đúng ba tài khoản

1. Ba tài khoản Email/Password đang có trong Firebase **không tự động là tài
   khoản Google**. Nút trong app gọi Google provider; tài khoản chỉ đăng nhập
   được nếu có Google account thật và Firebase Auth có provider `google.com`
   cho tài khoản đó. Không nhập email test vào màn hình Google nếu email đó
   không phải Google account.
2. Dùng ba Google account thật, riêng biệt. Nếu không thể liên kết an toàn
   Google provider với ba tài khoản test hiện có, hãy đăng nhập từng Google
   account mới qua nút Google; Firebase sẽ tạo user record khi provider được
   bật. Không cần tạo mật khẩu Email/Password cho các tài khoản này.
3. Trong Firebase Console → Authentication → Users, ghi lại Firebase UID của
   từng tài khoản và gán vai trò kiểm thử: account A là owner, B là viewer,
   C là editor. UID được nhập trong dialog chia sẻ; không dùng email làm UID.
4. Supabase RLS yêu cầu custom claim `role=authenticated` trên mỗi UID. Sau khi
   cả ba đã xuất hiện trong Firebase Auth, có thể dùng tool hiện có từ thư mục
   `tools/firebase-admin`:

   ```powershell
   npm test
   node .\set-supabase-role.mjs `
     --project mobileth1qltailieu `
     --uid <UID_A> `
     --uid <UID_B> `
     --uid <UID_C> `
     --apply
   ```

   Xác nhận lời nhắc tương tác bằng cách nhập nguyên văn dòng được tool yêu
   cầu. Tool đọc claim hiện có và chỉ thay trường `role`, giữ lại các claim
   khác. Không đưa service account key vào repo. Sau khi claim đã cấp, từng
   tài khoản cần đăng xuất rồi đăng nhập lại để Firebase phát ID token mới.
   Nếu không có quyền Firebase Admin/ADC, dừng ở bước này và nhờ project
   administrator cấp claim; không bỏ qua bằng cách nới RLS.
5. Với từng account sau khi đăng nhập lại, chờ trang cloud tải xong. Lần tải
   đầu sẽ upsert hồ sơ vào `public.users`; chỉ sau đó account đó mới dùng
   được làm người nhận chia sẻ. Nếu thấy lỗi RLS ở `users`, chưa tiếp tục test
   tài liệu: kiểm tra claim `role` và token mới trước.

#### Chạy kiểm thử owner/viewer/editor

1. Đăng nhập bằng A. Tạo một tài liệu cloud có tệp nhỏ; xác nhận tài liệu
   xuất hiện và mở/tải được.
2. Mở tài liệu → Chia sẻ. Cấp UID của B quyền `viewer`, UID của C quyền
   `editor`. Nếu tài khoản chưa từng đăng nhập app, cho tài khoản đó đăng nhập
   một lần trước để có hồ sơ `users`, rồi thử chia sẻ lại.
3. Đăng xuất A, đăng nhập B. Xác nhận B thấy tài liệu được chia sẻ, mở/tải
   được, nhưng không có nút sửa, chia sẻ hoặc xóa. B vẫn có quyền tạo tài liệu
   riêng; điều đó không cấp quyền lên tài liệu của A.
4. Đăng xuất B, đăng nhập C. Xác nhận C thấy và mở được tài liệu, sửa metadata
   được; thử thay tệp nếu cần kiểm tra Storage policy cho editor. C không được
   cấp/thu hồi quyền hoặc xóa tài liệu của A.
5. Đăng nhập lại A. Thu hồi quyền B và C. Đăng nhập lần lượt từng tài khoản,
   tải lại danh sách và xác nhận tài liệu của A không còn đọc/tải được.
6. Đăng nhập A và xóa tài liệu; xác nhận metadata và object tệp đã bị xóa.
   URL ký sẵn có thể còn dùng được cho tới khi hết hạn 60 giây.

Ghi lại kết quả thực tế cho từng account/thao tác, cùng lỗi Supabase đã loại
bỏ token, UID và dữ liệu cá nhân. Việc UI ẩn nút chỉ xác nhận UI; không tự nó
chứng minh backend từ chối request trái phép. Không ghi nhận test cloud đạt
nếu chưa chạy bằng ba phiên người dùng thật.

| Thao tác trên tài liệu của A | A (owner) | B (viewer) | C (editor) |
| --- | --- | --- | --- |
| Đọc metadata và tải tệp | Được | Được | Được |
| Sửa metadata / thay tệp | Được | Bị từ chối | Được |
| Cấp/thu hồi quyền hoặc xóa tài liệu của A | Được | Bị từ chối | Bị từ chối |

Mỗi tài khoản đã xác thực vẫn có thể tạo tài liệu mới và trở thành owner của
tài liệu đó; vai trò viewer/editor trong bảng chỉ áp dụng cho tài liệu của A
được chia sẻ với họ.

## 6. Trạng thái checklist cloud

Mã nguồn chứa Google Sign-In, thao tác tài liệu cloud, chia sẻ/thu hồi quyền,
migration schema/RLS và policy cho Storage. Migration và Storage policies của
project thật cần được áp dụng/đối chiếu trong Dashboard; các thao tác owner,
viewer, editor phải được xác nhận với ít nhất ba phiên người dùng thật trước
khi kết luận kiểm thử cloud end-to-end đạt.
