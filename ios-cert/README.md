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
- `--key`：复用指定的私钥；`--profile-name`：自定义描述文件名（默认 `AllCap-<name>`）。
- 依赖：`pip install pyjwt cryptography requests`，以及 `openssl`（3.x，p12 用 `-legacy` 兼容 iOS）。
- 云环境需允许访问 `api.appstoreconnect.apple.com`。

## 用自己的账号给客户开（共用一张证书）
不新建证书和应用组，只把客户设备加进自己的账号，每个客户单独一个描述文件：
```bash
python3 ioscert.py --issuer 自己的ISSUER --key-id 自己的KEY_ID --p8 自己的.p8 \
  --key 自己的ios.key --bundle-id com.yimeng.allcap \
  --name 客户名 --udid 客户UDID
```
输出 `out/<客户名>/AllCap-<客户名>.mobileprovision` + 同一个 `distribution.p12`。
注意：每年每类设备最多 100 台；所有客户共用一张证书，证书被撤销会全部失效。

## 开启的权限（28 项）
**API 自动开启（24 项）**：Access Wi-Fi Information、App Groups、Associated Domains、AutoFill Credential Provider、ClassKit、Custom Network Protocol、Data Protection（首次解锁后）、Game Center、HealthKit、HomeKit、Hotspot、iCloud（CloudKit）、In-App Purchase、Inter-App Audio、Low Latency HLS、Maps、Multipath、Network Extensions、NFC Tag Reading、Personal VPN、Push Notifications、Sign In with Apple、Siri、Wallet、Wireless Accessory Configuration。

**API 不支持，新 App ID 需网页手动勾选（4 项）**：Increased Memory Limit、Extended Virtual Addressing、Time Sensitive Notifications、Communication Notifications。脚本会列出未开成功的项。

**可选，仅网页能开**：Fonts、Group Activities、Push to Talk、WeatherKit、App Attest、Shared with You、Media Device Discovery、Head Pose、Spatial Audio Profile、Wi-Fi Aware、Wi-Fi Network Sharing、Network Topology Observation、Location Push Service Extension、iCloud Extended Share Access、Messages Collaboration、HealthKit Estimate Recalibration、Multitasking Camera Access、Sustained Execution、Low-Latency Streaming。

不开启（会导致无法安装）：App Clip 按需安装、DriverKit、Enhanced Security、Default 系列、MDM、System Extension、运营商相关。

## 新账号需要手动的一步：应用组 + 4 项权限
API 不支持创建 App Group，也开不了上面 4 项。新账号在 developer.apple.com：
1. 标识符 → ＋ → 应用组 → `group.com.<name>.allcap` → 注册
2. App ID `AllCap` → App Groups → Configure → 勾选该组；同时勾选那 4 项 → Save → Confirm
3. 再运行一次脚本（加 `--profile-only`）

## 用完
让客户在 App Store Connect 撤销 API 密钥。已生成的证书和描述文件不受影响。
