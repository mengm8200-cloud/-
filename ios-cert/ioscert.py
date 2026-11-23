#!/usr/bin/env python3
"""
iOS 证书一键生成（App Store Connect API）

用法:
  python3 ioscert.py --issuer ISSUER_ID --key-id KEY_ID --p8 AuthKey.p8 \
      --name zhangsan --udid 00008140-XXXX [--udid ...] [--password 123456] \
      [--bundle-id com.xxx.allcap] [--group group.com.xxx.allcap] [--profile-only]

步骤:
  1. 生成私钥 + CSR（已有则复用）
  2. 创建 Apple Distribution 证书（已有同私钥证书则复用）并合成 p12
  3. 注册设备 UDID（已存在则跳过）
  4. 创建明确 App ID 并开启常用全权限（已存在则复用）
  5. 生成 Ad Hoc 描述文件并下载
"""
import argparse, base64, json, os, shutil, subprocess, sys, time
import jwt, requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

API = "https://api.appstoreconnect.apple.com/v1"

# 能力列表: (capabilityType, settings)
CAPS = [
    ("ACCESS_WIFI_INFORMATION", None),
    ("APP_GROUPS", None),
    ("ASSOCIATED_DOMAINS", None),
    ("DATA_PROTECTION", [{"key": "DATA_PROTECTION_PERMISSION_LEVEL",
                          "options": [{"key": "PROTECTED_UNTIL_FIRST_USER_AUTH"}]}]),
    ("GAME_CENTER", [{"key": "GAME_CENTER_SETTING", "options": [{"key": "GAME_CENTER_IOS"}]}]),
    ("HEALTHKIT", None),
    ("HOMEKIT", None),
    ("HOT_SPOT", None),
    ("ICLOUD", [{"key": "ICLOUD_VERSION", "options": [{"key": "XCODE_6"}]}]),
    ("MULTIPATH", None),
    ("NETWORK_EXTENSIONS", None),
    ("NFC_TAG_READING", None),
    ("PERSONAL_VPN", None),
    ("PUSH_NOTIFICATIONS", None),
    ("SIRIKIT", None),
    ("APPLE_ID_AUTH", [{"key": "APPLE_ID_AUTH_APP_CONSENT", "options": [{"key": "PRIMARY_APP_CONSENT"}]}]),
    ("AUTOFILL_CREDENTIAL_PROVIDER", None),
    ("WALLET", None),
    ("MAPS", None),
    ("INTER_APP_AUDIO", None),
    ("CLASSKIT", None),
    ("COREMEDIA_HLS_LOW_LATENCY", None),
    ("NETWORK_CUSTOM_PROTOCOL", None),
    ("WIRELESS_ACCESSORY_CONFIGURATION", None),
    # 以下 4 项 API 不支持（新 App ID 上会失败），需到网页手动勾选
    ("INCREASED_MEMORY_LIMIT", None),
    ("EXTENDED_VIRTUAL_ADDRESSING", None),
    ("USERNOTIFICATIONS_TIMESENSITIVE", None),
    ("USERNOTIFICATIONS_COMMUNICATION", None),
]


class ASC:
    def __init__(self, issuer, key_id, p8_path):
        self.issuer, self.key_id = issuer, key_id
        self.key = open(p8_path).read()
        self._tok, self._exp = None, 0

    def token(self):
        now = int(time.time())
        if not self._tok or now > self._exp - 60:
            self._exp = now + 1100
            self._tok = jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": self._exp, "aud": "appstoreconnect-v1"},
                self.key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})
        return self._tok

    def req(self, method, path, **kw):
        url = path if path.startswith("http") else API + path
        r = requests.request(method, url, headers={"Authorization": "Bearer " + self.token(),
                                                   "Content-Type": "application/json"},
                             timeout=60, **kw)
        if r.status_code >= 400:
            try:
                errs = r.json().get("errors", [])
                msg = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errs)
            except Exception:
                msg = r.text[:500]
            raise RuntimeError(f"{method} {path} -> {r.status_code}: {msg}")
        return r.json() if r.content else {}

    def get_all(self, path, params=None, limit=True):
        out, url = [], path
        params = dict(params or {})
        if limit:
            params["limit"] = 200
        while url:
            j = self.req("GET", url, params=params)
            out += j.get("data", [])
            url, params = j.get("links", {}).get("next"), None
        return out


def log(msg):
    print(msg, flush=True)


def ensure_key_csr(outdir, name):
    key_p, csr_p = os.path.join(outdir, "ios.key"), os.path.join(outdir, "ios.csr")
    if os.path.exists(key_p):
        key = serialization.load_pem_private_key(open(key_p, "rb").read(), None)
        log("· 复用已有私钥 ios.key")
    else:
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        open(key_p, "wb").write(key.private_bytes(serialization.Encoding.PEM,
                                                  serialization.PrivateFormat.TraditionalOpenSSL,
                                                  serialization.NoEncryption()))
        os.chmod(key_p, 0o600)
        log("✓ 生成私钥 ios.key")
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name),
                                    x509.NameAttribute(NameOID.COUNTRY_NAME, "CN")]))
           .sign(key, hashes.SHA256()))
    pem = csr.public_bytes(serialization.Encoding.PEM)
    open(csr_p, "wb").write(pem)
    return key, pem


def ensure_cert(asc, key, csr_pem, outdir):
    pub = key.public_key().public_bytes(serialization.Encoding.DER,
                                        serialization.PublicFormat.SubjectPublicKeyInfo)
    for c in asc.get_all("/certificates", {"filter[certificateType]": "DISTRIBUTION"}):
        der = base64.b64decode(c["attributes"]["certificateContent"])
        cert = x509.load_der_x509_certificate(der)
        if cert.public_key().public_bytes(serialization.Encoding.DER,
                                          serialization.PublicFormat.SubjectPublicKeyInfo) == pub:
            log(f"· 复用已有证书 {c['attributes']['name']}（到期 {c['attributes']['expirationDate'][:10]}）")
            return c["id"], der
    body = {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": csr_pem.decode()}}}
    try:
        c = asc.req("POST", "/certificates", json=body)["data"]
    except RuntimeError as e:
        if "maximum" in str(e).lower() or "limit" in str(e).lower():
            raise RuntimeError("Distribution 证书数量已满，请先在后台撤销一个旧证书。原始错误: " + str(e))
        raise
    log(f"✓ 创建证书 {c['attributes']['name']}（到期 {c['attributes']['expirationDate'][:10]}）")
    return c["id"], base64.b64decode(c["attributes"]["certificateContent"])


def make_p12(outdir, der, password):
    cer_p, pem_p = os.path.join(outdir, "distribution.cer"), os.path.join(outdir, "distribution.pem")
    p12_p = os.path.join(outdir, "distribution.p12")
    open(cer_p, "wb").write(der)
    subprocess.run(["openssl", "x509", "-in", cer_p, "-inform", "DER", "-out", pem_p], check=True)
    subprocess.run(["openssl", "pkcs12", "-export", "-legacy", "-inkey", os.path.join(outdir, "ios.key"),
                    "-in", pem_p, "-name", "Apple Distribution", "-out", p12_p,
                    "-passout", "pass:" + password], check=True)
    os.remove(pem_p)
    log(f"✓ 合成 distribution.p12（密码 {password}）")


def ensure_devices(asc, udids):
    existing = {d["attributes"]["udid"].upper(): d for d in asc.get_all("/devices")}
    ids = []
    for u in udids:
        d = existing.get(u.upper())
        if d:
            if d["attributes"]["status"] != "ENABLED":
                asc.req("PATCH", f"/devices/{d['id']}", json={"data": {"type": "devices", "id": d["id"],
                                                                      "attributes": {"status": "ENABLED"}}})
            log(f"· 设备已存在 {u}")
            ids.append(d["id"])
            continue
        body = {"data": {"type": "devices", "attributes": {
            "name": "iPhone-" + u[-6:], "udid": u, "platform": "IOS"}}}
        d = asc.req("POST", "/devices", json=body)["data"]
        log(f"✓ 添加设备 {u}")
        ids.append(d["id"])
    return ids


def ensure_bundle(asc, bundle_id, name):
    for b in asc.get_all("/bundleIds", {"filter[identifier]": bundle_id}):
        if b["attributes"]["identifier"] == bundle_id:
            log(f"· 复用已有 App ID {bundle_id}")
            return b["id"], False
    body = {"data": {"type": "bundleIds", "attributes": {
        "identifier": bundle_id, "name": name, "platform": "IOS"}}}
    b = asc.req("POST", "/bundleIds", json=body)["data"]
    log(f"✓ 创建 App ID {bundle_id}")
    return b["id"], True


def enable_caps(asc, bid):
    have = {c["attributes"]["capabilityType"]
            for c in asc.get_all(f"/bundleIds/{bid}/bundleIdCapabilities", limit=False)}
    failed = []
    for cap, settings in CAPS:
        if cap in have:
            continue
        attrs = {"capabilityType": cap}
        if settings:
            attrs["settings"] = settings
        body = {"data": {"type": "bundleIdCapabilities", "attributes": attrs,
                         "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}}}}}
        try:
            asc.req("POST", "/bundleIdCapabilities", json=body)
        except RuntimeError as e:
            # 带 settings 失败时再试一次不带 settings
            if settings:
                try:
                    body["data"]["attributes"] = {"capabilityType": cap}
                    asc.req("POST", "/bundleIdCapabilities", json=body)
                    continue
                except RuntimeError:
                    pass
            failed.append((cap, str(e)))
    ok = len(CAPS) - len(failed)
    log(f"✓ 开启权限 {ok}/{len(CAPS)} 项")
    for cap, err in failed:
        log(f"  ! {cap} 未能通过 API 开启，需要到网页手动勾选（{err[:120]}）")
    return failed


def make_profile(asc, bid, cert_id, dev_ids, name, outdir):
    # 删除同名旧描述文件，避免名称冲突
    for p in asc.get_all("/profiles", {"filter[name]": name}):
        if p["attributes"]["name"] == name:
            asc.req("DELETE", f"/profiles/{p['id']}")
    body = {"data": {"type": "profiles", "attributes": {"name": name, "profileType": "IOS_APP_ADHOC"},
                     "relationships": {
                         "bundleId": {"data": {"type": "bundleIds", "id": bid}},
                         "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
                         "devices": {"data": [{"type": "devices", "id": d} for d in dev_ids]}}}}
    p = asc.req("POST", "/profiles", json=body)["data"]
    path = os.path.join(outdir, name + ".mobileprovision")
    open(path, "wb").write(base64.b64decode(p["attributes"]["profileContent"]))
    log(f"✓ 生成描述文件 {name}.mobileprovision（到期 {p['attributes']['expirationDate'][:10]}）")
    return path


def check_profile(path):
    raw = open(path, "rb").read()
    s, e = raw.find(b"<?xml"), raw.find(b"</plist>") + 8
    import plistlib
    pl = plistlib.loads(raw[s:e])
    ent = pl.get("Entitlements", {})
    groups = ent.get("com.apple.security.application-groups", [])
    bad = [k for k in ent if any(x in k for x in (
        "on-demand-install", "driverkit", "hardened-process", "calling-app", "dialing-app",
        "messaging-app", "navigation-app", "translation-app", "system-extension", "managed-app"))]
    log(f"  权限数量 {len(ent)} · 设备 {len(pl.get('ProvisionedDevices', []))} 台 · 应用组 {groups or '（空）'}")
    if bad:
        log(f"  ! 含冲突权限: {bad}")
    if not groups:
        log("  ! 应用组为空：需在网页创建 App Group 并分配给 App ID，然后用 --profile-only 重新生成")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--p8", required=True)
    ap.add_argument("--name", required=True, help="客户名/文件夹名，英文")
    ap.add_argument("--udid", action="append", default=[])
    ap.add_argument("--password", default="123456")
    ap.add_argument("--bundle-id")
    ap.add_argument("--out", default="out")
    ap.add_argument("--profile-only", action="store_true", help="只重新生成描述文件")
    ap.add_argument("--key", help="复用已有私钥 ios.key（用自己账号给多个客户开时传入）")
    ap.add_argument("--profile-name", help="描述文件名称，默认 AllCap-<name>")
    a = ap.parse_args()

    outdir = os.path.join(a.out, a.name)
    os.makedirs(outdir, exist_ok=True)
    if a.key:
        dst = os.path.join(outdir, "ios.key")
        if os.path.abspath(a.key) != os.path.abspath(dst):
            shutil.copyfile(a.key, dst)
            os.chmod(dst, 0o600)
    asc = ASC(a.issuer, a.key_id, a.p8)
    bundle = a.bundle_id or f"com.{a.name.lower()}.allcap"
    profile_name = a.profile_name or f"AllCap-{a.name}"

    key, csr = ensure_key_csr(outdir, a.name)
    cert_id, der = ensure_cert(asc, key, csr, outdir)
    if not a.profile_only:
        make_p12(outdir, der, a.password)
    dev_ids = ensure_devices(asc, a.udid) if a.udid else [d["id"] for d in asc.get_all(
        "/devices", {"filter[status]": "ENABLED", "filter[platform]": "IOS"})]
    if not dev_ids:
        raise RuntimeError("账号里没有设备，请用 --udid 传入至少一个 UDID")
    bid, _ = ensure_bundle(asc, bundle, "AllCap")
    if not a.profile_only:
        enable_caps(asc, bid)
    path = make_profile(asc, bid, cert_id, dev_ids, profile_name, outdir)
    check_profile(path)
    open(os.path.join(outdir, "密码.txt"), "w").write(f"p12 密码: {a.password}\nBundle ID: {bundle}\n")
    log(f"\n完成，文件在 {outdir}")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as e:
        print("✗ 失败:", e)
        sys.exit(1)
