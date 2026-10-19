package org.example.aitranslator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * AI 翻译官（独立应用）：多语言翻译 + 词典查词。
 * 由原 ai-translator-web 工程拆分而来，只保留翻译相关代码。
 */
@SpringBootApplication
public class AiTranslatorApplication {

    public static void main(String[] args) {
        SpringApplication.run(AiTranslatorApplication.class, args);
    }

}
