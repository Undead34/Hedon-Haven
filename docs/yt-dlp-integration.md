# yt-dlp Integration — Plan, Implementación y Estado

## Objetivo

Integrar **yt-dlp** como motor de extracción de streams en Hedon-Haven (Android).
En lugar de que cada plugin oficial parseé HTML/JS manualmente para obtener URLs de video,
puede delegar la extracción a yt-dlp, que soporta 1000+ sitios web.

---

## Arquitectura

```
┌─────────────────────────────┐
│     OfficialPlugin          │  ← Base class para plugins oficiales
│  checkUseYtDlp(codeName)    │     Lee SharedPrefs: yt_dlp_enabled_{codeName}
│  ytDlpExtractStreams(url)   │     Delega a YtDlpExtractorService
└─────────────┬───────────────┘
              │ llama
              ▼
┌─────────────────────────────┐
│   YtDlpExtractorService     │  ← Singleton, lib/services/yt_dlp_extractor.dart
│  initialize()               │     Inicializa engine con Completer (solo Android)
│  getStreamUrls(pageUrl)     │     → getVideoInfo() → Map<int, Uri>
│  getYtDlpVersion()          │     Versión de yt-dlp instalada
│  updateYtDlp()              │     Actualizar binario yt-dlp (retorna bool)
│  isSupported                │     Getter público para verificar compatibilidad (Android)
└─────────────┬───────────────┘
              │ usa
              ▼
┌─────────────────────────────┐
│   extractor: ^1.0.0         │  ← Paquete Flutter (pub.dev)
│   (youtubedl-android)       │     Embebe Python 3.8 + yt-dlp + FFmpeg 6.0
└─────────────────────────────┘
```

---

## Flujo de extracción

```
Usuario abre video
       │
       ▼
Plugin.getVideoMetadata(videoID, uvp)
       │
       ├─ checkUseYtDlp(codeName) == true ───→ ytDlpExtractStreams(pageUrl)
       │                                            │
       │                                            ├─ éxito → Map<int, Uri> → return metadata
       │                                            └─ fallo → log warning, cae a manual
       │
       └─ checkUseYtDlp(codeName) == false ──→ extracción manual (HTML/JS parsing)
```

---

## Archivos modificados (10)

| Archivo | Cambio | Estado |
|---------|--------|--------|
| `pubspec.yaml` | `extractor: ^1.0.0` | ✅ |
| `android/app/build.gradle.kts` | `minSdk = 24` | ✅ |
| `android/app/src/main/AndroidManifest.xml` | `android:extractNativeLibs="true"` | ✅ |
| `lib/main.dart` | `YtDlpExtractorService.instance.initialize()` (background) | ✅ |
| `lib/services/yt_dlp_extractor.dart` | **NUEVO** — servicio singleton con Completer, soporte y actualización robusta | ✅ |
| `lib/utils/official_plugin.dart` | `checkUseYtDlp()` + `ytDlpExtractStreams()` | ✅ |
| `lib/official_plugins/pornhub.dart` | yt-dlp en getVideoMetadata (primer intento) | ✅ |
| `lib/official_plugins/xhamster.dart` | yt-dlp en getVideoMetadata (primer intento) | ✅ |
| `lib/ui/screens/settings/settings_plugins/settings_plugins.dart` | Toggle adaptativo "Use yt-dlp for streams" (solo en Android) | ✅ |
| `lib/ui/screens/settings/settings_media.dart` | Sección "yt-dlp Engine" con carga asíncrona, update y Toast feedback | ✅ |

---

## Configuración por plugin

- Clave en SharedPrefs: `yt_dlp_enabled_{codeName}` → `bool`
- Ejemplo: `yt_dlp_enabled_com.hedon_haven.pornhub` → `true`
- Default: `null` → tratado como `false`
- UI: Settings → Plugins → (opciones del plugin) → toggle "Use yt-dlp for streams" (oculto en sistemas no Android)

---

## Dependencias

### Paquete Flutter
- **`extractor: ^1.0.0`** (pub.dev, Android-only)
  - youtubedl-android v0.18.1
  - yt-dlp (bundled, updatable via API)
  - FFmpeg 6.0 (bundled)
  - Python 3.8 (bundled)

### Android
- `minSdk = 24` (Android 7.0+)
- `android:extractNativeLibs="true"` en AndroidManifest

---

## Próximos pasos

1. **Ejecutar `flutter pub get`** para descargar extractor + dependencias nativas
2. **Compilar y probar**:
   ```bash
   flutter build apk --debug
   ```
3. **Si hay error de NDK**, fijar versión en `android/app/build.gradle.kts`:
   ```kotlin
   ndkVersion = "27.0.12077973"
   ```
4. **Probar en dispositivo Android**:
   - Activar yt-dlp para Pornhub en Settings → Plugins
   - Abrir un video → verificar que usa yt-dlp
   - Desactivar toggle → verificar que vuelve a extracción manual
5. **Futuro**: Extender a más plugins oficiales (Tester) y a plugins de terceros (JS)

---

## Notas técnicas y de robustez

- **Concurrencia segura (Completer)**: La inicialización de `YtDlpExtractorService` utiliza un `Completer<bool>`. Si múltiples hilos o componentes (como la inicialización en segundo plano en `main.dart` y el renderizado de la pantalla de ajustes de `MediaScreen`) llaman a `initialize()` simultáneamente, todos esperarán al mismo proceso de inicialización en lugar de fallar o lanzar múltiples ejecuciones paralelas.
- **UI Adaptativa y Limpia**: Dado que `yt-dlp` a través del paquete `extractor` solo es compatible con Android, la interfaz de usuario se adapta automáticamente. La sección "yt-dlp Engine" en Ajustes de Media y el interruptor en los ajustes individuales de los plugins se ocultan automáticamente en sistemas de escritorio (Windows, Linux, macOS) o iOS, evitando configuraciones inservibles.
- **Feedback de Actualización**: La acción de actualización del motor en Ajustes de Media devuelve el estado del proceso (éxito/fallo) y notifica al usuario inmediatamente mediante un mensaje emergente (Toast).
- **Live streams**: yt-dlp devuelve la URL correcta para streams en vivo. El player (fvp/libmdk) maneja HLS live nativamente. No requiere cambios.
- **Fallback**: Si yt-dlp falla (sitio no soportado, error de red, etc.), el plugin cae automáticamente a extracción manual.
- **Size impact**: ~40-60MB extra en APK por Python + yt-dlp + FFmpeg. Mitigable con ABI splits en release.

---

## Referencias

- [extractor package on pub.dev](https://pub.dev/packages/extractor)
- [youtubedl-android (Github)](https://github.com/yausername/youtubedl-android)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [Seal app (referencia de integración)](https://github.com/JunkFood02/Seal)

