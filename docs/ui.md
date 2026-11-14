# NexVault: thiết kế UI

Mockup: [`design/mockups.html`](../design/mockups.html) (v2), ảnh trong `design/shots/`; bản v1 để so sánh ở `design/shots-v1/`.
Icon: [`design/icon/gen_icon.py`](../design/icon/gen_icon.py) sinh ra `icon.svg`, foreground adaptive và bản monochrome.

## Ý tưởng
- Cảm hứng từ **két sắt và con dấu niêm phong**. Màu xanh rỉ đồng (verdigris) làm nền, màu đồng thau chỉ dành cho thương hiệu và con dấu.
- Điểm nhấn duy nhất là **con dấu sinh từ fingerprint** ([`design/seal.js`](../design/seal.js)). Có 6 màu nền × 3 màu kim loại, 5–12 cánh, sao 3–8 cánh và vòng 16 chấm, nên các workspace cạnh nhau nhìn khác nhau ngay.
- **Nền tối = thời điểm rủi ro cao**: mở khoá, sync, xác minh thành viên. Các màn còn lại dùng nền sáng.
- Font: **Be Vietnam Pro** cho chữ, **JetBrains Mono** chỉ cho dữ liệu thật (Key ID, mã 6 số, tên file).

## Token
| Tên | Hex | Dùng cho |
|---|---|---|
| paper | `#EDF0EE` | nền sáng |
| ink / ink2 | `#13252A` / `#4F6267` | chữ chính / phụ (5.3:1) |
| verdigris | `#1F6B5E` | nút chính |
| ground | `#173D3A` | nền tối, hộp secret |
| brass | `#C8963A` | logo, con dấu |
| edge | `#8FA19D` | viền nút ghost (≥3:1) |
| warn / danger | `#94540A` / `#A8302E` | sắp hết hạn, chưa sync lâu / huỷ, xoá |
| dOk / dRun | `#8FD3A8` / `#8DBEF0` | trên nền tối: xong (xanh lá) / đang chạy (xanh dương), khác màu hẳn để không cần nhìn icon mới phân biệt |

**Máy bật chế độ tối**: các màn nền sáng đổi sang bảng màu đêm (`NV.night`: paper `#101716`, ink `#E6ECEA`, verdigris `#6FC2B0`…). Màn nền tối (`DarkZone`) giữ nguyên `ground`, nên vẫn nổi lên là "lúc cần chú ý". Mã QR luôn đen trên trắng ở cả hai chế độ để camera dễ đọc.

## Kết quả đánh giá v1 → v2 (vision và một reviewer độc lập)
| Vấn đề ở v1 | Sửa trong v2 |
|---|---|
| Ba con dấu nhìn như nhau ở 54px | Thêm màu nền, màu kim loại và độ đa dạng hình |
| Nút "Giống nhau" nổi bật, dễ bấm bừa | Người dùng phải **chọn đúng 6 số** trong 3 lựa chọn; chỉ có một nút phụ "Không khớp" |
| Copy private key ra clipboard | Chỉ copy Key ID / Team ID ngoài màn hình; copy nội dung nằm trong menu ⋮, gắn cờ sensitive, tự xoá sau 30 giây |
| Hộp secret vẽ key thật rồi làm mờ | Chỉ vẽ placeholder; giữ để xem cần biometric/PIN; thêm "Hiện trong 10 giây" cho người khó giữ tay |
| Thanh "độ mới" không ai hiểu, chấm xanh giống "online" | Ghi bằng chữ: "Sync với Minh hôm qua", "19 ngày chưa sync" |
| Không có nút tham gia; ô tạo workspace nhìn như placeholder | Hai nút rõ ràng: "Tạo workspace" và "Quét mã" (một máy quét đọc được cả mã mời lẫn mã sync) |
| Host không thấy thiết bị lạ | Thêm hàng "Thiết bị lạ, đã từ chối"; thêm nút "Tạo mã mới" |
| Brass mang quá nhiều nghĩa | Trạng thái "đang chạy" dùng màu riêng (nay là xanh dương); brass chỉ cho thương hiệu |
| Icon button 40px, chữ 12px, viền 1.2:1 | 48px, tối thiểu 13px, viền `#8FA19D` |
| Thiếu "Quên PIN?" và số lần thử còn lại | Đã thêm |

## Tablet (iPad, tablet Android, chia đôi màn hình)
- Cửa sổ rộng từ 720 điểm trở lên: giao diện điện thoại nằm trong cột rộng 600 điểm, căn giữa trên nền `#0F2F2C` (`WideFrame` trong `ui/widgets.dart`). Cột bắt đầu dưới thanh trạng thái để chữ trên thanh trạng thái luôn sáng trên nền tối. Hộp thoại và bảng trượt mở trong cột.
- Màn PIN và màn mở khoá căn giữa theo chiều dọc khi màn cao trên 960 điểm (`TopGap`).
- Điện thoại khoá dọc; máy có cạnh ngắn từ 600 điểm trở lên được xoay tự do (iPad bắt buộc hỗ trợ đủ 4 hướng nếu muốn chạy Split View / Stage Manager).
- Bàn phím rời (Magic Keyboard…): gõ số và phím xoá ở mọi bàn phím PIN.
- Để sau: bố cục hai cột trên iPad (danh sách workspace / secret bên trái, chi tiết bên phải).

## Languages

English and Vietnamese. Strings live in `app/lib/l10n/app_en.arb` (template) and `app_vi.arb`;
`flutter gen-l10n` (run by `flutter pub get` / builds) writes `lib/l10n/gen/`. Code reads them
through the global `tr` (`lib/l10n/l10n.dart`), so non-widget code (core error texts, prompt
titles) is localized too. The app follows the phone: Vietnamese phones get Vietnamese, every
other language gets English. Settings > Language overrides it.

- Field labels stored inside secrets ("Mật khẩu .p12", "Hết hạn"…) stay as they are on disk and
  in sync; they are translated only for display, so mixed-language workspaces keep working.
- Native code sends error codes, not text; the Dart side words them. The biometric prompt
  buttons get their labels from the app (`setLabels`). iOS permission prompts use
  `InfoPlist.strings` in `en.lproj` / `vi.lproj`.
- New strings: add the key to both ARB files (placeholders and ICU plurals need `@key`
  metadata in `app_en.arb`).
