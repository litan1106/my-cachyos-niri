# Standalone backend entry point for Linux/Proton.
#
# The Hongguo Windows app is a Tauri shell (crashing Edge/WebView2 under Wine)
# wrapped around a local FastAPI backend that does all the real work: it forges
# the ByteDance/FQNovel API signatures (via a Java signer), fetches the catalog,
# and serves *decrypted, seekable MP4* at /stream. That backend runs fine under
# Wine. This entry point runs it directly -- no companion, no stdin handshake,
# no in-Wine Java signer -- on a fixed PORT so a native Linux browser can be the
# UI instead of the broken WebView2. It mirrors the env setup that the app's own
# desktop_bootstrap.py performs before importing the server.
#
# Provided by launch-hongguo via the environment:
#   PORT, SIGN_SERVER (host-JVM signer), HONGGUO_SESSION_API_KEY,
#   HONGGUO_BACKEND_DATA_DIR, HONGGUO_CONTENT_CONFIG, HONGGUO_HLS_WORK_DIR
import os, sys, secrets, traceback
from pathlib import Path

_LOG = os.environ.get("HONGGUO_STANDALONE_LOG", r"C:\hg-standalone.log")
def _log(msg):
    try:
        with open(_LOG, "a", encoding="utf-8") as f:
            f.write(str(msg) + "\n")
    except Exception:
        pass

try:
    open(_LOG, "w").close()
except Exception:
    pass
_log("entry")

root = Path(__file__).resolve().parent
sys.path.insert(0, str(root))

# Mirror desktop_bootstrap's packaged-mode environment.
os.environ.setdefault("ADMIN_TOKEN", secrets.token_hex(32))
os.environ["BIND_HOST"] = "127.0.0.1"
_data = os.environ.get("HONGGUO_BACKEND_DATA_DIR")
if _data:
    os.environ.setdefault("HONGGUO_STREAM_CACHE", str(Path(_data) / "stream-cache"))
os.environ["IMPERSONATE"] = ""
os.environ["DEVICE_POOL_SIZE"] = "0"          # Desktop never rotates device identities.
os.environ.pop("API_KEYS", None)
for _n in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy",
           "all_proxy", "HONGGUO_PROXY"):
    os.environ.pop(_n, None)

try:
    _log("env-set; importing server")
    import server     # noqa: E402  (import only after env is prepared)
    import uvicorn     # noqa: E402
    _log("server imported; starting uvicorn")
    port = int(os.environ.get("PORT", "8793"))
    cfg = uvicorn.Config(server.app, host="127.0.0.1", port=port, log_config=None,
                         access_log=False, log_level="warning")
    uvicorn.Server(cfg).run()
    _log("uvicorn returned")
except BaseException:
    _log("EXCEPTION:\n" + traceback.format_exc())
    raise
