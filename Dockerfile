# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Cài đặt thư viện NPM
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 3. TẢI ẢNH SEO ZALO TỪ GITHUB
RUN mkdir -p public/images && \
    wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg

# 4. SCRIPT DỊCH THUẬT VÀ TIÊM QUYỀN HOST (AN TOÀN TUYỆT ĐỐI)
RUN cat <<'EOF' > patcher.js
const fs = require('fs');

function replaceStr(file, searchStr, replaceStr) {
    if (!fs.existsSync(file)) return;
    let content = fs.readFileSync(file, 'utf8');
    if (content.includes(searchStr)) {
        content = content.split(searchStr).join(replaceStr);
        fs.writeFileSync(file, content, 'utf8');
    }
}

// 4.1. MỞ KHÓA QUYỀN QUẢN TRỊ VIÊN (ROOM ADMIN)
const apiFile = 'app/api/connection-details/route.ts';
if (fs.existsSync(apiFile)) {
    let apiContent = fs.readFileSync(apiFile, 'utf8');
    // Tìm dòng code cấp quyền cũ và thay thế bằng quyền có kèm Admin
    apiContent = apiContent.replace(/roomJoin:\s*true,/g, 'roomJoin: true, roomAdmin: true,');
    fs.writeFileSync(apiFile, apiContent, 'utf8');
    console.log('✅ Đã mở khóa quyền Host Admin');
}

// 4.2. VIỆT HÓA TRANG CHỦ & SEO
const layoutFile = 'app/layout.tsx';
if (fs.existsSync(layoutFile)) {
    let layoutContent = fs.readFileSync(layoutFile, 'utf8');
    layoutContent = layoutContent.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
    layoutContent = layoutContent.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.');
    fs.writeFileSync(layoutFile, layoutContent, 'utf8');
}

const pageFile = 'app/page.tsx';
if (fs.existsSync(pageFile)) {
    let pageContent = fs.readFileSync(pageFile, 'utf8');
    // Thay Logo
    pageContent = pageContent.replace(/<img[^>]*livekit-meet-home\.svg[^>]*\/?>/gi, '<div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center" }}><div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "50px", height: "50px", borderRadius: "14px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "24px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)" }}>TN</div><h1 style={{ fontSize: "40px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1></div>');
    // Thay Slogan
    pageContent = pageContent.replace(/<h2[^>]*>[\s\S]*?<\/h2>/gi, '<div style={{ textAlign: "center", maxWidth: "600px", marginTop: "1.2rem", marginBottom: "2rem" }}><p style={{ color: "#e4e4e7", fontSize: "1.15rem", fontWeight: "500", margin: "0 0 8px 0" }}>Hệ thống hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p><p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p></div>');
    // Thay Footer
    pageContent = pageContent.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '<footer style={{ marginTop: "auto", padding: "2.5rem 1rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid rgba(255,255,255,0.05)" }}><p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#a1a1aa"}}>Thanh Nguyen Group</b>. Mọi quyền được bảo lưu.</p><p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px" }}><span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 8px #10b981" }}></span> Hệ thống được mã hóa đầu cuối (E2EE) bảo mật tuyệt đối.</p></footer>');
    
    // Dịch Text ngoài
    const dict = [
        ['Try LiveKit Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
        ['Try NextGen Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
        ['Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server.', 'Truy cập hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.'],
        ['"Demo"', '"Họp Nhanh"'], ['>Demo<', '>Họp Nhanh<'],
        ['"Custom"', '"Phòng Riêng"'], ['>Custom<', '>Phòng Riêng<'],
        ['"Start Meeting"', '"Bắt Đầu Cuộc Họp"'], ['>Start Meeting<', '>Bắt Đầu Cuộc Họp<'],
        ['"Connect"', '"Kết Nối"'], ['>Connect<', '>Kết Nối<'],
        ['Enable end-to-end encryption', 'Kích hoạt mã hóa bảo mật cấp cao (E2EE)'],
        ['LiveKit Server URL', 'Địa chỉ máy chủ nội bộ']
    ];
    for (let [s, r] of dict) pageContent = pageContent.split(s).join(r);
    fs.writeFileSync(pageFile, pageContent, 'utf8');
}

// 4.3. VIỆT HÓA BÊN TRONG PHÒNG HỌP (TỪ NODE_MODULES)
const path = require('path');
function walkDir(dir, callback) {
    if (!fs.existsSync(dir)) return;
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        fs.statSync(dirPath).isDirectory() ? walkDir(dirPath, callback) : callback(dirPath);
    });
}

walkDir('node_modules/@livekit/components-react/dist', function(filePath) {
    if (filePath.endsWith('.js') || filePath.endsWith('.mjs')) {
        let content = fs.readFileSync(filePath, 'utf8');
        let orig = content;
        const trans = [
            ['"Microphone"', '"Micro"'], ['"Camera"', '"Máy ảnh"'],
            ['"Share screen"', '"Chia sẻ màn hình"'], ['"Stop sharing"', '"Dừng chia sẻ"'],
            ['"Chat"', '"Trò chuyện"'], ['"Leave"', '"Rời phòng"'],
            ['"Disable camera"', '"Tắt máy ảnh"'], ['"Enable camera"', '"Bật máy ảnh"'],
            ['"Mute"', '"Tắt mic"'], ['"Unmute"', '"Bật mic"'],
            ['"Remove from room"', '"Mời ra khỏi phòng"'],
            ['"Select microphone"', '"Chọn Micro"'], ['"Select camera"', '"Chọn Máy ảnh"'],
            ['"Default"', '"Mặc định"']
        ];
        for (let [s, r] of trans) content = content.split(s).join(r);
        if (content !== orig) fs.writeFileSync(filePath, content, 'utf8');
    }
});
EOF
RUN node patcher.js

# 5. NHÚNG BIẾN MÔI TRƯỜNG BUILD
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
