# Zigbolge

Classic Malbolge en Zig. Esta primera versión es el miembro Classic de la
familia Pibolge / Fortranbolge / Rustbolge.

## Compilar

```powershell
zig build-exe src\main.zig -O ReleaseFast
Move-Item main.exe zigbolge.exe
```

## Ejecutar el gate

```powershell
zigbolge.exe fixture.mal 100000000 1>out.bin 2>report.txt
```

Resultado esperado: `Hello, world.` con 48 pasos y estado final
`a=19758, c=85, d=63`.

## Alcance

Memoria Classic fija de 59049 celdas, instrucciones canónicas, cifrado
post-instrucción y reporte JSON compacto. `zigbolge19` será el segundo
programa del kit, separado del runtime Classic.
