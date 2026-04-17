FROM node:18-alpine AS builder
WORKDIR /app

# BỔ SUNG QUAN TRỌNG: Thêm git-lfs để tải ảnh background không bị lỗi
RUN apk add --no-cache git bash sed git-lfs

RUN git clone https://github.com/livekit/meet.git .

# Kích hoạt git-lfs và kéo hình ảnh gốc về
RUN git lfs install && git lfs pull

# --- THAY ĐỔI THƯƠNG HIỆU ---
RUN find . -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.html" \) -exec sed -i 's/LiveKit Meet/NextGen Meet/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/title: "LiveKit Meet"/title: "NextGen Meet - Thanh Nguyen Group"/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/description: "LiveKit Meet"/description: "Nền tảng họp trực tuyến cao cấp bởi Thanh Nguyen Group"/g' {} +
RUN if [ -f "components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' components/Header.tsx; fi
RUN if [ -f "src/components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' src/components/Header.tsx; fi

RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# --- NHÚNG BIẾN MÔI TRƯỜNG ---
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

RUN pnpm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.0"

ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
