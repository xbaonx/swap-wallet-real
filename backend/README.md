# Backend Proxy (Wert + 1inch + Moralis)

Dịch vụ Express (Node 18) làm proxy an toàn cho Wert Partner API, 1inch, và Moralis. Phù hợp deploy trên Render.com.

## Tính năng
- POST `/api/wert/create-session`: tạo session Wert, hỗ trợ idempotency (`x-idempotency-key`), lưu SQLite.
- GET `/api/wert/sessions?wallet=0x...`: liệt kê session theo ví.
- POST `/api/wert/webhook`: nhận webhook từ Wert, lưu log và cập nhật trạng thái session.
- GET `/api/oneinch/*`: proxy 1inch, tự chèn `Authorization: Bearer <ONEINCH_API_KEY>`.
- GET `/api/moralis/*`: proxy Moralis, tự chèn `X-API-Key: <MORALIS_API_KEY>`.
- `/healthz`: health check.
- Bảo mật cơ bản: Helmet, CORS whitelist, rate limit (60 req/phút/IP).

## Yêu cầu
- Node 18.x
- SQLite (embedded thông qua better-sqlite3)

## Biến môi trường (ENV)
Bắt buộc cho Wert:
- `WERT_CREATE_SESSION_URL` (sandbox/prod create-session endpoint của Wert)
- `WERT_API_KEY`
- `WERT_PARTNER_ID` (nếu không truyền từ client)
- `WERT_ENV` = `sandbox` | `production`
- `WERT_AUTH_SCHEME` = `bearer` | `x-api-key` (mặc định `bearer`)

Proxy 1inch/Moralis:
- `ONEINCH_API_KEY`
- `MORALIS_API_KEY`
- `ONEINCH_UPSTREAM_BASE` (mặc định `https://api.1inch.dev`)
- `MORALIS_UPSTREAM_BASE` (mặc định `https://deep-index.moralis.io/api/v2.2`)

Khác:
- `PORT` (Render cung cấp)
- `DB_PATH` (ví dụ `/var/data/app.db` khi dùng Persistent Disk trên Render)
- `CORS_ORIGINS` (danh sách origin, phân tách bằng dấu phẩy; để trống => cho phép tất cả - chỉ nên dùng dev)

Xem mẫu `backend/.env.example`.

## Chạy cục bộ
```bash
cd backend
cp .env.example .env
# Chỉnh các biến ENV phù hợp (sandbox)
npm install
npm start
# Server chạy ở http://localhost:3000
```

Test nhanh:
```bash
curl http://localhost:3000/healthz

# 1inch proxy tokens (BSC)
curl 'http://localhost:3000/api/oneinch/swap/v6.0/56/tokens'

# Moralis proxy balances (BSC)
curl 'http://localhost:3000/api/moralis/0x0123456789abcdef0123456789abcdef01234567/erc20?chain=bsc&limit=5'

# Wert create session
curl -X POST http://localhost:3000/api/wert/create-session \
  -H 'Content-Type: application/json' \
  -H 'x-idempotency-key: test-123' \
  -d '{
    "flow_type":"simple_full_restrict",
    "wallet_address":"0x0123456789abcdef0123456789abcdef01234567",
    "currency":"USD",
    "commodity":"TT",
    "network":"bsc",
    "currency_amount":50
  }'
```

## Deploy lên Render.com
1. Tạo dịch vụ Web (Node)
   - Build Command: `npm ci`
   - Start Command: `node index.js`
   - Region: gần người dùng.
2. Thêm Persistent Disk (tùy chọn nhưng khuyến nghị)
   - Mount path: `/var/data`
   - ENV: `DB_PATH=/var/data/app.db`
3. Cấu hình ENV
   - Bắt buộc: `WERT_CREATE_SESSION_URL`, `WERT_API_KEY`, `WERT_PARTNER_ID`, `WERT_ENV`
   - Proxy: `ONEINCH_API_KEY`, `MORALIS_API_KEY`
   - Khuyến nghị: `CORS_ORIGINS=https://your.app.domain`
4. Deploy. Lấy URL service, ví dụ: `https://your-service.onrender.com`.
5. Cập nhật app mobile `.env`:
   - `WERT_BACKEND_BASE_URL=https://your-service.onrender.com`
   - `ONEINCH_PROXY_URL=https://your-service.onrender.com/api/oneinch`
   - `MORALIS_PROXY_URL=https://your-service.onrender.com/api/moralis`

## Webhook
- Endpoint: `POST /api/wert/webhook`
- Lưu ý: có thể bổ sung xác minh chữ ký nếu Wert hỗ trợ. Hiện tại service lưu log và cập nhật trạng thái theo `sessionId` & `status` trong payload.

## Ghi chú bảo mật
- Luôn cấu hình `CORS_ORIGINS` khi lên production.
- Không bao giờ để lộ API key trong mobile app. Luôn dùng proxy URLs ở client.
