// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class SVi extends S {
  SVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'NexVault';

  @override
  String get langSystem => 'Theo ngôn ngữ của máy';

  @override
  String get langTitle => 'Ngôn ngữ';

  @override
  String get authNeedScreenLock =>
      'Cần xác thực bằng khoá màn hình để bảo vệ dữ liệu. Thử lại.';

  @override
  String get authPinMismatchRetry => 'Hai lần nhập không khớp, nhập lại';

  @override
  String get authWelcomeTitle => 'Chào mừng tới NexVault';

  @override
  String get authWelcomeBody =>
      'Secret chỉ nằm trên máy của các thành viên, không qua server nào. Tên của bạn hiện trên máy những người cùng workspace.';

  @override
  String get authYourName => 'Tên của bạn';

  @override
  String get authContinue => 'Tiếp tục';

  @override
  String get authRestoreBackup => 'Khôi phục từ bản sao lưu';

  @override
  String get authNoLockTitle => 'Máy chưa có khoá màn hình';

  @override
  String authNoLockBody(String bio) {
    return 'NexVault bảo vệ dữ liệu bằng khoá màn hình của máy ($bio hoặc mã mở máy). Hãy đặt khoá màn hình trong Cài đặt của máy rồi bấm Thử lại.\n\nNếu không muốn, bạn có thể dùng PIN 6 số riêng của app, nhưng PIN này kém an toàn hơn khoá màn hình.';
  }

  @override
  String get authRetry => 'Thử lại';

  @override
  String get authUseAppPin => 'Dùng PIN của app';

  @override
  String get authBioTitle => 'Mở khoá bằng vân tay?';

  @override
  String get authBioBody =>
      'Khoá dữ liệu được niêm phong trong chip bảo mật của máy và chỉ mở khi vân tay khớp. PIN vẫn dùng được khi cần.';

  @override
  String get authBioEnable => 'Bật vân tay';

  @override
  String get authLater => 'Để sau';

  @override
  String get authCreatePin => 'Tạo PIN 6 số';

  @override
  String get authRepeatPin => 'Nhập lại PIN';

  @override
  String get authPinHint =>
      'PIN mở khoá app trên máy này. NexVault không thể khôi phục PIN.';

  @override
  String get authRecoveryTitle => 'Mở bằng mã khôi phục';

  @override
  String get authCancel => 'Huỷ';

  @override
  String get authUnlock => 'Mở khoá';

  @override
  String authResealFailed(String error) {
    return 'Chưa bảo vệ lại bằng khoá màn hình: $error';
  }

  @override
  String authWrongRecovery(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Sai mã khôi phục, còn $left lần thử',
    );
    return '$_temp0';
  }

  @override
  String authWrongPin(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Sai PIN, còn $left lần thử',
    );
    return '$_temp0';
  }

  @override
  String get authNoLockSetPin =>
      'Máy không còn khoá màn hình. Đặt PIN 6 số cho app';

  @override
  String get authPinNowUsed =>
      'Từ giờ mở NexVault bằng PIN này. Đặt lại khoá màn hình để dùng vân tay / mã máy.';

  @override
  String get authPinsDontMatch => 'Hai lần nhập không khớp';

  @override
  String get authLocked => 'NexVault đã khoá';

  @override
  String authDeviceUnlockHint(String bio) {
    return 'Mở bằng $bio hoặc mã mở máy';
  }

  @override
  String get authSealLostHint =>
      'Máy vừa đặt lại kho khoá nên khoá màn hình không mở được NexVault nữa. Dữ liệu vẫn còn nguyên: mở bằng mã khôi phục.';

  @override
  String authRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Thử lại sau $seconds giây',
    );
    return '$_temp0';
  }

  @override
  String get authUseRecovery => 'Dùng mã khôi phục';

  @override
  String get authEnterAppPin => 'Nhập PIN của app để mở khoá';

  @override
  String get authUseFingerprint => 'Dùng vân tay';

  @override
  String get authForgotPinTitle => 'Quên PIN';

  @override
  String get authForgotPinBody =>
      'PIN không thể khôi phục vì dữ liệu chỉ nằm trên máy này. Bạn có thể xoá dữ liệu rồi khôi phục từ bản sao lưu, hoặc nhờ một thành viên khác mời lại bạn. Secret trên máy này sẽ mất nếu không có bản sao lưu.';

  @override
  String get authGotIt => 'Đã hiểu';

  @override
  String get authForgotPinLink => 'Quên PIN?';

  @override
  String get ceremonyProposalSent =>
      'Đã gửi đề xuất thêm thành viên. Các thành viên khác cần đồng ý qua sync.';

  @override
  String ceremonyCreateTitle(String name) {
    return 'Tạo $name';
  }

  @override
  String ceremonyInviteTitle(String name) {
    return 'Mời vào $name';
  }

  @override
  String get ceremonyStep1Create =>
      'Bước 1: từng thành viên mở NexVault, bấm \"Quét mã\" và quét mã này. Hai máy cần cùng Wi-Fi hoặc bắt hotspot của bạn.';

  @override
  String get ceremonyStep1Invite =>
      'Bước 1: người mới mở NexVault, bấm \"Quét mã\" và quét mã này khi đang ở cạnh bạn. Sau đó mọi thành viên khác cần đồng ý.';

  @override
  String get ceremonyStep2Host => 'Bước 2: đọc to mã cho từng người';

  @override
  String get ceremonyFinishing => 'Đang hoàn tất…';

  @override
  String get ceremonyWaitVerify => 'Chờ xác minh';

  @override
  String ceremonyFinishWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hoàn tất với $count người',
    );
    return '$_temp0';
  }

  @override
  String ceremonyProposeAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đề xuất thêm $count người',
    );
    return '$_temp0';
  }

  @override
  String get ceremonyWrongCode => 'Chọn sai mã';

  @override
  String get ceremonyWillBeAdded => 'Sẽ được thêm';

  @override
  String get ceremonyPickedRight => 'Đã chọn đúng mã';

  @override
  String get ceremonyWaitingPick => 'Đang chờ chọn mã';

  @override
  String ceremonyReadAloud(String name) {
    return 'Đọc to cho $name. Con dấu trên hai máy phải giống nhau.';
  }

  @override
  String get ceremonyMismatchHost =>
      'Mã không khớp: có thể ai đó đang chen vào giữa. Không thêm người này; bảo họ quét lại.';

  @override
  String ceremonyIsThisPerson(String name) {
    return 'Người đang cầm máy có đúng là $name không?';
  }

  @override
  String get ceremonyNotThem => 'Không phải';

  @override
  String get ceremonyRightPerson => 'Đúng người';

  @override
  String get ceremonyJoinFailed => 'Không tham gia được';

  @override
  String ceremonyConnecting(String name) {
    return 'Đang kết nối tới $name…';
  }

  @override
  String ceremonySameWifi(String name) {
    return 'Hai máy cần cùng Wi-Fi hoặc bạn bắt hotspot của $name.';
  }

  @override
  String ceremonyVerifyStep(String name) {
    return 'Bước 2/3: xác minh $name';
  }

  @override
  String ceremonyPickCode(String name) {
    return 'Chọn 6 số mà $name đọc to';
  }

  @override
  String get ceremonySealMatch => 'Con dấu trên hai máy cũng phải giống nhau.';

  @override
  String get ceremonyNoneMatch => 'Không có dãy nào khớp, dừng lại';

  @override
  String get ceremonyVerified => 'Đã xác minh';

  @override
  String ceremonyWaitFinish(String name) {
    return 'Chờ $name xác nhận và hoàn tất workspace. Giữ app mở.';
  }

  @override
  String get ceremonyStopped => 'Đã dừng';

  @override
  String ceremonyAbortedBody(String name) {
    return 'Mã không khớp, nghĩa là có thể ai đó đang chen vào giữa hai máy. Bạn chưa được thêm. Hãy nhờ $name tạo mã mời mới và quét lại.';
  }

  @override
  String ceremonyJoined(String name) {
    return 'Đã vào $name';
  }

  @override
  String get ceremonyStep3Done =>
      'Bước 3/3 xong. Bạn và các thành viên đã cùng ký điều lệ workspace.';

  @override
  String get ceremonyOpenWorkspace => 'Mở workspace';

  @override
  String get ceremonyJoinTitle => 'Tham gia workspace';

  @override
  String get errWrongPin => 'Sai PIN';

  @override
  String get errSyncExpired =>
      'Mã sync đã hết hạn. Nhờ người mở sync tạo mã mới.';

  @override
  String get errInviteExpired => 'Mã mời đã hết hạn.';

  @override
  String get errCodeDamaged => 'Mã bị hỏng hoặc thiếu. Hãy quét lại.';

  @override
  String get errNotYourWorkspace =>
      'Mã này không thuộc workspace nào trên máy bạn.';

  @override
  String get errNotNexVaultCode => 'Đây không phải mã NexVault.';

  @override
  String get errHostUnreachable =>
      'Không kết nối được tới máy kia. Hãy dùng cùng Wi-Fi, hoặc để máy mở sync chuyển sang 4G/5G (đa số nhà mạng có IPv6).';

  @override
  String get errRefused =>
      'Máy kia từ chối kết nối. Thiết bị này có thể không còn là thành viên.';

  @override
  String get errNeedMember => 'Cần ít nhất một thành viên khác đã xác minh.';

  @override
  String get errNotConfirmed => 'Người này chưa chọn đúng mã.';

  @override
  String get errVaultUnreadable => 'Không mở được dữ liệu trên máy.';

  @override
  String get errRestoredSyncFirst =>
      'Máy vừa khôi phục từ bản sao lưu. Hãy sync với một thành viên trước khi sửa.';

  @override
  String get errRemoved =>
      'Bạn đã bị xoá khỏi workspace này nên không sync được nữa.';

  @override
  String get errFolderNotEmpty =>
      'Thư mục chưa trống. Chuyển hoặc xoá các secret và thư mục con trước.';

  @override
  String get errFolderIntoItself => 'Không thể chuyển thư mục vào chính nó.';

  @override
  String get errFolderGone => 'Thư mục không còn tồn tại.';

  @override
  String get errAlreadyProposed => 'Đề xuất này đã có rồi.';

  @override
  String get errAlreadyMember => 'Người này đã là thành viên.';

  @override
  String get errOnlyMemberInvites =>
      'Chỉ thành viên đã có khoá mới mời được người mới.';

  @override
  String get errWrongPassphrase => 'Sai mật khẩu sao lưu.';

  @override
  String get errNotBackup => 'File này không phải bản sao lưu NexVault.';

  @override
  String get errHasIdentity =>
      'Máy này đã có danh tính. Xoá dữ liệu trước khi khôi phục.';

  @override
  String get errPassphraseShort => 'Mật khẩu sao lưu cần ít nhất 10 ký tự.';

  @override
  String get errSecretTooBig => 'Secret lớn hơn 10 MB.';

  @override
  String get errSessionFull => 'Phiên sync đã đủ người.';

  @override
  String get errNoKeyForItem =>
      'Máy này chưa có khoá để mở mục này. Hãy sync với thành viên khác.';

  @override
  String get errNewerVersion =>
      'Dữ liệu được tạo bởi bản NexVault mới hơn. Hãy cập nhật app.';

  @override
  String get timeNeverSynced => 'chưa sync';

  @override
  String get timeJustNow => 'vừa xong';

  @override
  String timeMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n phút trước',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n giờ trước',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'hôm qua';

  @override
  String timeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ngày trước',
    );
    return '$_temp0';
  }

  @override
  String timeToday(String time) {
    return 'hôm nay $time';
  }

  @override
  String get keysEnableFingerprint => 'Bật mở khoá bằng vân tay';

  @override
  String get keysProtectWithLock => 'Bảo vệ NexVault bằng khoá màn hình';

  @override
  String get keysReprotectWithLock => 'Bảo vệ lại NexVault bằng khoá màn hình';

  @override
  String get keysUnlockTitle => 'Mở khoá NexVault';

  @override
  String get keysDevInvalidated =>
      'Khoá màn hình của máy đã bị tắt hoặc thay đổi. Hãy mở bằng mã khôi phục.';

  @override
  String keysBioInvalidated(String bio) {
    return 'Dữ liệu sinh trắc ($bio) trên máy đã thay đổi, hãy mở bằng PIN rồi bật lại';
  }

  @override
  String get keysUnlockFirst => 'Mở khoá app trước khi bật vân tay';

  @override
  String get keysNotEnrolled => 'Chưa bật sinh trắc học';

  @override
  String get keysSealFailed => 'Không lưu được khoá. Máy cần đặt mật mã.';

  @override
  String get keysNoCipher => 'Không nhận được khoá';

  @override
  String get keysUsePin => 'Dùng PIN';

  @override
  String get commonCancel => 'Huỷ';

  @override
  String pinFilled(int filled, int length) {
    return 'Đã nhập $filled trên $length số';
  }

  @override
  String get commonDelete => 'Xoá';

  @override
  String get pinEnterToContinue => 'Nhập PIN để tiếp tục';

  @override
  String pinWrongLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Sai PIN, còn $left lần thử',
    );
    return '$_temp0';
  }

  @override
  String get copyDisabled => 'Sao chép đang tắt trong Cài đặt.';

  @override
  String get copyKeyboardTitle => 'Bàn phím có thể lưu lại';

  @override
  String get copyKeyboardBody =>
      'NexVault xoá bộ nhớ tạm sau 30 giây, nhưng một số bàn phím (Samsung Keyboard, Gboard…) giữ lịch sử sao chép riêng mà app không xoá được. Sau khi dán, hãy xoá mục đó trong lịch sử bàn phím, hoặc tắt lịch sử bộ nhớ tạm của bàn phím.\n\nCó thể tắt hẳn sao chép trong Cài đặt.';

  @override
  String get copyUnderstood => 'Đã hiểu, sao chép';

  @override
  String get qrLabel => 'Mã QR';

  @override
  String get recoveryTitle => 'Mã khôi phục';

  @override
  String get recoveryIntro =>
      'Dùng khi khoá màn hình của máy bị tắt hoặc đặt lại. Mã chỉ hiện một lần.';

  @override
  String get recoveryPrint => 'In ra giấy';

  @override
  String get recoveryPrintHint => 'Chỉ dùng máy in ở nhà';

  @override
  String get recoverySaved => 'Đã chép hoặc in mã';

  @override
  String recoveryPrintMeta(String device, String date) {
    return 'Máy: $device &middot; Ngày tạo: $date';
  }

  @override
  String get recoveryPrintUse =>
      'Dùng mã này để mở NexVault trên đúng máy này khi khoá màn hình của máy bị tắt hoặc đặt lại.';

  @override
  String get recoveryPrintKeep =>
      'Cất tờ giấy ở nơi an toàn, tách khỏi máy. Ai có cả mã này và máy của bạn đều mở được NexVault. Khi bạn tạo mã khôi phục mới, mã này hết hiệu lực: hãy huỷ tờ giấy này.';

  @override
  String get sealLabel => 'Con dấu workspace';

  @override
  String get commonDone => 'Xong';

  @override
  String get homeCreateTitle => 'Tạo workspace';

  @override
  String get homeCreateBody =>
      'Mọi thành viên cần có mặt, cùng mạng Wi-Fi hoặc bắt hotspot của bạn, để quét mã của bạn.';

  @override
  String get homeWorkspaceName => 'Tên workspace';

  @override
  String get homeCancel => 'Huỷ';

  @override
  String get homeCreateInvite => 'Tạo mã mời';

  @override
  String get homeNotSynced => 'Chưa sync';

  @override
  String homeSyncedWith(String name, String ago) {
    return 'Sync với $name $ago';
  }

  @override
  String get homeTitle => 'Workspace';

  @override
  String get homeSettings => 'Cài đặt';

  @override
  String get homeLockApp => 'Khoá app';

  @override
  String get homeEmptyTitle => 'Chưa có workspace nào';

  @override
  String get homeEmptyBody =>
      'Tạo workspace khi các thành viên ở cạnh nhau, hoặc quét mã mời của người tạo.';

  @override
  String get homePendingApproval => 'Đang chờ các thành viên đồng ý';

  @override
  String get homeNeedsAction => 'Có đề xuất cần bạn xem';

  @override
  String homeCounts(int members, int secrets) {
    String _temp0 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members thành viên',
    );
    String _temp1 = intl.Intl.pluralLogic(
      secrets,
      locale: localeName,
      other: '$secrets secret',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String homeYouAre(String name, String device) {
    return 'Bạn là $name, thiết bị $device';
  }

  @override
  String get homeCreateWorkspace => 'Tạo workspace';

  @override
  String get homeScanCode => 'Quét mã';

  @override
  String get scanNoCodeInImage => 'Không tìm thấy mã NexVault trong ảnh.';

  @override
  String get scanNotNexVault => 'Đây không phải mã NexVault.';

  @override
  String get scanPaste => 'Dán mã';

  @override
  String get scanCancel => 'Huỷ';

  @override
  String get scanOpenCode => 'Mở mã';

  @override
  String get scanTitle => 'Quét mã';

  @override
  String get scanHint =>
      'Quét mã mời workspace hoặc mã sync trên máy của thành viên khác.';

  @override
  String get scanCameraDenied =>
      'NexVault chưa được dùng camera. Cho phép để quét mã, hoặc dùng \"Chọn ảnh mã\" / \"Dán mã\".';

  @override
  String get scanCameraFailed =>
      'Không mở được camera. Dùng \"Chọn ảnh mã\" hoặc \"Dán mã\".';

  @override
  String get scanAllowCamera => 'Cho phép camera';

  @override
  String get scanPickImage => 'Chọn ảnh mã';

  @override
  String get secretActionCreated => 'đã tạo';

  @override
  String get secretActionEdited => 'đã sửa';

  @override
  String get secretActionViewed => 'đã xem';

  @override
  String get secretActionCopied => 'đã sao chép';

  @override
  String get secretActionExported => 'đã xuất file';

  @override
  String get secretFieldP12Password => 'Mật khẩu .p12';

  @override
  String get secretFieldExpires => 'Hết hạn';

  @override
  String get secretFieldStorePassword => 'Mật khẩu store';

  @override
  String get secretFieldKeyPassword => 'Mật khẩu key';

  @override
  String get secretFieldHost => 'Máy chủ';

  @override
  String secretFieldSecretLabel(String field) {
    return '$field (bí mật)';
  }

  @override
  String get secretFieldExpiresHint => 'Hết hạn (yyyy-mm-dd)';

  @override
  String secretAuthToView(String name) {
    return 'Xác thực để xem $name';
  }

  @override
  String get secretBinaryUseExport =>
      'Nội dung là file nhị phân, hãy dùng \"Xuất file\".';

  @override
  String get secretCopiedAutoClear =>
      'Đã sao chép. Bộ nhớ tạm tự xoá sau 30 giây.';

  @override
  String get secretExportTitle => 'Xuất file?';

  @override
  String get secretExportBody =>
      'File chứa khoá bí mật ở dạng không mã hoá. Chỉ lưu vào nơi bạn tin tưởng. Việc xuất được ghi vào lịch sử.';

  @override
  String get secretCancel => 'Huỷ';

  @override
  String get secretExport => 'Xuất file';

  @override
  String get secretMoved => 'Đã chuyển thư mục';

  @override
  String secretDeleteTitle(String name) {
    return 'Xoá $name?';
  }

  @override
  String get secretDeleteBody =>
      'Secret bị xoá trên mọi máy sau lần sync tới. Lịch sử vẫn giữ lại.';

  @override
  String get secretDelete => 'Xoá secret';

  @override
  String get secretMore => 'Thêm';

  @override
  String get secretCopyContent => 'Sao chép nội dung';

  @override
  String get secretAutoClear30 => 'Tự xoá sau 30 giây';

  @override
  String secretCopyField(String field) {
    return 'Sao chép $field';
  }

  @override
  String get secretEdit => 'Sửa';

  @override
  String get secretMoveFolder => 'Chuyển thư mục';

  @override
  String secretSubtitle(String kind, String version) {
    return '$kind, phiên bản $version';
  }

  @override
  String secretCopiedField(String field) {
    return 'Đã sao chép $field';
  }

  @override
  String secretFileSize(String name, String size) {
    return '$name, $size byte';
  }

  @override
  String get secretContentShown => 'Nội dung secret đang hiện';

  @override
  String get secretHoldToViewContent => 'Nhấn giữ để xem nội dung secret';

  @override
  String secretHideIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Ẩn sau $seconds giây',
    );
    return '$_temp0';
  }

  @override
  String get secretShow10s => 'Hiện trong 10 giây';

  @override
  String get secretHistory => 'Lịch sử';

  @override
  String get secretConflictBody =>
      'Hai người sửa secret này cùng lúc. Cả hai phiên bản được giữ lại, hãy chọn bản đúng.';

  @override
  String get secretView => 'Xem';

  @override
  String get secretKeepThis => 'Giữ bản này';

  @override
  String secretAuthToViewVersion(String name) {
    return 'Xác thực để xem phiên bản của $name';
  }

  @override
  String secretVersionOf(String name) {
    return 'Bản của $name';
  }

  @override
  String secretBinaryFile(String name, String size) {
    return 'File nhị phân $name, $size byte';
  }

  @override
  String get secretClose => 'Đóng';

  @override
  String secretKeptVersion(String name) {
    return 'Đã giữ bản của $name';
  }

  @override
  String get secretHoldToView => 'Nhấn giữ để xem';

  @override
  String secretHoldToViewWhat(String what) {
    return 'Nhấn giữ để xem $what';
  }

  @override
  String get secretAuthedHint =>
      'Đã xác thực trong 60 giây. Nội dung ẩn lại khi bạn thả tay.';

  @override
  String get secretNeedAuthHint =>
      'Cần vân tay hoặc PIN. Nội dung ẩn lại khi bạn thả tay.';

  @override
  String secretCopiedFieldAutoClear(String field) {
    return 'Đã sao chép $field. Bộ nhớ tạm tự xoá sau 30 giây.';
  }

  @override
  String secretBinaryUseMenu(String name) {
    return 'File nhị phân $name. Dùng \"Xuất file\" trong menu.';
  }

  @override
  String get secretWhatKey => 'private key';

  @override
  String get secretWhatP12 => 'cert và mật khẩu';

  @override
  String get secretWhatJks => 'keystore và mật khẩu';

  @override
  String get secretWhatEnv => 'biến môi trường';

  @override
  String get secretWhatContent => 'nội dung';

  @override
  String get secretKindP12 => 'Chứng chỉ .p12';

  @override
  String get secretKindEnv => 'File .env';

  @override
  String get secretKindText => 'Ghi chú bảo mật';

  @override
  String get secretNameRequired => 'Đặt tên cho secret';

  @override
  String get secretFileOrPaste => 'Chọn file hoặc dán nội dung';

  @override
  String get secretAddTitle => 'Thêm secret';

  @override
  String get secretEditTitle => 'Sửa secret';

  @override
  String get secretKind => 'Loại';

  @override
  String get secretNameHint => 'Tên, ví dụ Key máy chủ production';

  @override
  String get secretNoFolder => 'Không thuộc thư mục nào';

  @override
  String get secretChange => 'Đổi';

  @override
  String get secretChooseFile => 'Chọn file';

  @override
  String secretChooseFileExt(String ext) {
    return 'Chọn file .$ext';
  }

  @override
  String get secretChangeFile => 'Đổi file';

  @override
  String get secretOrPaste => 'Hoặc dán nội dung';

  @override
  String get secretTextHint =>
      'Điều cần giữ kín: mã dự phòng, số tài khoản, ghi chú…';

  @override
  String get secretEncryptedNote =>
      'Secret được mã hoá trên máy này. Các thành viên khác nhận được ở lần sync tới.';

  @override
  String get secretSaving => 'Đang lưu…';

  @override
  String get secretSave => 'Lưu secret';

  @override
  String get settingsCurrentPin => 'Nhập PIN hiện tại';

  @override
  String get settingsWrongPin => 'Sai PIN';

  @override
  String get settingsNewPin => 'PIN mới';

  @override
  String get settingsRepeatNewPin => 'Nhập lại PIN mới';

  @override
  String get settingsMismatch => 'Hai lần nhập không khớp';

  @override
  String get settingsPinChanged => 'Đã đổi PIN';

  @override
  String get settingsPinToDevice => 'Nhập PIN để chuyển sang khoá màn hình';

  @override
  String get settingsSwitchedToDevice =>
      'Đã chuyển sang mở bằng khoá màn hình. PIN cũ không còn dùng.';

  @override
  String get settingsAuthNewRecovery => 'Xác thực để tạo mã khôi phục mới';

  @override
  String get settingsLockNow => 'Ngay khi rời app';

  @override
  String get settingsLock1 => 'Sau 1 phút';

  @override
  String get settingsLock5 => 'Sau 5 phút';

  @override
  String get settingsAutoLock => 'Tự khoá';

  @override
  String get settingsAuthCopy => 'Xác thực để bật sao chép';

  @override
  String get settingsPinForBio => 'Nhập PIN để bật vân tay';

  @override
  String get settingsSetBackupPass => 'Đặt mật khẩu sao lưu';

  @override
  String get settingsBackupPass => 'Mật khẩu sao lưu';

  @override
  String get settingsBackupPassHint =>
      'Ít nhất 10 ký tự. Không có cách nào khôi phục nếu quên mật khẩu này. Nên dùng một câu dài.';

  @override
  String get settingsPassword => 'Mật khẩu';

  @override
  String get settingsRepeat => 'Nhập lại';

  @override
  String get settingsCancel => 'Huỷ';

  @override
  String get settingsMinChars => 'Cần ít nhất 10 ký tự';

  @override
  String get settingsContinue => 'Tiếp tục';

  @override
  String get settingsAuthBackup => 'Xác thực để sao lưu';

  @override
  String get settingsBackupSaved => 'Đã lưu bản sao lưu';

  @override
  String get settingsWipeTitle => 'Xoá mọi dữ liệu trên máy này?';

  @override
  String get settingsWipeBody =>
      'Danh tính, workspace và mọi secret trên máy này bị xoá vĩnh viễn. Dữ liệu trên máy các thành viên khác vẫn còn. Muốn quay lại workspace, bạn cần khôi phục từ bản sao lưu hoặc được mời lại trực tiếp.';

  @override
  String get settingsWipeConfirm => 'Xoá hết';

  @override
  String get settingsAuthWipe => 'Xác thực để xoá dữ liệu';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsDeviceId => 'Mã thiết bị ';

  @override
  String get settingsUnlockSection => 'Mở khoá';

  @override
  String get settingsScreenLock => 'Khoá màn hình của máy';

  @override
  String settingsScreenLockSub(String bio) {
    return 'Mở bằng $bio hoặc mã mở máy';
  }

  @override
  String get settingsNewRecovery => 'Tạo mã khôi phục mới';

  @override
  String get settingsNewRecoverySub => 'Mã cũ sẽ không dùng được nữa';

  @override
  String get settingsChangePin => 'Đổi PIN';

  @override
  String get settingsToDevice => 'Chuyển sang mở bằng khoá màn hình';

  @override
  String settingsToDeviceSub(String bio) {
    return 'Dùng $bio hoặc mã mở máy thay cho PIN của app';
  }

  @override
  String get settingsBio => 'Mở khoá bằng vân tay';

  @override
  String get settingsBioSub =>
      'Khoá dữ liệu được niêm phong trong chip bảo mật của máy';

  @override
  String get settingsCopy => 'Cho phép sao chép secret';

  @override
  String get settingsCopySub =>
      'Tự xoá sau 30 giây, nhưng lịch sử của bàn phím có thể vẫn giữ lại';

  @override
  String get settingsAutoLockAfter1 => 'Sau 1 phút ở nền';

  @override
  String settingsAutoLockAfterMin(int minutes) {
    return 'Sau $minutes phút ở nền';
  }

  @override
  String settingsAutoLockSub(String when) {
    return '$when. Mỗi lần xem secret cần xác thực lại.';
  }

  @override
  String get settingsBackupSection => 'Sao lưu';

  @override
  String get settingsExport => 'Xuất bản sao lưu mã hoá';

  @override
  String get settingsExportSub =>
      'Gồm danh tính và mọi workspace, khoá bằng mật khẩu riêng. Dùng khi mất hoặc đổi máy.';

  @override
  String get settingsDangerSection => 'Nguy hiểm';

  @override
  String get settingsWipe => 'Xoá mọi dữ liệu trên máy này';

  @override
  String settingsVersion(String core, String vault) {
    return 'NexVault core $core, định dạng vault v$vault';
  }

  @override
  String get syncPeerDone => 'Đã xong';

  @override
  String get syncPeerSyncing => 'Đang đồng bộ';

  @override
  String get syncPeerLeft => 'Đã rời';

  @override
  String get syncPeerNotScanned => 'Chưa quét';

  @override
  String syncPeerRemovedName(String name) {
    return '$name (đã bị xoá)';
  }

  @override
  String get syncPeerRejected => 'Đã từ chối';

  @override
  String syncPeerNewMember(String name) {
    return '$name (thành viên mới)';
  }

  @override
  String syncStrangers(int count) {
    return 'Thiết bị lạ ($count)';
  }

  @override
  String syncHostTitle(String name) {
    return 'Sync $name';
  }

  @override
  String get syncHostIntro =>
      'Thành viên mở NexVault và quét mã này. Người ở xa: gửi ảnh mã qua chat (chỉ thiết bị trong workspace giải mã được) và để máy này dùng 4G/5G.';

  @override
  String get syncExpiresIn => 'Mã hết hạn sau ';

  @override
  String get syncExpired => 'Mã đã hết hạn, cổng kết nối đã đóng';

  @override
  String get syncConnectVia =>
      'Kết nối thẳng qua Wi-Fi hoặc 4G/5G, không qua máy chủ trung gian';

  @override
  String syncShareText(String name, String left) {
    return 'Mã sync NexVault ($name), hết hạn sau $left';
  }

  @override
  String get syncShareButton => 'Gửi ảnh mã cho người ở xa';

  @override
  String get syncNewCode => 'Tạo mã mới';

  @override
  String get syncEnd => 'Kết thúc';

  @override
  String syncJoinConnecting(String host) {
    return 'Đang kết nối tới $host…';
  }

  @override
  String get syncJoinConnectingHint =>
      'Thử cùng Wi-Fi trước, rồi kết nối thẳng qua 4G/5G.';

  @override
  String syncJoinSyncing(String host) {
    return 'Đang đồng bộ với $host';
  }

  @override
  String syncJoinCounts(String received, String sent) {
    return 'Đã nhận $received, đã gửi $sent thay đổi.';
  }

  @override
  String syncJoinDone(String host) {
    return 'Đã đồng bộ với $host';
  }

  @override
  String syncJoinDoneBody(String received, String sent) {
    return 'Đã nhận $received, đã gửi $sent thay đổi. Giữ màn hình này mở để nhận thêm thay đổi của người khác trong phiên.';
  }

  @override
  String get syncJoinClosed => 'Phiên sync đã kết thúc';

  @override
  String get syncJoinFailed => 'Không sync được';

  @override
  String get syncDone => 'Xong';

  @override
  String get syncClose => 'Đóng';

  @override
  String get workspaceSave => 'Lưu';

  @override
  String get workspaceFolderName => 'Tên thư mục';

  @override
  String get workspaceCancel => 'Huỷ';

  @override
  String get workspaceNewFolder => 'Thư mục mới';

  @override
  String get workspaceCreate => 'Tạo';

  @override
  String get workspaceRename => 'Đổi tên';

  @override
  String get workspaceMoveFolder => 'Chuyển tới thư mục khác';

  @override
  String get workspaceDeleteFolder => 'Xoá thư mục';

  @override
  String get workspaceDeleteFolderHint => 'Chỉ xoá được thư mục trống';

  @override
  String get workspaceRenameFolder => 'Đổi tên thư mục';

  @override
  String get workspaceMembers => 'Thành viên';

  @override
  String get workspaceMembersRule =>
      'Thêm người cần mọi thành viên đồng ý. Xoá người cần 2/3 số người ở lại đồng ý.';

  @override
  String workspaceMemberYou(String name) {
    return '$name (bạn)';
  }

  @override
  String get workspaceThisDevice => 'Thiết bị này';

  @override
  String workspaceMemberSynced(String when) {
    return 'Sync $when';
  }

  @override
  String get workspaceProposeRemoval => 'Đề xuất xoá';

  @override
  String get workspaceInviteMember => 'Mời thành viên mới';

  @override
  String workspaceProposeRemoveTitle(String name) {
    return 'Đề xuất xoá $name?';
  }

  @override
  String get workspaceProposeRemoveBody =>
      'Đề xuất có hiệu lực khi đủ người đồng ý qua các lần sync. Sau đó workspace dùng khoá mới. Người bị xoá đã thấy các secret hiện tại: hãy đổi (rotate) những key quan trọng.';

  @override
  String get workspaceExpired => 'Đã hết hạn';

  @override
  String workspaceExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Hết hạn sau $days ngày',
    );
    return '$_temp0';
  }

  @override
  String get workspaceConflict => 'Có 2 phiên bản, cần chọn';

  @override
  String workspaceVersionDate(String version, String date) {
    return 'Phiên bản $version, $date';
  }

  @override
  String get workspaceJustCreated => 'Mới tạo';

  @override
  String workspaceUpdated(String when) {
    return 'Cập nhật $when';
  }

  @override
  String workspaceMemberYouShort(String name) {
    return '$name\n(bạn)';
  }

  @override
  String get workspacePendingBanner =>
      'Đang chờ các thành viên đồng ý thêm bạn. Mở sync với họ để nhận phiếu duyệt và khoá workspace.';

  @override
  String get workspaceStaleBanner =>
      'Máy vừa khôi phục từ bản sao lưu. Hãy mở sync với một thành viên để lấy lại phần thay đổi mới hơn bản sao lưu, sau đó mới sửa được.';

  @override
  String get workspaceRemovedBanner =>
      'Bạn đã bị xoá khỏi workspace này. Dữ liệu mới sẽ không đến máy này nữa.';

  @override
  String workspaceSearchHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tìm trong $count secret',
    );
    return '$_temp0';
  }

  @override
  String get workspaceAll => 'Tất cả';

  @override
  String workspaceSecretCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secret',
    );
    return '$_temp0';
  }

  @override
  String get workspaceFolderOptions => 'Tuỳ chọn thư mục';

  @override
  String get workspaceEmpty =>
      'Chưa có secret nào. Thêm tài khoản, API key, mật khẩu Wi-Fi, ghi chú hay file như .env, SSH key, nhóm vào thư mục, rồi mở sync để chia sẻ.';

  @override
  String get workspaceFolderEmpty => 'Thư mục trống.';

  @override
  String get workspaceAddSecret => 'Thêm secret';

  @override
  String get workspaceOpenSync => 'Mở sync';

  @override
  String get workspaceNeverSynced => 'chưa sync';

  @override
  String get workspaceJustNow => 'vừa xong';

  @override
  String workspaceMinutesShort(int n) {
    return '$n phút';
  }

  @override
  String workspaceHoursShort(int n) {
    return '$n giờ';
  }

  @override
  String workspaceDaysShort(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ngày',
    );
    return '$_temp0';
  }

  @override
  String workspaceProposalAdd(
    String proposer,
    String name,
    String approvals,
    String needed,
  ) {
    return '$proposer đề xuất thêm $name: $approvals/$needed người đồng ý';
  }

  @override
  String workspaceProposalRemove(String name, String approvals, String needed) {
    return 'Đề xuất xoá $name: $approvals/$needed người đồng ý';
  }

  @override
  String workspaceProposalAwaitingKeys(String text) {
    return '$text. Đang chờ trao khoá ở lần sync tới.';
  }

  @override
  String workspaceApproveAddTitle(String name) {
    return 'Đồng ý thêm $name?';
  }

  @override
  String workspaceApproveRemoveTitle(String name) {
    return 'Đồng ý xoá $name?';
  }

  @override
  String workspaceApproveAddBody(String proposer, String name) {
    return '$proposer đã gặp trực tiếp và xác minh $name. Khi mọi người đồng ý, $name đọc được toàn bộ secret của workspace.';
  }

  @override
  String workspaceApproveRemoveBody(String name) {
    return 'Khi đủ người đồng ý, $name không nhận được dữ liệu mới nữa và workspace chuyển sang khoá mới.';
  }

  @override
  String get workspaceApprove => 'Đồng ý';

  @override
  String get workspacePickFolder => 'Chọn thư mục';

  @override
  String get workspaceNoFolder => 'Không thuộc thư mục nào';

  @override
  String get syncPathNoServer => 'Không qua máy chủ trung gian';

  @override
  String get syncPathNearby => 'Cùng mạng Wi-Fi';

  @override
  String get syncPathInternet => 'Kết nối thẳng qua 4G/5G (IPv6)';

  @override
  String get syncPathEither => 'Cùng Wi-Fi, hoặc thẳng qua 4G/5G';

  @override
  String get syncPathThisDevice => 'Máy này';

  @override
  String get syncPathOther => 'Máy kia';

  @override
  String get syncHowTitle => 'Sync hoạt động thế nào';

  @override
  String get syncHowBody =>
      'Hai máy kết nối thẳng với nhau: qua cùng Wi-Fi khi ở gần, hoặc qua 4G/5G bằng IPv6 khi ở xa.\n\nKhông có máy chủ nào của NexVault hay bên thứ ba, và dữ liệu không được lưu ở đâu khác. Mọi thứ được mã hoá đầu-cuối, nên router Wi-Fi hay nhà mạng chỉ chuyển những gói tin họ không đọc được.\n\nMã chỉ dùng được trong 5 phút và chỉ với thành viên của workspace này.';

  @override
  String get syncHowButton => 'Cách hoạt động';

  @override
  String get bioAndroid => 'vân tay';

  @override
  String get bioIos => 'Face ID / Touch ID';

  @override
  String get ceremonyWaitingScan => 'Đang chờ thành viên quét mã…';

  @override
  String get secretKindLogin => 'Tài khoản';

  @override
  String get secretKindApi => 'API key';

  @override
  String get secretKindWifi => 'Wi-Fi';

  @override
  String get secretKindFiles => 'File & khoá';

  @override
  String get secretKindFile => 'Bất kỳ file';

  @override
  String get secretKindLoginLong => 'Tài khoản đăng nhập';

  @override
  String get secretKindApiLong => 'API key / token';

  @override
  String get secretKindWifiLong => 'Mật khẩu Wi-Fi';

  @override
  String get secretKindFileLong => 'File';

  @override
  String get secretFileType =>
      'Loại file: tự nhận theo file bạn chọn, hoặc chọn tay';

  @override
  String get secretFieldWebsite => 'Trang web / ứng dụng';

  @override
  String get secretFieldUsername => 'Tên đăng nhập / email';

  @override
  String get secretFieldWifiName => 'Tên mạng Wi-Fi';

  @override
  String get secretPassword => 'Mật khẩu';

  @override
  String get secretApiValue => 'Key hoặc token';

  @override
  String get secretGenerate => 'Tạo mật khẩu mạnh';

  @override
  String get secretShowValue => 'Hiện';

  @override
  String get secretHideValue => 'Ẩn';

  @override
  String get secretPasswordRequired => 'Nhập mật khẩu';

  @override
  String get secretKeyRequired => 'Nhập key hoặc token';

  @override
  String get secretNameHintLogin => 'Tên, ví dụ Gmail công ty';

  @override
  String get secretNameHintApi => 'Tên, ví dụ Stripe production';

  @override
  String get secretNameHintWifi => 'Tên, ví dụ Wi-Fi văn phòng';

  @override
  String get secretNameHintNote => 'Tên, ví dụ Mã dự phòng 2FA';

  @override
  String get secretWhatPassword => 'mật khẩu';

  @override
  String get secretWhatApi => 'key';

  @override
  String get secretCopyPassword => 'Sao chép mật khẩu';

  @override
  String get secretWifiQr => 'Hiện QR để vào Wi-Fi này';

  @override
  String get secretWifiQrHint =>
      'Trên máy kia, mở camera và quét để kết nối. Tự đóng sau 60 giây.';

  @override
  String get secretWifiNoName => 'Hãy thêm tên mạng Wi-Fi trước (Sửa)';

  @override
  String get hotspotOffer =>
      'Không có Wi-Fi chung? Phát Wi-Fi riêng từ máy này';

  @override
  String hotspotOnTitle(String ssid) {
    return 'Đang phát Wi-Fi riêng: $ssid';
  }

  @override
  String get hotspotOnHint =>
      'Mã QR đã kèm Wi-Fi này: máy kia quét là tự vào. Wi-Fi này không có internet và tự tắt khi bạn rời màn hình.';

  @override
  String get hotspotStop => 'Tắt';

  @override
  String get hotspotDenied =>
      'NexVault cần quyền Thiết bị ở gần để phát Wi-Fi. App không dùng vị trí của bạn.';

  @override
  String get hotspotFailed =>
      'Không phát được Wi-Fi. Hãy tắt Điểm phát sóng của máy rồi thử lại.';

  @override
  String hotspotJoining(String ssid) {
    return 'Đang vào Wi-Fi của máy kia ($ssid)…';
  }

  @override
  String get hotspotJoinFailed =>
      'Không vào được Wi-Fi của máy kia, thử qua mạng hiện tại.';

  @override
  String get hotspotVpnTitle => 'VPN đang chặn';

  @override
  String get hotspotJoinVpn =>
      'VPN trên máy này giữ mọi app đi qua VPN, nên NexVault không dùng được Wi-Fi riêng của máy kia. Tạm tắt VPN một lúc rồi quét lại, hoặc vào cùng Wi-Fi với máy kia.';

  @override
  String get hotspotPermTitle => 'Cho phép Thiết bị ở gần';

  @override
  String get hotspotPermBody =>
      'Android cần quyền Thiết bị ở gần thì app mới phát được Wi-Fi. Câu hỏi của Android có nhắc tới vị trí thiết bị, nhưng NexVault chỉ dùng quyền này để phát Wi-Fi riêng và không biết vị trí của bạn.';

  @override
  String get hotspotPermContinue => 'Tiếp tục';
}
