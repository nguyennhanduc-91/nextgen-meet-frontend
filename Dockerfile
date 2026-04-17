# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt các công cụ cần thiết, BAO GỒM CẢ GIT-LFS để kéo file ảnh gốc tránh lỗi Webpack
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .

# Kéo dữ liệu LFS
RUN git lfs install && git lfs pull

# --- CHIẾN DỊCH ĐẠI TU GIAO DIỆN (PHIÊN BẢN QUÉT ĐỆ QUY TẬN GỐC) ---

# 1. GHI ĐÈ CÁC FILE ẢNH BẰNG SVG TRỐNG ĐỂ FIX TRIỆT ĐỂ LỖI 404 SERVICE WORKER
RUN mkdir -p public/images && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/favicon.ico

# 2. SCRIPT QUÉT ĐỆ QUY TOÀN BỘ PROJECT VÀ THAY THẾ MẠNH TAY
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
    } else if (fullPath.match(/\.(tsx|ts|jsx|js|html|json)$/)) {
      let content = fs.readFileSync(fullPath, 'utf-8');
      let orig = content;

      // Xóa triệt để Logo hình ảnh cũ và chèn HTML Logo Thanh Nguyen mới vào JSX
      if (fullPath.match(/\.(tsx|jsx)$/)) {
        content = content.replace(/<(?:img|Image)[^>]*livekit-meet-home\.svg[^>]*\/?>/gi, '<div style={{ display: "flex", alignItems: "center", gap: "12px", justifyContent: "center", paddingBottom: "1.5rem" }}><div style={{ width: "45px", height: "45px", backgroundColor: "#dc2626", borderRadius: "10px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "bold", fontSize: "22px", fontFamily: "sans-serif"}}>TN</div><span style={{ fontSize: "34px", fontWeight: "bold", color: "white", letterSpacing: "-0.05em", fontFamily: "sans-serif" }}>NextGen <span style={{ color: "#dc2626" }}>Meet</span></span></div>');
      }

      // Tiêu diệt toàn bộ thẻ <a> chứa LiveKit
      content = content.replace(/<a[^>]*href=["'][^"']*github\.com\/livekit[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Thanh Nguyen</b>');
      content = content.replace(/<a[^>]*href=["'][^"']*livekit\.io[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Group</b>');

      // Đổi tên thương hiệu (xử lý các ký tự khoảng trắng đặc biệt &nbsp;)
      content = content.replace(/LiveKit(?:&nbsp;|\s|{"\\u00A0"}|\\u00A0)*Meet/gi, 'NextGen Meet');
      content = content.replace(/LiveKit(?:&nbsp;|\s|{"\\u00A0"}|\\u00A0)*Components/gi, 'Thanh Nguyen');
      content = content.replace(/LiveKit(?:&nbsp;|\s|{"\\u00A0"}|\\u00A0)*Cloud/gi, 'Group');
      content = content.replace(/LiveKit(?:&nbsp;|\s|{"\\u00A0"}|\\u00A0)*Server/gi, 'Máy chủ TN');

      // Dịch từng đoạn Text chính xác
      content = content.replace(/Open source video conferencing app built on/gi, 'Hệ thống hội nghị trực tuyến bảo mật cao của');
      content = content.replace(/and Next\.js\./gi, '');
      
      content = content.replace(/Try NextGen Meet for free with our live demo project\./gi, 'Tạo hoặc tham gia phòng họp trực tuyến bảo mật ngay.');
      content = content.replace(/Connect NextGen Meet with a custom server using Group or Máy chủ TN\./gi, 'Kết nối mạng nội bộ an toàn bằng hệ thống máy chủ mã hóa của Thanh Nguyen Group.');

      // Dịch các Nút bấm & Nhãn UI
      content = content.replace(/>\s*Demo\s*</gi, '>Phòng ngẫu nhiên<');
      content = content.replace(/"Demo"/gi, '"Phòng ngẫu nhiên"');
      content = content.replace(/>\s*Custom\s*</gi, '>Phòng có sẵn<');
      content = content.replace(/"Custom"/gi, '"Phòng có sẵn"');
      content = content.replace(/>\s*Start Meeting\s*</gi, '>Bắt đầu cuộc họp<');
      content = content.replace(/"Start Meeting"/gi, '"Bắt đầu cuộc họp"');
      content = content.replace(/Enable end-to-end encryption/gi, 'Bật mã hóa đầu cuối (E2EE)');
      content = content.replace(/>\s*Connect\s*</gi, '>Kết nối<');

      // Dịch Footer
      content = content.replace(/Hosted on/gi, 'Bản quyền © 2026 thuộc về');
      content = content.replace(/\. Source code on/gi, '');

      // Chỉnh lại ngữ pháp (Thanh Nguyen, Group -> Thanh Nguyen và Group)
      content = content.replace(/Thanh Nguyen<\/b>\s*,\s*<b/gi, 'Thanh Nguyen</b> và <b');

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
