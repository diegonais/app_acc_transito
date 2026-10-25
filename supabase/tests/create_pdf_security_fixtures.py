"""Casos adversariales sinteticos; sin documentos binarios versionados."""
import struct
import zlib


def security_cases():
    def classic(catalog=b"", page=b"", info=b"", content=b"q Q"):
        objects = [b"<< /Type /Catalog /Pages 2 0 R " + catalog + b" >>",
                   b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
                   b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources <<>> /Contents 4 0 R " + page + b" >>",
                   b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"\nendstream"]
        if info:
            objects.append(info)
        data = bytearray(b"%PDF-1.7\n")
        offsets = [0]
        for i, body in enumerate(objects, 1):
            offsets.append(len(data))
            data.extend(str(i).encode() + b" 0 obj\n" + body + b"\nendobj\n")
        xref = len(data)
        data.extend(b"xref\n0 " + str(len(offsets)).encode() + b"\n0000000000 65535 f \n")
        for offset in offsets[1:]:
            data.extend(f"{offset:010d} 00000 n \n".encode())
        data.extend(b"trailer\n<< /Root 1 0 R /Size " + str(len(offsets)).encode() +
                    (b" /Info 5 0 R" if info else b"") + b" >>\nstartxref\n" + str(xref).encode() + b"\n%%EOF\n")
        return bytes(data)

    cases = [
        ("PDF_literal_inerte", classic(info=b"<< /Producer (/Names /OpenAction /AA /Encrypt) >>"), True),
        ("PDF_hex_inerte", classic(info=b"<< /Producer <2f4e616d6573> >>"), True),
        ("PDF_comentarios_inertes", classic(catalog=b"% /OpenAction /Names\n", content=b"% /Names /AA\nq Q"), True),
        ("PDF_OpenAction_comentado", classic(catalog=b"/OpenAction % distraccion /Names\n << /S /JavaScript /JS (alert) >>"), False),
        ("PDF_clave_escapada", classic(catalog=b"/Open#41ction << /S /JavaScript /JS (alert) >>"), False),
        ("PDF_Names_escapado", classic(catalog=b"/Na#6des << /JavaScript << /Names [] >> >>"), False),
        ("PDF_AA_pagina", classic(page=b"/AA << /O << /S /JavaScript /JS (alert) >> >>"), False),
        ("PDF_anotacion", classic(page=b"/Annots [<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /A << /S /URI /URI (https://example.invalid) >> >>]"), False),
        ("PDF_adjunto", classic(catalog=b"/Names << /EmbeddedFiles << /Names [] >> >>"), False),
        ("PDF_clave_duplicada", classic(catalog=b"/Pages 2 0 R"), False),
        ("PDF_referencia_inexistente", classic(catalog=b"/Otro 99 0 R"), False),
        ("PDF_accion_URI_contextual", classic(catalog=b"/Otro << /S /URI /URI (https://example.invalid) >>"), False),
        ("PDF_tipo_Action_contextual", classic(catalog=b"/Otro << /Type /Action >>"), False),
        ("PDF_accion_subtipo_indirecto", classic(catalog=b"/Otro << /S 5 0 R /URI (https://example.invalid) >>", info=b"/URI"), False),
    ]

    def compressed(extra=b"", corrupt=False):
        catalog = b"<< /Type /Catalog /Pages 2 0 R " + extra + b" >>"
        payload = zlib.compress(b"1 0 " + catalog)
        objects = {2: b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
                   3: b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources <<>> /Contents 4 0 R >>",
                   4: b"<< /Length 3 >>\nstream\nq Q\nendstream",
                   5: b"<< /Type /ObjStm /N 1 /First 4 /Filter /FlateDecode /Length " + str(len(payload)).encode() + b" >>\nstream\n" + payload + b"\nendstream"}
        data = bytearray(b"%PDF-1.7\n")
        offsets = {}
        for i, body in objects.items():
            offsets[i] = len(data)
            data.extend(str(i).encode() + b" 0 obj\n" + body + b"\nendobj\n")
        offsets[6] = xref = len(data)
        rows = [(0, 0, 65535), (2, 5, 0)] + [(1, offsets[i] + (1 if corrupt and i == 3 else 0), 0) for i in range(2, 7)]
        stream = zlib.compress(b"".join(struct.pack(">BIH", *r) for r in rows))
        data.extend(b"6 0 obj\n<< /Type /XRef /Size 7 /W [1 4 2] /Root 1 0 R /Filter /FlateDecode /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream\nendobj\nstartxref\n" + str(xref).encode() + b"\n%%EOF\n")
        return bytes(data)

    cases += [("PDF_objetos_comprimidos", compressed(), True),
              ("PDF_accion_comprimida", compressed(b"/Open#41ction % comentario\n<< /S /JavaScript /JS (alert) >>"), False),
              ("PDF_xref_stream_offset_invalido", compressed(corrupt=True), False),
              ("PDF_objstm_truncado", compressed()[:-50], False)]
    return cases
