# Estado actual - Fase 13 completada

## Etapa

**Fase 13 - Pruebas y estabilizacion**: finalizada para el alcance
automatizable en entorno local.

La aplicacion queda integrada y estable sobre lo implementado hasta Fase 12. En
esta fase no se agregaron funcionalidades nuevas, no se modifico el esquema
SQLite y no se incorporaron dependencias. El trabajo se limito a revisar el
producto integrado, ampliar pruebas automatizadas y registrar validaciones
pendientes para dispositivo Android real.

## Flujos validados

### Autenticacion

- creacion del primer `ADMIN` solo cuando no existe administrador;
- contrasenas almacenadas con hash + salt, no texto plano;
- login valido de `ADMIN` y `POLICE`;
- logout con sesion conservada solo en memoria;
- credenciales incorrectas rechazadas;
- usuario inactivo rechazado;
- reset local de contrasena policial por `ADMIN`;
- roles aplicados en repositorios/controladores.

### Persistencia

- creacion de BD versionada;
- migracion incremental desde version 1 hasta version actual;
- `PRAGMA foreign_keys = ON`;
- restricciones `UNIQUE`, `CHECK` y FK;
- triggers para impedir relacion vehiculo-conductor de otro informe;
- transaccion completa al finalizar informe;
- rollback sin informes parciales ante falla dependiente;
- manejo y limpieza de fotografias temporales/persistentes en escenarios de
  cancelacion o reversa.

### Informe y correlativo

- validacion de obligatorios antes de finalizar;
- cancelar descarta informacion en memoria sin crear borradores;
- `Finalizar informe` persiste informe, conductores, vehiculos, personas y
  fotografias en una transaccion;
- informe finalizado se consulta en modo lectura;
- `POLICE` no puede crear informes para terceros;
- `ADMIN` no puede finalizar informes desde controlador;
- correlativo `AAAA-NNNNNN`;
- correlativo por gestion/anio;
- reinicio de secuencia al cambiar de gestion;
- no reutilizacion de numeros;
- informes inactivos cuentan para el siguiente correlativo.

### Relaciones

- conductores multiples;
- vehiculos multiples;
- relacion conductor-vehiculo valida dentro del mismo informe;
- personas involucradas `HERIDO` y `FALLECIDO`;
- fotografias con categorias aprobadas y rutas en SQLite, no BLOB.

### Soft Delete

- inactivar cambia solo `estado = 0`;
- solo `ADMIN` puede inactivar;
- contenido, relaciones y archivos asociados se conservan;
- informes inactivos quedan excluidos de listados, detalle activo y dashboard;
- no existe UI de reactivacion en el alcance actual.

### Dashboard

- dashboard `ADMIN` calcula total activo, policias activos, dia, mes, fecha,
  totales por policia y meses;
- dashboard `POLICE` calcula solo indicadores propios;
- inactivos quedan excluidos;
- escenario vacio cubierto por consultas y widgets de estado.

### Dispositivo, PDF y QR

- manifiesto Android declara permisos de ubicacion, camara e internet;
- GPS maneja servicio deshabilitado, permisos denegados y errores sin bloquear
  la finalizacion;
- mapa/croquis conserva coordenadas y ruta PNG opcional;
- apertura externa de coordenadas construye URI `geo`;
- fotografias se copian a almacenamiento persistente y no usan BLOB;
- PDF se genera localmente con nombre
  `NUMERO_CASO_GRADO_APELLIDO_NOMBRE.pdf`;
- nombre PDF se normaliza para evitar caracteres inseguros;
- QR contiene nombre completo, grado, numero de placa y unidad del policia
  propietario;
- PDF consultado por `ADMIN` usa el QR del policia propietario, no del Admin.

## Pruebas ampliadas en Fase 13

- migracion real de una BD version 1 a la version actual;
- presencia de triggers de version 2 e indices de version 3 tras migrar;
- soft delete con conductores, vehiculos, personas y fotografias conservados;
- detalle activo excluye informes inactivos;
- limpieza de fotos persistentes cuando una transaccion debe revertirse;
- reset de contrasena policial desde controlador;
- normalizacion de nombre de archivo PDF;
- URI estable de mapas para coordenadas limite `0,0`.

## Defectos corregidos

- No se detectaron defectos de produccion que requirieran cambios en `lib/`.
- Durante la ampliacion de pruebas se corrigio un problema del test de migracion
  en Windows: la BD se cerraba despues de intentar borrar el directorio temporal.
  Ahora se cierra antes de limpiar el sandbox.
- Se elimino un import redundante detectado por `flutter analyze`.

## Pruebas ejecutadas

| Comando | Estado | Resultado |
|---|---|---|
| `dart format .` | correcto | 55 archivos revisados, 0 cambios |
| `flutter analyze` | correcto | sin issues |
| `flutter test` | correcto | 56 tests pasaron |
| `flutter devices` | informativo | no hay Android fisico ni emulador conectado |

Durante `flutter test` siguen apareciendo advertencias conocidas del paquete
`pdf` sobre fuentes Helvetica sin soporte Unicode. No fallan pruebas, pero
deben observarse durante la validacion visual final del PDF.

## Checklist de dispositivo real pendiente

Requiere Android fisico compatible o emulador con capacidades equivalentes:

- [ ] Instalar y abrir APK en Android.
- [ ] Confirmar que cada nuevo inicio solicita login.
- [ ] Validar permisos de ubicacion permitidos, denegados y denegados
  permanentemente.
- [ ] Validar GPS activo y GPS deshabilitado.
- [ ] Confirmar que una falla de GPS no bloquea `Finalizar informe`.
- [ ] Capturar fotografia desde camara.
- [ ] Denegar permiso de camara y revisar mensaje/estado.
- [ ] Seleccionar una imagen desde galeria.
- [ ] Seleccionar multiples imagenes desde galeria.
- [ ] Confirmar miniaturas, cambio de categoria y eliminacion de fotografia.
- [ ] Cancelar informe con fotografias y confirmar limpieza de temporales
  propios.
- [ ] Finalizar informe con fotografias y confirmar rutas persistentes internas.
- [ ] Verificar que las rutas persistidas no apunten a cache temporal.
- [ ] Visualizar mapa/croquis con OpenStreetMap.
- [ ] Mover/ajustar zoom del mapa solo para encuadre.
- [ ] Capturar PNG del croquis cuando el mapa este disponible.
- [ ] Finalizar informe aunque falle la cartografia.
- [ ] Abrir coordenadas en aplicacion externa de mapas.
- [ ] Verificar almacenamiento local de archivos asociados.
- [ ] Generar PDF en dispositivo.
- [ ] Visualizar PDF.
- [ ] Guardar PDF.
- [ ] Compartir PDF mediante share sheet Android.
- [ ] Imprimir PDF.
- [ ] Confirmar nombre del PDF con `NUMERO_CASO_GRADO_APELLIDO_NOMBRE.pdf`.
- [ ] Leer QR desde el PDF generado y verificar propietario.
- [ ] Inactivar informe y confirmar exclusion de dashboard/listados.
- [ ] Verificar en SQLite del dispositivo que informe inactivo, relaciones y
  archivos asociados permanecen.
- [ ] Validar pantallas largas, teclado, rotacion razonable y ausencia de
  overflow visible.
- [ ] Generar APK release final y validar instalacion.

## Problemas conocidos

- No se pudo realizar validacion fisica Android porque `flutter devices` no
  detecto telefono ni emulador Android conectado.
- La generacion PDF sigue siendo minima respecto al documento oficial completo.
  PDF/QR esta integrado y probado, pero la validacion visual final contra el
  Word oficial continua pendiente.
- Las advertencias de Helvetica sin soporte Unicode del paquete `pdf` podrian
  afectar caracteres especiales en el PDF final; validar visualmente en Android.

## Estado de estabilidad

Estable en entorno local automatizado. No hay errores de formato, analisis ni
tests. La app puede pasar a preparacion de release solamente despues de completar
el checklist de dispositivo real y validar visualmente el PDF oficial.

## Siguiente fase

**Fase 14.**
