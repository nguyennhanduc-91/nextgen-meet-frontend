FROM node:18-alpine AS builder
WORKDIR /app

# Cài đặt git và git-lfs để tải ảnh
RUN apk add --no-cache git bash sed git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# --- THAY ĐỔI THƯƠNG HIỆU ---
RUN find . -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.html" \) -exec sed -i 's/LiveKit Meet/NextGen Meet/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/title: "LiveKit Meet"/title: "NextGen Meet - Thanh Nguyen Group"/g' {} +
RUN find . -type f -name "layout.tsx" -exec sed -i 's/description: "LiveKit Meet"/description: "Nền tảng họp trực tuyến cao cấp bởi Thanh Nguyen Group"/g' {} +
RUN if [ -f "components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' components/Header.tsx; fi
RUN if [ -f "src/components/Header.tsx" ]; then sed -i 's/<Logo \/>/<h2 className="text-xl font-bold text-white">NextGen Meet<\/h2>/g' src/components/Header.tsx; fi

# Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# --- NHÚNG BIẾN MÔI TRƯỜNG ---
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
# BỔ SUNG BIẾN NÀY ĐỂ FIX LỖI API 500
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group" 
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Build ứng dụng
RUN pnpm run build

# --- CHẠY ỨNG DỤNG ---
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.0"

ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
# BỔ SUNG BIẾN NÀY ĐỂ FIX LỖI API 500
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Copy TOÀN BỘ thư mục từ bước build sang
COPY --from=builder /app ./

# Kích hoạt lại pnpm trong môi trường chạy
RUN corepack enable && corepack prepare pnpm@latest --activate

EXPOSE 3000
ENV PORT=3000

# Chạy ứng dụng bằng lệnh chuẩn của Next.js
CMD ["pnpm", "start"]
