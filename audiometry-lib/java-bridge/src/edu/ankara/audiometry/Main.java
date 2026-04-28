package edu.ankara.audiometry;

import java.nio.file.Path;

public final class Main {
  public static void main(String[] args) throws Exception {
    if (args.length != 1) {
      System.err.println("Usage: java ... edu.ankara.audiometry.Main /abs/path/to/audiometry-bridge");
      System.exit(2);
    }

    Path bridge = Path.of(args[0]);
    var client = new AudiometryBridgeClient();

    var req = new AudiometryBridgeClient.Request(
        1000,
        40,
        AudiometryBridgeClient.Ear.RIGHT,
        AudiometryBridgeClient.Response.HEARD
    );

    var resp = client.applyResponse(bridge, req);
    System.out.println(resp.rawJson());
    if (resp.error() != null) System.exit(1);
  }
}

