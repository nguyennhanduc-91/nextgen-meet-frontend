# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt các công cụ cần thiết, BAO GỒM CẢ GIT-LFS để kéo file ảnh gốc tránh lỗi Webpack
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .

# Kéo dữ liệu LFS
RUN git lfs install && git lfs pull

# --- CHIẾN DỊCH ĐẠI TU GIAO DIỆN (PHƯƠNG PHÁP AN TOÀN) ---

# 1. TẠO LOGO THANH NGUYEN ĐỂ GHI ĐÈ LÊN LOGO CŨ (Fix triệt để lỗi 404)
RUN mkdir -p public/images && cat <<'SVG' > public/images/livekit-meet-home.svg
<svg width="360" height="45" viewBox="0 0 360 45" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="5" width="35" height="35" rx="8" fill="#dc2626"/>
  <text x="17.5" y="29" font-family="Arial, sans-serif" font-size="18" font-weight="bold" fill="#ffffff" text-anchor="middle">TN</text>
  <text x="45" y="32" font-family="Arial, sans-serif" font-size="28" font-weight="bold" fill="#ffffff" letter-spacing="-0.5">NextGen <tspan fill="#dc2626">Meet</tspan></text>
</svg>
SVG

# 2. SCRIPT DỊCH THUẬT VÀ THAY THẾ TỪ KHÓA BẢO TOÀN CẤU TRÚC
RUN cat <<'EOF' > rebrand.js
const fs = require('fs');
const path = require('path');

function walk(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      if (!['node_modules', '.git', '.next', 'public'].includes(file)) {
        walk(fullPath);
      }
    } else if (fullPath.match(/\.(tsx|ts|jsx|js|html)$/)) {
      let content = fs.readFileSync(fullPath, 'utf-8');
      let orig = content;

      // Đổi tên thương hiệu
      content = content.replace(/LiveKit Meet/g, 'NextGen Meet');
      
      // Dịch word-by-word các câu text trên trang chủ
      content = content.replace(/Open source video conferencing app built on/g, 'Hệ thống hội nghị trực tuyến bảo mật cao của');
      content = content.replace(/LiveKit Components/g, 'Thanh Nguyen');
      content = content.replace(/LiveKit Cloud/g, 'Group');
      content = content.replace(/and Next\.js\./g, '');
      
      // Dịch các Nút bấm & Nhãn
      content = content.replace(/Try NextGen Meet for free with our live demo project\./g, 'Tạo hoặc tham gia phòng họp trực tuyến bảo mật ngay.');
      content = content.replace(/>Demo</g, '>Phòng ngẫu nhiên<');
      content = content.replace(/"Demo"/g, '"Phòng ngẫu nhiên"');
      content = content.replace(/>Custom</g, '>Phòng có sẵn<');
      content = content.replace(/"Custom"/g, '"Phòng có sẵn"');
      content = content.replace(/>Start Meeting</g, '>Bắt đầu cuộc họp<');
      content = content.replace(/"Start Meeting"/g, '"Bắt đầu cuộc họp"');
      content = content.replace(/Enable end-to-end encryption/g, 'Bật mã hóa đầu cuối (E2EE)');
      
      // Chỉnh sửa Footer
      content = content.replace(/Hosted on/g, 'Bản quyền © 2026 thuộc về');
      content = content.replace(/\. Source code on/g, '');
      content = content.replace(/>GitHub</g, '></');

      if (content !== orig) {
        fs.writeFileSync(fullPath, content, 'utf-8');
      }
    }
  }
}
walk('.');
EOF
RUN node rebrand.js

# Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# --- NHÚNG BIẾN MÔI TRƯỜNG BUILD ---
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group" 
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Build ứng dụng
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
