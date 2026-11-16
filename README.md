# Khách BĐS – App quản lý khách hàng bất động sản (Android, offline)

Viết bằng **Flutter**. Dữ liệu lưu **ngay trong điện thoại**, không cần mạng.
Giao diện tiếng Việt, chữ to, nút to, bấm được bằng 1 tay. Màu trắng, xanh dương đậm và vàng gold.

---

## App có gì?

### Trang chủ: 3 nút lớn

1. **THÊM KHÁCH** (nút vàng)
2. **DANH SÁCH KHÁCH**: tìm theo tên, SĐT, khu vực, dự án; lọc theo trạng thái
3. **CẦN GỌI HÔM NAY**: có số đỏ báo bao nhiêu khách cần gọi (tính cả khách quá hẹn)

Bên dưới có 3 nút nhỏ: **Dự án**, **Tiền & HH**, **Sao lưu / Excel**. Nút ⚙️ góc trên là Cài đặt (mật khẩu, vân tay).

### 1. Khách hàng
- **Thông tin:** Tên, SĐT, Zalo, Facebook, Nguồn khách (Zalo / Facebook / Người quen / Đi xem đất / Chạy ads)
- **Nhu cầu:** Mua / Thuê / Đầu tư, Loại BĐS (Đất nền / Chung cư / Nhà phố / Shophouse), Khu vực, Ngân sách, Thời gian muốn mua
- **Trạng thái:** Mới, Đã gọi, Đã hẹn gặp, Đã dẫn đi xem, Đang đàm phán, Đã cọc, Đã chốt, Không nghe máy, Không tiềm năng
- **Lịch sử chăm sóc:** mỗi lần gọi / nhắn ghi lại ngày giờ và nội dung. Đổi trạng thái cũng được app **tự ghi lại**, nên 1 tháng sau mở ra vẫn biết khách đã nói gì
- **Nhắc hẹn:** Gọi lại / Dẫn đi xem / Gặp mặt, chọn **báo trước 30 phút hoặc 1 tiếng**. Có nút chọn nhanh "9h sáng mai", "14h chiều mai"
- **Nút liên hệ nhanh:** Gọi, SMS, Zalo, Facebook. Sau khi gọi, app nhắc bạn ghi lại nội dung

### 2. Dự án / Hàng hóa
- Tên dự án, **ảnh** (chọn từ thư viện hoặc chụp), vị trí, giá, diện tích, pháp lý (Sổ đỏ / HĐMB), hoa hồng, số căn đang bán
- Gắn khách vào dự án họ quan tâm. Trong trang dự án sẽ thấy danh sách khách quan tâm
- Khi khách **cọc hoặc chốt**, app **tự trừ 1 căn**. Hết căn thì hiện "ĐÃ BÁN HẾT". Cũng có nút đánh dấu bán hết bằng tay

### 3. Tiền & Hoa hồng
- Mỗi giao dịch có: giá chốt, đã cọc, **còn lại (app tự tính)**, tổng hoa hồng, chia cho ai, tôi nhận bao nhiêu, đã nhận chưa
- Số tiền nhập theo **triệu đồng**: gõ `2500` nghĩa là 2,5 tỷ (app hiện "= 2,5 tỷ" để bạn kiểm tra)
- Thống kê theo tháng: chốt mấy căn, hoa hồng của tôi, đã nhận / chưa nhận, kèm danh sách hoa hồng chưa nhận
- Khi đổi khách sang "Đã cọc" hoặc "Đã chốt", app hỏi có muốn nhập tiền luôn không

### 4. Nhập / Xuất / Sao lưu
- **Sao lưu:** tạo 1 file chứa toàn bộ khách, lịch sử, dự án (kèm ảnh) và giao dịch. Gửi file qua Zalo hoặc Drive, hoặc lưu vào máy
- **Khôi phục:** chọn file sao lưu để lấy lại dữ liệu khi đổi máy hoặc cài lại app
- **Xuất Excel:** 4 trang tính (Khách hàng, Lịch sử chăm sóc, Dự án, Giao dịch) để gửi sếp
- **Nhập Excel / CSV:** khách **trùng SĐT sẽ được cập nhật, không tạo trùng**. Có nút "Tải file mẫu"
- Trang chủ hiện **cảnh báo** nếu đã hơn 7 ngày chưa sao lưu

### 5. Bảo mật
- Mật khẩu mở app (4 số), có thể mở bằng **vân tay**
- App tự khóa lại khi bạn rời app hơn 2 phút

---

## CÁCH 1 (dễ nhất): Nhờ GitHub build APK miễn phí

> ⚠️ **Nên tạo repository MỚI** cho mỗi lần tải bản mới lên. Tải đè lên repository cũ dễ bị sót file cũ, gây lỗi khi build.
> Repository cũ có thể xóa ở *Settings → Danger Zone → Delete this repository*.

1. Vào <https://github.com> và đăng nhập.
2. Bấm **+** → **New repository** → đặt tên mới (vd `khach-bds-v2`) → chọn **Private** → **Create repository**.
3. Bấm link **uploading an existing file**.
4. Giải nén file zip. Mở thư mục `quan_ly_khach`, chọn **tất cả** bên trong (`android`, `lib`, `test`, `pubspec.yaml`, `analysis_options.yaml`, …), kéo thả vào trang GitHub rồi bấm **Commit changes**.
   ⚠️ Phải có đủ thư mục **`android`**: bên trong có MainActivity, các file build.gradle, ảnh icon và `keystore/debug.keystore`.
5. Tạo file build tự động (thư mục `.github` bị máy ẩn nên phải làm tay):
   - Bấm **Add file → Create new file**
   - Ô tên file gõ: `.github/workflows/build-apk.yml`
   - Mở file đó trong zip (trên Mac: trong Finder nhấn `Cmd + Shift + .` để hiện file ẩn), copy toàn bộ nội dung dán vào → **Commit changes**
6. Bấm tab **Actions** và đợi khoảng **10–15 phút** đến khi hiện dấu ✅ xanh.
7. Bấm vào lần chạy có dấu ✅ → mục **Artifacts** → tải **QuanLyKhach-APK** → giải nén ra **`QuanLyKhach.apk`**.

**Phiên bản công cụ (đã kiểm tra tương thích với nhau):** Flutter 3.24.5 · Java 17 · Gradle 8.11.1 · Android Gradle Plugin 8.9.1 · Kotlin 2.1.0 · compileSdk 36.
Đừng hạ Kotlin xuống 1.9.x: các thư viện mới cần Kotlin 2.x.

**Nếu bị dấu ❌ đỏ:**
- Nếu bước **"Kiểm tra đủ file"** bị đỏ: lỗi sẽ ghi rõ thiếu file nào, bạn tải bổ sung file đó lên.
- Nếu bước khác bị đỏ: bấm vào bước đó, copy đoạn chữ lỗi (thường ở gần cuối) gửi lại cho Claude.

---

## CÁCH 2: Build trên máy tính

1. Cài **Flutter 3.24.5**: <https://docs.flutter.dev/release/archive> (chọn đúng bản 3.24.5 cho hệ điều hành của bạn).
2. Cài **Android Studio**: <https://developer.android.com/studio>. Mở lên để nó tải Android SDK, và cài thêm **Android SDK Command-line Tools**.
3. Mở Terminal, chạy `flutter doctor --android-licenses` (gõ `y` liên tục), sau đó chạy `flutter doctor`.
4. Build:
   - Mac / Linux: `bash build_apk.sh`
   - Windows: bấm đúp `build_apk.bat`
   - Hoặc gõ 2 lệnh: `flutter pub get` rồi `flutter build apk --release`
5. Có file APK tại `build/app/outputs/flutter-apk/app-release.apk`.

---

## Cài lên điện thoại

1. Gửi `QuanLyKhach.apk` vào điện thoại (qua Zalo, Drive, cáp USB…) rồi mở file.
2. Nếu máy hỏi về *"ứng dụng không rõ nguồn gốc"*: bật **Cho phép từ nguồn này**.
3. Nếu Play Protect cảnh báo, bấm **Vẫn cài đặt**.
4. Mở app, bấm **Cho phép** thông báo.
5. Để nhắc hẹn chạy chắc chắn (nhất là máy Xiaomi, Oppo, Vivo, Samsung): vào *Cài đặt → Ứng dụng → Khách BĐS → Pin* → chọn **Không hạn chế**, và bật **Tự khởi chạy** nếu có.

> **Lưu ý:** Bản 2.0 dùng cơ sở dữ liệu mới, khách nhập ở bản thử 1.0 (nếu có) sẽ không tự chuyển sang.
> Cài đè bản mới thì giữ nguyên dữ liệu, **nếu luôn build cùng 1 cách** (luôn GitHub, hoặc luôn trên máy tính).

---

## Cấu trúc code (để tự sửa sau này)

```
lib/
  main.dart                 Khởi động app, tiếng Việt, khóa app
  theme.dart                Màu sắc (kNavy, kGold), cỡ chữ, nút
  models.dart               Khách, Trạng thái, Lịch sử, Dự án, Giao dịch, các lựa chọn
  db.dart                   Cơ sở dữ liệu SQLite
  store.dart                Dữ liệu dùng chung + thống kê
  notifications.dart        Nhắc hẹn
  security.dart             Mật khẩu, vân tay, màn hình khóa
  data_io.dart              Excel, CSV, sao lưu / khôi phục
  utils.dart                Định dạng ngày / tiền, tìm không dấu, gọi / Zalo
  widgets.dart              Mảnh giao diện dùng chung
  screens/                  Các màn hình
android/                    Phần Android (v2 embedding, Gradle cho Flutter 3.24)
  settings.gradle, build.gradle, gradle.properties
  app/build.gradle          Cấu hình app (namespace, SDK, desugaring)
  app/src/main/AndroidManifest.xml   Tên app, quyền, flutterEmbedding = 2
  app/src/main/kotlin/.../MainActivity.kt
```

**Sửa nhanh:**
- Thêm nguồn khách, loại BĐS, khu vực: `lib/models.dart` → class `Opt`
- Đổi màu: `lib/theme.dart`
- Đổi tên app trên điện thoại: `AndroidManifest.xml` → `android:label`
