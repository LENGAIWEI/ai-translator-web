package org.example.aitranslator;

public class TranslateResponse {
    private String original;
    private String translated;
    private String direction;     // 兼容旧版，形如 zh2en
    private String sourceLang;
    private String targetLang;
    private String detectedLang;  // 自动检测时显示「自动检测」
    private String mode;          // translate | dictionary
    private String time;
    private boolean success;
    private String error;

    public TranslateResponse() {
    }

    public static TranslateResponse ok(String original, String translated,
                                       String sourceLang, String targetLang,
                                       String mode, String time) {
        TranslateResponse r = new TranslateResponse();
        r.original = original;
        r.translated = translated;
        r.sourceLang = sourceLang;
        r.targetLang = targetLang;
        r.direction = sourceLang + "2" + targetLang;
        r.detectedLang = "auto".equals(sourceLang) ? "自动检测" : sourceLang;
        r.mode = mode;
        r.time = time;
        r.success = true;
        return r;
    }

    public static TranslateResponse error(String original, String sourceLang,
                                          String targetLang, String mode,
                                          String time, String error) {
        TranslateResponse r = new TranslateResponse();
        r.original = original;
        r.sourceLang = sourceLang;
        r.targetLang = targetLang;
        r.direction = sourceLang + "2" + targetLang;
        r.mode = mode;
        r.time = time;
        r.success = false;
        r.error = error;
        return r;
    }

    public String getOriginal() {
        return original;
    }

    public String getTranslated() {
        return translated;
    }

    public String getDirection() {
        return direction;
    }

    public String getSourceLang() {
        return sourceLang;
    }

    public String getTargetLang() {
        return targetLang;
    }

    public String getDetectedLang() {
        return detectedLang;
    }

    public String getMode() {
        return mode;
    }

    public String getTime() {
        return time;
    }

    public boolean isSuccess() {
        return success;
    }

    public String getError() {
        return error;
    }
}
