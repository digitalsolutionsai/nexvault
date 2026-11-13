# Google Play: nội dung Store và khai báo

Dùng file này để điền vào Play Console. Mỗi mục ghi rõ vị trí trong Console. Ảnh nằm trong `docs/play/vi`, `docs/play/en` và `docs/play/icon-512.png`.

## Thông tin cơ bản (Create app)
- **App name:** NexVault
- **Default language:** Tiếng Việt (vi-VN). Thêm bản dịch: English (en-US)
- **App or game:** App · **Free or paid:** Free
- **Package:** `vn.dsai.nexvault`
- **Category:** Productivity (Năng suất)
- **Privacy policy:** https://dsai.vn/nexvault/privacy
- **Website:** https://dsai.vn
- **Contact email:** email hỗ trợ của DSAI

## Store listing: Tiếng Việt
**Tên (≤30):** NexVault

**Mô tả ngắn (≤80):**
Chia sẻ mật khẩu, chứng chỉ, khoá trong nhóm. Không máy chủ, mã hoá đầu cuối.

**Mô tả đầy đủ:**
```
NexVault giúp nhóm của bạn giữ và chia sẻ secret (tài khoản đăng nhập, API key, mật khẩu Wi-Fi, ghi chú bảo mật, và file như .env, SSH key, chứng chỉ .p12, keystore) mà không cần máy chủ hay tài khoản.

KHÔNG MÁY CHỦ
• Dữ liệu chỉ nằm trên máy của các thành viên, trong file được mã hoá.
• Sync trực tiếp giữa các máy: cùng Wi‑Fi hoặc qua IPv6, mã hoá đầu cuối.
• Không tài khoản, không quảng cáo, không công cụ theo dõi.

AN TOÀN NGAY CẢ KHI MẤT MÁY
• Mở app bằng khoá màn hình của máy (vân tay, khuôn mặt hoặc mã mở máy); khoá dữ liệu được bảo vệ bởi chip bảo mật của máy. Có mã khôi phục khi đổi khoá màn hình.
• Mỗi lần xem secret đều phải xác thực lại; nội dung tự ẩn sau 10 giây.
• Chặn chụp màn hình và che nội dung trong màn hình đa nhiệm.
• Sao chép có xác thực, ghi lịch sử và tự xoá bộ nhớ tạm sau 30 giây (có thể tắt hẳn sao chép).
• Tự khoá khi rời app, sau 1 hoặc 5 phút (tuỳ chọn).

NHÓM NGANG HÀNG
• Workspace được tạo khi các thành viên gặp trực tiếp: quét mã và so khớp để chống giả mạo.
• Thêm người mới cần sự đồng ý của toàn bộ thành viên.
• Lịch sử có chữ ký: ai tạo, xem, sao chép secret nào đều được ghi lại.
• Xoá thành viên thì đổi khoá, người bị xoá không nhận được dữ liệu mới.

SYNC TIỆN LỢI
• Mở sync, thành viên quét mã QR có hiệu lực 5 phút.
• Ở xa? Gửi ảnh mã qua ứng dụng chat; chỉ máy trong workspace mới giải mã được.
• Nhận ảnh mã qua nút Chia sẻ của Android.

KHÁC
• Sắp xếp secret theo thư mục, tìm kiếm nhanh.
• Theo dõi ngày hết hạn của chứng chỉ.
• Sao lưu mã hoá bằng mật khẩu riêng để chuyển máy.

NexVault dành cho đội kỹ thuật, startup và nhóm nhỏ cần chia sẻ thông tin nhạy cảm mà không muốn giao cho dịch vụ đám mây.
```

## Store listing: English
**Name:** NexVault

**Short description (≤80):**
Share passwords, certificates and keys in your team. No server, end-to-end.

**Full description:**
```
NexVault lets your team keep and share secrets (logins, API keys, Wi-Fi passwords, secure notes, and files such as .env, SSH keys, .p12 certificates and keystores) with no server and no accounts.

NO SERVER
• Data lives only on members' devices, in an encrypted file.
• Devices sync directly: same Wi‑Fi or IPv6, end-to-end encrypted.
• No accounts, no ads, no trackers.

SAFE EVEN IF A PHONE IS LOST
• Unlock with the device lock screen (fingerprint, face or device PIN); the data key is protected by the device's secure hardware. A recovery code covers lock screen changes.
• Every view requires authentication again; content hides after 10 seconds.
• Screenshots are blocked and content is hidden in the recent apps screen.
• Copying requires authentication, is logged and the clipboard clears after 30 seconds (copy can be turned off).
• Auto-locks when you leave the app, or after 1 or 5 minutes.

PEER-EQUAL TEAMS
• A workspace is created in person: members scan and compare codes to prevent impersonation.
• Adding someone requires every member's approval.
• Signed history: who created, viewed or copied each secret.
• Removing a member rotates the keys; they get no new data.

EASY SYNC
• Open sync and members scan a QR code valid for 5 minutes.
• Far away? Send the code image through a chat app; only devices in the workspace can decrypt it.
• Receive code images through Android's Share button.

MORE
• Folders and fast search.
• Certificate expiry tracking.
• Password-encrypted backup to move to a new phone.

Built for engineering teams, startups and small groups that need to share sensitive information without handing it to a cloud service.
```
Ghi chú: giao diện app hiện chỉ có tiếng Việt. Nếu muốn, thêm câu "The app interface is currently in Vietnamese." vào cuối bản English.

## Đồ hoạ (Store listing → Graphics)
| Mục | File |
|---|---|
| App icon 512×512 | `docs/play/icon-512.png` |
| Feature graphic 1024×500 | `docs/play/vi/feature-graphic.png`, `docs/play/en/feature-graphic.png` |
| Phone screenshots (6 ảnh, 1080×1920) | `docs/play/vi/01…06-*.png`, `docs/play/en/01…06-*.png` |

## App content (Policy → App content)
- **Privacy policy:** URL ở trên.
- **Ads:** No, my app does not contain ads.
- **App access:** All functionality is available without special access. App không có đăng nhập; lần đầu mở app dùng khoá màn hình của máy (hoặc PIN 6 số nếu máy không có khoá màn hình). Muốn thử sync cần 2 máy; ghi chú cho người duyệt:
  `No account or login. On first launch, choose a display name and confirm with the device lock screen (a 6-digit app PIN is offered if the device has no lock screen). Create a workspace from the home screen to add secrets. Sync requires a second device running NexVault.`
- **Content rating (IARC):** Category "Utility, Productivity, Communication or Other". Trả lời No cho mọi câu về bạo lực, tình dục, ngôn từ, chất cấm, cờ bạc. Câu "users can interact / exchange content": **Yes**: thành viên trong workspace chia sẻ nội dung với nhau (không công khai, không có người lạ). Câu chia sẻ vị trí: No. Mua hàng số: No.
- **Target audience:** 18+ (hoặc 16+ trở lên). Không chọn nhóm dưới 13.
- **News app:** No · **Government app:** No · **Financial features:** none · **Health:** No
- **Data safety:** xem mục dưới.

## Data safety
App không gửi dữ liệu người dùng về máy chủ của mình. Dữ liệu duy nhất rời khỏi máy theo nghĩa của Play là **dữ liệu chẩn đoán của Google ML Kit** (thư viện quét QR, xem https://developers.google.com/ml-kit/android-data-disclosure). Sync trực tiếp giữa các máy của người dùng, mã hoá đầu cuối, và do người dùng chủ động thực hiện. Theo định nghĩa của Play, đó không phải là "collected".

- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **No**. ML Kit không có cơ chế xoá; dữ liệu trong app thì người dùng tự xoá trên máy.

Các loại dữ liệu cần khai:

| Loại (Play) | Collected | Shared | Ephemeral | Required? | Mục đích |
|---|---|---|---|---|---|
| App info and performance → **Diagnostics** | Yes | No | No | Required | Analytics |
| App info and performance → **Other app performance data** | Yes | No | No | Required | Analytics |
| Device or other IDs | Yes | No | No | Required | Analytics |

Quyền **Thiết bị ở gần** (`NEARBY_WIFI_DEVICES`, khai `neverForLocation`) chỉ dùng để phát Wi‑Fi riêng khi ghép/sync; không thu thập gì, không suy ra vị trí.

Không khai: vị trí, thông tin cá nhân, tin nhắn, ảnh, file, danh bạ, tài chính, sức khoẻ, lịch sử duyệt web. Ảnh camera được xử lý trên máy, không gửi đi.

Muốn ghi "No data collected" thì phải thay ML Kit bằng thư viện quét QR không gửi số liệu (ví dụ ZXing). Xem phần đề xuất trong báo cáo.

## Release
- **Track:** tổ chức không bị yêu cầu closed test. Nên lên **Internal testing** trước (duyệt nhanh, thử trên máy thật bằng bản từ Play), rồi Promote lên Production.
- **Play App Signing:** dùng mặc định (Google giữ khoá ký app). Lần upload đầu tiên đăng ký upload key của file AAB.
- **File:** `app/build/app/outputs/bundle/release/app-release.aab` (version 1.0.0, versionCode 1)
- **Upload key:** giữ ngoài repo (`app/android/key.properties` trỏ tới file .jks, đã gitignore). Phải sao lưu an toàn. Mất thì phải nhờ Google reset upload key, mất vài ngày.
- **Release notes (vi-VN):**
  ```
  Phiên bản đầu tiên của NexVault.
  ```
  **(en-US):**
  ```
  First release of NexVault.
  ```
