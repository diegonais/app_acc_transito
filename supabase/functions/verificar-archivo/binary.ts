// Validacion estructural, no autenticidad del texto ni generacion de PDF/QR.
// Parsers fijados en deno.json/deno.lock; sin canvas nativo ni red de documentos.
import { decode as pngDecode } from "fast-png";
import jpeg from "jpeg-js";
const text = new TextDecoder("latin1");
const MAX_PIXELS = 16_000_000;
const MAX_EXPANDED = 64 * 1024 * 1024;
function require(ok: unknown): asserts ok {
  if (!ok) throw new Error("FORMATO_INVALIDO");
}

export async function boundedRead(
  response: Pick<Response, "body" | "headers">,
  maximum: number,
): Promise<Uint8Array> {
  require(response.body && maximum >= 0 && maximum <= 10485760);
  const declared = response.headers.get("content-length");
  require(
    declared === null ||
      (Number.isSafeInteger(Number(declared)) && Number(declared) <= maximum),
  );
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      require(total <= maximum);
      chunks.push(value);
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  const out = new Uint8Array(total);
  let p = 0;
  for (const chunk of chunks) {
    out.set(chunk, p);
    p += chunk.length;
  }
  return out;
}

async function png(data: Uint8Array) {
  require(
    data.length > 45 &&
      data.slice(0, 8).every((v, i) =>
        v === [137, 80, 78, 71, 13, 10, 26, 10][i]
      ),
  );
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  let p = 8,
    count = 0,
    width = 0,
    height = 0,
    bits = 0,
    channels = 0,
    interlace = 0,
    ended = false,
    seenData = false;
  const idat: Uint8Array[] = [];
  let metadataSize = 0;
  while (p < data.length) {
    require(p + 12 <= data.length && ++count <= 4096);
    const n = view.getUint32(p);
    const type = text.decode(data.subarray(p + 4, p + 8));
    require(n <= data.length - p - 12);
    if (count === 1) {
      require(type === "IHDR" && n === 13);
      width = view.getUint32(p + 8);
      height = view.getUint32(p + 12);
      bits = data[p + 16];
      const color = data[p + 17];
      channels =
        ({ 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 } as Record<number, number>)[color];
      require(
        width > 0 && height > 0 && width * height <= MAX_PIXELS && channels,
      );
      require(
        (color === 3 ? [1, 2, 4, 8] : color === 0 ? [1, 2, 4, 8, 16] : [8, 16])
          .includes(bits),
      );
      require(data[p + 18] === 0 && data[p + 19] === 0 && data[p + 20] <= 1);
      interlace = data[p + 20];
      require(
        width * height * channels * Math.max(1, bits / 8) <= MAX_EXPANDED,
      );
    } else require(type !== "IHDR");
    require(type !== "acTL"); // Mismo criterio que Pillow: una sola imagen.
    if (["iCCP", "zTXt", "iTXt"].includes(type)) {
      const meta = data.subarray(p + 8, p + 8 + n);
      const zero = meta.indexOf(0);
      require(zero > 0 && zero <= 79 && zero + 2 < meta.length);
      let payload = zero + 2, compressed = true;
      if (type === "iTXt") {
        require(meta[zero + 1] <= 1 && meta[zero + 2] === 0);
        compressed = meta[zero + 1] === 1;
        payload = meta.indexOf(0, zero + 3) + 1;
        require(payload > zero + 3);
        payload = meta.indexOf(0, payload) + 1;
        require(payload > 0);
      } else require(meta[zero + 1] === 0);
      if (compressed) {
        const stream = new Blob([meta.slice(payload)]).stream().pipeThrough(
          new DecompressionStream("deflate"),
        );
        const reader = stream.getReader();
        let size = 0;
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            size += value.length;
            require(size <= 1048576);
          }
        } finally {
          await reader.cancel().catch(() => {});
        }
        metadataSize += size;
      } else {
        require(meta.length - payload <= 1048576);
        metadataSize += meta.length - payload;
      }
      require(metadataSize <= 8 * 1048576);
    }
    if (type === "IDAT") {
      require(!ended);
      seenData = true;
      idat.push(data.subarray(p + 8, p + 8 + n));
    } else if (seenData) ended = true;
    if (type === "IEND") {
      require(n === 0 && p + 12 === data.length && seenData);
      break;
    }
    require(
      type === "IHDR" || type === "PLTE" || type === "IDAT" ||
        (data[p + 4] & 32) !== 0,
    );
    p += 12 + n;
  }
  require(
    p + 12 === data.length &&
      text.decode(data.subarray(p + 4, p + 8)) === "IEND",
  );
  const passes = interlace
    ? [[0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4], [0, 2, 2, 4], [
      1,
      0,
      2,
      2,
    ], [0, 1, 1, 2]]
    : [[0, 0, 1, 1]];
  let expected = 0;
  for (const [x, y, dx, dy] of passes) {
    const w = Math.max(0, Math.ceil((width - x) / dx)),
      h = Math.max(0, Math.ceil((height - y) / dy));
    if (w && h) expected += h * (1 + Math.ceil(w * channels * bits / 8));
  }
  require(expected <= MAX_EXPANDED);
  // Inflado acotado ANTES del parser, que de otro modo podria reservar sin limite.
  const compressed = new Blob(idat as BlobPart[]).stream().pipeThrough(
    new DecompressionStream("deflate"),
  );
  const reader = compressed.getReader();
  let expanded = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      expanded += value.length;
      require(expanded <= expected);
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  require(expanded === expected);
  const image = pngDecode(data, { checkCrc: true });
  require(
    image.width === width && image.height === height && image.data.length > 0,
  );
}

function jpg(data: Uint8Array) {
  require(
    data.length > 4 && data[0] === 255 && data[1] === 216 &&
      data.at(-2) === 255 && data.at(-1) === 217,
  );
  const image = jpeg.decode(data, {
    useTArray: true,
    tolerantDecoding: false,
    maxResolutionInMP: 16,
    maxMemoryUsageInMB: 64,
  });
  require(
    image.width > 0 && image.height > 0 &&
      image.width * image.height <= MAX_PIXELS &&
      image.data.length === image.width * image.height * 4,
  );
}

async function pdf(data: Uint8Array) {
  // Carga diferida: una foto no necesita el heap ni el arranque del parser PDF.
  const { default: DOMMatrix } = await import("dommatrix");
  const { WorkerMessageHandler } = await import("pdfjs-worker");
  Object.defineProperty(globalThis, "DOMMatrix", {
    value: DOMMatrix,
    configurable: true,
  });
  Object.defineProperty(globalThis, "pdfjsWorker", {
    value: { WorkerMessageHandler },
    configurable: true,
  });
  const { getDocument } = await import("pdfjs");
  const footer = /startxref\s+([0-9]+)\s+%%EOF\s*$/.exec(
    text.decode(data.subarray(-2048)),
  );
  require(footer);
  const xref = Number(footer[1]);
  require(Number.isSafeInteger(xref) && xref > 0 && xref < data.length);
  // PDF.js puede reconstruir xref danados. No aceptar esa recuperacion silenciosa.
  const head = text.decode(
    data.subarray(xref, Math.min(xref + 128, data.length)),
  );
  require(
    head.startsWith("xref") ||
      /^\d+\s+\d+\s+obj\b[\s\S]*\/Type\s*\/XRef\b/.test(head),
  );
  if (head.startsWith("xref")) {
    // Comprobar cada offset de xref clasico antes del parser tolerante.
    let p = xref + 4, entries = 0;
    const source = text.decode(data);
    while (true) {
      while (/\s/.test(source[p] ?? "x")) p++;
      if (source.startsWith("trailer", p)) break;
      const section = /^(\d+)\s+(\d+)\s*\r?\n/.exec(source.slice(p, p + 64));
      require(section);
      const first = Number(section[1]), count = Number(section[2]);
      require(count > 0 && first >= 0 && entries + count <= 100000);
      entries += count;
      p += section[0].length;
      for (let i = 0; i < count; i++) {
        const entry = /^(\d{10}) (\d{5}) ([fn])(?:\r\n|\n|\r| \n| \r)/.exec(
          source.slice(p, p + 24),
        );
        require(entry);
        if (entry[3] === "n") {
          const offset = Number(entry[1]), generation = Number(entry[2]);
          require(
            offset > 0 && offset < data.length &&
              new RegExp(`^${first + i}\\s+${generation}\\s+obj\\b`).test(
                source.slice(offset, offset + 64),
              ),
          );
        }
        p += entry[0].length;
      }
    }
    // Presupuesto del trailer, independiente del limite aprobado de 10 MiB.
    const marker = source.lastIndexOf("startxref");
    require(marker > p && marker - p <= 65536);
  }
  require(
    text.decode(data.subarray(0, 5)) === "%PDF-" &&
      /%%EOF\s*$/.test(text.decode(data.subarray(-1024))),
  );
  // Rechazo conservador adicional. El parser revisa tambien estructuras comprimidas.
  require(!/\/(?:OpenAction|AA|Names|Encrypt)\b/.test(text.decode(data)));
  const task = getDocument({
    data: data.slice(),
    stopAtErrors: true,
    useSystemFonts: false,
    useWasm: false,
    disableFontFace: true,
    disableAutoFetch: true,
    disableRange: true,
    disableStream: true,
    maxImageSize: MAX_PIXELS,
    verbosity: 0,
  });
  let doc;
  try {
    doc = await task.promise;
    require(doc.numPages > 0 && doc.numPages <= 1000);
    require(
      await doc.getPermissions() === null &&
        await doc.getJSActions() === null &&
        await doc.getAttachments() === null,
    );
    require(Object.keys(await doc.getDestinations()).length === 0);
    for (let i = 1; i <= doc.numPages; i++) {
      const page = await doc.getPage(i);
      require(
        (await page.getAnnotations()).length === 0 &&
          await page.getJSActions() === null,
      );
      await page.getOperatorList(); // Parsear contenido; no basta cabecera/xref.
      page.cleanup();
    }
  } finally {
    await task.destroy();
  }
}

export async function inspectBytes(
  mime: string,
  data: Uint8Array,
): Promise<void> {
  require(
    data.length > 0 &&
      data.length <= (mime === "application/pdf" ? 10485760 : 5242880),
  );
  if (mime === "image/png") await png(data);
  else if (mime === "image/jpeg") jpg(data);
  else if (mime === "application/pdf") await pdf(data);
  else require(false);
}
