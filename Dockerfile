# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# Cài đặt các công cụ cần thiết
RUN apk add --no-cache git bash python3 make g++
RUN git clone https://github.com/livekit/meet.git .

# --- CHIẾN DỊCH ĐẠI TU GIAO DIỆN & TỐI ƯU HÓA BẰNG SCRIPT ---
# Tạo và chạy script quét/thay thế mã nguồn đa dòng
RUN cat <<'EOF' > rebrand.js
const fs = require('fs');
const path = require('path');

function replaceInFile(filePath, replacements) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf-8');
  let originalContent = content;
  replacements.forEach(([regex, replace]) => {
    content = content.replace(regex, replace);
  });
  if (content !== originalContent) {
    fs.writeFileSync(filePath, content, 'utf-8');
  }
}

// 1. Dọn sạch trang chủ (page.tsx)
const pagePath = 'src/app/page.tsx';
if (fs.existsSync(pagePath)) {
  replaceInFile(pagePath, [
    // Xóa thẻ ảnh chứa logo Livekit và thay bằng Logo Thanh Nguyen Group thiết kế bằng CSS hiện đại
    [/<img[^>]*livekit-meet-home\.svg[^>]*\/?>/g, '<h1 style={{ fontSize: "3rem", fontWeight: "800", color: "#ffffff", marginBottom: "0.5rem", display: "flex", alignItems: "center", justifyContent: "center", letterSpacing: "-0.05em" }}><span style={{ color: "#ffffff", backgroundColor: "#dc2626", padding: "6px 14px", borderRadius: "10px", marginRight: "12px", fontSize: "2.5rem", boxShadow: "0 4px 14px 0 rgba(220, 38, 38, 0.39)" }}>TN</span>NextGen Meet</h1>'],
    // Sửa câu Slogan
    [/<h2[^>]*>[\s\S]*?<\/h2>/g, '<h2 style={{ fontSize: "1.25rem", color: "#a1a1aa", fontWeight: "400", marginTop: "0.5rem" }}>Hệ thống hội nghị trực tuyến cao cấp thuộc hệ sinh thái <b style={{color:"#ffffff"}}>Thanh Nguyen Group</b>.</h2>'],
    // Sửa phần bản quyền ở Footer
    [/Hosted on[\s\S]*?GitHub<\/a>\./g, 'Bản quyền © 2026 thuộc về Thanh Nguyen Group. Nền tảng được tối ưu hóa cho mạng lưới nội bộ.'],
    // Việt hóa các nút bấm
    [/Try LiveKit Meet for free with our live demo project\./g, 'Tạo hoặc tham gia phòng họp trực tuyến bảo mật ngay.'],
    [/Try NextGen Meet for free with our live demo project\./gi, 'Tạo hoặc tham gia phòng họp trực tuyến bảo mật ngay.'],
    [/Demo/g, 'Phòng ngẫu nhiên'],
    [/Custom/g, 'Phòng có sẵn'],
    [/Start Meeting/g, 'Bắt đầu cuộc họp'],
    [/Enable end-to-end encryption/g, 'Kích hoạt mã hóa bảo mật đầu cuối (E2EE)']
  ]);
}

// 2. Dọn sạch Meta SEO và cấu hình (layout.tsx)
const layoutPath = 'src/app/layout.tsx';
if (fs.existsSync(layoutPath)) {
  replaceInFile(layoutPath, [
    [/LiveKit Meet/g, 'NextGen Meet'],
    [/LiveKit is an open source WebRTC project[^"']*/g, 'Hệ thống họp trực tuyến bảo mật chất lượng cao của Thanh Nguyen Group.'],
    [/meet\.livekit\.io/g, 'meet.thanhnguyen.group'],
    [/@livekitted/g, '@thanhnguyen']
  ]);
}

// 3. Quét toàn bộ components để thay thế các chữ LiveKit Meet còn sót
function walkAndReplace(dir) {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      walkAndReplace(fullPath);
    } else if (fullPath.endsWith('.tsx') || fullPath.endsWith('.ts')) {
      replaceInFile(fullPath, [
        [/LiveKit Meet/gi, 'NextGen Meet']
      ]);
    }
  }
}
walkAndReplace('src');
EOF

RUN node rebrand.js

// Xóa triệt để các file ảnh gốc để trình duyệt không tự động bắt link cache
RUN rm -f public/images/livekit-meet-open-graph.png public/images/livekit-meet-home.svg public/favicon.ico || true

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
