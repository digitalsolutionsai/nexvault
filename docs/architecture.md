# NexVault: kiến trúc

NexVault là app Android/iOS để một nhóm nhỏ (founders, team DevOps, gia đình…) chia sẻ secret (Apple `.p8`, `.p12`, Android keystore, SSH key, `.env`…) **không qua server**. Mọi thiết bị đều ngang hàng.

## 1. Quyết định nền tảng

| Chủ đề | Quyết định | Lý do |
|---|---|---|
| Server / relay | **Không có.** | Không tin bên thứ ba, không có hạ tầng cần vận hành. |
| Sync chính | Gặp nhau: cùng Wi‑Fi, hotspot của một máy, BLE (sau MVP). | Chạy được trên cả iOS lẫn Android, không phụ thuộc mạng ngoài. |
| Sync từ xa | IPv6 qua **sync ticket** (QR hoặc link), hiệu lực **5 phút**. Đây là nice‑to‑have. | Người dùng chủ động mở, app ở foreground, không cần socket nền. |
| Sync nhóm | Mô hình hub: host mở ticket, nhiều member cùng vào, host chuyển tiếp entry ngay. | Một buổi họp là cả nhóm khớp dữ liệu. |
| Tạo workspace / thêm người | **Bắt buộc gặp trực tiếp**, so con dấu và 6 số. | Đây là lúc trao identity key; qua kênh từ xa thì không chống được MITM. |
| Governance | Thêm người: **100% members ký**. Xoá người: **⌈2/3⌉ members còn lại ký**. | Thêm người là việc nhạy cảm nên cần đồng thuận; xoá phải làm được kể cả khi người bị xoá không hợp tác. |
| Mở app / xem secret | Mặc định: khoá màn hình của máy (sinh trắc hoặc mã mở máy) gắn với key trong Android Keystore / iOS Keychain, kèm mã khôi phục. Máy không có khoá màn hình: PIN của app (Argon2id), tuỳ chọn thêm vân tay. | |
| Stack | **Rust core** (crypto, log, sync, mạng) + **Flutter UI**, nối qua `dart:ffi` với API JSON. | Viết core một lần cho cả hai nền tảng; Flutter là stack team đang dùng. |

## 2. Thành phần

```
┌──────────────── Flutter app ────────────────┐
│ UI (Material 3, theme NexVault)              │
│ Unlock: khoá màn hình máy / PIN + mã khôi phục│
│ Secure storage: Android Keystore / Keychain  │
│ QR: hiển thị (qr_flutter), quét (camera/ảnh) │
│ Deep link: nexvault://t/<ticket>             │
└───────────────┬─────────────────────────────┘
                │ dart:ffi  nv_call(json) -> json
┌───────────────▼──── nexvault-core (Rust) ────┐
│ identity   Ed25519 (ký) + X25519 (Noise/wrap)│
│ log        entry có ký, seq theo tác giả     │
│ state      fold log → members, secrets       │
│ crypto     envelope: DEK wrap cho từng member│
│ ticket     mã hoá bằng workspace ticket key  │
│ net        TCP + Noise IKpsk2, host hub      │
│ store      file vault mã hoá bằng master key │
└──────────────────────────────────────────────┘
```

**Master key** (32 byte) do Rust sinh lần đầu và **không bao giờ đi qua Dart**:
- Luồng khoá màn hình (mặc định, Android 11+ và iOS): `device_setup` sinh key trong core; native niêm phong key bằng khoá Keystore `nexvault_dev_v1` (`AUTH_BIOMETRIC_STRONG | AUTH_DEVICE_CREDENTIAL`, không mất khi thêm vân tay) hoặc mục Keychain `.userPresence`. Mã mở máy được phần cứng giới hạn số lần thử (Gatekeeper/Weaver, Secure Enclave), PIN của app thì không, nên đây là mặc định.
- Mã khôi phục: 120 bit ngẫu nhiên, base32 Crockford, 6 nhóm 4 ký tự. `recovery_new` trả mã và blob wrap bằng Argon2id; Dart chỉ lưu blob (`rec_blob`). Dùng khi khoá màn hình bị tắt hoặc đặt lại (khoá Keystore / mục Keychain mất hiệu lực): `recovery_open` mở vault rồi niêm phong lại; nếu máy không còn khoá màn hình thì người dùng đặt PIN của app (`pin_set`). Nhập sai bị đếm và khoá tạm như PIN.
- Không bao giờ tự xoá một vault còn trên đĩa. Android có thể đặt lại secure storage (lỗi Keystore sau khi khởi động lại hay cập nhật hệ điều hành); thư viện `flutter_secure_storage` mặc định `resetOnError` sẽ xoá sạch nó, nên app tắt cờ này. Khi secure storage mất bản ghi mà vault vẫn còn, `Keys.isSetUp` dựng lại từ những gì nằm ngoài nó: còn khoá niêm phong (`nexvault_dev`) thì ghi lại chế độ khoá màn hình; không còn thì mở bằng mã khôi phục, vì blob khôi phục có thêm một bản sao `vault/recovery.blob` cạnh vault (an toàn trên đĩa: mã 120 bit qua Argon2id, dữ liệu app không nằm trong bản sao lưu). Chỉ dọn những gì không thể mở: phần còn sót khi không có vault, hoặc lần cài đầu bị ngắt trước khi kịp niêm phong.
- Luồng PIN: Dart chỉ giữ blob đã wrap bằng PIN (trong secure storage). Các lệnh `pin_setup`, `pin_open`, `pin_check`, `pin_change` tự unwrap và so khớp key trong core.
- Luồng vân tay: Kotlin giải mã bằng khoá Keystore sau BiometricPrompt, rồi đưa thẳng `ByteArray` vào Rust qua JNI (`core/src/jni.rs`) và xoá mảng ngay. Dart chỉ nhận kết quả mở khoá.

Lý do: String trong Dart là bất biến, do GC quản lý và không xoá được, nên key sẽ nằm lại trong heap.

## 3. Dữ liệu

### Identity (mỗi thiết bị)
- `sign_sk/pk`: Ed25519. Dùng để ký mọi entry.
- `dh_sk/pk`: X25519. Dùng làm static key cho Noise và để nhận DEK được wrap.
- `device_id = blake3(sign_pk)[..8]`, hiển thị dạng hex.

### Workspace
- `ws_id`: 16 byte ngẫu nhiên.
- **Khoá workspace** (32 byte) có `key_id = blake3("nv/key-id" ‖ key)[..8]`. Mỗi khoá được wrap riêng cho từng member và nằm trong log (`KeyWrap{epoch, wrap}`). Khoá con:
  - `item_key = HKDF(key, "nv/item")`: niêm phong secret và thư mục.
  - `ticket_key = HKDF(genesis_key, "nv/ticket")`: mã hoá sync ticket. Luôn lấy từ khoá **gốc** để member chưa kịp sync sau một lần xoá vẫn đọc được ticket (đánh đổi ghi ở T9).
- Mỗi item ghi rõ `key_id` của khoá đã niêm phong nó. Thiết bị giữ **mọi khoá ứng viên** nhận được, nên hai người cùng lúc tạo hai khoá khác nhau (hai approval đồng thời) không bao giờ làm dữ liệu không đọc được.
- **Con dấu và fingerprint** = `blake3(genesis_entry_id)`, 9 byte đầu dùng để vẽ con dấu, xem [`design/seal.js`](../design/seal.js).

### Log
Mỗi workspace là một **append‑only log** gồm các entry:

```
Entry  { body: bytes(CBOR Body), sigs: [(signer_pk, sig64)] }
Body   { ws, author, seq, ts, op }
id     = blake3(body)
```

- `seq` tăng dần theo **từng tác giả** (1, 2, 3…) nên version vector `{author → seq lớn nhất}` đủ để biết mỗi bên thiếu gì.
- Chữ ký nằm trên `body` gốc (bytes), nên không cần canonicalize lại khi chuyển tiếp.
- Entry bị từ chối nếu: chữ ký sai, tác giả không phải member/newcomer đang chờ, seq nhảy cóc, sai workspace, entry > 12 MB. Có test cho từng trường hợp (`core/tests/log.rs`).
- **Fold** (log → state) có thứ tự xác định: Genesis trước, sau đó theo `(ts, author, seq, id)`. Hai máy có cùng tập entry luôn ra cùng state, bất kể nhận theo thứ tự nào (có test).

Các `op`:

| op | Nội dung | Ai ký |
|---|---|---|
| `Genesis` | tên, members (tên, sign_pk, dh_pk), khoá gốc wrap cho từng người | **Tất cả** thành viên đầu tiên (co‑sign trong buổi gặp) |
| `SecretPut` | `secret_id`, `version`, `key_id`, `sealed` = XChaCha20‑Poly1305(item_key, {name, kind, fields, folder, file, content}), AAD = (ws, id, version, "secret") | tác giả |
| `SecretDelete` | `secret_id` (tombstone) | tác giả |
| `FolderPut` | `folder_id`, `version`, `key_id`, `sealed` = {name, parent} | tác giả |
| `FolderDelete` | `folder_id` (chỉ khi thư mục trống) | tác giả |
| `Audit` | `secret_id`, `viewed / copied / exported` | tác giả |
| `Propose` | `Add{member}` hoặc `Remove{target}`, kèm khoá nếu một mình đã đủ ngưỡng | tác giả |
| `Approve` | `proposal`; **người hoàn tất ngưỡng** kèm khoá | tác giả |
| `Keys` | `proposal`, khoá còn thiếu (dự phòng) | bất kỳ member nào có khoá |

**Thư mục.** Tên và cây thư mục cũng được mã hoá như secret, nên người ngoài không thấy cấu trúc. Secret trỏ tới thư mục qua trường `folder` bên trong phần đã niêm phong. Thư mục mất cha (cha bị xoá ở máy khác) hoặc tạo vòng lặp do hai lần chuyển đồng thời thì được coi là thư mục gốc. Chỉ xoá được thư mục trống.

**Thay đổi thành viên.**
- Thêm người cần **100%** member hiện tại đồng ý. Người mời gặp trực tiếp người mới (cùng nghi thức mã 6 số + con dấu), tạo `Propose{Add}` (tính là phiếu của mình) rồi gửi cho người mới bản log hiện tại và `ticket_key`. Người mới ở trạng thái **chờ**: đọc được ticket, được host nhận vào phiên sync, nhưng chưa có khoá đọc secret.
- Xoá người cần **⌈2/3⌉ số người ở lại** đồng ý (tối thiểu 1).
- Approval nào làm đạt ngưỡng thì phải kèm khoá: với Add là mọi khoá hiện có wrap cho người mới; với Remove là một khoá **mới** chỉ wrap cho người ở lại. Nếu hai người cùng duyệt mà không ai thấy phiếu của người kia (ai cũng nghĩ mình chưa hoàn tất), proposal đạt ngưỡng nhưng thiếu khoá: state đánh dấu `needs_keys` và lần sync/mở workspace sau, máy đầu tiên có khoá sẽ tự gửi `Keys` (`maintain`).
- Remove làm `epoch_count` tăng; proposal liên quan tới người bị xoá bị huỷ.

### Xung đột
Hai `SecretPut` cùng `secret_id` + `version` từ hai tác giả: **giữ cả hai** ("heads"), UI hiện "Có 2 phiên bản" với nút Xem / Giữ bản này. Lựa chọn được lưu bằng `SecretPut` mới với `version + 1`. Không bao giờ tự động last‑write‑wins. Thư mục cũng có heads nhưng tự chọn bản mới nhất theo (ts, entry_id) vì chỉ là tên.

## 4. Mạng

### Sync ticket
```
QR / link:  nexvault://t/<base64url( ws_id(16) | nonce(24) | XChaCha20‑Poly1305(ticket_key, T) )>
T = { v, host_sign_pk, addrs[], port, psk(32), expires_at, sig }
```
- Hiệu lực **5 phút**. Dùng được cho **nhiều thiết bị** (sync nhóm), nhưng **mỗi device chỉ vào một lần**.
- Người ngoài workspace không giải mã được, nên kênh chat dùng để gửi chỉ thấy một blob vô nghĩa.
- `addrs` gồm các IP LAN (IPv4/IPv6) và IPv6 global nếu có.

### Phiên kết nối
1. Joiner thử lần lượt các `addrs` bằng TCP, timeout ngắn cho mỗi địa chỉ.
2. **Noise `IKpsk2_25519_ChaChaPoly_BLAKE2s`**. Joiner biết trước static key của host (lấy từ member list), PSK lấy từ ticket. Host kiểm tra static key của joiner có thuộc members không.
3. Hai bên gửi `Hello{ws, vv}` → gửi các entry bên kia thiếu (theo vv) → verify và áp dụng.
4. Host **chuyển tiếp** entry mới cho mọi phiên đang mở và trả lời mọi `Ack` bằng version vector của mình, nên joiner nhận đủ qua đường chuyển tiếp vẫn biết là đã xong.
5. Thiết bị không phải member: host gửi `Error("not a member")`. Member đã bị xoá: `Error("removed")`, màn host hiện tên người đó. Tối đa 32 thiết bị mỗi phiên.

Framing: `u32 length | các frame noise ≤ 60 KB`, tổng tối đa 64 MB một message.

### Tạo workspace (gặp trực tiếp)
1. Người tạo hiện **QR mời** gồm `sign_pk`, `dh_pk`, địa chỉ LAN, PSK một lần. QR này không mã hoá vì quét trực tiếp trên màn hình.
2. Thành viên kia quét → Noise IKpsk2 → gửi profile `{name, sign_pk, dh_pk}`.
3. Hai máy hiện **con dấu + 6 số** sinh từ handshake hash → người dùng xác nhận "Giống nhau".
4. Người mới phải **chọn đúng mã** người tạo đọc to trong 3 lựa chọn (chống bấm bừa). Chọn sai thì phiên bị huỷ và người tạo được cảnh báo.
5. Người tạo xác nhận "Đúng người" → khi đủ người, dựng `Genesis` → gửi cho từng người co‑sign → phát `Genesis` hoàn chỉnh.
6. Mời vào workspace có sẵn dùng cùng nghi thức; bước 5 thay bằng `Propose{Add}` + gửi `Bootstrap{log, ticket_key}`.

### Wi‑Fi riêng khi không có mạng chung
Wi‑Fi quán cà phê hay Wi‑Fi khách thường chặn các máy nói chuyện với nhau. Khi đó máy mở sync/mời có thể **phát Wi‑Fi riêng**:
- **Android 13+** (máy phát): `LocalOnlyHotspot` của Android. Không có internet, tên và mật khẩu ngẫu nhiên, tắt khi rời màn hình. Chỉ cần quyền `NEARBY_WIFI_DEVICES` với `neverForLocation`, không xin vị trí. Interface của hotspot được báo thêm cho core (`netIfaces`) để địa chỉ của nó vào mã.
- QR mang thêm đuôi `#w=<base64url {"s":ssid,"p":pass,"t":security}>`. Core không thấy phần sau `#`. Ảnh mã gửi cho người ở xa không kèm đuôi này.
- Máy quét: Android 10+ dùng `WifiNetworkSpecifier` (hệ thống hỏi người dùng), rồi `bindProcessToNetwork` để mọi socket, kể cả của core Rust, đi qua mạng đó, và nhả ra khi màn ghép/sync đóng. iOS dùng `NEHotspotConfiguration` (`joinOnce`, entitlement *Hotspot Configuration*).
- iPhone không tự phát được (Apple không cho app bật hotspot): người dùng bật Điểm truy cập cá nhân như trước.
- Hotspot chỉ là đường đi: phiên vẫn là Noise IKpsk2 với PSK trong mã, nên ai vào được Wi‑Fi đó cũng không đọc hay giả mạo được.

### Giới hạn hiện tại và kế hoạch
- Dùng **TCP**: đủ cho LAN/hotspot và IPv6 khi host nhận được kết nối vào.
- Chưa có: BLE GATT, QUIC/UDP hole punching hai chiều. NFC đã cân nhắc và bỏ: Android không còn NFC giữa hai máy, iPhone không đóng vai thẻ được.

## 5. Lưu trữ trên máy
- `vault.bin` = `"NXV2" | nonce | XChaCha20‑Poly1305(master_key, CBOR{version, identity, logs, local})`.
- Ghi bền: file tạm → `fsync` → giữ bản trước làm `vault.bak` → rename → `fsync` thư mục. Nếu `vault.bin` hỏng (ghi dở, bit rot) thì tự mở `vault.bak`.
- `version` của định dạng: bản app cũ từ chối mở vault do bản mới ghi, thay vì làm hỏng dữ liệu.
- Khoá và plaintext trong bộ nhớ được `zeroize` khi xong việc.
- **Master key**: 32 byte ngẫu nhiên, wrap bằng PIN (Argon2id 19 MiB, t=2) trong Keystore‑backed secure storage, và tuỳ chọn niêm phong thêm bằng khoá Keystore cần sinh trắc (BiometricPrompt + CryptoObject). Đổi PIN chỉ wrap lại master key.
- **Sao lưu**: `"NXB1" | salt | nonce | XChaCha20‑Poly1305(Argon2id(passphrase, 64 MiB, t=3), CBOR vault)`. Gồm cả danh tính, nên khôi phục trên máy mới là quay lại đúng member cũ. Mật khẩu ≥ 10 ký tự, không có cách khôi phục.
- Sau khi khôi phục, mọi workspace bị đánh dấu `stale`: chưa được ghi gì cho tới khi sync xong với một member. Lý do là máy cũ có thể đã ghi thêm entry sau thời điểm sao lưu; ghi ngay sẽ dùng lại số `seq` đó và entry mới bị các máy khác bỏ qua. Vẫn còn hở nếu member được sync cũng chưa có các entry đó.
- State (members, secrets) được tính lại từ log mỗi lần load. Log nhỏ nên việc này rẻ.
- Plaintext của secret chỉ được giải mã **khi người dùng giữ nút xem** và không bao giờ được cache.

Xem thêm: [threat-model.md](threat-model.md), [ui.md](ui.md).

## Cổng sync và địa chỉ trong mã
- App hỏi Android interface nào thuộc mạng Wi‑Fi, Ethernet, VPN hoặc mạng có Internet (`ConnectivityManager`). Mạng IMS/VoLTE và ePDG bị bỏ qua.
- Core chỉ bind cổng trên đúng các địa chỉ đó (cùng một cổng, kèm loopback), không bind `[::]`. Mã sync và mã mời chỉ chứa các địa chỉ đã bind được.

## Nhận mã qua share ảnh
`ShareReceiverActivity` nhận ảnh QR hoặc chữ `nexvault://` từ app khác:
- Chép ảnh vào `cache/shared`, rồi chuyển cho task NexVault đang chạy.
- MainActivity chỉ chấp nhận đường dẫn nằm trong thư mục đó. App khác không thể khiến NexVault đọc hoặc xoá file khác.
