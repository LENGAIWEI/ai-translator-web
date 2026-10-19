package org.example.aitranslator;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 服务：封装与大模型 API 的通信，面向翻译与查词场景。
 * 使用 Jackson 解析 JSON，支持多语言与自动检测。
 *
 * 说明：拆分自原工程，只保留 {@link #translate} / {@link #lookup}；
 * RAG 知识库问答用的通用 chat 方法已随知识库应用独立出去。
 */
@Service
public class AiService {

    /** 支持的语言：code -> 中文名（LinkedHashMap 保证顺序） */
    public static final Map<String, String> LANGUAGES = new LinkedHashMap<>();

    static {
        LANGUAGES.put("auto", "自动检测");
        LANGUAGES.put("zh", "中文");
        LANGUAGES.put("en", "英语");
        LANGUAGES.put("ja", "日语");
        LANGUAGES.put("ko", "韩语");
        LANGUAGES.put("fr", "法语");
        LANGUAGES.put("de", "德语");
        LANGUAGES.put("es", "西班牙语");
        LANGUAGES.put("ru", "俄语");
        LANGUAGES.put("pt", "葡萄牙语");
        LANGUAGES.put("it", "意大利语");
        LANGUAGES.put("ar", "阿拉伯语");
    }

    private final AiProperties properties;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public AiService(AiProperties properties) {
        this.properties = properties;
    }

    /**
     * 翻译文本
     *
     * @param text       原文
     * @param sourceLang 源语言代码（auto 表示自动检测）
     * @param targetLang 目标语言代码
     * @return 翻译结果（含成功标记与错误信息）
     */
    public Result translate(String text, String sourceLang, String targetLang) {
        String src = (sourceLang == null || sourceLang.isBlank()) ? "auto" : sourceLang;
        String tgt = (targetLang == null || targetLang.isBlank()) ? "zh" : targetLang;
        String srcName = LANGUAGES.getOrDefault(src, "源语言");
        String tgtName = LANGUAGES.getOrDefault(tgt, "目标语言");

        String prompt;
        if ("auto".equals(src)) {
            prompt = "请先自动识别下面文本的语言，然后将其翻译成" + tgtName
                    + "，只输出翻译结果，不要任何解释：\n" + text;
        } else {
            prompt = "请把下面的" + srcName + "文本翻译成" + tgtName
                    + "，只输出翻译结果，不要任何解释：\n" + text;
        }

        return runPrompt(prompt);
    }

    /**
     * 词典查词：列出单词的全部主要义项（一词多义全部列出）
     */
    public Result lookup(String word, String sourceLang, String targetLang) {
        String tgt = (targetLang == null || targetLang.isBlank()) ? "zh" : targetLang;
        String tgtName = LANGUAGES.getOrDefault(tgt, "目标语言");

        String prompt = "请作为一本双语词典，查询「" + word + "」这个词的全部主要含义，用" + tgtName + "解释。\n"
                + "要求：\n"
                + "1. 按词性分组（名词/动词/形容词等）列出所有义项，一词多义必须全部列出；\n"
                + "2. 每个义项给出简明" + tgtName + "释义，并附一个例句（例句后附" + tgtName + "翻译）；\n"
                + "3. 用编号和换行清晰排版，只输出查询结果，不要输出无关内容。";

        return runPrompt(prompt);
    }

    private Result runPrompt(String prompt) {
        try {
            String content = callApi(prompt);
            return Result.ok(content);
        } catch (Exception e) {
            return Result.error(e.getMessage() == null ? "未知错误" : e.getMessage());
        }
    }

    private String callApi(String prompt) throws Exception {
        String apiKey = properties.getApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("尚未配置 API Key，请点击右上角「设置」填写");
        }

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", properties.getModel());
        body.put("temperature", 0.7);
        body.put("messages", List.of(Map.of("role", "user", "content", prompt)));

        String jsonBody = objectMapper.writeValueAsString(body);

        HttpURLConnection conn = (HttpURLConnection) new URL(properties.getApiUrl()).openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Authorization", "Bearer " + apiKey);
        conn.setConnectTimeout(30_000);
        conn.setReadTimeout(60_000);
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(jsonBody.getBytes(StandardCharsets.UTF_8));
            os.flush();
        }

        int code = conn.getResponseCode();
        InputStream is = (code >= 200 && code < 300) ? conn.getInputStream() : conn.getErrorStream();
        String responseText = readBody(is);

        if (code < 200 || code >= 300) {
            throw new RuntimeException("AI 接口返回错误(" + code + ")：" + extractErrorMessage(responseText));
        }

        JsonNode root = objectMapper.readTree(responseText);
        JsonNode contentNode = root.path("choices").path(0).path("message").path("content");
        String content = contentNode.isMissingNode() ? "" : contentNode.asString();
        if (content.isBlank()) {
            throw new RuntimeException("AI 返回内容为空或解析失败");
        }
        return content.trim();
    }

    private String readBody(InputStream is) throws Exception {
        if (is == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }
        }
        return sb.toString();
    }

    private String extractErrorMessage(String responseText) {
        try {
            JsonNode root = objectMapper.readTree(responseText);
            JsonNode msg = root.path("error").path("message");
            if (!msg.isMissingNode()) {
                return msg.asString();
            }
        } catch (Exception ignored) {
            // 解析失败时直接返回原始响应
        }
        return responseText;
    }

    /** 调用结果封装 */
    public static class Result {
        private final boolean success;
        private final String content;
        private final String error;

        private Result(boolean success, String content, String error) {
            this.success = success;
            this.content = content;
            this.error = error;
        }

        public static Result ok(String content) {
            return new Result(true, content, null);
        }

        public static Result error(String error) {
            return new Result(false, null, error);
        }

        public boolean isSuccess() {
            return success;
        }

        public String getContent() {
            return content;
        }

        public String getError() {
            return error;
        }
    }
}
