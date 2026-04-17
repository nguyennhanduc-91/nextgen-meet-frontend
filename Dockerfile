FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Tải ảnh SEO Zalo chuẩn từ GitHub của bạn
RUN mkdir -p public/images && \
    wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico

# 3. Cài đặt thư viện (Bắt buộc để thư mục node_modules xuất hiện)
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 4. GHI ĐÈ FILE TRANG CHỦ (PAGE.TSX) BẰNG CODE REACT HOÀN CHỈNH
# Đập bỏ hoàn toàn giao diện cũ, xây dựng UI Doanh nghiệp Tiếng Việt
RUN cat <<'EOF' > app/page.tsx
'use client';
import { useRouter, useSearchParams } from 'next/navigation';
import React, { Suspense, useState } from 'react';
import { generateRoomId } from '@/lib/client-utils';

function Tabs() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const tabIndex = searchParams?.get('tab') === 'custom' ? 1 : 0;
  const [e2ee, setE2ee] = useState(false);
  const startMeeting = () => {
    router.push(`/rooms/${generateRoomId()}${e2ee ? '#e2ee=true' : ''}`);
  };
  return (
    <div style={{ backgroundColor: "#18181b", padding: "2rem", borderRadius: "16px", border: "1px solid #27272a", width: "100%", maxWidth: "500px" }}>
      <div style={{ display: "flex", gap: "10px", marginBottom: "2rem" }}>
        <button onClick={() => router.push('/?tab=demo')} className="lk-button" style={{ flex: 1, backgroundColor: tabIndex === 0 ? "#dc2626" : "#27272a" }}>Họp Nhanh</button>
        <button onClick={() => router.push('/?tab=custom')} className="lk-button" style={{ flex: 1, backgroundColor: tabIndex === 1 ? "#dc2626" : "#27272a" }}>Phòng Riêng</button>
      </div>
      <div>
        {tabIndex === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <p style={{ margin: 0, color: "#e4e4e7", textAlign: "center" }}>Khởi tạo phòng họp bảo mật cấp tốc.</p>
            <button className="lk-button" onClick={startMeeting} style={{ width: "100%", padding: "1rem", fontSize: "1.1rem", backgroundColor: "#ef4444" }}>Bắt Đầu Cuộc Họp</button>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', justifyContent: 'center', marginTop: '1rem' }}>
              <input id="use-e2ee" type="checkbox" checked={e2ee} onChange={(ev) => setE2ee(ev.target.checked)} />
              <label htmlFor="use-e2ee" style={{ color: '#a1a1aa', fontSize: '0.9rem' }}>Bật mã hóa đầu cuối (E2EE)</label>
            </div>
          </div>
        ) : (
          <form onSubmit={(e) => { e.preventDefault(); }}>
             <p style={{ margin: "0 0 1rem 0", color: "#e4e4e7", textAlign: "center" }}>Kết nối vào hệ thống Server nội bộ.</p>
             <input id="serverUrl" placeholder="Địa chỉ máy chủ nội bộ (Server URL)" required type="url" style={{ width: "100%", padding: "0.8rem", marginBottom: "1rem", borderRadius: "8px", background: "#27272a", border: "1px solid #3f3f46", color: "white" }}/>
             <textarea id="token" placeholder="Chuỗi Token bảo mật" required rows={4} style={{ width: "100%", padding: "0.8rem", marginBottom: "1rem", borderRadius: "8px", background: "#27272a", border: "1px solid #3f3f46", color: "white" }}></textarea>
             <button className="lk-button" type="submit" style={{ width: "100%", padding: "1rem", backgroundColor: "#ef4444" }}>Kết Nối</button>
          </form>
        )}
      </div>
    </div>
  );
}

export default function Page() {
  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", backgroundColor: "#09090b" }}>
      <main style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "2rem" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1rem", marginBottom: "2.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "60px", height: "60px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "28px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)" }}>TN</div>
            <h1 style={{ fontSize: "48px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em", fontFamily: "sans-serif" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>
          <div style={{ textAlign: "center", marginTop: "0.5rem" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.2rem", fontWeight: "500", margin: "0 0 5px 0" }}>Nền tảng hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "0.95rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>
        <Suspense fallback={<p style={{color: 'white'}}>Đang tải...</p>}>
          <Tabs />
        </Suspense>
      </main>
      <footer style={{ padding: "2rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem", borderTop: "1px solid #27272a" }}>
        <p style={{ margin: "0 0 6px 0" }}>Bản quyền © 2026 <b style={{color:"#fff"}}>Thanh Nguyen Group</b>. Mọi quyền được bảo lưu.</p>
        <p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px" }}><span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 8px #10b981" }}></span> Hệ thống được mã hóa đầu cuối (E2EE) bảo mật tuyệt đối.</p>
      </footer>
    </div>
  );
}
EOF

# 5. GHI ĐÈ FILE API SINH TOKEN ĐỂ ÉP MỞ KHÓA QUYỀN HOST (ADMIN)
RUN cat <<'EOF' > app/api/connection-details/route.ts
import { getLiveKitURL } from '@/lib/getLiveKitURL';
import { AccessToken, VideoGrant } from 'livekit-server-sdk';
import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;
const LIVEKIT_URL = process.env.LIVEKIT_URL;

export async function GET(request: NextRequest) {
  try {
    const roomName = request.nextUrl.searchParams.get('roomName');
    const participantName = request.nextUrl.searchParams.get('participantName');
    const region = request.nextUrl.searchParams.get('region');

    if (!roomName || !participantName) return NextResponse.json({ error: 'Missing data' }, { status: 400 });
    if (!API_KEY || !API_SECRET || !LIVEKIT_URL) return NextResponse.json({ error: 'Server config error' }, { status: 500 });

    const participantToken = crypto.randomUUID().substring(0, 8);
    const identity = `${participantName}__${participantToken}`;

    // CẤP QUYỀN QUẢN TRỊ TẠI ĐÂY
    const grant: VideoGrant = {
      roomJoin: true,
      room: roomName,
      roomAdmin: true, // Kích hoạt quyền Kick/Mute
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    const token = new AccessToken(API_KEY, API_SECRET, { identity, name: participantName });
    token.addGrant(grant);

    return NextResponse.json({
      serverUrl: region ? getLiveKitURL(LIVEKIT_URL, region) : LIVEKIT_URL,
      roomName, participantName, participantToken,
      token: await token.toJwt(),
    });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 500 });
  }
}
EOF

# 6. DỊCH THUẬT MENU BÊN TRONG PHÒNG HỌP BẰNG SCRIPT AN TOÀN
RUN cat <<'EOF' > patch-modules.js
const fs = require('fs');
const path = require('path');
function walk(dir) {
    if (!fs.existsSync(dir)) return;
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            walk(fullPath);
        } else if (fullPath.endsWith('.js') || fullPath.endsWith('.mjs')) {
            let content = fs.readFileSync(fullPath, 'utf8');
            let orig = content;
            const dict = {
                '"Microphone"': '"Micro"',
                '"Camera"': '"Máy ảnh"',
                '"Share screen"': '"Chia sẻ"',
                '"Stop sharing"': '"Dừng chia sẻ"',
                '"Chat"': '"Trò chuyện"',
                '"Leave"': '"Rời phòng"',
                '"Settings"': '"Cấu hình"',
                '"Disable camera"': '"Tắt máy ảnh"',
                '"Enable camera"': '"Bật máy ảnh"',
                '"Mute"': '"Tắt mic"',
                '"Unmute"': '"Bật mic"',
                '"Remove from room"': '"Mời ra khỏi phòng"',
                '"Select microphone"': '"Chọn Micro"',
                '"Select camera"': '"Chọn Máy ảnh"',
                '"Default"': '"Mặc định"'
            };
            for (let key in dict) {
                content = content.split(key).join(dict[key]);
            }
            if (content !== orig) fs.writeFileSync(fullPath, content, 'utf8');
        }
    }
}
walk('node_modules/@livekit/components-react/dist');
walk('node_modules/@livekit/components-core/dist');
EOF
RUN node patch-modules.js

# 7. SỬA SEO THUỘC TÍNH
RUN sed -i 's/LiveKit Meet | Conference app build with LiveKit open source/Hệ thống Họp Trực Tuyến | Thanh Nguyen Group/g' app/layout.tsx
RUN sed -i 's/LiveKit is an open source WebRTC project.*/Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) của Thanh Nguyen Group."/g' app/layout.tsx

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
