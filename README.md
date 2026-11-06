# Zigbolge v2.0 — Motores Malbolge Classic & Unshackled en Zig

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](README.md)
[![Zig](https://img.shields.io/badge/Zig-0.16%20%7C%200.17-orange.svg)](https://ziglang.org)
[![Status](https://img.shields.io/badge/status-verified--gate-brightgreen.svg)](README.md)

Runtimes nativos de Malbolge de ultra-alto rendimiento en Zig (0.16+). Miembro en Zig de la familia de motores nativos ISyCo (`Rustbolge`, `Cobolge`, `Fortranbolge`, `Pibolge`, `Wasmbolge`).

## Novedades en v2.0

- **Arquitectura Dual Integrada:**
  1. **`zigbolge` (Classic):** Motor canónico Ben Olmstead de 10 trits ($3^{10} = 59{,}049$ celdas) con semántica estricta de EOF ($a = 59048$) y operación `crazy` optimizada a $O(1)$ por cuadrícula base-9 sin cuotas comptime.
  2. **`zigbolge19` (Unshackled):** Motor de 19 trits ($3^{19} = 1{,}162{,}261{,}467$ celdas) con paginación perezosa `64 KiB`, decodificación fast20 regional por tercios (`offs[]`) y tabla continua de cifrado extendido (135 caracteres).
- **Harness de Construcción Zig 0.16:** Soporte nativo para `zig build` y `zig build test` sin artefactos heredados de Windows.

## Compilación

```bash
zig build -Doptimize=ReleaseFast
```

Los binarios quedan disponibles en `zig-out/bin/`:
- `zig-out/bin/zigbolge`
- `zig-out/bin/zigbolge19`

## Pruebas unitarias

```bash
zig build test
```

Ejecuta el conjunto de tests de integridad semántica:
- Paridad exacta de operación Crazy ($0 \text{ CRZ } 0 = 29524$ en Classic y $(3^{19}-1)/2$ en Unshackled).
- Gate canónico de `Hello, world.` (48 pasos, $a=19758, c=85, d=63$).
- Comportamiento de EOF canónico (asigna $LAST$ a registro $a$ sin abortar ejecución).
- Smoke de Unshackled en paso 1 contra oráculo de referencia ($a=0, c=1, d=41$).

## Uso

### Classic (59,049 celdas)

```bash
./zig-out/bin/zigbolge fixture.mal [max_steps]
```

Salida estándar contiene la salida del programa; stderr emite el reporte JSON de telemetría:
```json
{"final":{"a":19758,"c":85,"d":63},"halt_reason":"VInstruction","output_len":13,"status":"HALTED","steps":48}
```

### Unshackled (3^19 celdas)

```bash
./zig-out/bin/zigbolge19 programa.mb [max_steps]
```

Reporte:
```json
{"final":{"a":0,"c":1,"d":41},"halt_reason":"StepsExhausted","output_len":0,"status":"TIMEOUT","steps":1}
```
