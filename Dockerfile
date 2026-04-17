# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt các công cụ cần thiết
RUN apk add --no-cache git bash sed git-lfs python3 make g++
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# --- BẮT ĐẦU CHIẾN DỊCH XÓA SẠCH LIVEKIT & REBRANDING ---

# 1. Ghi đè file Logo.tsx để xóa SVG LiveKit và thay bằng Logo NextGen Meet
RUN echo 'export default function Logo() { return <div style={{ display: "flex", alignItems: "center", gap: "8px" }}><div style={{ width: "32px", height: "32px", backgroundColor: "#dc2626", borderRadius: "8px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "bold", fontSize: "18px"}}>TN</div><span style={{ fontSize: "24px", fontWeight: "bold", color: "white", letterSpacing: "-0.05em" }}>NextGen<span style={{ color: "#dc2626" }}>Meet</span></span></div>; }' > src/components/Logo.tsx || true
RUN echo 'export default function Logo() { return <div style={{ display: "flex", alignItems: "center", gap: "8px" }}><div style={{ width: "32px", height: "32px", backgroundColor: "#dc2626", borderRadius: "8px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "bold", fontSize: "18px"}}>TN</div><span style={{ fontSize: "24px", fontWeight: "bold", color: "white", letterSpacing: "-0.05em" }}>NextGen<span style={{ color: "#dc2626" }}>Meet</span></span></div>; }' > components/Logo.tsx || true

# 2. Xóa các đoạn text tiếng Anh và thay bằng Tiếng Việt chuyên nghiệp trên trang chủ (page.tsx)
RUN find . -type f -name "page.tsx" -exec sed -i 's/Open source video conferencing app built on/Hệ thống hội nghị trực tuyến bảo mật cao của/g' {} + || true
RUN find . -type f -name "page.tsx" -exec sed -i 's/LiveKit Components, LiveKit Cloud and Next.js./Thanh Nguyen Group./g' {} + || true
RUN find . -type f -name "page.tsx" -exec sed -i 's/Hosted on <a[^>]*>LiveKit Cloud<\/a>\. Source code on <a[^>]*>GitHub<\/a>\./Được phát triển và vận hành độc quyền bởi Thanh Nguyen Group./g' {} + || true
RUN find . -type f -name "page.tsx" -exec sed -i 's/Try NextGen Meet for free with our live demo project./Tham gia phòng họp trực tuyến ngay với mã bảo mật./g' {} + || true
RUN find . -type f -name "page.tsx" -exec sed -i 's/Demo/Phòng ngẫu nhiên/g' {} + || true
RUN find . -type f -name "page.tsx" -exec sed -i 's/Custom/Phòng chỉ định/g' {} + || true

# 3. Đổi tên ứng dụng toàn cục
RUN find . -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.html" \) -exec sed -i 's/LiveKit Meet/NextGen Meet/g' {} + || true
RUN find . -type f -name "layout.tsx" -exec sed -i 's/title: "LiveKit Meet"/title: "NextGen Meet - Thanh Nguyen Group"/g' {} + || true

# --- KẾT THÚC REBRANDING ---

# Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# Build ứng dụng
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group" 
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

RUN pnpm run build

# --- CHẠY ỨNG DỤNG ---
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.0"

ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

COPY --from=builder /app ./
RUN corepack enable && corepack prepare pnpm@latest --activate

EXPOSE 3000
ENV PORT=3000

CMD ["pnpm", "start"]
