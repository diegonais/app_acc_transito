PDF.js / pdfjs-dist 6.4.299 — Mozilla Foundation y colaboradores.
Licencia Apache-2.0; ver LICENSE y los avisos conservados en ambos modulos.

Distribucion de inspeccion de archivos, sin renderizado. Se conservan el parser
y worker legacy de la misma version. Las dos adaptaciones de pdf.mjs retiran el
bootstrap opcional de canvas/Path2D nativo y hacen fallar NodeCanvasFactory si se
intentara renderizar. No se cambia el parser del worker ni se simula un canvas.
DOMMatrix se proporciona mediante la dependencia JavaScript fijada en deno.json.

Regenerar desde la raiz: node supabase/tests/prepare_pdfjs.mjs
Comprobar: node supabase/tests/prepare_pdfjs.mjs --check
La herramienta verifica SHA-512 del tarball npm y genera hashes SHA-256. No
instala el paquete npm ni sus binarios opcionales; solo extrae dos modulos y su
licencia. manifest.json identifica origen, version, adaptaciones y resultados.
No se distribuyen mapas de fuentes, fuentes externas, WASM ni canvas nativo.
Los PDF Flutter de regresion incluyen sus fuentes embebidas; la funcion inspecciona
contenido, no certifica autenticidad, equivalencia visual ni firma digital.
