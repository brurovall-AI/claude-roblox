# Ironhaven — Gym Simulator (Roblox)

Simulador de gimnasio premium para Roblox: un complejo deportivo de 4 niveles (planta
baja, segunda planta, sótano y azotea) más una pista exterior y un laboratorio futurista,
con entrenamiento basado en minijuegos, progresión profunda, competiciones, funciones
sociales e interfaz moderna.

> English summary: Ironhaven is a premium Roblox gym simulator built as a Rojo project.
> Open `Ironhaven.rbxl` in Roblox Studio, or sync `default.project.json` with Rojo.
> See `docs/ARCHITECTURE.md` for the technical design.

## Abrirlo en Roblox Studio (lo más rápido)

1. Descarga `Ironhaven.rbxl` de este repositorio.
2. Abre Roblox Studio → **File → Open from File…** → elige `Ironhaven.rbxl`.
3. Pulsa **Play**.

### Ajustes recomendados en Studio (una sola vez)

* **Game Settings → Avatar → Avatar type: R15** (las animaciones procedurales usan R15).
* **Game Settings → Security → Enable Studio Access to API Services** para que el
  guardado de datos (DataStores) y las clasificaciones funcionen en Studio. Sin esto
  el juego funciona igual pero el progreso no se guarda (aparece un aviso).
* Publica el juego en tu cuenta antes de probar DataStores en Studio.

## Sincronizar con Rojo (para editar el código)

```bash
rojo serve default.project.json
```
y conecta desde el plugin de Rojo en Studio.

## Personalizar

| Qué | Dónde |
|---|---|
| Balance (ganancias, niveles, precios) | `src/shared/Config/*.luau`, `src/shared/Formulas.luau` |
| Pases de juego y productos Robux | `src/shared/Config/Monetization.luau` (pon tus IDs; 0 = desactivado) |
| Música y sonidos | `src/shared/Config/Audio.luau` (huecos marcados *ASSET SLOT* para tus audios de la Creator Store) |
| Zonas y niveles de desbloqueo | `src/shared/Config/Areas.luau` |
| Equipamiento, compañeros, cosméticos | `src/shared/Config/{Stations,Gear,Companions,Cosmetics}.luau` |
| El mapa | `src/map/` (se “hornea” a `assets/Map.rbxm`) |

## Estructura

```
src/shared   configuración, fórmulas y utilidades (ReplicatedStorage.Shared)
src/server   servicios del servidor (datos, entrenamiento, tienda, competiciones…)
src/client   controladores del cliente (HUD, minijuegos, animaciones, mundo…)
src/map      constructor del mapa (arquitectura, equipamiento, decoración por zonas)
tools/       comprobador de tipos Luau, horneado del mapa, renderizador de previsualización
docs/        arquitectura y contratos entre sistemas
```

## Herramientas de desarrollo

```bash
node tools/check/check.mjs        # comprobación estricta de tipos Luau
lune run tools/bake/bake.luau     # genera assets/Map.rbxm
tools/build.sh                    # todo lo anterior + Ironhaven.rbxl
tools/build.sh --render           # + imágenes de previsualización en build/preview
```
Requisitos: Node 18+, [Lune](https://github.com/lune-org/lune), [Rojo](https://rojo.space) 7.7+,
Rust (solo para el renderizador). `cd tools/check && npm install` la primera vez.
