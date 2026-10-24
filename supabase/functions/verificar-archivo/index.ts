import { createClient } from "@supabase/supabase-js";
import { boundedRead, inspectBytes } from "./binary.ts";

type Reservation = {
  reserva_id: string;
  auth_uid: string;
  operation_id: string;
  objeto: string;
  bucket_id: string;
  mime: string;
  clase: string;
  bytes_esperados: number;
  sha256_esperado: string;
  estado: string;
};
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
export function makeHandler(
  env: (name: string) => string | undefined = Deno.env.get,
  network: typeof fetch = fetch,
) {
  return async (request: Request): Promise<Response> => {
    let rid: string | null = null;
    const reply = (status: number, estado: string, error?: string) =>
      Response.json(
        { estado, reserva_id: rid, ...(error ? { error } : {}) },
        { status, headers: { "Cache-Control": "no-store" } },
      );
    if (request.method !== "POST") {
      return reply(405, "RECHAZADO", "METODO_INVALIDO");
    }
    const auth = request.headers.get("authorization");
    if (!auth?.startsWith("Bearer ")) {
      return reply(401, "RECHAZADO", "JWT_REQUERIDO");
    }
    const abort = new AbortController();
    const deadline = Date.now() + 15000;
    const timer = setTimeout(() => abort.abort(), 15000);
    try {
      if (
        request.headers.get("content-type")?.split(";")[0] !==
          "application/json"
      ) return reply(400, "RECHAZADO", "SOLICITUD_INVALIDA");
      const body = JSON.parse(
        new TextDecoder().decode(await boundedRead(request, 1024)),
      );
      if (
        !body || Object.keys(body).length !== 1 ||
        typeof body.reserva_id !== "string" ||
        !UUID.test(body.reserva_id ?? "")
      ) return reply(400, "RECHAZADO", "SOLICITUD_INVALIDA");
      rid = body.reserva_id.toLowerCase();
      // URL exclusivamente del entorno servidor, nunca de headers/body del cliente.
      const base = env("SUPABASE_URL"),
        anon = env("SUPABASE_ANON_KEY"),
        service = env("SUPABASE_SERVICE_ROLE_KEY");
      if (!base || !anon || !service) throw Error("CONFIGURACION");
      const url = new URL(base);
      if (
        !["http:", "https:"].includes(url.protocol) || url.username ||
        url.password || url.pathname !== "/"
      ) throw Error("CONFIGURACION");
      const safeFetch: typeof fetch = (input, init) =>
        network(input, { ...init, signal: abort.signal, redirect: "error" });
      const client = createClient(base, anon, {
        global: { headers: { Authorization: auth }, fetch: safeFetch },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      });
      const { data: identity, error: authError } = await client.auth.getUser(
        auth.slice(7),
      );
      if (abort.signal.aborted) throw Error("TIEMPO_AGOTADO");
      if (authError || !identity.user) {
        return reply(403, "RECHAZADO", "JWT_INVALIDO");
      }
      const { data, error } = await client.rpc(
        "consultar_reserva_verificacion",
        { p_reserva: rid },
      );
      if (abort.signal.aborted) throw Error("TIEMPO_AGOTADO");
      if (error || !data) {
        return reply(403, "RECHAZADO", "RESERVA_NO_AUTORIZADA");
      }
      const r = data as Reservation;
      const limit = r.clase === "PDF" ? 10485760 : 5242880;
      if (
        r.reserva_id !== rid || r.auth_uid !== identity.user.id ||
        !UUID.test(r.operation_id) ||
        r.objeto !== `${identity.user.id}/${r.operation_id}/${rid}` ||
        r.bucket_id !==
          (r.clase === "PDF" ? "transito-pdf" : "transito-evidencias") ||
        !["RESERVADO", "VERIFICADO", "VINCULADO"].includes(r.estado) ||
        !Number.isSafeInteger(r.bytes_esperados) || r.bytes_esperados < 1 ||
        r.bytes_esperados > limit ||
        !/^[a-f0-9]{64}$/.test(r.sha256_esperado) ||
        (r.clase === "CROQUIS" && r.mime !== "image/png")
      ) return reply(422, "RECHAZADO", "RESERVA_INVALIDA");
      const response = await safeFetch(
        `${
          base.replace(/\/$/, "")
        }/storage/v1/object/authenticated/${r.bucket_id}/${r.objeto}`,
        { headers: { apikey: anon, Authorization: auth } },
      );
      if (!response.ok) return reply(422, "RECHAZADO", "STORAGE_NO_DISPONIBLE");
      if (response.headers.get("content-type")?.split(";")[0] !== r.mime) {
        return reply(422, "RECHAZADO", "MIME_INVALIDO");
      }
      let bytes: Uint8Array;
      try {
        bytes = await boundedRead(response, r.bytes_esperados);
      } catch {
        return reply(
          abort.signal.aborted ? 503 : 422,
          "RECHAZADO",
          abort.signal.aborted ? "TIEMPO_AGOTADO" : "TAMANO_O_LECTURA_INVALIDO",
        );
      }
      if (bytes.length !== r.bytes_esperados) {
        return reply(422, "RECHAZADO", "TAMANO_INVALIDO");
      }
      const digest = Array.from(
        new Uint8Array(
          await crypto.subtle.digest("SHA-256", bytes.slice().buffer),
        ),
        (v) => v.toString(16).padStart(2, "0"),
      ).join("");
      if (digest !== r.sha256_esperado) {
        return reply(422, "RECHAZADO", "HUELLA_INVALIDA");
      }
      try {
        await inspectBytes(r.mime, bytes);
      } catch {
        return reply(422, "RECHAZADO", "FORMATO_INVALIDO");
      }
      // Deadline comprobado tambien tras trabajo CPU; si el runtime mata el worker,
      // nunca se llega a confirmar. Un timeout de red no prueba rollback remoto.
      if (abort.signal.aborted || Date.now() >= deadline) {
        return reply(503, "RECHAZADO", "TIEMPO_AGOTADO");
      }
      const backend = createClient(base, service, {
        global: { fetch: safeFetch },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      });
      const confirmed = await backend.rpc("confirmar_archivo_backend", {
        p_reserva: rid,
        p_uid: identity.user.id,
        p_bytes: bytes.length,
        p_sha256: digest,
        p_mime: r.mime,
      });
      if (abort.signal.aborted) throw Error("TIEMPO_AGOTADO");
      if (confirmed.error) {
        return reply(422, "RECHAZADO", "CONFIRMACION_RECHAZADA");
      }
      return reply(200, confirmed.data);
    } catch {
      return reply(
        abort.signal.aborted ? 503 : 400,
        "RECHAZADO",
        abort.signal.aborted
          ? "TIEMPO_AGOTADO"
          : "SOLICITUD_O_SERVICIO_INVALIDO",
      );
    } finally {
      clearTimeout(timer);
    }
  };
}
if (import.meta.main) Deno.serve(makeHandler());
