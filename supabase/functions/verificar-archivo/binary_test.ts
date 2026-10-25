import { boundedRead, inspectBytes } from "./binary.ts";
type Fixture = {
  name: string;
  mime: string;
  base64: string;
  expected: boolean;
  python: boolean;
  size: number;
};
const file = Deno.env.get("TRANSITO_EDGE_FIXTURES");
if (!file) throw Error("Faltan fixtures sinteticos: create_edge_fixtures.py");
const cases = JSON.parse(await Deno.readTextFile(file)) as Fixture[];
if (Deno.env.get("TRANSITO_FLUTTER_PDFS")) {
  Deno.test("los siete PDF Flutter reales estan incluidos", () => {
    const pdfs = cases.filter((f) => f.name.startsWith("Flutter_"));
    if (
      pdfs.length !== 7 || new Set(pdfs.map((f) => f.name)).size !== 7 ||
      pdfs.some((f) => !f.expected || !f.python)
    ) {
      throw Error("Regresion Flutter incompleta");
    }
  });
}
for (const fixture of cases) {
  Deno.test(fixture.name, async () => {
    const data = Uint8Array.from(atob(fixture.base64), (c) => c.charCodeAt(0));
    let accepted = false;
    try {
      await inspectBytes(fixture.mime, data);
      accepted = true;
    } catch { /* Rechazo seguro */ }
    if (accepted !== fixture.expected) {
      throw Error(`Aceptacion Edge inesperada ${fixture.name}`);
    }
    // Una diferencia del oraculo se conserva en el reporte; no cambia el criterio Edge.
    if (fixture.expected && !fixture.python) {
      throw Error(`Fixture valido rechazado por oraculo ${fixture.name}`);
    }
  });
}
Deno.test("lectura acotada rechaza exceso real aunque Content-Length mienta", async () => {
  let failed = false;
  try {
    await boundedRead(
      new Response(new Uint8Array(20), { headers: { "Content-Length": "2" } }),
      10,
    );
  } catch {
    failed = true;
  }
  if (!failed) throw Error("Lectura excedio limite");
});
Deno.test("lectura acotada rechaza exceso declarado antes de leer", async () => {
  let failed = false;
  try {
    await boundedRead(
      new Response("x", { headers: { "Content-Length": "200" } }),
      10,
    );
  } catch {
    failed = true;
  }
  if (!failed) throw Error("Cabecera excesiva admitida");
});
