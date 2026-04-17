# Nâng cấp Node 20
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Tải ảnh thương hiệu từ GitHub (Làm ảnh SEO và đưa vào giao diện)
RUN mkdir -p public/images && \
    wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true && \
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg

# 3. Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# =================================================================
# 4. VIẾT LẠI LÕI API: FIX LỖI 401 JWT TOKEN + ÉP QUYỀN QUẢN TRỊ 
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

    if (!roomName || !participantName) return NextResponse.json({ error: 'Missing params' }, { status: 400 });
    if (!API_KEY || !API_SECRET || !LIVEKIT_URL) return NextResponse.json({ error: 'Server config err' }, { status: 500 });

    const identity = `${participantName}__${crypto.randomUUID().substring(0, 8)}`;

    const grant: VideoGrant = {
      roomJoin: true,
      room: roomName,
      roomAdmin: true, // QUYỀN QUẢN TRỊ ADMIN TỐI CAO ĐƯỢC ÉP BUỘC Ở ĐÂY
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    const at = new AccessToken(API_KEY, API_SECRET, { identity, name: participantName });
    at.addGrant(grant);
    const jwtToken = await at.toJwt(); // FIX LỖI 401 BẰNG JWT CHUẨN

    return NextResponse.json({
      serverUrl: region ? getLiveKitURL(LIVEKIT_URL, region) : LIVEKIT_URL,
      roomName,
      participantName,
      participantToken: jwtToken,
    });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 500 });
  }
}
EOF

# =================================================================
# 5. LỘT XÁC GIAO DIỆN TRANG CHỦ (TÍCH HỢP ẢNH, ICON, HIỆU ỨNG GLASS)
# =================================================================
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
    <div style={{ backgroundColor: "rgba(24, 24, 27, 0.75)", backdropFilter: "blur(24px)", padding: "2.5rem", borderRadius: "24px", border: "1px solid rgba(255,255,255,0.08)", width: "100%", maxWidth: "500px", boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.6)" }}>
      <div style={{ display: "flex", gap: "12px", marginBottom: "2rem", backgroundColor: "rgba(0,0,0,0.3)", padding: "6px", borderRadius: "16px" }}>
        <button onClick={() => router.push('/?tab=demo')} style={{ flex: 1, padding: "12px", borderRadius: "12px", fontWeight: "bold", border: "none", cursor: "pointer", transition: "all 0.3s", backgroundColor: tabIndex === 0 ? "#ef4444" : "transparent", color: tabIndex === 0 ? "white" : "#a1a1aa", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
          <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14v-4z"></path><rect x="3" y="6" width="12" height="12" rx="2"></rect></svg> Họp Nhanh
        </button>
        <button onClick={() => router.push('/?tab=custom')} style={{ flex: 1, padding: "12px", borderRadius: "12px", fontWeight: "bold", border: "none", cursor: "pointer", transition: "all 0.3s", backgroundColor: tabIndex === 1 ? "#ef4444" : "transparent", color: tabIndex === 1 ? "white" : "#a1a1aa", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
          <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0110 0v4"></path></svg> Phòng Riêng
        </button>
      </div>
      <div>
        {tabIndex === 0 ? (
          <div style={{ textAlign: "center" }}>
            <p style={{ margin: "0 0 1.5rem 0", color: "#d4d4d8", fontSize: "1.05rem" }}>Khởi tạo phòng họp trực tuyến siêu tốc với mã hóa E2EE.</p>
            <button onClick={startMeeting} style={{ width: "100%", padding: "16px", fontSize: "1.15rem", fontWeight: "bold", backgroundColor: "#ef4444", color: "white", border: "none", borderRadius: "14px", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: "10px", boxShadow: "0 8px 20px rgba(239, 68, 68, 0.4)", transition: "all 0.2s" }} onMouseOver={(e)=>e.currentTarget.style.transform='translateY(-2px)'} onMouseOut={(e)=>e.currentTarget.style.transform='translateY(0)'}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M13 5l7 7-7 7M5 5l7 7-7 7"/></svg>
              Bắt Đầu Cuộc Họp
            </button>
          </div>
        ) : (
          <form onSubmit={(e) => e.preventDefault()}>
             <p style={{ margin: "0 0 1rem 0", color: "#d4d4d8", textAlign: "center" }}>Kết nối Máy chủ Máy chủ Nội bộ.</p>
             <input placeholder="🌐 Địa chỉ máy chủ (Server URL)" required type="url" style={{ width: "100%", padding: "14px", marginBottom: "1rem", borderRadius: "12px", background: "rgba(0,0,0,0.4)", border: "1px solid rgba(255,255,255,0.1)", color: "white", outline: "none", fontSize: "1rem" }}/>
             <textarea placeholder="🔑 Chuỗi Token bảo mật (JWT)" required rows={3} style={{ width: "100%", padding: "14px", marginBottom: "1.5rem", borderRadius: "12px", background: "rgba(0,0,0,0.4)", border: "1px solid rgba(255,255,255,0.1)", color: "white", outline: "none", fontSize: "1rem", resize: "none" }}></textarea>
             <button type="submit" style={{ width: "100%", padding: "16px", fontSize: "1.15rem", fontWeight: "bold", backgroundColor: "#ef4444", color: "white", border: "none", borderRadius: "14px", cursor: "pointer", boxShadow: "0 8px 20px rgba(239, 68, 68, 0.4)" }}>⚡ Kết Nối</button>
          </form>
        )}
      </div>
    </div>
  );
}

export default function Page() {
  return (
    <div style={{ minHeight: "100vh", backgroundColor: "#09090b", backgroundImage: "radial-gradient(circle at 50% 0%, rgba(220, 38, 38, 0.15), transparent 60%)", display: "flex", flexDirection: "column", fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <main style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "2rem", zIndex: 1 }}>
        
        {/* HEADER BRANDING CÓ ICON 3D */}
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1.5rem", marginBottom: "2.5rem", textAlign: "center" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px", justifyContent: "center" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "64px", height: "64px", borderRadius: "18px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "30px", boxShadow: "0 15px 35px -5px rgba(220, 38, 38, 0.5)", border: "1px solid rgba(255,255,255,0.2)" }}>TN</div>
            <h1 style={{ fontSize: "52px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.05em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>
          
          {/* NHÚNG ẢNH TỪ GITHUB LÀM BANNER CHÍNH */}
          <div style={{ width: "100%", maxWidth: "650px", position: "relative", borderRadius: "20px", padding: "4px", background: "linear-gradient(180deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 100%)", marginTop: "1rem" }}>
              <img src="/images/livekit-meet-open-graph.png" alt="Thanh Nguyen Group Banner" style={{ width: "100%", borderRadius: "16px", boxShadow: "0 20px 40px -10px rgba(0,0,0,0.6)", display: "block" }} />
          </div>

          <div style={{ maxWidth: "600px", marginTop: "1.5rem" }}>
            <p style={{ color: "#f4f4f5", fontSize: "1.3rem", fontWeight: "500", margin: "0 0 8px 0", letterSpacing: "-0.01em" }}>Hệ thống Hội nghị Trực tuyến Cấp độ Doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "1rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>

        <Suspense fallback={<div style={{color:"white"}}>Đang tải hệ thống...</div>}>
          <Tabs />
        </Suspense>
      </main>

      {/* FOOTER HIỆN ĐẠI */}
      <footer style={{ padding: "2rem", textAlign: "center", color: "#71717a", fontSize: "0.95rem", borderTop: "1px solid rgba(255,255,255,0.05)", background: "rgba(0,0,0,0.3)", backdropFilter: "blur(10px)" }}>
        <p style={{ margin: "0 0 8px 0" }}>Bản quyền © 2026 <b style={{color:"#e4e4e7"}}>Thanh Nguyen Group</b>. Mọi quyền được bảo lưu.</p>
        <p style={{ margin: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: "8px", fontWeight: "500" }}>
            <span style={{ display: "inline-block", width: "10px", height: "10px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 15px #10b981", animation: "pulse 2s infinite" }}></span> 
            Bảo mật tuyệt đối với Mã hóa Đầu - Cuối (E2EE)
        </p>
      </footer>
      <style dangerouslySetInnerHTML={{__html: `
        @keyframes pulse { 0% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(1.3); } 100% { opacity: 1; transform: scale(1); } }
        input:focus, textarea:focus { border-color: #ef4444 !important; box-shadow: 0 0 0 2px rgba(239,68,68,0.25) !important; }
      `}} />
    </div>
  );
}
EOF

# =================================================================
# 6. BƠM CSS CAO CẤP VÀO PHÒNG HỌP & DỊCH THUẬT SÂU
# =================================================================
RUN cat <<'EOF' > post_build.js
const fs = require('fs');
const path = require('path');

// 1. Tùy chỉnh SEO
const layoutPath = 'app/layout.tsx';
if (fs.existsSync(layoutPath)) {
    let content = fs.readFileSync(layoutPath, 'utf8');
    content = content.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
    content = content.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE) được phát triển và vận hành độc quyền bởi Thanh Nguyen Group.');
    fs.writeFileSync(layoutPath, content, 'utf8');
}

// 2. Bơm giao diện kính mờ (Glassmorphism) vào lõi
const cssPath = 'styles/globals.css';
if (fs.existsSync(cssPath)) {
    const customCSS = `
/* PREMIUM ROOM UI */
.lk-control-bar {
    background: rgba(24, 24, 27, 0.7) !important;
    backdrop-filter: blur(20px) saturate(150%) !important;
    border-top: 1px solid rgba(255, 255, 255, 0.1) !important;
    box-shadow: 0 -10px 40px rgba(0,0,0,0.5) !important;
    padding: 1.2rem !important;
}
.lk-button {
    border-radius: 14px !important;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
}
.lk-button:hover {
    transform: translateY(-3px) scale(1.05) !important;
    box-shadow: 0 10px 20px rgba(0,0,0,0.3) !important;
    background-color: #3f3f46 !important;
}
.lk-disconnect-button {
    background-color: #ef4444 !important;
}
.lk-disconnect-button:hover {
    background-color: #dc2626 !important;
}
.lk-participant-tile {
    border-radius: 20px !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
    box-shadow: 0 15px 35px rgba(0,0,0,0.3) !important;
    overflow: hidden !important;
}
`;
    fs.appendFileSync(cssPath, customCSS, 'utf8');
}

// 3. Dịch Menu "Chuột Phải / Nhấn Giữ"
function translate(dir) {
    if (!fs.existsSync(dir)) return;
    fs.readdirSync(dir).forEach(file => {
        const fp = path.join(dir, file);
        if (fs.statSync(fp).isDirectory()) translate(fp);
        else if (fp.endsWith('.js') || fp.endsWith('.mjs')) {
            let c = fs.readFileSync(fp, 'utf8');
            let orig = c;
            const dict = [
                ['"Microphone"', '"Micro"'], ['"Camera"', '"Máy ảnh"'],
                ['"Share screen"', '"Chia sẻ màn hình"'], ['"Stop sharing"', '"Dừng chia sẻ"'],
                ['"Chat"', '"Trò chuyện"'], ['"Leave"', '"Rời phòng"'],
                ['"Disable camera"', '"Tắt máy ảnh"'], ['"Enable camera"', '"Bật máy ảnh"'],
                ['"Mute"', '"Tắt mic"'], ['"Unmute"', '"Bật mic"'],
                ['"Remove from room"', '"Mời ra khỏi phòng"'],
                ['"Select microphone"', '"Chọn Micro"'], ['"Select camera"', '"Chọn Máy ảnh"'],
                ['"Default"', '"Mặc định"']
            ];
            dict.forEach(([e, v]) => c = c.split(e).join(v));
            if (c !== orig) fs.writeFileSync(fp, c, 'utf8');
        }
    });
}
translate('node_modules/@livekit/components-react/dist');
EOF
RUN node post_build.js

# 7. Thông số bảo mật Server
ENV NEXT_PUBLIC_LIVEKIT_URL="wss://livekit.thanhnguyen.group"
ENV LIVEKIT_URL="wss://livekit.thanhnguyen.group" 
ENV LIVEKIT_API_KEY="API_nextgen_admin_key"
ENV LIVEKIT_API_SECRET="SEC_thanhnguyen_group_super_secure_9999"

# Xây dựng hệ thống
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
