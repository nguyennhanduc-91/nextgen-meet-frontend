# Sử dụng Node 20
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Tải ảnh SEO Zalo
RUN mkdir -p public/images && \
    wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg

# 3. Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# =================================================================
# 4. KỊCH BẢN LỘT XÁC TOÀN DIỆN (UI CSS + QUYỀN ADMIN + DỊCH THUẬT)
# =================================================================
RUN cat <<'EOF' > build_premium.js
const fs = require('fs');
const path = require('path');

function overrideFile(filePath, replacerCallback) {
    if (!fs.existsSync(filePath)) return;
    const orig = fs.readFileSync(filePath, 'utf8');
    const modified = replacerCallback(orig);
    if (orig !== modified) fs.writeFileSync(filePath, modified, 'utf8');
}

// --- 4.1. ÉP QUYỀN ADMIN CHO NGƯỜI DÙNG TẠO PHÒNG ---
overrideFile('app/api/connection-details/route.ts', (content) => {
    return content.replace(/roomJoin:\s*true,?\s*room:\s*roomName,?/g, 'roomJoin: true, room: roomName, roomAdmin: true,');
});

// --- 4.2. BƠM CSS ĐỂ LỘT XÁC GIAO DIỆN BÊN TRONG PHÒNG HỌP ---
const cssPath = 'styles/globals.css';
if (fs.existsSync(cssPath)) {
    const customCSS = `
/* --- THANH NGUYEN PREMIUM UI OVERRIDES --- */
.lk-control-bar {
    background: rgba(24, 24, 27, 0.85) !important;
    backdrop-filter: blur(12px) !important;
    border-top: 1px solid rgba(255, 255, 255, 0.1) !important;
    padding: 1rem !important;
}
.lk-button {
    border-radius: 12px !important;
    transition: all 0.2s ease !important;
}
.lk-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}
.lk-participant-tile {
    border-radius: 16px !important;
    overflow: hidden !important;
    border: 1px solid rgba(255,255,255,0.05) !important;
    box-shadow: 0 8px 24px rgba(0,0,0,0.2) !important;
}
.lk-disconnect-button {
    background-color: #ef4444 !important;
    border-radius: 12px !important;
}
`;
    fs.appendFileSync(cssPath, customCSS, 'utf8');
}

// --- 4.3. THIẾT KẾ LẠI GIAO DIỆN TRANG CHỦ & FOOTER ---
overrideFile('app/page.tsx', (content) => {
    content = content.replace(/<img[^>]*livekit-meet-home\.svg[^>]*\/?>/gi, 
        `<div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center", paddingBottom: "10px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "55px", height: "55px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "26px", boxShadow: "0 10px 25px -5px rgba(220, 38, 38, 0.6)", border: "1px solid rgba(255,255,255,0.15)" }}>TN</div>
            <h1 style={{ fontSize: "44px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "system-ui, sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
        </div>`
    );
    content = content.replace(/<h2[^>]*>[\s\S]*?<\/h2>/gi, 
        `<div style={{ textAlign: "center", maxWidth: "600px", marginBottom: "2.5rem" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.2rem", fontWeight: "500", margin: "0 0 8px 0" }}>Nền tảng hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
        </div>`
    );
    content = content.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, 
        `<footer style={{ marginTop: "auto", padding: "2rem 1rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid rgba(255,255,255,0.05)" }}>
            <p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#e4e4e7"}}>Thanh Nguyen Group</b>. Hạ tầng mạng viễn thông nội bộ.</p>
            <p style={{ margin: 0, fontSize: "0.85rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
                <span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 10px #10b981", animation: "pulse 2s infinite" }}></span> 
                Đường truyền mã hóa E2EE bảo mật tuyệt đối.
            </p>
        </footer>`
    );
    const dict = [
        ['Try LiveKit Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
        ['Try NextGen Meet for free with our live demo project.', 'Khởi tạo phòng họp bảo mật ngay lập tức.'],
        ['Connect LiveKit Meet with a custom server using LiveKit Cloud or LiveKit Server.', 'Truy cập hệ thống máy chủ nội bộ an toàn của Thanh Nguyen Group.'],
        ['"Demo"', '"Họp Nhanh"'], ['>Demo<', '>Họp Nhanh<'],
        ['"Custom"', '"Phòng Riêng"'], ['>Custom<', '>Phòng Riêng<'],
        ['"Start Meeting"', '"Bắt Đầu Cuộc Họp"'], ['>Start Meeting<', '>Bắt Đầu Cuộc Họp<'],
        ['"Connect"', '"Kết Nối"'], ['>Connect<', '>Kết Nối<'],
        ['Enable end-to-end encryption', 'Kích hoạt mã hóa bảo mật E2EE'],
        ['LiveKit Server URL', 'Địa chỉ máy chủ nội bộ']
    ];
    for (let [en, vi] of dict) content = content.split(en).join(vi);
    return content;
});

// --- 4.4. CẬP NHẬT SEO META (ZALO) ---
overrideFile('app/layout.tsx', (content) => {
    content = content.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
    content = content.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.');
    content = content.replace(/@livekitted/g, '@thanhnguyen');
    return content;
});

// --- 4.5. VIỆT HÓA SÂU LÕI PHÒNG HỌP ---
function translateNodeModules(dir) {
    if (!fs.existsSync(dir)) return;
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            translateNodeModules(fullPath);
        } else if (file.endsWith('.js') || file.endsWith('.mjs')) {
            overrideFile(fullPath, (content) => {
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
                for (let [en, vi] of trans) content = content.split(en).join(vi);
                return content;
            });
        }
    }
}
translateNodeModules('node_modules/@livekit/components-react/dist');
translateNodeModules('node_modules/@livekit/components-core/dist');
EOF
RUN node build_premium.js

# 5. Khai báo thông số Server
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group" 
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Build hệ thống
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
