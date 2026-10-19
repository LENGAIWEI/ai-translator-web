package org.example.aitranslator;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * AI 接口配置（翻译官）
 * 默认值从 application.properties 读取（ai.api-key / ai.api-url / ai.model），
 * 运行时可通过 /api/config 接口动态修改（重启后恢复为配置文件中的默认值）。
 *
 * 说明：拆分时已移除 Embedding / 知识库相关字段，那些配置只属于 RAG 知识库应用。
 */
@Component
@ConfigurationProperties(prefix = "ai")
public class AiProperties {

    private String apiKey = "";
    private String apiUrl = "https://api.deepseek.com/v1/chat/completions";
    private String model = "deepseek-chat";

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getApiUrl() {
        return apiUrl;
    }

    public void setApiUrl(String apiUrl) {
        this.apiUrl = apiUrl;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }
}
