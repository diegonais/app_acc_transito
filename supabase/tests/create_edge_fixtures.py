"""Solo fixtures y oraculo 12. No participa en la ruta funcional Edge."""
import base64
import hashlib
import io
import json
import pathlib
import random
import struct
import subprocess
import sys
import zlib
from PIL import Image
from pypdf import PdfWriter
from pypdf.generic import DecodedStreamObject, NameObject

cases = []
oracle = pathlib.Path(__file__).parents[1] / "local" / "storage_verifier.py"


def add(name, mime, data, expected):
    result = subprocess.run([sys.executable, str(oracle), "--inspect", mime], input=data,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    cases.append(dict(name=name, mime=mime, base64=base64.b64encode(data).decode(),
                      expected=expected, python=result.returncode == 0, size=len(data),
                      sha256=hashlib.sha256(data).hexdigest()))


images = {}
for fmt in ("PNG", "JPEG"):
    b = io.BytesIO()
    Image.new("RGB", (32, 32), (50, 100, 150)).save(b, format=fmt)
    images[fmt] = b.getvalue()
    mime = "image/png" if fmt == "PNG" else "image/jpeg"
    add(fmt + "_valido", mime, b.getvalue(), True)
    add(fmt + "_truncado", mime, b.getvalue()[:len(b.getvalue()) // 2], False)
    add(fmt + "_vacio", mime, b"", False)
    add(fmt + "_falso", mime, b"contenido sintetico falso", False)
    add(fmt + "_solo_firma", mime, b.getvalue()[:8], False)
b = io.BytesIO()
Image.new("RGB", (64, 64)).save(b, format="JPEG", progressive=True)
add("JPEG_progresivo", "image/jpeg", b.getvalue(), True)
add("JPEG_truncado_con_EOI", "image/jpeg", images["JPEG"][:150] + b"\xff\xd9", False)
crc_bad = bytearray(images["PNG"])
crc_bad[29] ^= 1
add("PNG_CRC_invalido", "image/png", bytes(crc_bad), False)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


badpng = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
badpng += chunk(b"IDAT", zlib.compress(bytes(2_000_000))) + chunk(b"IEND", b"")
add("PNG_inflado_excesivo", "image/png", badpng, False)
for label, content, expected in (("valido", b"texto sintetico", True),
                                 ("excesivo", bytes(2_000_000), False)):
    original = images["PNG"]
    metadata = chunk(b"zTXt", b"demo\0\0" + zlib.compress(content))
    add("PNG_metadatos_" + label, "image/png", original[:33] + metadata + original[33:], expected)
for compressed in (False, True):
    writer = PdfWriter()
    page = writer.add_blank_page(width=100, height=100)
    stream = DecodedStreamObject()
    stream.set_data(b"q 1 0 0 rg 10 10 30 30 re f Q")
    page[NameObject("/Contents")] = writer._add_object(stream)
    if compressed:
        page.compress_content_streams()
    b = io.BytesIO()
    writer.write(b)
    data = b.getvalue()
    add("PDF_comprimido" if compressed else "PDF_valido", "application/pdf", data, True)
    add("PDF_truncado_" + str(compressed), "application/pdf", data[:len(data)//2], False)
    add("PDF_sin_cabecera_" + str(compressed), "application/pdf", b"falso" + data[5:], False)
add("PDF_falso_con_firma", "application/pdf", b"%PDF-1.7\ntexto falso\n%%EOF", False)
add("PDF_vacio", "application/pdf", b"", False)
# Cargas cercanas al limite real; entropia sintetica determinista, sin datos reales.
for fmt, side, options in (("PNG", 1280, {}), ("JPEG", 2048, {"quality": 95})):
    b = io.BytesIO()
    Image.frombytes("RGB", (side, side), random.Random(13).randbytes(side*side*3)).save(b, format=fmt, **options)
    add(fmt + "_cercano_5MiB", "image/png" if fmt == "PNG" else "image/jpeg", b.getvalue(), True)
base = data
import re
corrupt = re.sub(rb"startxref\s+\d+", b"startxref\n0", base)
add("PDF_xref_invalido", "application/pdf", corrupt, False)
corrupt = re.sub(rb"[0-9]{10} ([0-9]{5}) n", rb"0000000000 \1 n", base)
add("PDF_offsets_invalidos", "application/pdf", corrupt, False)
# Diferencia conservadora explicita: Python acepta este literal inocuo; Edge
# rechaza tokens activos incluso en texto. No se rebaja ningun control de 12.
writer = PdfWriter()
page = writer.add_blank_page(width=100, height=100)
stream = DecodedStreamObject()
stream.set_data(b"% literal sintetico /Names\nq Q")
page[NameObject("/Contents")] = writer._add_object(stream)
b = io.BytesIO()
writer.write(b)
add("PDF_token_conservador", "application/pdf", b.getvalue(), False)
writer = PdfWriter()
writer.add_blank_page(width=100, height=100)
subject = "X" * (10485760-500)
for _ in range(4):
    writer.add_metadata({"/Subject": subject})
    b = io.BytesIO()
    writer.write(b)
    if len(b.getvalue()) == 10485760:
        break
    difference = 10485760-len(b.getvalue())
    subject = subject + "X" * difference if difference > 0 else subject[:difference]
add("PDF_10MiB", "application/pdf", b.getvalue(), True)
# Representa elementos del PDF futuro: fuente TTF del proyecto, imagen y vectores.
# Solo fixture sintetico; la generacion funcional de PDF/QR permanece en Flutter.
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader
font = pathlib.Path(__file__).parents[2] / "assets" / "fonts" / "roboto-regular.ttf"
pdfmetrics.registerFont(TTFont("FuenteSintetica", str(font)))
b = io.BytesIO()
document = canvas.Canvas(b, pagesize=(400, 500))
document.setFont("FuenteSintetica", 14)
document.drawString(30, 450, "Informe sintético - Colisión - 2026-000001")
document.drawImage(ImageReader(io.BytesIO(images["JPEG"])), 30, 300, width=100, height=100)
document.drawImage(ImageReader(io.BytesIO(images["PNG"])), 150, 300, width=100, height=100)
document.rect(30, 200, 80, 80, fill=1)
document.save()
add("PDF_fuente_imagenes_vectores", "application/pdf", b.getvalue(), True)
pathlib.Path(sys.argv[1]).write_text(json.dumps(cases), encoding="utf8")
print(json.dumps({"fixtures": len(cases), "python_rejected": sum(not c["python"] for c in cases)}))
