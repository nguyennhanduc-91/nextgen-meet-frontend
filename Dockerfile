# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# --- CHIẾN DỊCH NÂNG CẤP GIAO DIỆN ENTERPRISE (THANH NGUYEN GROUP) ---

# 1. Tạo file ảnh SVG ảo định tuyến bộ nhớ đệm (Fix lỗi 404)
RUN mkdir -p public/images && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/favicon.ico

# 2. SCRIPT THIẾT KẾ LẠI TOÀN BỘ GIAO DIỆN CHÍNH
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
      // A. ĐẬP BỎ VÀ XÂY MỚI KHỐI HEADER (LOGO & SLOGAN) THEO CHUẨN CAO CẤP
      // ====================================================================
      if (fullPath.includes('page.tsx')) {
        const newHeader = `<div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1.25rem", marginBottom: "2.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "60px", height: "60px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "28px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)", border: "1px solid rgba(255,255,255,0.1)" }}>TN</div>
            <h1 style={{ fontSize: "46px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "system-ui, sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>
          <div style={{ textAlign: "center", maxWidth: "600px" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.2rem", fontWeight: "500", margin: "0 0 8px 0" }}>Nền tảng hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>`;
        
        // Thay thế toàn bộ thẻ <div className="header">...</div> cũ bằng thiết kế mới
        content = content.replace(/<div className="header">[\s\S]*?<\/div>/i, newHeader);

        // ====================================================================
        // B. ĐẬP BỎ VÀ XÂY MỚI FOOTER (CHUYÊN NGHIỆP, GỌN GÀNG)
        // ====================================================================
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
      // C. VIỆT HÓA CHUYÊN NGHIỆP CÁC NÚT BẤM VÀ MENU 
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

      // Thay thế tên hiển thị trên Tab trình duyệt
      content = content.replace(/LiveKit Meet/g, 'NextGen Meet');

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
