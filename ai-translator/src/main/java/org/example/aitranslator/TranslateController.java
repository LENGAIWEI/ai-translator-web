package org.example.aitranslator;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 翻译相关接口：/translate、/languages、/api/config
 */
@RestController
public class TranslateController {

    private final AiService aiService;
    private final AiProperties properties;

    public TranslateController(AiService aiService, AiProperties properties) {
        this.aiService = aiService;
        this.properties = properties;
    }

    /** 返回支持的语言列表，供前端渲染下拉框 */
    @GetMapping("/languages")
    public Map<String, Object> languages() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("languages", AiService.LANGUAGES);
        return result;
    }

    @PostMapping("/translate")
    public TranslateResponse translate(@RequestBody TranslateRequest request) {
        String text = request.getText();
        String sourceLang = request.getSourceLang();
        String targetLang = request.getTargetLang();
        String mode = request.getMode();

        // 兼容旧版 direction 参数（zh2en / en2zh）
        if ((sourceLang == null || sourceLang.isBlank()) && request.getDirection() != null) {
            sourceLang = "zh2en".equals(request.getDirection()) ? "zh" : "en";
            targetLang = "zh2en".equals(request.getDirection()) ? "en" : "zh";
        }
        if (sourceLang == null || sourceLang.isBlank()) {
            sourceLang = "auto";
        }
        if (targetLang == null || targetLang.isBlank()) {
            targetLang = "zh";
        }
        if (mode == null || mode.isBlank()) {
            mode = "translate";
        }

        String time = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());

        if (text == null || text.isBlank()) {
            return TranslateResponse.error("", sourceLang, targetLang, mode, time,
                    "dictionary".equals(mode) ? "请输入要查询的单词" : "请输入要翻译的内容");
        }

        AiService.Result r = "dictionary".equals(mode) || "lookup".equals(mode)
                ? aiService.lookup(text, sourceLang, targetLang)
                : aiService.translate(text, sourceLang, targetLang);

        if (r.isSuccess()) {
            return TranslateResponse.ok(text, r.getContent(), sourceLang, targetLang, mode, time);
        }
        return TranslateResponse.error(text, sourceLang, targetLang, mode, time, r.getError());
    }

    /** 读取当前配置（API Key 打码返回） */
    @GetMapping("/api/config")
    public Map<String, Object> getConfig() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("model", properties.getModel());
        m.put("apiUrl", properties.getApiUrl());
        m.put("apiKey", mask(properties.getApiKey()));
        m.put("hasKey", properties.getApiKey() != null && !properties.getApiKey().isBlank());
        return m;
    }

    /** 更新配置（API Key 留空或为打码占位符时保持不变） */
    @PostMapping("/api/config")
    public Map<String, Object> updateConfig(@RequestBody Map<String, String> body) {
        String apiKey = body.get("apiKey");
        String model = body.get("model");
        String apiUrl = body.get("apiUrl");

        if (apiKey != null && !apiKey.isBlank() && !apiKey.contains("••••")) {
            properties.setApiKey(apiKey.trim());
        }
        if (model != null && !model.isBlank()) {
            properties.setModel(model.trim());
        }
        if (apiUrl != null && !apiUrl.isBlank()) {
            properties.setApiUrl(apiUrl.trim());
        }
        return getConfig();
    }

    private String mask(String key) {
        if (key == null || key.isBlank()) {
            return "";
        }
        if (key.length() <= 10) {
            return "••••••";
        }
        return key.substring(0, 6) + "••••••" + key.substring(key.length() - 4);
    }
}
