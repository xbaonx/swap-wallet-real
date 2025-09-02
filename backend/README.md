# Backend Proxy (1inch + Moralis)

Dịch vụ Express (Node 18) làm proxy an toàn cho 1inch và Moralis, đồng thời cung cấp cấu hình cho app (Transak mở trực tiếp từ app). Phù hợp deploy trên Render.com.

## Tính năng
- GET `/api/oneinch/*`: proxy 1inch, tự chèn `Authorization: Bearer <ONEINCH_API_KEY>`.
- GET `/api/moralis/*`: proxy Moralis, tự chèn `X-API-Key: <MORALIS_API_KEY>`.
- GET `/api/config`: trả về cờ tính năng và `transak_buy_url` để app mở ngoài.
- POST `/api/analytics/track`: lưu sự kiện analytics vào SQLite.
- POST `/api/notify/register`: đăng ký thiết bị nhận push (OneSignal).
- GET `/healthz`: health check.
- Bảo mật cơ bản: Helmet, CORS whitelist, rate limit (60 req/phút/IP).

## Yêu cầu
- Node 18.x
- SQLite (embedded thông qua better-sqlite3)

## Biến môi trường (ENV)
- `PORT` (Render cung cấp)
- `DB_PATH` (ví dụ `/var/data/app.db` khi dùng Persistent Disk trên Render)
- `CORS_ORIGINS` (danh sách origin, phân tách bằng dấu phẩy; để trống => cho phép tất cả - chỉ nên dùng dev)
- `APP_ENV` = `dev` | `staging` | `production`
- `TRANSAK_BUY_URL` (URL Transak để app mở ngoài)
- `ONEINCH_API_KEY`, `ONEINCH_UPSTREAM_BASE` (mặc định `https://api.1inch.dev`)
- `MORALIS_API_KEY`, `MORALIS_UPSTREAM_BASE` (mặc định `https://deep-index.moralis.io/api/v2.2`)
- Tuỳ chọn: `JWT_SECRET` hoặc `HMAC_SECRET` (bảo vệ các endpoint ghi), `ONESIGNAL_APP_ID`, `ONESIGNAL_API_KEY`

Xem mẫu `backend/.env.example`.

## Chạy cục bộ
```bash
cd backend
cp .env.example .env
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
   - Proxy: `ONEINCH_API_KEY`, `MORALIS_API_KEY`
   - Khuyến nghị: `CORS_ORIGINS=https://your.app.domain`
   - Tùy chọn: `TRANSAK_BUY_URL=https://global.transak.com...?apiKey=...`
4. Deploy. Lấy URL service, ví dụ: `https://your-service.onrender.com`.
5. Cập nhật app mobile `.env` (frontend):
   - `BACKEND_BASE_URL=https://your-service.onrender.com`

## Ghi chú bảo mật
- Luôn cấu hình `CORS_ORIGINS` khi lên production.
- Không bao giờ để lộ API key trong mobile app. Luôn dùng proxy URLs ở client.
