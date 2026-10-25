// Guardia sintactica previa a PDF.js. No busca tokens dentro de texto ni streams.
// Perfil cerrado: una revision, xref clasico o stream Flate sin predictores.
type Name = { name: string };
type Ref = { ref: number; generation: number };
type Value =
  | number
  | boolean
  | null
  | Name
  | Ref
  | { string: true }
  | Value[]
  | Map<string, Value>;
type Entry = { kind: number; a: number; b: number };
const decoder = new TextDecoder("latin1");
// deno-lint-ignore no-control-regex -- NUL es espacio PDF segun su sintaxis.
const WS = /[\x00\t\n\f\r ]/;
// deno-lint-ignore no-control-regex -- Delimitadores PDF, incluido NUL.
const DELIMITER = /[\x00\t\n\f\r ()<>\[\]{}/%]/;
const MAX_OBJECTS = 100000;
function check(ok: unknown): asserts ok {
  if (!ok) throw Error("ESTRUCTURA_PDF_INVALIDA");
}
function integer(v: Value | undefined): number {
  check(typeof v === "number" && Number.isSafeInteger(v) && v >= 0);
  return v;
}
function name(v: Value | undefined, expected: string): boolean {
  return !!v && typeof v === "object" && "name" in v && v.name === expected;
}
class Reader {
  p: number;
  tokens = 0;
  constructor(readonly source: string, p = 0, readonly end = source.length) {
    this.p = p;
  }
  space() {
    while (this.p < this.end) {
      if (WS.test(this.source[this.p])) this.p++;
      else if (this.source[this.p] === "%") {
        while (this.p < this.end && !/[\r\n]/.test(this.source[this.p])) {
          this.p++;
        }
      } else break;
    }
  }
  word(): string {
    this.space();
    const start = this.p;
    while (this.p < this.end && !DELIMITER.test(this.source[this.p])) this.p++;
    check(this.p > start && this.p - start <= 256);
    return this.source.slice(start, this.p);
  }
  uint(): number {
    const w = this.word();
    check(/^\d+$/.test(w));
    return integer(Number(w));
  }
  value(depth = 0): Value {
    check(depth <= 32 && ++this.tokens <= 200000);
    this.space();
    check(this.p < this.end);
    const s = this.source, c = s[this.p++];
    if (c === "/") {
      const start = this.p;
      while (this.p < this.end && !DELIMITER.test(s[this.p])) this.p++;
      check(this.p - start <= 256);
      const raw = s.slice(start, this.p);
      check(!/#(?![0-9a-fA-F]{2})/.test(raw));
      return {
        name: raw.replace(
          /#([0-9a-fA-F]{2})/g,
          (_, h) => String.fromCharCode(parseInt(h, 16)),
        ),
      };
    }
    if (c === "(") {
      let nesting = 1;
      while (this.p < this.end && nesting) {
        const t = s[this.p++];
        if (t === "\\") {
          check(this.p < this.end);
          this.p++;
        } else if (t === "(") check(++nesting <= 32);
        else if (t === ")") nesting--;
      }
      check(nesting === 0);
      return { string: true };
    }
    if (c === "<" && s[this.p] !== "<") {
      while (this.p < this.end && s[this.p] !== ">") {
        check(/[\da-fA-F]/.test(s[this.p]) || WS.test(s[this.p]));
        this.p++;
      }
      check(s[this.p++] === ">");
      return { string: true };
    }
    if (c === "<") {
      this.p++;
      const dict = new Map<string, Value>();
      while (true) {
        this.space();
        if (s.slice(this.p, this.p + 2) === ">>") {
          this.p += 2;
          return dict;
        }
        const key = this.value(depth + 1);
        check(
          key && typeof key === "object" && "name" in key &&
            !dict.has(key.name),
        );
        dict.set(key.name, this.value(depth + 1));
      }
    }
    if (c === "[") {
      const out: Value[] = [];
      while (true) {
        this.space();
        check(this.p < this.end);
        if (s[this.p] === "]") {
          this.p++;
          return out;
        }
        out.push(this.value(depth + 1));
      }
    }
    this.p--;
    const w = this.word();
    if (w === "true" || w === "false") return w === "true";
    if (w === "null") return null;
    check(/^[+-]?(?:\d+\.?\d*|\.\d+)$/.test(w));
    const n = Number(w);
    check(Number.isFinite(n));
    const saved = this.p;
    if (/^\d+$/.test(w)) {
      this.space();
      const refTail = /^(\d+)/.exec(
        s.slice(this.p, Math.min(this.p + 64, this.end)),
      );
      if (refTail) {
        this.p += refTail[0].length;
        const end = this.p;
        this.space();
        if (
          this.p > end && s[this.p] === "R" &&
          (this.p + 1 === this.end || DELIMITER.test(s[this.p + 1]))
        ) {
          this.p++;
          return { ref: integer(n), generation: integer(Number(refTail[1])) };
        }
      }
    }
    this.p = saved;
    return n;
  }
}
export async function validatePdfStructure(data: Uint8Array): Promise<void> {
  const source = decoder.decode(data);
  check(source.startsWith("%PDF-"));
  const footer = /startxref\s+(\d+)\s+%%EOF\s*$/.exec(source.slice(-2048));
  check(footer);
  const offset = Number(footer[1]);
  check(Number.isSafeInteger(offset) && offset > 0 && offset < data.length);
  const entries = new Map<number, Entry>();
  let expandedTotal = 0;
  async function inflate(
    bytes: Uint8Array,
    dict: Map<string, Value>,
  ): Promise<Uint8Array> {
    check(
      !dict.has("DecodeParms") &&
        (name(dict.get("Filter"), "FlateDecode") || !dict.has("Filter")),
    );
    if (!dict.has("Filter")) return bytes;
    const reader = new Blob([bytes.slice().buffer]).stream().pipeThrough(
      new DecompressionStream("deflate"),
    ).getReader();
    const chunks: Uint8Array[] = [];
    let length = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        length += value.length;
        expandedTotal += value.length;
        check(expandedTotal <= 64 * 1024 * 1024);
        chunks.push(value);
      }
    } finally {
      await reader.cancel().catch(() => {});
    }
    const out = new Uint8Array(length);
    let p = 0;
    for (const b of chunks) {
      out.set(b, p);
      p += b.length;
    }
    return out;
  }
  const forbidden = new Set([
    "OpenAction",
    "AA",
    "Names",
    "Encrypt",
    "JS",
    "JavaScript",
    "EmbeddedFiles",
    "Launch",
    "RichMedia",
    "XFA",
  ]);
  function inspect(value: Value, refs = true) {
    if (!value || typeof value !== "object") return;
    if (value instanceof Map) {
      for (const [key, child] of value) {
        check(!forbidden.has(key));
        inspect(child, refs);
      }
      check(!name(value.get("Type"), "EmbeddedFile"));
      check(!name(value.get("Type"), "Action"));
      if (value.has("S")) {
        const subtype = value.get("S");
        // No aceptar alias indirectos para un selector de accion/subtipo.
        check(subtype && typeof subtype === "object" && "name" in subtype);
        check(
          ![
            "JavaScript",
            "Launch",
            "GoToR",
            "GoTo",
            "GoToE",
            "URI",
            "Thread",
            "Sound",
            "Movie",
            "Hide",
            "Named",
            "SubmitForm",
            "ResetForm",
            "ImportData",
            "SetOCGState",
            "Rendition",
            "Trans",
            "GoTo3DView",
          ].some((n) => name(value.get("S"), n)),
        );
      }
    } else if (Array.isArray(value)) value.forEach((v) => inspect(v, refs));
    else if ("ref" in value && refs) {
      const e = entries.get(value.ref);
      check(
        e && e.kind !== 0 &&
          (e.kind === 2 ? value.generation === 0 : e.b === value.generation),
      );
    }
  }
  function object(at: number, id?: number, generation?: number) {
    check(at > 0 && at < data.length && /\d/.test(source[at]));
    const r = new Reader(source, at);
    const oid = r.uint(), gen = r.uint();
    check(
      r.word() === "obj" && (id === undefined || oid === id) &&
        (generation === undefined || gen === generation),
    );
    const value = r.value();
    r.space();
    let stream: Uint8Array | undefined;
    if (source.slice(r.p, r.p + 6) === "stream") {
      check(value instanceof Map);
      r.p += 6;
      if (source[r.p] === "\r") r.p++;
      check(source[r.p++] === "\n");
      let size = value.get("Length");
      if (size && typeof size === "object" && "ref" in size) {
        const e = entries.get(size.ref);
        check(e?.kind === 1 && e.b === size.generation);
        const lr = new Reader(source, e.a);
        check(
          lr.uint() === size.ref && lr.uint() === size.generation &&
            lr.word() === "obj",
        );
        size = lr.value();
        check(lr.word() === "endobj");
      }
      const length = integer(size);
      check(r.p + length <= data.length);
      stream = data.subarray(r.p, r.p + length);
      r.p += length;
      check(r.word() === "endstream");
    }
    check(r.word() === "endobj");
    return { oid, gen, value, stream, end: r.p };
  }
  function add(id: number, e: Entry) {
    check(
      id >= 0 && id < MAX_OBJECTS && !entries.has(id) &&
        entries.size < MAX_OBJECTS,
    );
    check(e.kind >= 0 && e.kind <= 2);
    entries.set(id, e);
  }
  let trailer: Map<string, Value>;
  if (source.startsWith("xref", offset)) {
    const r = new Reader(source, offset);
    check(r.word() === "xref");
    while (true) {
      r.space();
      if (source.startsWith("trailer", r.p)) {
        check(r.word() === "trailer");
        break;
      }
      const first = r.uint(), count = r.uint();
      check(count > 0 && first + count <= MAX_OBJECTS);
      for (let i = 0; i < count; i++) {
        const a = r.uint(), b = r.uint(), flag = r.word();
        check(flag === "n" || flag === "f");
        add(first + i, { kind: flag === "n" ? 1 : 0, a, b });
      }
    }
    const start = r.p, value = r.value();
    check(value instanceof Map && r.p - start <= 65536);
    trailer = value;
    check(r.word() === "startxref" && r.uint() === offset);
  } else {
    const x = object(offset);
    check(
      x.value instanceof Map && name(x.value.get("Type"), "XRef") && x.stream,
    );
    trailer = x.value;
    const w = trailer.get("W");
    check(Array.isArray(w) && w.length === 3);
    const widths = w.map(integer);
    check(widths.every((n) => n <= 4) && widths.reduce((a, b) => a + b) > 0);
    const size = integer(trailer.get("Size"));
    check(size > 0 && size <= MAX_OBJECTS);
    const index = trailer.get("Index") ?? [0, size];
    check(Array.isArray(index) && index.length % 2 === 0);
    const bytes = await inflate(x.stream, trailer);
    let p = 0;
    for (let k = 0; k < index.length; k += 2) {
      const first = integer(index[k]), count = integer(index[k + 1]);
      check(count > 0 && first + count <= size);
      for (let i = 0; i < count; i++) {
        const fields = widths.map((width, field) => {
          if (width === 0) return field === 0 ? 1 : 0;
          let n = 0;
          for (let j = 0; j < width; j++) {
            check(p < bytes.length);
            n = n * 256 + bytes[p++];
          }
          return n;
        });
        add(first + i, { kind: fields[0], a: fields[1], b: fields[2] });
      }
    }
    check(
      p === bytes.length && entries.get(x.oid)?.a === offset &&
        entries.get(x.oid)?.b === x.gen,
    );
    const tail = new Reader(source, x.end);
    check(tail.word() === "startxref" && tail.uint() === offset);
  }
  check(!trailer.has("Prev") && !trailer.has("XRefStm")); // Sin recuperacion ni revisiones ambiguas.
  const root = trailer.get("Root");
  check(root && typeof root === "object" && "ref" in root);
  inspect(trailer);
  const parsed = new Map<number, ReturnType<typeof object>>();
  const intervals: { start: number; end: number }[] = [];
  for (const [id, e] of entries) {
    if (e.kind !== 1) continue;
    const obj = object(e.a, id, e.b);
    parsed.set(id, obj);
    inspect(obj.value);
    intervals.push({ start: e.a, end: obj.end });
    if (obj.value instanceof Map && name(obj.value.get("Type"), "ObjStm")) {
      check(obj.stream);
      const n = integer(obj.value.get("N")),
        first = integer(obj.value.get("First"));
      check(n > 0 && n <= MAX_OBJECTS);
      const bytes = await inflate(obj.stream, obj.value),
        s = decoder.decode(bytes);
      check(first < s.length);
      const header = new Reader(s, 0, first);
      const members: { id: number; at: number }[] = [];
      for (let i = 0; i < n; i++) {
        members.push({ id: header.uint(), at: header.uint() });
      }
      header.space();
      check(header.p === first);
      for (let i = 0; i < n; i++) {
        const m = members[i],
          end = i + 1 < n ? first + members[i + 1].at : s.length;
        check(first + m.at < end && end <= s.length);
        const entry = entries.get(m.id);
        check(entry?.kind === 2 && entry.a === id && entry.b === i);
        const reader = new Reader(s, first + m.at, end);
        inspect(reader.value());
        reader.space();
        check(reader.p === end);
      }
    }
  }
  intervals.sort((a, b) => a.start - b.start);
  for (let i = 1; i < intervals.length; i++) {
    check(intervals[i - 1].end <= intervals[i].start);
  }
  for (const e of entries.values()) {
    if (e.kind === 2) {
      const obj = parsed.get(e.a);
      check(
        obj?.value instanceof Map && name(obj.value.get("Type"), "ObjStm") &&
          e.b < integer(obj.value.get("N")),
      );
    }
  }
  const catalog = parsed.get(root.ref); // Catalogo comprimido tambien sera comprobado por PDF.js.
  if (catalog) {
    check(
      catalog.value instanceof Map &&
        name(catalog.value.get("Type"), "Catalog"),
    );
  }
}
