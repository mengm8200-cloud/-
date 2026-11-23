# iOS 证书一键生成

通过 App Store Connect API 自动完成：证书 → p12 → 设备 → App ID（含常用全权限）→ Ad Hoc 描述文件。

## 需要客户提供
- `.p8` API 密钥文件（App Store Connect → 用户和访问 → 集成 → App Store Connect API，访问权限选「管理」）
- Issuer ID
- 密钥 ID（`AuthKey_` 后面 10 位）
- 设备 UDID（可多个）

## 运行
```bash
python3 ioscert.py --issuer ISSUER_ID --key-id KEY_ID --p8 AuthKey_XXXX.p8 \
  --name zhangsan --udid 00008140-XXXXXXXXXXXXXXXX --password 123456
```
输出在 `out/<name>/`：`distribution.p12`、`AllCap.mobileprovision`、`ios.key`、`ios.csr`、`密码.txt`。

- 同一个 `out/<name>/ios.key` 已存在时会复用，并复用账号里匹配该私钥的证书（不新建证书）。
- `--profile-only`：只重新生成描述文件（加设备、改完应用组后用）。
- 依赖：`pip install pyjwt cryptography requests`，以及 `openssl`（3.x，p12 用 `-legacy` 兼容 iOS）。
- 云环境需允许访问 `api.appstoreconnect.apple.com`。

## 开启的权限（19 项）
Access Wi-Fi Information、App Groups、Associated Domains、Data Protection（首次解锁后）、Game Center、HealthKit、HomeKit、Hotspot、iCloud（CloudKit）、Multipath、Network Extensions、NFC Tag Reading、Personal VPN、Push Notifications、Siri、Increased Memory Limit、Extended Virtual Addressing、Time Sensitive Notifications、Communication Notifications。

不开启（会导致无法安装）：App Clip 按需安装、DriverKit、Enhanced Security、Default 系列、MDM、System Extension、运营商相关。

## 需要手动的一步：应用组
API 不支持创建 App Group。新账号需在 developer.apple.com：
1. 标识符 → ＋ → 应用组 → `group.com.<name>.allcap` → 注册
2. App ID `AllCap` → App Groups → Configure → 勾选该组 → Save → Confirm
3. 再运行一次脚本（加 `--profile-only`）

## 用完
让客户在 App Store Connect 撤销 API 密钥。已生成的证书和描述文件不受影响。
