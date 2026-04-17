# Nâng cấp Node 20
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
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
# 4. GHI ĐÈ TRỰC TIẾP FILE API ĐỂ BẢO ĐẢM 100% CÓ QUYỀN ADMIN
# =================================================================
RUN cat <<'EOF' > app/api/connection-details/route.ts
import { getLiveKitURL } from '@/lib/getLiveKitURL';
import { ConnectionDetails } from '@/lib/types';
import { AccessToken, AccessTokenOptions, VideoGrant } from 'livekit-server-sdk';
import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;
const LIVEKIT_URL = process.env.LIVEKIT_URL;

export async function GET(request: NextRequest) {
  try {
    const roomName = request.nextUrl.searchParams.get('roomName');
    const participantName = request.nextUrl.searchParams.get('participantName');
    const region = request.nextUrl.searchParams.get('region');

    if (!roomName || !participantName) {
      return NextResponse.json({ error: 'Missing roomName or participantName' }, { status: 400 });
    }
    if (!API_KEY || !API_SECRET || !LIVEKIT_URL) {
      return NextResponse.json({ error: 'Server misconfigured' }, { status: 500 });
    }

    const participantToken = crypto.randomUUID().substring(0, 8);
    const identity = `${participantName}__${participantToken}`;

    // ÉP CẤP QUYỀN ADMIN TẠI ĐÂY
    const grant: VideoGrant = {
      roomJoin: true,
      room: roomName,
      roomAdmin: true, // <--- QUYỀN LỰC ĐƯỢC ÉP BUỘC Ở ĐÂY
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    const token = new AccessToken(API_KEY, API_SECRET, {
      identity,
      name: participantName,
    });
    token.addGrant(grant);

    return NextResponse.json({
      serverUrl: region ? getLiveKitURL(LIVEKIT_URL, region) : LIVEKIT_URL,
      roomName,
      participantName,
      participantToken,
      token: await token.toJwt(),
    });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 500 });
  }
}
EOF

# =================================================================
# 5. KỊCH BẢN THIẾT KẾ LẠI GIAO DIỆN & VIỆT HÓA
# =================================================================
RUN cat <<'EOF' > build_enterprise.js
const fs = require('fs');
const path = require('path');

function overrideFile(filePath, replacerCallback) {
    if (!fs.existsSync(filePath)) return;
    const orig = fs.readFileSync(filePath, 'utf8');
    const modified = replacerCallback(orig);
    if (orig !== modified) fs.writeFileSync(filePath, modified, 'utf8');
}

// 5.1. THIẾT KẾ LẠI GIAO DIỆN TRANG CHỦ CHUYÊN NGHIỆP
overrideFile('app/page.tsx', (content) => {
    content = content.replace(/<img[^>]*livekit-meet-home\.svg[^>]*\/?>/gi, 
        `<div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center", paddingBottom: "10px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "55px", height: "55px", borderRadius: "14px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "26px", boxShadow: "0 10px 25px -5px rgba(220, 38, 38, 0.6)", border: "1px solid rgba(255,255,255,0.1)" }}>TN</div>
            <h1 style={{ fontSize: "42px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "system-ui, sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
        </div>`
    );
    content = content.replace(/<h2[^>]*>[\s\S]*?<\/h2>/gi, 
        `<div style={{ textAlign: "center", maxWidth: "600px", marginBottom: "2rem" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.15rem", fontWeight: "500", margin: "0 0 8px 0" }}>Nền tảng hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
        </div>`
    );
    content = content.replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, 
        `<footer style={{ marginTop: "auto", padding: "2rem 1rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid rgba(255,255,255,0.05)" }}>
            <p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#a1a1aa"}}>Thanh Nguyen Group</b>. Hệ thống hạ tầng mạng nội bộ.</p>
            <p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px" }}>
                <span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 8px #10b981", animation: "pulse 2s infinite" }}></span> 
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

// 5.2. CẬP NHẬT SEO META (ZALO)
overrideFile('app/layout.tsx', (content) => {
    content = content.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
    content = content.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.');
    content = content.replace(/@livekitted/g, '@thanhnguyen');
    return content;
});

// 5.3. VIỆT HÓA SÂU LÕI PHÒNG HỌP
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
RUN node build_enterprise.js

# 6. Khai báo thông số Server
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
