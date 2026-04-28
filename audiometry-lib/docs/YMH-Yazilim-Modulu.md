## YMH — Yazılım (Haskell) Modülü: Kapsam ve Arayüz

Bu doküman, odyometri projesindeki Yazılım/Haskell ekibinin (YMH) teslimatlarını ve Java uygulamasıyla olan JSON stdin/stdout arayüz sözleşmesini özetler.

### Sorumluluklar (YMH)

- **Medikal hesaplamalar (pure)**: Hughson–Westlake prosedürü, dB adım kuralları, eşik karar mantığı.
- **Immutable state**: Test oturumu `TestSession` ile yönetilir; her RESPONSE yeni bir session üretir (mutation yok).
- **Doğrulama**: Frekans ve şiddet doğrulaması (`validateFrequency`, `validateIntensity`).
- **Testler**: Unit test + QuickCheck property testleri ile IEC 60645-1 uyum kanıtına temel oluşturacak şekilde doğrulama.
- **Java entegrasyonu**: `audiometry-bridge` executable ile JSON stdin/stdout köprüsü.

### Modül yapısı (Haskell)

- `Audiometry/Types.hs`: Domain tipleri (`Frequency`, `Intensity`, `Ear`, `Response`, `TestSession`, `Threshold`)
- `Audiometry/Algorithm.hs`: Pure fonksiyonlar (`nextIntensity`, `applyResponse`, `isThresholdReached`, vb.)
- `Audiometry/Error.hs`: Doğrulama (`validateFrequency`, `validateIntensity`)
- `app/Main.hs`: JSON stdin/stdout köprüsü (Java entegrasyonu)

### JSON Arayüz Sözleşmesi

#### İstek (Java → Haskell)

- **stdin**: tek bir JSON obje
- Alanlar:
  - `action`: `"applyResponse"` (zorunlu)
  - `frequency`: `250 | 500 | 1000 | 2000 | 4000 | 8000`
  - `intensity`: \(-10\) ile \(120\) arası (dB HL)
  - `ear`: `"left" | "right"`
  - `response`: `"HEARD" | "NOT_HEARD"`

Örnek istek:

```json
{
  "action": "applyResponse",
  "frequency": 1000,
  "intensity": 40,
  "ear": "right",
  "response": "HEARD"
}
```

#### Yanıt (Haskell → Java)

- **stdout**: tek bir JSON obje
- Alanlar:
  - `nextIntensity` (integer): bir sonraki sunulacak şiddet (dB HL)
  - `thresholdReached` (boolean): **bu adım ile yeni eşik eklendiyse** `true`
  - `thresholds` (array): `[{ "frequency": 1000, "intensity": 25, "ear": "right" }, ...]`

Örnek yanıt:

```json
{
  "nextIntensity": 30,
  "thresholdReached": false,
  "thresholds": []
}
```

#### Hata Yanıtı

- `{"error":"invalid_json"}`: JSON parse/alan eksik/`action` yanlış
- `{"error":"invalid_frequency"}`: standart olmayan frekans
- `{"error":"intensity_out_of_range"}`: \([-10,120]\) dışı şiddet

### İş akışı (tek çağrı)

1. Java, bir request JSON üretir ve Haskell process’inin stdin’ine yazar.
2. Haskell:
   - `validateFrequency` + `validateIntensity` ile request doğrular
   - `applyResponse` ile `TestSession`’ı bir adım ilerletir
   - `nextIntensity`, `thresholdReached`, `thresholds` alanlarını döner
3. Java, stdout’tan gelen JSON’u parse eder ve GUI state’ine uygular.

### Java implementasyon örneği (Process spawn + JSON gönder/al)

Bu örnek, `audiometry-bridge` executable’ını çalıştırıp **tek request JSON** gönderir ve **tek response JSON** okur.

Bağımlılık:

- Jackson Databind (ör. Maven: `com.fasterxml.jackson.core:jackson-databind`)

Kod:

```java
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Map;

public class AudiometryBridgeClient {
  private static final ObjectMapper M = new ObjectMapper();

  public static Map<String, Object> applyResponse(
      String bridgePath,
      int frequency,
      int intensity,
      String ear,        // "left" | "right"
      String response    // "HEARD" | "NOT_HEARD"
  ) throws Exception {

    Process p = new ProcessBuilder(bridgePath)
        .redirectErrorStream(true)
        .start();

    var req = Map.of(
        "action", "applyResponse",
        "frequency", frequency,
        "intensity", intensity,
        "ear", ear,
        "response", response
    );

    try (Writer w = new OutputStreamWriter(p.getOutputStream(), StandardCharsets.UTF_8)) {
      M.writeValue(w, req);
      w.flush();
    }

    String out;
    try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
      out = r.readLine(); // Haskell tek satır JSON basıyor
    }

    int code = p.waitFor();
    if (code != 0) throw new RuntimeException("bridge exit=" + code + " out=" + out);

    @SuppressWarnings("unchecked")
    Map<String, Object> respObj = M.readValue(out, Map.class);
    return respObj;
  }
}
```

### Örnek senaryolar (Request → Response)

#### Senaryo A — Başarılı istek

Request:

```json
{"action":"applyResponse","frequency":1000,"intensity":40,"ear":"right","response":"HEARD"}
```

Response (örnek; `nextIntensity` algoritmaya göre değişir):

```json
{"nextIntensity":30,"thresholdReached":false,"thresholds":[]}
```

#### Senaryo B — Geçersiz frekans

Request:

```json
{"action":"applyResponse","frequency":300,"intensity":40,"ear":"right","response":"HEARD"}
```

Response:

```json
{"error":"invalid_frequency"}
```

#### Senaryo C — Şiddet aralık dışı

Request:

```json
{"action":"applyResponse","frequency":1000,"intensity":130,"ear":"right","response":"HEARD"}
```

Response:

```json
{"error":"intensity_out_of_range"}
```

#### Senaryo D — Geçersiz JSON / action

Request:

```json
{"action":"unknown","frequency":1000,"intensity":40,"ear":"right","response":"HEARD"}
```

Response:

```json
{"error":"invalid_json"}
```

