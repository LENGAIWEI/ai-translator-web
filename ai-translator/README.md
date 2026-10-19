# AI 翻译官（ai-translator）

多语言翻译 + 词典查词的独立 Spring Boot 应用，由原 `ai-translator-web` 工程拆分而来。

## 一、拆分说明

原工程 `ai-translator-web` 把「翻译官」和「RAG 知识库问答」做在同一个应用里。
本次拆分后，本工程是**完全独立**的应用：有独立的 `pom.xml`、启动类、端口、配置文件，可以单独编译、单独部署、互不影响。

| 内容 | 本工程（翻译官） | 已移出到 RAG 知识库 |
| --- | --- | --- |
| 控制器 | `TranslateController` | `KnowledgeController` |
| 服务 | `AiService.translate / lookup` | `KnowledgeService`、`AiService.chat` |
| 配置类 | `AiProperties`（仅对话模型字段） | `AiProperties`（含 Embedding 字段）、`KnowledgeProperties` |
| 前端 | `static/index.html` | `static/index.html`（原 `knowledge.html`） |
| 配置项 | `ai.api-key / ai.api-url / ai.model` | `ai.embedding-*`、`kb.*` |
| 数据 | 无 | `data/knowledge-base.json` |

拆分时一并去掉的内容（它们不属于任何一个业务，且仍完整保留在原始工程的备份包里）：

- `AIUtil.java`：已废弃的空实现类；
- `HelloController.java`：`/hello`、`/greet` 两个入门示例接口。

> 说明：两个应用各自带一份 `AiService` / `AiProperties`，但只保留自己用得到的方法与字段，因此两个包可以零依赖地独立编译运行。

## 二、目录结构

```
ai-translator/
├── pom.xml                     Maven 工程描述（artifactId: ai-translator）
├── mvnw / mvnw.cmd             Maven Wrapper，无需预装 Maven
├── test.http                   接口调试脚本（IDEA HTTP Client / VS Code REST Client）
├── README.md
└── src
    ├── main
    │   ├── java/org/example/aitranslator
    │   │   ├── AiTranslatorApplication.java   启动类
    │   │   ├── AiProperties.java              AI 配置（apiKey / apiUrl / model）
    │   │   ├── AiService.java                 大模型调用（translate / lookup）
    │   │   ├── TranslateController.java       接口：/translate、/languages、/api/config
    │   │   ├── TranslateRequest.java          请求体
    │   │   └── TranslateResponse.java         响应体
    │   └── resources
    │       ├── application.properties         端口 + AI 配置
    │       └── static/index.html              前端页面（访问 / 即可）
    └── test/java/org/example/aitranslator/AiTranslatorApplicationTests.java
```

## 三、本地运行

```bash
# Windows
mvnw.cmd spring-boot:run

# Linux / macOS
./mvnw spring-boot:run
```

启动后访问 <http://localhost:8080/>。

## 四、接口一览

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/languages` | 支持的语言列表（前端下拉框用） |
| POST | `/translate` | 翻译 / 查词，`mode=dictionary` 时为查词 |
| GET | `/api/config` | 读取配置（API Key 打码返回） |
| POST | `/api/config` | 修改配置（`apiKey` 留空表示不修改） |

请求示例：

```json
POST /translate
{
  "text": "Hello, how are you?",
  "sourceLang": "auto",
  "targetLang": "zh",
  "mode": "translate"
}
```

详细示例见 `test.http`。

## 五、配置

`src/main/resources/application.properties`：

```properties
server.port=8080
ai.api-key=sk-****
ai.api-url=https://api.deepseek.com/v1/chat/completions
ai.model=deepseek-chat
```

也可以在页面右上角「⚙️ 设置」里动态修改，**重启后会恢复成配置文件里的默认值**。
生产环境建议把 `application.properties` 放到 jar 同级的 `config/` 目录（部署包里已经带好），这样改配置不用重新打包。

## 六、打包

```bash
./mvnw clean package          # 产物：target/ai-translator-0.0.1-SNAPSHOT.jar
```

## 七、部署到宝塔

见部署包里的 `部署说明.md`（`ai-translator-deploy.zip` 解压后即可看到）。
要点：宝塔安装 JDK 17，用「Java 项目」或 Supervisor 方式启动，端口 `8080`，把 `config/application.properties` 里的 Key 换成自己的。
