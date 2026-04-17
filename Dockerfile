# Dùng node 18 alpine cho nhẹ
FROM node:18-alpine AS builder

WORKDIR /app

# Cài đặt công cụ
RUN apk add --no-cache git bash sed

# Kéo source code gốc của LiveKit Meet
RUN git clone https://github.com/livekit/meet.git .

# =========================================================
# TỰ ĐỘNG FIX THƯƠNG HIỆU THÀNH NEXTGEN MEET (THANH NGUYEN)
# =========================================================
RUN find . -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.html" \) -exec sed -i 's/LiveKit Meet/NextGen Meet/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/title: "LiveKit Meet"/title: "NextGen Meet - Thanh Nguyen Group"/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/description: "LiveKit Meet"/description: "Nền tảng họp trực tuyến cao cấp bởi Thanh Nguyen Group"/g' {} +
RUN if [ -f "components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' components/Header.tsx; fi
RUN if [ -f "src/components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' src/components/Header.tsx; fi

# Cài đặt pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# =========================================================
# NHÚNG CỨNG BIẾN MÔI TRƯỜNG VÀO CODE ĐỂ BUILD TỰ ĐỘNG
# =========================================================
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Build source
RUN pnpm run build

# =========================================================
# ĐÓNG GÓI CHẠY APP
# =========================================================
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV HOSTNAME "0.0.0.0"

# Nhúng lại biến môi trường cho môi trường chạy thực tế
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
