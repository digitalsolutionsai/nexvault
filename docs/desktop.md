# NexVault trên desktop (Ubuntu, Windows, macOS): phân tích, chưa làm

Kết luận: **khả thi**, nhưng chỉ nên phát hành sau khi có mô hình **một người, nhiều thiết bị**.
Thứ tự nên làm: macOS → Windows → Linux. Mức bảo đảm thấp dần theo đúng thứ tự đó.

## Vì sao không cho desktop làm member riêng
Hiện tại 1 danh tính = 1 thiết bị = 1 member. Phiếu bầu và ngưỡng đếm theo member (`model.rs`: Add cần 100%, Remove cần ⌈2/3⌉).
Nếu máy tính là một member riêng thì:
- Một người có 2 phiếu. Trong nhóm 3 người, người đó có thể tự đạt 2/3.
- Mỗi lần thêm một máy lại cần cả nhóm duyệt.
- Tên member bị trùng.

## Thiết kế đề xuất: Person → Devices
- `Member` có danh sách `devices{sign_pk, dh_pk, class: mobile|desktop, hw: secure-enclave|tpm|hello|fido2|none}`.
- Op `DeviceAdd`:
  - Ký bởi một thiết bị đang dùng của chính người đó, kèm chữ ký của thiết bị mới để chứng minh sở hữu key.
  - Làm qua nghi thức gặp trực tiếp giữa hai máy của người đó: desktop hiện QR, điện thoại quét, hai bên so mã 6 số và con dấu, người dùng chọn đúng mã trên điện thoại.
- Op `DeviceRevoke`:
  - Chính người đó tự thu hồi, hoặc ⌈2/3⌉ người khác thu hồi khi máy bị mất.
  - **Bắt buộc đổi khoá workspace**.
- Phiếu bầu tính theo **người**. Khoá được wrap cho **từng thiết bị**. Host nhận kết nối theo `dh_pk` của thiết bị.
- Lợi ích phụ: mỗi thiết bị có `seq` riêng, nên hết hẳn lỗi trùng `seq` khi khôi phục bản sao lưu.

## Giữ master key trên từng OS
PIN 6 số chỉ an toàn khi **phần cứng** giới hạn số lần thử. Trên desktop, malware chạy cùng user lấy được blob PIN rồi brute‑force offline.

| OS | Nên dùng | Không đủ nếu chỉ dùng một mình |
|---|---|---|
| macOS | Secure Enclave + Touch ID (`BiometryCurrentSet`, `ThisDeviceOnly`), keychain gắn chữ ký app, hardened runtime | Keychain thường |
| Windows | Windows Hello (`KeyCredentialManager`, TPM) để dẫn xuất KEK; dự phòng CNG Platform Crypto Provider | DPAPI (cùng user là mở được) |
| Linux | Khoá FIDO2 `hmac-secret` (YubiKey…), tuỳ chọn TPM2 | Secret Service/libsecret (mọi process cùng user đều đọc được) |

## Rủi ro riêng của desktop và cách giảm
| | macOS | Windows | Linux |
|---|---|---|---|
| Chụp màn hình | `NSWindow.sharingType = .none` | `WDA_EXCLUDEFROMCAPTURE` | X11: không chặn được |
| Clipboard | `ConcealedType` + `TransientType` | Loại khỏi Clipboard History và cloud | Chỉ đặt được hint; clipboard manager vẫn lưu |
| Bộ nhớ, dump | `mlock`, hardened runtime | `VirtualLock`, tắt WER | `PR_SET_DUMPABLE=0`, `mlock` |
| Cập nhật | Developer ID + notarize | Authenticode | Gói ký GPG |

Cần làm ở core trước:
- Master key không đi qua Dart, chỉ nằm trong Rust.
- Bind cổng vào đúng interface LAN thay vì `[::]`.
- Load thư viện theo OS.
- Không phát hành CLI `nv`, vì nó nhận key qua argv.

## Chính sách nên có
- Cờ workspace `allow_desktop` và `desktop_requires_hw` (cần 100% member đồng ý).
- Thiết bị desktop có thể đặt "không xuất file / không copy", hoặc "không bỏ phiếu".
- Tự khoá sau 2–5 phút không dùng và khi khoá màn hình. Audit ghi thêm mã thiết bị.

**Không giải quyết được:** máy tính đang mở khoá có malware cùng user thì đọc được secret đang hiển thị, clipboard, bộ nhớ, và ký entry thay người dùng.

## Lộ trình ước lượng (một người)
| Giai đoạn | Nội dung | Thời gian |
|---|---|---|
| 0 | Hardening core | 1–1,5 tuần |
| 1 | Multi‑device + test (**bắt buộc trước khi có bản desktop**) | 3–4 tuần |
| 2 | macOS | 2–3 tuần |
| 3 | Windows | 2–3 tuần |
| 4 | Linux (FIDO2) | 2–3 tuần |
