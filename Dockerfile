# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 1. CÀI ĐẶT THƯ VIỆN TRƯỚC (RẤT QUAN TRỌNG ĐỂ CÓ THỂ CAN THIỆP VÀO LÕI GIAO DIỆN PHÒNG HỌP)
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 2. XÓA SẠCH ẢNH SEO CŨ CỦA LIVEKIT VÀ TẠO ẢNH TRỐNG BẢO TOÀN HỆ THỐNG
RUN mkdir -p public/images && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="100%" height="100%" fill="#111"/></svg>' > public/images/livekit-meet-open-graph.png && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg

# 3. SCRIPT CAN THIỆP ĐA TẦNG (SEO ZALO + GIAO DIỆN NGOÀI + QUYỀN HOST + LÕI PHÒNG HỌP)
RUN cat <<'EOF' > rebrand.js
const fs = require('fs');
const path = require('path');

function replaceSafely(filePath, replacements) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf-8');
  let orig = content;
  for (const [regex, replacement] of replacements) {
    content = content.replace(regex, replacement);
  }
  if (content !== orig) fs.writeFileSync(filePath, content, 'utf-8');
}

// ====================================================================
// TẦNG 1: SỬA TẬN GỐC SEO (ĐỂ GỬI LINK ZALO HIỆN ĐÚNG THƯƠNG HIỆU)
// ====================================================================
replaceSafely('src/app/layout.tsx', [
  [/LiveKit Meet \| Conference app build with LiveKit open source/g, 'NextGen Meet | Thanh Nguyen Group'],
  [/LiveKit is an open source WebRTC project[^"']*/g, 'Hệ thống hội nghị trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.'],
  [/NextGen Meet/g, 'Hệ thống Họp Trực Tuyến - Thanh Nguyen Group'],
  [/@livekitted/g, '@thanhnguyen']
]);

// ====================================================================
// TẦNG 2: MỞ KHÓA QUYỀN QUẢN TRỊ (HOST CONTROLS) TRONG API TOKEN
// ====================================================================
// Cấp quyền Admin cho mọi Token được tạo ra (Để bạn kick/mute được người khác)
replaceSafely('src/app/api/connection-details/route.ts', [
  [/roomJoin:\s*true,/g, 'roomJoin: true, roomAdmin: true,']
]);

// ====================================================================
// TẦNG 3: ĐẬP BỎ VÀ XÂY MỚI TRANG CHỦ THEO CHUẨN ENTERPRISE
// ====================================================================
replaceSafely('src/app/page.tsx', [
  [/<div className="header">[\s\S]*?<\/div>/i, `<div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1.25rem", marginBottom: "2.5rem" }}><div style={{ display: "flex", alignItems: "center", gap: "16px" }}><div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "60px", height: "60px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "28px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)", border: "1px solid rgba(255,255,255,0.1)" }}>TN</div><h1 style={{ fontSize: "46px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "system-ui, sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1></div><div style={{ textAlign: "center", maxWidth: "600px" }}><p style={{ color: "#e4e4e7", fontSize: "1.2rem", fontWeight: "500", margin: "0 0 8px 0" }}>Hệ thống hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p><p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p></div></div>`],
  [/<footer[^>]*>[\s\S]*?<\/footer>/i, `<footer style={{ marginTop: "auto", padding: "2.5rem 1rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid rgba(255,255,255,0.05)" }}><p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#a1a1aa"}}>Thanh Nguyen Group</b>. All rights reserved.</p><p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px" }}><span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 8px #10b981" }}></span> Hệ thống được mã hóa đầu cuối (E2EE) đảm bảo an toàn dữ liệu tuyệt đối.</p></footer>`],
  [/>\s*Demo\s*</g, '>Họp Nhanh<'],
  [/"Demo"/g, '"Họp Nhanh"'],
  [/>\s*Custom\s*</g, '>Phòng Riêng<'],
  [/"Custom"/g, '"Phòng Riêng"'],
  [/>\s*Start Meeting\s*</g, '>Bắt Đầu Cuộc Họp<'],
  [/"Start Meeting"/g, '"Bắt Đầu Cuộc Họp"'],
  [/>\s*Connect\s*</g, '>Kết Nối<'],
  [/placeholder="LiveKit Server URL[^"]*"/gi, 'placeholder="Địa chỉ máy chủ nội bộ (Server URL)"'],
  [/Enable end-to-end encryption/gi, 'Kích hoạt mã hóa bảo mật cấp cao (E2EE)'],
  [/Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server\./gi, 'Truy cập vào hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.'],
  [/Try LiveKit Meet for free with our live demo project\./gi, 'Khởi tạo phòng họp ngay lập tức mà không cần cài đặt phần mềm.']
]);

// ====================================================================
// TẦNG 4: DỊCH LÕI THƯ VIỆN BÊN TRONG PHÒNG HỌP (NPM PATCHING)
// ====================================================================
function patchLibrary(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      patchLibrary(fullPath);
    } else if (fullPath.endsWith('.js') || fullPath.endsWith('.mjs')) {
      let content = fs.readFileSync(fullPath, 'utf-8');
      let orig = content;
      
      // Dịch Thanh công cụ
      content = content.replace(/"Microphone"/g, '"Micro"');
      content = content.replace(/"Camera"/g, '"Máy ảnh"');
      content = content.replace(/"Share screen"/g, '"Chia sẻ"');
      content = content.replace(/"Stop sharing"/g, '"Dừng chia sẻ"');
      content = content.replace(/"Chat"/g, '"Trò chuyện"');
      content = content.replace(/"Settings"/g, '"Cài đặt"');
      content = content.replace(/"Leave"/g, '"Rời phòng"');
      
      // Dịch Menu Admin / Ngữ cảnh
      content = content.replace(/"Disable camera"/g, '"Tắt máy ảnh"');
      content = content.replace(/"Enable camera"/g, '"Bật máy ảnh"');
      content = content.replace(/"Mute"/g, '"Tắt mic"');
      content = content.replace(/"Unmute"/g, '"Bật mic"');
      content = content.replace(/"Remove from room"/g, '"Mời ra khỏi phòng"');
      content = content.replace(/"Select microphone"/g, '"Chọn Micro"');
      content = content.replace(/"Select camera"/g, '"Chọn Máy ảnh"');

      if (content !== orig) fs.writeFileSync(fullPath, content, 'utf-8');
    }
  }
}
// Chọc thẳng vào thư mục biên dịch của LiveKit để Việt hóa
patchLibrary('node_modules/@livekit/components-react/dist');
patchLibrary('node_modules/@livekit/components-core/dist');

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
