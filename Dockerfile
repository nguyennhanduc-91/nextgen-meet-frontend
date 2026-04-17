# Nâng cấp lên Node 20 để tương thích Next.js 14+
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Cài đặt thư viện TRƯỚC 
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 3. GHI ĐÈ ẢNH SEO ZALO/FACEBOOK BẰNG ẢNH TRỐNG BẢO TOÀN
RUN mkdir -p public/images && \
    echo '<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#000"/><text x="50%" y="50%" font-family="sans-serif" font-size="60" font-weight="bold" fill="#dc2626" text-anchor="middle">Thanh Nguyen Group</text></svg>' > public/images/livekit-meet-open-graph.png && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    cp public/images/livekit-meet-open-graph.png public/images/livekit-meet-home.svg

# 4. SCRIPT NHẮM BẮN MỤC TIÊU CHÍNH XÁC (KHÔNG DÙNG SCANDIR)
RUN cat <<'EOF' > rebrand.js
const fs = require('fs');
const path = require('path');

// Hàm thay thế text an toàn tuyệt đối
function replaceText(file, replacements) {
    if (!fs.existsSync(file)) return;
    let content = fs.readFileSync(file, 'utf8');
    let orig = content;
    for (let [search, replace] of replacements) {
        content = content.split(search).join(replace);
    }
    if (content !== orig) fs.writeFileSync(file, content, 'utf8');
}

// Hàm thay thế bằng Regex (Dành cho code phức tạp)
function replaceRegex(file, regex, replaceStr) {
    if (!fs.existsSync(file)) return;
    let content = fs.readFileSync(file, 'utf8');
    let orig = content;
    content = content.replace(regex, replaceStr);
    if (content !== orig) fs.writeFileSync(file, content, 'utf8');
}

// ====================================================================
// MỤC TIÊU 1: CẤP QUYỀN QUẢN TRỊ VIÊN (HOST) TRONG LÕI TOKEN
// ====================================================================
const apiFiles = [
    'app/api/connection-details/route.ts',
    'app/api/token/route.ts',
    'lib/token.ts'
];
apiFiles.forEach(file => {
    replaceRegex(file, /roomJoin:\s*true/g, 'roomJoin: true, roomAdmin: true');
});

// ====================================================================
// MỤC TIÊU 2: SEO META (THẺ ZALO/FACEBOOK)
// ====================================================================
replaceText('app/layout.tsx', [
    ['LiveKit Meet | Conference app build with LiveKit open source', 'Hệ thống Họp trực tuyến | Thanh Nguyen Group'],
    ['LiveKit is an open source WebRTC project that gives you everything needed to build scalable and real-time audio and/or video experiences in your applications.', 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.'],
    ['meet.livekit.io', 'meet.thanhnguyen.group'],
    ['@livekitted', '@thanhnguyen']
]);

// ====================================================================
// MỤC TIÊU 3: THIẾT KẾ LẠI TOÀN BỘ GIAO DIỆN TRANG CHỦ ENTERPRISE
// ====================================================================
// Thay thế Logo bằng CSS tĩnh siêu đẹp
replaceRegex('app/page.tsx', /<img[^>]*livekit-meet-home\.svg[^>]*\/?>/g, '<div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center" }}><div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "50px", height: "50px", borderRadius: "14px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "24px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)" }}>TN</div><h1 style={{ fontSize: "40px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1></div>');

// Dịch 100% văn bản giao diện ngoài
replaceText('app/page.tsx', [
    ['Open source video conferencing app built on', 'Hệ thống hội nghị trực tuyến bảo mật cao của'],
    ['LiveKit Components', 'Thanh Nguyen'],
    ['LiveKit Cloud', 'Group'],
    ['and Next.js.', ''],
    ['Try LiveKit Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
    ['Try NextGen Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
    ['>Demo<', '>Họp Nhanh<'],
    ['"Demo"', '"Họp Nhanh"'],
    ['>Custom<', '>Phòng Riêng<'],
    ['"Custom"', '"Phòng Riêng"'],
    ['>Start Meeting<', '>Bắt Đầu Cuộc Họp<'],
    ['"Start Meeting"', '"Bắt Đầu Cuộc Họp"'],
    ['Enable end-to-end encryption', 'Kích hoạt mã hóa bảo mật cấp cao (E2EE)'],
    ['Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server.', 'Truy cập hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.'],
    ['Connect NextGen Meet with a custom server using Group or Máy chủ TN.', 'Truy cập hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.'],
    ['LiveKit Server URL', 'Địa chỉ máy chủ nội bộ (Server URL)'],
    ['>Connect<', '>Kết Nối<'],
    ['"Connect"', '"Kết Nối"'],
    ['Hosted on', 'Bản quyền © 2026 thuộc về'],
    ['. Source code on', '']
]);

// Cắt đứt hoàn toàn Link ngoài (GitHub)
replaceRegex('app/page.tsx', /<a[^>]*href=["'][^"']*github\.com\/livekit[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Thanh Nguyen</b>');
replaceRegex('app/page.tsx', /<a[^>]*href=["'][^"']*livekit\.io[^"']*["'][^>]*>[\s\S]*?<\/a>/gi, '<b style={{color: "#ffffff"}}>Group</b>');


// ====================================================================
// MỤC TIÊU 4: VIỆT HÓA LÕI MENU BÊN TRONG PHÒNG HỌP (TỪ THƯ VIỆN)
// ====================================================================
function patchNodeModules(dir) {
    if (!fs.existsSync(dir)) return;
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            patchNodeModules(fullPath);
        } else if (fullPath.endsWith('.js') || fullPath.endsWith('.mjs')) {
            replaceText(fullPath, [
                ['"Microphone"', '"Micro"'],
                ['"Camera"', '"Máy ảnh"'],
                ['"Share screen"', '"Chia sẻ"'],
                ['"Stop sharing"', '"Dừng chia sẻ"'],
                ['"Chat"', '"Trò chuyện"'],
                ['"Settings"', '"Cài đặt"'],
                ['"Leave"', '"Rời phòng"'],
                ['"Disable camera"', '"Tắt máy ảnh"'],
                ['"Enable camera"', '"Bật máy ảnh"'],
                ['"Mute"', '"Tắt mic"'],
                ['"Unmute"', '"Bật mic"'],
                ['"Remove from room"', '"Mời ra khỏi phòng"'],
                ['"Select microphone"', '"Chọn Micro"'],
                ['"Select camera"', '"Chọn Máy ảnh"'],
                ['"Default"', '"Mặc định"']
            ]);
        }
    }
}
patchNodeModules('node_modules/@livekit/components-react/dist');
patchNodeModules('node_modules/@livekit/components-core/dist');

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
