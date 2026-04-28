## Java Bridge (no deps)

Bu klasör, `audiometry-bridge` (Haskell) executable’ını Java’dan çağırmak için **JDK-only** (harici dependency yok) örnek bir modül içerir.

### Gereksinimler

- JDK 21+ (`javac`, `java`)
- Haskell tarafında build edilmiş `audiometry-bridge` binary’si

Binary yolunu bulmak için:

```bash
cd ..
cabal build audiometry-bridge
cabal list-bin exe:audiometry-bridge
```

### Derleme

```bash
cd java-bridge
mkdir -p out
javac -d out $(find src -name "*.java")
```

### Çalıştırma (demo)

```bash
BRIDGE_PATH="/abs/path/to/audiometry-bridge"
java -cp out edu.ankara.audiometry.Main "$BRIDGE_PATH"
```

