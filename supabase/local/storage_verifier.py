"""Intervencion 12: verificador privilegiado SOLO LOCAL, sin generacion PDF/QR.

Runtime: Python >=3.11, Pillow==12.3.0, pypdf==6.10.0. No dependencias Flutter.
Variables: TRANSITO_LOCAL_URL, TRANSITO_ANON_KEY, TRANSITO_SERVICE_KEY,
TRANSITO_VERIFY_PORT (default 57523). Claves solo entorno del proceso.
POST /verificar {"reserva_id": UUID}, Authorization: Bearer JWT real.
Solo localhost. No registrar headers, tokens, objetos ni errores de terceros.
"""
import hashlib
import http.client
import io
import json
import os
import subprocess
import sys
import uuid
import warnings
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.parse import urlparse


def inspect_bytes(mime, data):
    # Parser completo en proceso separado con timeout; nunca basta magic/MIME.
    if mime in ("image/png", "image/jpeg"):
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = 16_000_000
        warnings.simplefilter("error")
        with Image.open(io.BytesIO(data)) as image:
            if image.format != {"image/png": "PNG", "image/jpeg": "JPEG"}[mime]:
                raise ValueError()
            if getattr(image, "n_frames", 1) != 1:
                raise ValueError()
            image.verify()
        with Image.open(io.BytesIO(data)) as image:
            image.load()
    elif mime == "application/pdf":
        from pypdf import PdfReader
        if not data.startswith(b"%PDF-") or not data.rstrip().endswith(b"%%EOF"):
            raise ValueError()
        reader = PdfReader(io.BytesIO(data), strict=True)
        if reader.is_encrypted or not 1 <= len(reader.pages) <= 1000:
            raise ValueError()
        # No ejecuta scripts/adjuntos; rechaza estas funciones activas del catalogo.
        root = reader.trailer["/Root"]
        if any(k in root for k in ("/OpenAction", "/AA", "/Names")):
            raise ValueError()
        for page in reader.pages:
            content = page.get_contents()
            if content is not None:
                content.get_data()
            if any(k in page for k in ("/AA", "/Annots")):
                raise ValueError()
    else:
        raise ValueError()


if len(sys.argv) == 3 and sys.argv[1] == "--inspect":
    try:
        inspect_bytes(sys.argv[2], sys.stdin.buffer.read(10485761))
    except Exception:
        sys.exit(1)
    sys.exit(0)

BASE = os.environ["TRANSITO_LOCAL_URL"]
parsed = urlparse(BASE)
if parsed.scheme != "http" or parsed.hostname != "127.0.0.1" or parsed.path not in ("", "/"):
    raise RuntimeError("Solo API Supabase localhost")
ANON = os.environ["TRANSITO_ANON_KEY"]
SERVICE = os.environ["TRANSITO_SERVICE_KEY"]


def api(path, token, body=None, privileged=False, maximum=10485761, mime=None):
    headers = {"apikey": SERVICE if privileged else ANON, "Authorization": "Bearer " + token}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    # Conexion directa sin proxy ni redirecciones; JWT nunca sale de localhost.
    connection = http.client.HTTPConnection('127.0.0.1', parsed.port, timeout=15)
    try:
        connection.request('POST' if body is not None else 'GET', path, body=data, headers=headers)
        response = connection.getresponse()
        result = response.read(maximum + 1)
        if response.status >= 300:
            raise HTTPError(BASE + path, response.status, '', response.headers, io.BytesIO(result))
        if mime is not None and response.headers.get_content_type() != mime:
            raise ValueError()
        if len(result) > maximum:
            raise ValueError()
        return result
    finally:
        connection.close()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, state):
        data = json.dumps({"estado": state}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        stage = "SOLICITUD"
        self.connection.settimeout(20)
        if self.path != "/verificar":
            return self.reply(404, "NO_ENCONTRADO")
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 1024:
                return self.reply(400, "SOLICITUD_INVALIDA")
            token = self.headers.get("Authorization", "")
            if not token.startswith("Bearer "):
                return self.reply(401, "JWT_REQUERIDO")
            token = token[7:]
            body = json.loads(self.rfile.read(size))
            if set(body) != {"reserva_id"}:
                return self.reply(400, "SOLICITUD_INVALIDA")
            rid = str(uuid.UUID(body["reserva_id"]))
            # GoTrue valida firma/token real. PostgREST vuelve a validar JWT y actor.
            stage = "AUTH"
            actor = json.loads(api("/auth/v1/user", token))
            stage = "RESERVA"
            r = json.loads(api("/rest/v1/rpc/consultar_reserva_verificacion", token, {"p_reserva": rid}))
            if r["auth_uid"] != actor["id"]:
                return self.reply(403, "NO_AUTORIZADO")
            stage = "STORAGE"
            data = api("/storage/v1/object/authenticated/" + r["bucket_id"] + "/" + r["objeto"], token, mime=r["mime"])
            digest = hashlib.sha256(data).hexdigest()
            if len(data) != r["bytes_esperados"] or digest != r["sha256_esperado"]:
                return self.reply(422, "CONTENIDO_NO_COINCIDE")
            proc = subprocess.run([sys.executable, __file__, "--inspect", r["mime"]],
                                  input=data, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15,
                                  env={k: v for k, v in os.environ.items()
                                       if k.upper() in ("SYSTEMROOT", "WINDIR", "TEMP", "TMP")})
            if proc.returncode:
                return self.reply(422, "FORMATO_INVALIDO")
            stage = "CONFIRMACION"
            state = json.loads(api("/rest/v1/rpc/confirmar_archivo_backend", SERVICE,
                {"p_reserva": rid, "p_uid": actor["id"], "p_bytes": len(data),
                 "p_sha256": digest, "p_mime": r["mime"]}, privileged=True))
            self.reply(200, state)
        except HTTPError as error:
            # Solo codigo enumerado de GoTrue; nunca cuerpo, JWT ni headers.
            reason = ""
            try:
                value = json.loads(error.read(4096)).get("error_code", "")
                if value in ("bad_jwt", "no_authorization", "user_not_found", "session_not_found"):
                    reason = "_" + value
            except Exception:
                pass
            self.reply(403 if error.code in (401, 403) else 422, "RECHAZADO_" + stage + reason)
        except (ValueError, KeyError, TypeError):
            self.reply(400, "SOLICITUD_INVALIDA")
        except Exception:
            self.reply(503, "VERIFICACION_NO_DISPONIBLE")


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("TRANSITO_VERIFY_PORT", "57523"))), Handler).serve_forever()
