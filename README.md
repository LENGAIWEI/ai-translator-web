# v2 · 翻译官 / 知识库 完全分离

`v1` 把「翻译官」和「RAG 知识库问答」做在同一个工程里，两边共用 `AiService`、`AiProperties`，
甚至共用一个前端页面。改动任何一处都要回归测试另一处。

`v2` 把它们彻底拆成**两个独立可运行的应用**，并借这次拆分把知识库的检索能力做了一次完整的升级。

```
v2/
├── ai-translator/     翻译官：翻译 + 词典查词（原样搬过来，只保留自己的代码）
└── rag-knowledge/     知识库：混合检索 + 精排 Rerank + Query 改写/HyDE（本次重点）
```

---

## 一、两个工程的关系

**没有任何关系。** 没有父 `pom`、没有共享模块、没有互相引用、没有公共依赖版本。
各自有独立的启动类、端口、配置文件、数据文件和前端页面。

| | ai-translator | rag-knowledge |
| --- | --- | --- |
| 端口 | `8080` | `8081` |
| 启动类 | `AiTranslatorApplication` | `RagKnowledgeApplication` |
| 业务 | 翻译、词典查词 | 文档入库、检索问答 |
| 数据 | 无 | `data/knowledge-base.json` |
| 前端 | `static/index.html` | `static/index.html` |

**为什么不抽公共模块？** 两个工程的"共用代码"实际上只有「调用大模型 HTTP 接口」这 100 来行，
而它们的调用参数、错误处理、超时策略、降级行为都不一样（翻译要 `temperature=0.7` 且只输出译文，
知识库改写要 `0.1`、作答要 `0.3`）。强行抽一个 `common-ai` 模块，换来的是
"改翻译官要重新发布知识库"——正好是这次拆分想解决的问题。

**重复 100 行代码，换两个工程彻底解耦，这笔账是划算的。**

---

## 二、v2 相对 v1 改了什么

### 翻译官：几乎没有改动

从 `dist/ai-translator` 原样搬过来（去掉 `target/` 构建产物）。
它只需要 `AiService.translate / lookup`，`AiProperties` 里也只保留对话模型字段。

### 知识库：检索链路重做

v1 的检索只有一层：

```
问题 → 向量化 → 暴力余弦 → 阈值过滤 → topK → 拼 Prompt
```

v2 变成三层（这也是 RAG 工程里最能拉开差距的部分）：

```
问题
 │
 ├─ ① Query 改写 / HyDE ───────── 把"用户怎么说"翻译成"文档怎么写"
 │      指代消解 · 同义改写（多查询扩展）· 关键词抽取 · 假设答案
 │
 ├─ ② 混合检索 ─────────────────── 两路互补召回，RRF 按排名融合
 │      向量路（语义）+ BM25 路（关键词/专有名词/编号）
 │
 ├─ ③ 精排 Rerank ──────────────── 交叉特征重排，把答案顶到最前
 │      本地纯 Java 精排 ⇄ bge-reranker 交叉编码器（可插拔 + 自动降级）
 │
 └─ 截断 topK → 拼 Prompt → 大模型作答
```

配套的工程改动：

- **切段升级**：按 Markdown 标题层级切章节，每块带 `section` 元数据（如「员工手册 > 请假制度 > 年假」），
  章节路径同时参与 BM25 检索；
- **全链路可观测**：响应里带回向量分、BM25 分、RRF 融合分、精排分、命中路径、各阶段耗时，
  首页「检索轨迹」直接可视化；
- **全链路可降级**：Embedding 挂了退纯 BM25；rerank 服务挂了退本地精排；改写失败退原问题。
  任何一个外部依赖抖动都不会让问答中断；
- **前端重做**：双栏布局、检索轨迹可视化、改写结果展示、命中片段的分数拆解。

细节见 [`rag-knowledge/docs/检索三层详解.md`](rag-knowledge/docs/检索三层详解.md) 与
[`rag-knowledge/README.md`](rag-knowledge/README.md)。

---

## 三、快速开始

两个工程各自独立启动，互不影响。

```bash
# 翻译官 → http://localhost:8080/
cd ai-translator
mvnw.cmd spring-boot:run          # Linux/macOS: ./mvnw spring-boot:run

# 知识库 → http://localhost:8081/
cd rag-knowledge
mvnw.cmd spring-boot:run
```

打包：

```bash
cd ai-translator   && mvnw.cmd clean package   # target/ai-translator-0.0.1-SNAPSHOT.jar
cd rag-knowledge   && mvnw.cmd clean package   # target/rag-knowledge-0.0.1-SNAPSHOT.jar
```

知识库检索层的算法测试（11 个用例，毫秒级，不需要网络和密钥）：

```bash
cd rag-knowledge && mvnw.cmd test
```

知识库要接**真正的 bge-reranker 模型**（可选，免费本地跑）：

```bash
cd rag-knowledge/tools/bge-reranker-service
start.bat          # 首次约 2.2GB 模型下载，国内请先设 HF_ENDPOINT=https://hf-mirror.com
```

然后在知识库页面「设置 → 第 2 层 · 精排 Rerank」把服务地址填成
`http://127.0.0.1:8090/rerank` 即可。不启动它也能用，会自动走本地精排。

---

## 四、和 v1 的关系

`v1` 的代码**一个字节都没有动**，都还在原位，可以随时对照：

| 位置 | 说明 |
| --- | --- |
| `src/`（仓库根） | v1 合体版（翻译官 + 知识库） |
| `dist/` | v1 的拆分尝试（包名拆开了，但检索逻辑与合体版逐行相同，没有做优化） |
| `docs/` | v1 的代码详解（仍然有效，讲的是 `dist/` 那两个工程） |
| **`v2/`** | **本次产出：完全分离 + 检索三层优化** |
