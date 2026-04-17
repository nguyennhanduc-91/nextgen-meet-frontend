# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Cài đặt thư viện TRƯỚC (Để Lõi phòng họp xuất hiện trong node_modules)
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 3. GHI ĐÈ ẢNH SEO (DÀNH CHO ZALO/FACEBOOK) BẰNG ẢNH MỚI
RUN mkdir -p public/images && \
    echo '<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#000"/><text x="50%" y="50%" font-family="sans-serif" font-size="60" font-weight="bold" fill="#dc2626" text-anchor="middle">Thanh Nguyen Group</text></svg>' > public/images/livekit-meet-open-graph.png && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    cp public/images/livekit-meet-open-graph.png public/images/livekit-meet-home.svg

# 4. SCRIPT XỬ LÝ ĐA TẦNG (SEO + GIAO DIỆN + LÕI PHÒNG HỌP)
RUN cat <<'EOF' > rebrand.js
const fs = require('fs');
const path = require('path');

// TẦNG 1: Dịch mã nguồn gốc (Trang chủ & Cấp quyền Host)
function walkSource(dir) {
  if (!fs.existsSync(dir)) return; // Fix an toàn kiểm tra thư mục tồn tại
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      if (!['node_modules', '.git', '.next', 'public'].includes(file)) walkSource(fullPath);
    } else {
      let content = fs.readFileSync(fullPath, 'utf-8');
      let orig = content;

      // A. Mở khóa quyền HOST (Quản trị viên)
      if (fullPath.endsWith('route.ts')) {
         content = content.replace(/roomJoin:\s*true/g, 'roomJoin: true, roomAdmin: true');
      }

      // B. SEO Metadata (Link Zalo)
      if (fullPath.endsWith('layout.tsx')) {
        content = content.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
        content = content.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.');
        content = content.replace(/meet\.livekit\.io/g, 'meet.thanhnguyen.group');
        content = content.replace(/@livekitted/g, '@thanhnguyen');
      }

      // C. Rebrand trang chủ Doanh nghiệp
      if (fullPath.endsWith('page.tsx') && fullPath.includes('app')) {
        // Thay Logo
        content = content.replace(/<img[^>]*livekit-meet-home\.svg[^>]*\/?>/g, '<div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center" }}><div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "50px", height: "50px", borderRadius: "14px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "24px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)" }}>TN</div><h1 style={{ fontSize: "40px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1></div>');
        
        // Dịch văn bản tĩnh
        content = content.replace(/Open source video conferencing app built on/g, 'Hệ thống hội nghị trực tuyến bảo mật cao của');
        content = content.replace(/LiveKit Components/g, 'Thanh Nguyen');
        content = content.replace(/LiveKit Cloud/g, 'Group');
        content = content.replace(/and Next\.js\./g, '');
        content = content.replace(/Try LiveKit Meet for free with our live demo project\./g, 'Khởi tạo phòng họp bảo mật ngay lập tức.');
        content = content.replace(/Try NextGen Meet for free with our live demo project\./g, 'Khởi tạo phòng họp bảo mật ngay lập tức.');
        content = content.replace(/"Demo"/g, '"Họp Nhanh"');
        content = content.replace(/"Custom"/g, '"Phòng Riêng"');
        content = content.replace(/"Start Meeting"/g, '"Bắt Đầu Cuộc Họp"');
        content = content.replace(/Enable end-to-end encryption/g, 'Kích hoạt mã hóa bảo mật cấp cao (E2EE)');
        content = content.replace(/Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server\./g, 'Truy cập hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.');
        content = content.replace(/LiveKit Server URL/g, 'Địa chỉ máy chủ nội bộ (Server URL)');
        content = content.replace(/"Connect"/g, '"Kết Nối"');
        
        // Sửa Footer
        content = content.replace(/Hosted on/g, 'Bản quyền © 2026 thuộc về');
        content = content.replace(/\. Source code on/g, '');
        content = content.replace(/<a[^>]*href=["'][^"']*github\.com\/livekit[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Thanh Nguyen</b>');
        content = content.replace(/<a[^>]*href=["'][^"']*livekit\.io[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Group</b>');
      }

      if (content !== orig) fs.writeFileSync(fullPath, content, 'utf-8');
    }
  }
}
// FIX: Quét toàn bộ thư mục gốc thay vì chỉ quét thư mục 'src'
walkSource('.');

// TẦNG 2: Dịch Lõi thư viện (Bên trong phòng họp)
function patchNodeModules(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      patchNodeModules(fullPath);
    } else if (fullPath.endsWith('.js') || fullPath.endsWith('.mjs')) {
      let content = fs.readFileSync(fullPath, 'utf-8');
      let orig = content;
      
      // Dịch chuẩn xác các nút bấm
      content = content.replace(/"Microphone"/g, '"Micro"');
      content = content.replace(/"Camera"/g, '"Máy ảnh"');
      content = content.replace(/"Share screen"/g, '"Chia sẻ"');
      content = content.replace(/"Stop sharing"/g, '"Dừng chia sẻ"');
      content = content.replace(/"Chat"/g, '"Trò chuyện"');
      content = content.replace(/"Settings"/g, '"Cài đặt"');
      content = content.replace(/"Leave"/g, '"Rời phòng"');
      
      // Menu Admin (Host Controls)
      content = content.replace(/"Disable camera"/g, '"Tắt máy ảnh"');
      content = content.replace(/"Enable camera"/g, '"Bật máy ảnh"');
      content = content.replace(/"Mute"/g, '"Tắt mic"');
      content = content.replace(/"Unmute"/g, '"Bật mic"');
      content = content.replace(/"Remove from room"/g, '"Mời ra khỏi phòng"');
      
      // Dịch tùy chọn thiết bị
      content = content.replace(/"Select microphone"/g, '"Chọn Micro"');
      content = content.replace(/"Select camera"/g, '"Chọn Máy ảnh"');
      content = content.replace(/"Default"/g, '"Mặc định"');

      if (content !== orig) fs.writeFileSync(fullPath, content, 'utf-8');
    }
  }
}
patchNodeModules('node_modules/@livekit/components-react/dist');

EOF
RUN node rebrand.js

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
