# NexVault: threat model

## Tài sản cần bảo vệ
Nội dung secret (private key, cert, mật khẩu), metadata (tên secret, ai có quyền), và danh sách members.

## Kẻ tấn công và cách chống

| # | Kẻ tấn công | Muốn | Chống bằng | Còn hở |
|---|---|---|---|---|
| T1 | Người cùng mạng Wi‑Fi / nhà mạng | Đọc dữ liệu sync | Noise (ChaCha20‑Poly1305, forward secrecy) | Biết được có 2 IP đang nói chuyện |
| T2 | Kênh chat dùng để gửi ticket (Zalo, Telegram…) | Biết IP/port, chen vào phiên | Ticket mã hoá bằng `ticket_key`; vào phiên cần static key của member | Biết có một blob được gửi |
| T3 | Người lấy được ảnh QR ticket nhưng không phải member | Vào phiên sync | Không giải mã được ticket; dù có PSK thì Noise vẫn đòi static key thuộc members | Có thể gửi gói rác trong 5 phút để làm phiên chậm (DoS nhẹ) |
| T4 | MITM lúc tạo workspace | Cài key giả | Gặp trực tiếp + so con dấu và 6 số từ handshake hash | Người dùng bấm "Giống nhau" mà không so thật |
| T5 | Kẻ trộm điện thoại | Đọc vault | Vault mã hoá; mặc định master key niêm phong bằng khoá Keystore / Keychain chỉ mở được bằng sinh trắc hoặc mã mở máy, mà phần cứng giới hạn số lần thử; mã khôi phục 120 bit (không đoán được); key chỉ nằm trong Rust (không qua Dart, xoá sau khi dùng). Máy không có khoá màn hình: PIN của app (Argon2id) có giới hạn số lần thử | Điện thoại đã root và đang mở khoá. Kẻ biết mã mở máy mở được app (cùng mức với mọi dữ liệu khác trên máy). Ở chế độ PIN, giới hạn số lần thử do app tự đếm, không phải phần cứng. Mã khôi phục bị lộ (chép ra giấy) cho phép mở vault nếu có cả máy |
| T6 | Ép mở bằng vân tay | Xem secret | Chế độ PIN: tắt vân tay để chỉ dùng PIN. Chế độ khoá màn hình: dùng tính năng khoá sinh trắc tạm thời của hệ điều hành (Lockdown trên Android, bấm giữ nút nguồn trên iPhone) | Chế độ khoá màn hình chưa có lớp PIN thứ hai của app (dự kiến). Chưa có tuỳ chọn "chỉ PIN" riêng cho từng workspace |
| T7 | Malware đọc màn hình hoặc clipboard | Lấy secret đang hiển thị | `FLAG_SECURE`; giữ để xem; mọi lần copy (nội dung hoặc trường bí mật) đều xác thực lại, ghi audit, đánh dấu sensitive và tự xoá sau 30 giây; trường bí mật không cho bôi đen để copy bằng menu hệ thống ; lần đầu copy có cảnh báo về lịch sử bàn phím; có thể tắt hẳn copy trong Cài đặt (bật lại cần xác thực) | Accessibility service độc hại. **Đã kiểm chứng trên S24:** Samsung Keyboard hiện nội dung trên thanh gợi ý và lưu vào lịch sử "Bộ nhớ tạm" của nó, bỏ qua cờ sensitive; mục đó vẫn còn sau 30 giây và app không xoá được |
| T8 | Member xấu (insider) | Lấy secret rồi rời nhóm | **Không chống được** vì member đã thấy secret. App ghi audit (xem / sao chép / xuất file) và hộp thoại xoá member nhắc rotate key quan trọng | Chưa tự đánh dấu secret nào cần rotate |
| T9 | Member bị xoá | Tiếp tục nhận dữ liệu mới | Xoá thì sinh khoá mới (key_id mới), chỉ wrap cho người ở lại; host từ chối static key không còn là member và báo `removed` (có test) | Ticket mã hoá bằng khoá epoch gốc để member chưa sync vẫn vào được, nên người đã bị xoá vẫn đọc được IP/port trong ticket. Device chưa sync sau lần xoá vẫn có thể gửi cho người đó tới khi nó sync |
| T10 | Device của member bị chiếm, giả mạo entry | Sửa hoặc xoá secret | Mọi entry đều ký; lịch sử giữ đủ phiên bản; xoá chỉ là tombstone; entry giả, sửa, nhảy seq bị từ chối (có test) | Kẻ chiếm vẫn ký được entry thay member đó |
| T11 | Người lấy được file sao lưu | Đọc vault | Argon2id 64 MiB + XChaCha20‑Poly1305; mật khẩu ≥ 10 ký tự | Mật khẩu yếu vẫn brute‑force được offline |
| T12 | Một member tự ý thêm người | Đưa người ngoài vào | Thêm người cần 100% member; người mới chỉ có khoá khi đủ phiếu | Member có thể tự gửi secret cho người ngoài (giống T8) |
| T14 | App khác trên cùng điện thoại | Gửi intent giả để NexVault đọc/xoá file, hoặc kết nối cổng sync | Đường dẫn ảnh share chỉ được nằm trong `cache/shared`; deep link chỉ nhận `nexvault://`; cổng sync cần static key của member (Noise) | Có thể mở màn tham gia/sync bằng deep link; người dùng vẫn phải xác nhận |
| T13 | (Desktop, chưa làm) Malware cùng user trên máy tính | Đọc vault, bộ nhớ, clipboard | Xem [desktop.md](desktop.md) | Máy đang mở khoá thì không chặn được |

## Ngoài phạm vi
- Hệ điều hành đã bị chiếm quyền hoàn toàn (root/jailbreak cùng malware chạy bằng quyền kernel).
- Phân tích lưu lượng (traffic analysis) ở mức nhà mạng.
- Mất toàn bộ device của mọi member mà không ai có bản sao lưu. (Social recovery bằng Shamir chưa làm.)
