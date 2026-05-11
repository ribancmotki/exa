# Search Platform - Content Intelligence System (Zig)

## 1. Concept & Vision

A production-grade web search and content intelligence platform built entirely in Zig, providing neural and keyword search, content extraction, LLM-powered synthesis, monitor automation, and webset management. The system targets Linux x86_64 as a standalone binary compiled with Zig 0.14.0.

A production-grade web search and content intelligence platform built entirely in Zig, providing neural and keyword search, content extraction, LLM-powered synthesis, monitor automation, and webset management. The system prioritizes performance (sub-100ms search latency), cost efficiency (credit-based metering), and developer experience (MCP protocol support, OpenAI-compatible APIs).

The platform feels like a self-hosted alternative to premium search APIs—fast, reliable, and deeply integrated with content intelligence workflows.

## 2. Technical Architecture

### Stack
- **Language**: Zig 0.14.0 (native binary, no runtime)
- **Database**: PostgreSQL (libpq) for persistent storage
- **Cache**: Redis (hiredis) for caching and rate limiting
- **HTTP**: Custom POSIX socket server with thread pool
- **TLS**: OpenSSL for HTTPS client requests
- **Compression**: zlib for gzip decompression

### Build Configuration
- Target: linux-x86_64, ReleaseFast optimization
- Linkage: libpq, hiredis, libssl, libcrypto, libz, libc
- Executable: `search-platform`

## 3. Data Model

### Core Entities
- **teams**: Tenant isolation, credit balance
- **api_keys**: Authentication, rate limiting, per-key budgets
- **documents**: Crawled content with pgvector embeddings
- **search_requests**: Audit trail with cost tracking
- **content_requests**: Per-URL content fetch records

### Monitors
- Scheduled searches with webhook delivery
- Run history with status tracking
- Deduplication across runs

### Websets
- Multi-search campaigns with entity matching
- Item enrichment pipeline
- CSV import/export

### Billing
- Per-team credit balance
- Daily API key usage aggregation
- Event-sourced billing history

## 4. API Surface

### Search Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /search | Unified search with multiple types |
| POST | /contents | Batch content extraction |
| POST | /answer | LLM-powered question answering |
| POST | /context | Code context retrieval |

### Research Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /research/v1 | Create async research task |
| GET | /research/v1 | List research tasks |
| GET | /research/v1/{id} | Get task status/output |

### Monitor Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /monitors | Create scheduled monitor |
| GET | /monitors | List monitors |
| GET | /monitors/{id} | Get monitor details |
| PATCH | /monitors/{id} | Update monitor |
| DELETE | /monitors/{id} | Delete monitor |
| POST | /monitors/{id}/trigger | Manual trigger |
| GET | /monitors/{id}/runs | List runs |
| GET | /monitors/{id}/runs/{runId} | Get run details |

### Webset Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /websets/v0/websets | Create webset |
| GET | /websets/v0/websets | List websets |
| GET | /websets/v0/websets/{id} | Get webset |
| POST | /websets/v0/websets/{id} | Update webset |
| DELETE | /websets/v0/websets/{id} | Delete webset |
| POST | /websets/v0/websets/{id}/cancel | Cancel operations |
| POST | /websets/v0/websets/{id}/searches | Add search |
| GET | /websets/v0/websets/{id}/items | List items |
| POST | /websets/v0/websets/{id}/exports | Create export |
| POST | /websets/v0/imports | Import URLs |

### Webhook Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | /websets/v0/webhooks | Create webhook |
| GET | /websets/v0/webhooks | List webhooks |
| GET | /websets/v0/webhooks/{id} | Get webhook |
| PATCH | /websets/v0/webhooks/{id} | Update webhook |
| DELETE | /websets/v0/webhooks/{id} | Delete webhook |
| GET | /websets/v0/webhooks/{id}/attempts | List attempts |

### Management Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api-keys | List API keys |
| POST | /api-keys | Create API key |
| GET | /api-keys/{id} | Get API key |
| PUT | /api-keys/{id} | Update API key |
| DELETE | /api-keys/{id} | Revoke API key |
| GET | /api-keys/{id}/usage | Get usage report |
| GET | /websets/v0/teams/me | Get team info |
| GET | /websets/v0/events | List events |
| GET | /health | Health check |

### OpenAI Compatibility
| Method | Path | Description |
|--------|------|-------------|
| POST | /chat/completions | Chat completion API |
| POST | /responses | Responses API |

### MCP Protocol
| Method | Path | Description |
|--------|------|-------------|
| GET | /mcp | SSE stream for tools |
| POST | /mcp | JSON-RPC tool calls |

## 5. Search Types

| Type | Description | Latency | Cost |
|------|-------------|---------|------|
| auto | Neural + keyword fusion | ~200ms | Standard |
| fast | Simplified fusion | ~100ms | Standard |
| instant | Cached neural | ~50ms | Standard |
| neural | Pure embedding search | ~150ms | Standard |
| keyword | Full-text PostgreSQL | ~100ms | Standard |
| deep-lite | Enhanced + synthesis | ~500ms | +50% |
| deep | Multi-query + synthesis | ~1s | +70% |
| deep-reasoning | Chain-of-thought | ~2s | +100% |

## 6. Middleware Stack

1. **Logger**: Structured JSON logging
2. **Auth**: API key validation with Redis cache
3. **Rate Limiter**: Token bucket via Redis EVAL
4. **CORS**: Wildcard origin with preflight support

## 7. Background Workers

- **Monitor Scheduler**: Checks due monitors every 30s
- **Monitor Runner**: Executes triggered monitors
- **Research Worker**: Processes async research tasks
- **Webset Search Agent**: Executes webset searches
- **Webset Enrichment Agent**: Processes item enrichment
- **Webhook Retry**: Exponential backoff delivery
- **MCP Server**: Tool protocol handler

## 8. Configuration

All settings via environment variables:
- `LISTEN_HOST`, `LISTEN_PORT`
- `POSTGRES_DSN`, `REDIS_URL`
- `ANTHROPIC_API_KEY`
- `EMBEDDING_MODEL_URL`, `EMBEDDING_MODEL_NAME`, `EMBEDDING_DIM`
- `RERANKER_URL`
- `CRAWLER_*` settings
- `RATE_LIMIT_*` settings
- `WEBHOOK_*` settings
- `CREDIT_*` pricing settings
- `LOG_LEVEL`, `MCP_LISTEN_PORT`
- `DB_POOL_SIZE`, `INDEX_DATA_DIR`

## 9. Quality Requirements

- Zero memory leaks (GPA with leak detection)
- All errors propagate via error unions
- C library errors translated to typed Zig errors
- Thread-safe shared data with Mutex/RwLock
- Graceful shutdown with SIGTERM/SIGINT handling
- Request ID propagation through all operations
- ISO 8601 date parsing/formatting
- JSON Schema validation for output_schema