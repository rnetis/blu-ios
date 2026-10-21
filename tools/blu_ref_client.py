#!/usr/bin/env python3
"""Reference implementation of the Blu Bank openapi protocol (for protocol verification).

Flow: ECDH P-256 key-exchange -> derive AES-256-GCM + HMAC-SHA256 keys from the raw
shared secret -> protobuf request bodies -> detached-payload JWS (HS256, b64:false).

Nothing here is specific to the iOS app; it exists to prove the protocol on the wire.
"""
import base64, hashlib, hmac, json, os, secrets, struct, sys, uuid
import urllib.request, urllib.error

from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

BASE = "https://openapi.sdb247.com/openapi/v0"
APP_VERSION = (3, 11, 0, 30)
BUNDLE_ID = "blu.saman.solutions"
LOCALE = "fa_IR"

# ---------------------------------------------------------------- protobuf write
def _varint(v: int) -> bytes:
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        out.append(b | 0x80 if v else b)
        if not v:
            return bytes(out)

def tag(field: int, wire: int) -> bytes:
    return _varint(field << 3 | wire)

def uvar_f(field: int, value: int) -> bytes:          # varint field
    return tag(field, 0) + _varint(value)

def bytes_f(field: int, value: bytes) -> bytes:        # bytes field
    return tag(field, 2) + _varint(len(value)) + value

def str_f(field: int, value: str) -> bytes:
    return bytes_f(field, value.encode())

def sub_f(field: int, value: bytes) -> bytes:      # nested message field
    return bytes_f(field, value)

# ---------------------------------------------------------------- protobuf read
def read_varint(buf, i):
    v = s_ = 0
    while True:
        x = buf[i]; i += 1
        v |= (x & 0x7F) << s_
        if not x & 0x80:
            return v, i
        s_ += 7

def parse(buf):
    out, i = [], 0
    while i < len(buf):
        key, i = read_varint(buf, i)
        f, w = key >> 3, key & 7
        if w == 0:
            v, i = read_varint(buf, i); out.append((f, w, v))
        elif w == 2:
            ln, i = read_varint(buf, i)
            val, i = buf[i:i + ln], i + ln
            out.append((f, w, val))
        elif w == 5:
            out.append((f, w, buf[i:i + 4])); i += 4
        elif w == 1:
            out.append((f, w, buf[i:i + 8])); i += 8
        else:
            raise ValueError("bad wire type %d" % w)
    return out

def find(buf, field):
    for f, w, v in parse(buf):
        if f == field:
            return v
    return None

def dump(buf, indent=0):
    for f, w, v in parse(buf):
        pre = "  " * indent
        if w == 2:
            try:
                txt = v.decode(); printable = all(32 <= ord(c) < 127 or ord(c) > 127 for c in txt)
            except Exception:
                printable = False
            if printable and len(v) < 200:
                print(f"{pre}{f}: \"{txt}\"")
            else:
                try:
                    sub = parse(v)
                    print(f"{pre}{f}: {{")
                    dump(v, indent + 1)
                    print(f"{pre}}}")
                except Exception:
                    print(f"{pre}{f}: <{len(v)}B> {v[:24].hex()}")
        else:
            print(f"{pre}{f}: {v}")

# ---------------------------------------------------------------- crypto
class Session:
    def __init__(self):
        self.device_id = secrets.token_bytes(16)
        self.request_uuid = str(uuid.uuid4())
        self.priv = ec.generate_private_key(ec.SECP256R1())
        self.key_id = None
        self.aes_key = None
        self.hmac_key = None
        self.token = None
        self.token_issue = self.token_expire = None

    def public_spki(self) -> bytes:
        return self.priv.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)

    def derive(self, server_spki: bytes):
        server_pub = serialization.load_der_public_key(server_spki)
        secret = self.priv.exchange(ec.ECDH(), server_pub)          # 32-byte raw secret
        self.aes_key = secret
        self.hmac_key = secret

    def encrypt(self, data: bytes, iv_len=12) -> bytes:
        iv = os.urandom(iv_len)
        return iv + AESGCM(self.aes_key).encrypt(iv, data, None)

    def decrypt(self, blob: bytes, iv_len=12) -> bytes:
        return AESGCM(self.aes_key).decrypt(blob[:iv_len], blob[iv_len:], None)

    def jws(self, body: bytes, request_id: str, public: bool):
        if public:
            return None
        header = {"alg": "HS256", "kid": self.key_id, "crit": ["b64"], "b64": False,
                  "requestId": request_id}
        h = base64.urlsafe_b64encode(json.dumps(header, separators=(",", ":")).encode()).rstrip(b"=")
        signing_input = h + b"." + body
        sig = hmac.new(self.hmac_key, signing_input, hashlib.sha256).digest()
        return (h + b".." + base64.urlsafe_b64encode(sig).rstrip(b"=")).decode()

    # ---------------- context
    def context(self, account: str = None, profile: str = None) -> bytes:
        app = uvar_f(10, 0)
        if self.key_id:
            app += bytes_f(998, bytes.fromhex(self.key_id))
        app += sub_f(999, uvar_f(1, APP_VERSION[0]) + uvar_f(2, APP_VERSION[1]) + uvar_f(3, APP_VERSION[2]) + uvar_f(4, APP_VERSION[3]))
        ctx = bytes_f(1, uuid.UUID(self.request_uuid).bytes) + sub_f(8, app)
        ctx += sub_f(9, str_f(1, LOCALE))
        if account and profile:
            ctx += sub_f(10, str_f(1, profile) + uvar_f(2, 1) + sub_f(3, str_f(1, account)) + uvar_f(4, 41))
        if self.token:
            tok = sub_f(1, uvar_f(1, self.token_issue)) + sub_f(2, uvar_f(1, self.token_expire)) + bytes_f(3, self.token)
            ctx += sub_f(4, tok)
        ctx += sub_f(11, uvar_f(1, 1) + uvar_f(2, 1) + sub_f(3, uvar_f(1, 15)))
        return ctx

# ---------------------------------------------------------------- transport
def call(session: Session, service: str, path: str, body: bytes, public=False, token=True):
    """The gateway only speaks HTTP/2 (HTTP/1.1 is reset), so drive curl."""
    import subprocess, tempfile
    url = f"{BASE}/{path}"
    ctype = (f'application/x-protobuf;reqMsg="solutions.saman.bluebank.services.{service}Request"; '
             f'respMsg="solutions.saman.bluebank.services.{service}Response";')
    args = ["curl", "--http2", "-sS", "-o", "-", "-w", "\n%{http_code}",
            "--max-time", "25", "-X", "POST", url,
            "-H", f"Content-Type: {ctype}",
            "-H", "Accept: application/x-protobuf",
            "-H", f"X-Request-Id: {session.request_uuid}",
            "-H", "Origin: https://app.blubank.com",
            "-H", "Referer: https://app.blubank.com/"]
    sig = session.jws(body, session.request_uuid, public)
    if sig:
        args += ["-H", f"X-Jws-Signature: {sig}"]
    if token and session.token:
        args += ["-H", "Authorization: Bearer " + base64.urlsafe_b64encode(session.token).decode().rstrip("=")]
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(body)
        path_in = f.name
    args += ["--data-binary", "@" + path_in]
    out = subprocess.run(args, capture_output=True).stdout
    idx = out.rfind(b"\n")
    code = int(out[idx + 1:].strip() or 0)
    return code, out[:idx]

# ---------------------------------------------------------------- steps
def key_exchange(s: Session):
    body = sub_f(1, s.context()) + bytes_f(2, s.device_id) + bytes_f(3, s.public_spki()) + uvar_f(4, 3)
    status, resp = call(s, "SessionKeyExchange", "session/key-exchange", body, public=True, token=False)
    print(f"[key-exchange] HTTP {status}, {len(resp)} bytes")
    dump(resp, 1)
    key_id = find(resp, 2)
    server_pub = find(resp, 3)
    if not server_pub:
        raise SystemExit("no server public key in response")
    s.key_id = key_id.decode() if key_id else None   # server returns a hex string
    s.derive(server_pub)
    print(f"[key-exchange] keyId={s.key_id} ({len(bytes.fromhex(s.key_id))} bytes)  key={s.hmac_key.hex()[:16]}...")
    return True

def login(s: Session, username: str, password: str):
    plain = str_f(1, username) + sub_f(2, bytes_f(1, s.encrypt(password.encode())))
    auth = sub_f(3, plain)
    version = uvar_f(1, APP_VERSION[0]) + uvar_f(2, APP_VERSION[1]) + uvar_f(3, APP_VERSION[2]) + uvar_f(4, APP_VERSION[3])
    device = (bytes_f(1, bytes.fromhex(s.key_id)) + sub_f(2, sub_f(1, version) + str_f(3, BUNDLE_ID))
              + sub_f(3, uvar_f(1, 1) + uvar_f(2, 1) + sub_f(3, uvar_f(1, 15))) + str_f(5, "Mobile Safari")
              + sub_f(7, str_f(1, LOCALE)))
    body = sub_f(1, s.context()) + auth + sub_f(4, device)
    status, resp = call(s, "SessionLogin", "session/login", body, public=False, token=False)
    print(f"[login] HTTP {status}, {len(resp)} bytes")
    dump(resp, 1)
    return status, resp

if __name__ == "__main__":
    sess = Session()
    key_exchange(sess)
    login(sess, "hermes_protocol_probe", "not-a-real-password-9f2a")
