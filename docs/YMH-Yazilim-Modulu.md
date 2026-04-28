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

Bu repo içinde çalışan örnek, `java-bridge/` klasöründe **harici dependency olmadan (JDK-only)** mevcuttur.

Kısa demo (CLI):

```bash
cd audiometry-lib
cabal build audiometry-bridge
BRIDGE_PATH="$(cabal list-bin exe:audiometry-bridge)"

cd ../java-bridge
mkdir -p out
javac -d out src/*.java
java -cp out Main "$BRIDGE_PATH"
```

Koddan kullanım (özet):

```java
import java.nio.file.Path;

public class Example {
  public static void main(String[] args) throws Exception {
    var client = new AudiometryBridgeClient();

    var req = new AudiometryBridgeClient.Request(
        1000,
        40,
        AudiometryBridgeClient.Ear.RIGHT,
        AudiometryBridgeClient.Response.HEARD
    );

    var resp = client.applyResponse(Path.of(System.getenv("BRIDGE_PATH")), req);
    System.out.println(resp.rawJson());
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

