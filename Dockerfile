# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# --- CHIẾN DỊCH NÂNG CẤP ENTERPRISE & MỞ KHÓA TÍNH NĂNG HOST ---

# 1. Tạo file SVG ảo định tuyến bộ nhớ đệm (Fix lỗi 404 hình ảnh)
RUN mkdir -p public/images && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/favicon.ico

# 2. SCRIPT XỬ LÝ LOGIC BACKEND VÀ GIAO DIỆN FRONTEND
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

      // ====================================================================
      // PHẦN 1: MỞ KHÓA QUYỀN QUẢN TRỊ (HOST CONTROLS) TRONG API TOKEN
      // ====================================================================
      // Tiêm quyền roomAdmin: true vào hàm tạo Token của LiveKit Backend
      if (fullPath.includes('route.ts') || fullPath.includes('token')) {
        content = content.replace(/roomJoin:\s*true,/g, 'roomJoin: true, roomAdmin: true,');
      }

      // ====================================================================
      // PHẦN 2: THIẾT KẾ GIAO DIỆN TRANG CHỦ ENTERPRISE (THANH NGUYEN GROUP)
      // ====================================================================
      if (fullPath.includes('page.tsx')) {
        const newHeader = `<div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1.25rem", marginBottom: "2.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "60px", height: "60px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "28px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)", border: "1px solid rgba(255,255,255,0.1)" }}>TN</div>
            <h1 style={{ fontSize: "46px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "system-ui, sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>
          <div style={{ textAlign: "center", maxWidth: "600px" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.2rem", fontWeight: "500", margin: "0 0 8px 0" }}>Hệ thống hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>`;
        content = content.replace(/<div className="header">[\s\S]*?<\/div>/i, newHeader);

        const newFooter = `<footer style={{ marginTop: "auto", padding: "2.5rem 1rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid rgba(255,255,255,0.05)" }}>
          <p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#a1a1aa"}}>Thanh Nguyen Group</b>. All rights reserved.</p>
          <p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px" }}>
            <span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 8px #10b981" }}></span> 
            Hệ thống được mã hóa đầu cuối (E2EE) đảm bảo an toàn dữ liệu tuyệt đối.
          </p>
        </footer>`;
        content = content.replace(/<footer[^>]*>[\s\S]*?<\/footer>/i, newFooter);
      }

      // ====================================================================
      // PHẦN 3: VIỆT HÓA SÂU BÊN TRONG PHÒNG HỌP & QUYỀN HOST
      // ====================================================================
      // Thanh công cụ chính
      content = content.replace(/>\s*Microphone\s*</g, '>Micro<');
      content = content.replace(/"Microphone"/g, '"Micro"');
      content = content.replace(/>\s*Camera\s*</g, '>Máy ảnh<');
      content = content.replace(/"Camera"/g, '"Máy ảnh"');
      content = content.replace(/>\s*Share screen\s*</g, '>Chia sẻ màn hình<');
      content = content.replace(/"Share screen"/g, '"Chia sẻ màn hình"');
      content = content.replace(/>\s*Stop sharing\s*</g, '>Dừng chia sẻ<');
      content = content.replace(/"Stop sharing"/g, '"Dừng chia sẻ"');
      content = content.replace(/>\s*Chat\s*</g, '>Trò chuyện<');
      content = content.replace(/"Chat"/g, '"Trò chuyện"');
      content = content.replace(/>\s*Settings\s*</g, '>Bảng điều khiển<');
      content = content.replace(/"Settings"/g, '"Bảng điều khiển"');
      content = content.replace(/>\s*Leave\s*</g, '>Rời phòng<');
      content = content.replace(/"Leave"/g, '"Rời phòng"');
      
      // Menu cấu hình thiết bị (Nút [v])
      content = content.replace(/"Default"/g, '"Mặc định"');
      content = content.replace(/"Select microphone"/g, '"Chọn Micro"');
      content = content.replace(/"Select camera"/g, '"Chọn Máy ảnh"');
      
      // Menu Quản trị viên (Host Controls) khi click vào người khác
      content = content.replace(/"Mute"/g, '"Tắt mic"');
      content = content.replace(/"Unmute"/g, '"Bật mic"');
      content = content.replace(/"Disable camera"/g, '"Tắt máy ảnh"');
      content = content.replace(/"Enable camera"/g, '"Bật máy ảnh"');
      content = content.replace(/"Remove from room"/gi, '"Mời khỏi phòng"');
      content = content.replace(/>\s*Remove\s*</g, '>Mời ra<');

      // Bảng Settings (Chất lượng mạng)
      content = content.replace(/>\s*Audio and Video\s*</g, '>Âm thanh & Hình ảnh<');
      content = content.replace(/>\s*Connection Quality\s*</g, '>Chất lượng kết nối<');

      // ====================================================================
      // PHẦN 4: VIỆT HÓA GIAO DIỆN BÊN NGOÀI & SEO
      // ====================================================================
      content = content.replace(/>\s*Demo\s*</g, '>Họp Nhanh<');
      content = content.replace(/"Demo"/g, '"Họp Nhanh"');
      content = content.replace(/>\s*Custom\s*</g, '>Phòng Riêng<');
      content = content.replace(/"Custom"/g, '"Phòng Riêng"');
      content = content.replace(/Try LiveKit Meet for free with our live demo project\./gi, 'Khởi tạo phòng họp ngay lập tức mà không cần cài đặt phần mềm.');
      content = content.replace(/Try NextGen Meet for free with our live demo project\./gi, 'Khởi tạo phòng họp ngay lập tức mà không cần cài đặt phần mềm.');
      content = content.replace(/Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server\./gi, 'Truy cập vào hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.');
      content = content.replace(/Connect NextGen Meet with a custom server using Group or Máy chủ TN\./gi, 'Truy cập vào hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.');
      content = content.replace(/LiveKit Server URL/gi, 'Địa chỉ máy chủ nội bộ (Server URL)');
      content = content.replace(/>\s*Start Meeting\s*</g, '>Bắt Đầu Cuộc Họp<');
      content = content.replace(/"Start Meeting"/g, '"Bắt Đầu Cuộc Họp"');
      content = content.replace(/Enable end-to-end encryption/gi, 'Kích hoạt mã hóa bảo mật cấp cao (E2EE)');
      content = content.replace(/>\s*Connect\s*</g, '>Kết Nối<');
      content = content.replace(/LiveKit(?:&nbsp;|\s|{"\\u00A0"}|\\u00A0)+Meet/gi, 'NextGen Meet');
      content = content.replace(/LiveKit/g, 'NextGen Meet'); // Dọn dẹp nốt tàn dư

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
