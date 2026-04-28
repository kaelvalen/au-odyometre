package edu.ankara.audiometry;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class AudiometryBridgeClient {
  public record Request(
      int frequency,
      int intensity,
      Ear ear,
      Response response
  ) {}

  public enum Ear { LEFT, RIGHT }
  public enum Response { HEARD, NOT_HEARD }

  public record Threshold(int frequency, int intensity, Ear ear) {}

  public record BridgeResponse(
      Integer nextIntensity,
      Boolean thresholdReached,
      List<Threshold> thresholds,
      String error,
      String rawJson
  ) {}

  public BridgeResponse applyResponse(Path bridgePath, Request req) throws IOException, InterruptedException {
    Objects.requireNonNull(bridgePath, "bridgePath");
    Objects.requireNonNull(req, "req");

    String requestJson = toRequestJson(req);

    Process p = new ProcessBuilder(bridgePath.toString())
        .redirectErrorStream(true)
        .start();

    try (Writer w = new OutputStreamWriter(p.getOutputStream(), StandardCharsets.UTF_8)) {
      w.write(requestJson);
      w.flush();
    }

    String out;
    try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
      out = r.readLine(); // bridge tek satır JSON basıyor
      if (out == null) out = "";
    }

    int code = p.waitFor();
    if (code != 0) {
      return new BridgeResponse(null, null, List.of(), "bridge_exit_" + code, out);
    }

    return parseBridgeResponse(out);
  }

  private static String toRequestJson(Request req) {
    return "{"
        + "\"action\":\"applyResponse\""
        + ",\"frequency\":" + req.frequency()
        + ",\"intensity\":" + req.intensity()
        + ",\"ear\":\"" + (req.ear() == Ear.LEFT ? "left" : "right") + "\""
        + ",\"response\":\"" + (req.response() == Response.HEARD ? "HEARD" : "NOT_HEARD") + "\""
        + "}";
  }

  private static BridgeResponse parseBridgeResponse(String json) {
    String error = extractString(json, "error");
    Integer nextIntensity = extractInt(json, "nextIntensity");
    Boolean reached = extractBoolean(json, "thresholdReached");
    List<Threshold> thresholds = extractThresholds(json);
    return new BridgeResponse(nextIntensity, reached, thresholds, error, json);
  }

  // ---- Minimal JSON helpers (known-shape, no deps) ----
  // Not a general-purpose JSON parser. It’s intentionally tiny for this project’s contract.

  private static Integer extractInt(String json, String key) {
    String raw = extractNumberRaw(json, key);
    if (raw == null) return null;
    try { return Integer.parseInt(raw); } catch (NumberFormatException e) { return null; }
  }

  private static Boolean extractBoolean(String json, String key) {
    String needle = "\"" + key + "\":";
    int idx = json.indexOf(needle);
    if (idx < 0) return null;
    int start = idx + needle.length();
    String rest = json.substring(start).trim();
    if (rest.startsWith("true")) return Boolean.TRUE;
    if (rest.startsWith("false")) return Boolean.FALSE;
    return null;
  }

  private static String extractString(String json, String key) {
    String needle = "\"" + key + "\":\"";
    int idx = json.indexOf(needle);
    if (idx < 0) return null;
    int start = idx + needle.length();
    int end = json.indexOf('"', start);
    if (end < 0) return null;
    return json.substring(start, end);
  }

  private static String extractNumberRaw(String json, String key) {
    String needle = "\"" + key + "\":";
    int idx = json.indexOf(needle);
    if (idx < 0) return null;
    int start = idx + needle.length();
    int i = start;
    while (i < json.length() && Character.isWhitespace(json.charAt(i))) i++;
    int j = i;
    if (j < json.length() && json.charAt(j) == '-') j++;
    while (j < json.length() && Character.isDigit(json.charAt(j))) j++;
    if (j == i || (j == i + 1 && json.charAt(i) == '-')) return null;
    return json.substring(i, j);
  }

  private static List<Threshold> extractThresholds(String json) {
    String needle = "\"thresholds\":[";
    int idx = json.indexOf(needle);
    if (idx < 0) return List.of();
    int start = idx + needle.length();
    int end = json.indexOf(']', start);
    if (end < 0) return List.of();
    String arr = json.substring(start, end).trim();
    if (arr.isEmpty()) return List.of();

    // Split objects by "},{" (works for this fixed object shape).
    String[] parts = arr.split("\\},\\{");
    List<Threshold> out = new ArrayList<>();
    for (String p : parts) {
      String obj = p;
      if (!obj.startsWith("{")) obj = "{" + obj;
      if (!obj.endsWith("}")) obj = obj + "}";
      Integer f = extractInt(obj, "frequency");
      Integer i = extractInt(obj, "intensity");
      String ear = extractString(obj, "ear");
      if (f == null || i == null || ear == null) continue;
      out.add(new Threshold(f, i, "left".equals(ear) ? Ear.LEFT : Ear.RIGHT));
    }
    return out;
  }
}

