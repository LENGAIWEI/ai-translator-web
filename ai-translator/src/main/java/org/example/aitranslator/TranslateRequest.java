package org.example.aitranslator;

public class TranslateRequest {
    protected String text;
    protected String direction;   // 兼容旧版（zh2en / en2zh）
    protected String sourceLang;  // 源语言代码，auto 表示自动检测
    protected String targetLang;  // 目标语言代码
    protected String mode;        // translate（翻译）| dictionary（查词）

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public String getDirection() {
        return direction;
    }

    public void setDirection(String direction) {
        this.direction = direction;
    }

    public String getSourceLang() {
        return sourceLang;
    }

    public void setSourceLang(String sourceLang) {
        this.sourceLang = sourceLang;
    }

    public String getTargetLang() {
        return targetLang;
    }

    public void setTargetLang(String targetLang) {
        this.targetLang = targetLang;
    }

    public String getMode() {
        return mode;
    }

    public void setMode(String mode) {
        this.mode = mode;
    }
}
