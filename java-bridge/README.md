## Java Bridge (no deps)

Bu klasör, `audiometry-bridge` (Haskell) executable’ını Java’dan çağırmak için **JDK-only** (harici dependency yok) örnek bir modül içerir.

### Gereksinimler

- JDK 21+ (`javac`, `java`)
- Haskell tarafında build edilmiş `audiometry-bridge` binary’si

Binary yolunu bulmak için:

```bash
cd audiometry-lib
cabal build audiometry-bridge
BRIDGE_PATH="$(cabal list-bin exe:audiometry-bridge)"
echo "$BRIDGE_PATH"
```

### Derleme

```bash
cd ../java-bridge
mkdir -p out
javac -d out src/*.java
```

### Çalıştırma (demo)

```bash
java -cp out Main "$BRIDGE_PATH"
```
