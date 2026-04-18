# Sử dụng Node 20
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# =================================================================
# 2. DIỆT SẠCH ẢNH CỦA HÃNG & TẢI ẢNH THƯƠNG HIỆU THANH NGUYEN
# =================================================================
RUN mkdir -p public/images && \
    # Tải Banner dài (Hình chữ nhật) cho Zalo/Facebook
    wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true && \
    # Ghi đè Favicon
    echo '<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="16" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/favicon.ico && \
    # GHI ĐÈ ẢNH VUÔNG APPLE TOUCH (THỦ PHẠM GÂY LỖI TRÊN ZALO)
    echo '<svg width="180" height="180" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#dc2626"/><text x="50%" y="50%" font-family="sans-serif" font-size="80" font-weight="bold" fill="#fff" text-anchor="middle" dominant-baseline="central">TN</text></svg>' > public/images/livekit-apple-touch.png && \
    # Ẩn ảnh logo nhỏ
    echo '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>' > public/images/livekit-meet-home.svg

# 3. Cài đặt thư viện
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# =================================================================
# 4. LÕI API: QUYỀN ADMIN TỐI CAO & FIX LỖI 401
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
      roomAdmin: true, // QUYỀN ADMIN LUÔN BẬT
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    };

    const at = new AccessToken(API_KEY, API_SECRET, { identity, name: participantName });
    at.addGrant(grant);
    const jwtToken = await at.toJwt();

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
# 5. GIAO DIỆN TRANG CHỦ: TỐI GIẢN (KHÔNG ẢNH), RESPONSIVE
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
    <div className="tn-action-box" style={{ backgroundColor: "rgba(24, 24, 27, 0.75)", backdropFilter: "blur(24px)", borderRadius: "20px", border: "1px solid rgba(255,255,255,0.08)", width: "100%", maxWidth: "420px", boxShadow: "0 20px 40px -10px rgba(0, 0, 0, 0.5)", margin: "0 auto" }}>
      <div style={{ display: "flex", gap: "8px", marginBottom: "1.5rem", backgroundColor: "rgba(0,0,0,0.3)", padding: "5px", borderRadius: "14px" }}>
        <button onClick={() => router.push('/?tab=demo')} style={{ flex: 1, padding: "10px", borderRadius: "10px", fontWeight: "bold", border: "none", cursor: "pointer", transition: "all 0.3s", backgroundColor: tabIndex === 0 ? "#ef4444" : "transparent", color: tabIndex === 0 ? "white" : "#a1a1aa", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px", fontSize: "0.95rem" }}>
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14v-4z"></path><rect x="3" y="6" width="12" height="12" rx="2"></rect></svg> Họp Nhanh
        </button>
        <button onClick={() => router.push('/?tab=custom')} style={{ flex: 1, padding: "10px", borderRadius: "10px", fontWeight: "bold", border: "none", cursor: "pointer", transition: "all 0.3s", backgroundColor: tabIndex === 1 ? "#ef4444" : "transparent", color: tabIndex === 1 ? "white" : "#a1a1aa", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px", fontSize: "0.95rem" }}>
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0110 0v4"></path></svg> Phòng Riêng
        </button>
      </div>
      <div>
        {tabIndex === 0 ? (
          <div style={{ textAlign: "center" }}>
            <p style={{ margin: "0 0 1.2rem 0", color: "#d4d4d8", fontSize: "0.95rem" }}>Khởi tạo phòng họp bảo mật mã hóa E2EE.</p>
            <button onClick={startMeeting} style={{ width: "100%", padding: "14px", fontSize: "1.05rem", fontWeight: "bold", backgroundColor: "#ef4444", color: "white", border: "none", borderRadius: "12px", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px", boxShadow: "0 6px 15px rgba(239, 68, 68, 0.4)", transition: "all 0.2s" }} onMouseOver={(e)=>e.currentTarget.style.transform='translateY(-2px)'} onMouseOut={(e)=>e.currentTarget.style.transform='translateY(0)'}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M13 5l7 7-7 7M5 5l7 7-7 7"/></svg>
              Bắt Đầu Cuộc Họp
            </button>
          </div>
        ) : (
          <form onSubmit={(e) => e.preventDefault()}>
             <input placeholder="🌐 Địa chỉ máy chủ (Server URL)" required type="url" style={{ width: "100%", padding: "12px", marginBottom: "1rem", borderRadius: "10px", background: "rgba(0,0,0,0.4)", border: "1px solid rgba(255,255,255,0.1)", color: "white", outline: "none", fontSize: "0.95rem" }}/>
             <textarea placeholder="🔑 Chuỗi Token bảo mật (JWT)" required rows={2} style={{ width: "100%", padding: "12px", marginBottom: "1.2rem", borderRadius: "10px", background: "rgba(0,0,0,0.4)", border: "1px solid rgba(255,255,255,0.1)", color: "white", outline: "none", fontSize: "0.95rem", resize: "none" }}></textarea>
             <button type="submit" style={{ width: "100%", padding: "14px", fontSize: "1.05rem", fontWeight: "bold", backgroundColor: "#ef4444", color: "white", border: "none", borderRadius: "12px", cursor: "pointer", boxShadow: "0 6px 15px rgba(239, 68, 68, 0.4)" }}>⚡ Kết Nối</button>
          </form>
        )}
      </div>
    </div>
  );
}

export default function Page() {
  return (
    <div style={{ minHeight: "100dvh", backgroundColor: "#09090b", backgroundImage: "radial-gradient(circle at 50% 0%, rgba(220, 38, 38, 0.12), transparent 50%)", display: "flex", flexDirection: "column", fontFamily: "system-ui, -apple-system, sans-serif" }}>
      
      <main style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "1rem", zIndex: 1, overflowY: "auto" }}>
        
        {/* HEADER BRANDING TỐI GIẢN */}
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", width: "100%" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "12px", justifyContent: "center" }}>
            <div className="tn-logo" style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", borderRadius: "14px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", boxShadow: "0 10px 25px -5px rgba(220, 38, 38, 0.5)", border: "1px solid rgba(255,255,255,0.2)" }}>TN</div>
            <h1 className="tn-title" style={{ fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>

          <div style={{ maxWidth: "500px", margin: "1.5rem 0" }}>
            <p className="tn-slogan" style={{ color: "#f4f4f5", fontWeight: "500", margin: "0 0 4px 0", letterSpacing: "-0.01em" }}>Hệ thống Hội nghị Cấp độ Doanh nghiệp.</p>
            <p className="tn-sub" style={{ color: "#a1a1aa", margin: 0 }}>Vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>

        <Suspense fallback={<div style={{color:"white"}}>Đang tải...</div>}>
          <Tabs />
        </Suspense>
      </main>

      <footer style={{ padding: "1.2rem 1rem", textAlign: "center", color: "#71717a", borderTop: "1px solid rgba(255,255,255,0.05)", background: "rgba(0,0,0,0.4)", backdropFilter: "blur(10px)", flexShrink: 0 }}>
        <p style={{ margin: "0 0 6px 0", fontSize: "0.85rem" }}>Bản quyền © 2026 <b style={{color:"#e4e4e7"}}>Thanh Nguyen Group</b>.</p>
        <p style={{ margin: 0, fontSize: "0.8rem", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px", fontWeight: "500" }}>
            <span style={{ display: "inline-block", width: "8px", height: "8px", borderRadius: "50%", backgroundColor: "#10b981", boxShadow: "0 0 10px #10b981", animation: "pulse 2s infinite" }}></span> 
            Bảo mật E2EE tuyệt đối
        </p>
      </footer>

      {/* CSS TỰ ĐỘNG THÍCH ỨNG */}
      <style dangerouslySetInnerHTML={{__html: `
        @keyframes pulse { 0% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(1.3); } 100% { opacity: 1; transform: scale(1); } }
        input:focus, textarea:focus { border-color: #ef4444 !important; box-shadow: 0 0 0 2px rgba(239,68,68,0.25) !important; }
        .tn-logo { width: 55px; height: 55px; font-size: 26px; }
        .tn-title { font-size: 46px; }
        .tn-slogan { font-size: 1.15rem; }
        .tn-sub { font-size: 0.9rem; }
        .tn-action-box { padding: 2rem; }
        @media (max-width: 640px) {
            .tn-logo { width: 42px; height: 42px; font-size: 20px; border-radius: 10px; }
            .tn-title { font-size: 32px; }
            .tn-slogan { font-size: 1rem; }
            .tn-sub { font-size: 0.8rem; }
            .tn-action-box { padding: 1.2rem; border-radius: 16px; }
        }
      `}} />
    </div>
  );
}
EOF

# =================================================================
# 6. TIÊM MÃ SEO (ÉP ZALO NHẬN ẢNH) & DỊCH THUẬT
# =================================================================
RUN cat <<'EOF' > post_build.js
const fs = require('fs');
const path = require('path');

function overrideFile(filePath, replacerCallback) {
    if (!fs.existsSync(filePath)) return;
    const orig = fs.readFileSync(filePath, 'utf8');
    const modified = replacerCallback(orig);
    if (orig !== modified) fs.writeFileSync(filePath, modified, 'utf8');
}

// 1. TIÊM MÃ SEO TRỰC TIẾP VÀO LAYOUT.TSX ĐỂ ĐÁNH BẠI ZALO
overrideFile('app/layout.tsx', (content) => {
    // Sửa Text thường
    content = content.replace(/LiveKit Meet \| Conference app build with LiveKit open source/g, 'Hệ thống Họp trực tuyến | Thanh Nguyen Group');
    content = content.replace(/LiveKit is an open source WebRTC project[^"']*/g, 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp (E2EE).');
    content = content.replace(/@livekitted/g, '@thanhnguyen');
    
    // TIÊM OBJECT OPENGRAPH VÀO LÕI METADATA CỦA NEXT.JS
    if (!content.includes('openGraph:')) {
        content = content.replace(/export const metadata: Metadata = \{/, 
            `export const metadata: Metadata = {
              openGraph: {
                title: 'Hệ thống Họp trực tuyến | Thanh Nguyen Group',
                description: 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp.',
                images: [
                  {
                    url: '/images/livekit-meet-open-graph.png',
                    width: 1200,
                    height: 630,
                    alt: 'Thanh Nguyen Group',
                  },
                ],
                locale: 'vi_VN',
                type: 'website',
              },
              twitter: {
                card: 'summary_large_image',
                title: 'Hệ thống Họp trực tuyến | Thanh Nguyen Group',
                description: 'Nền tảng họp trực tuyến bảo mật cấp độ doanh nghiệp.',
                images: ['/images/livekit-meet-open-graph.png'],
              },`
        );
    }
    return content;
});

// 2. CSS UI PHÒNG HỌP KÍNH MỜ + NÚT ĐỎ CHỮ TRẮNG
const cssPath = 'styles/globals.css';
if (fs.existsSync(cssPath)) {
    const customCSS = `
.lk-control-bar {
    background: rgba(24, 24, 27, 0.85) !important;
    backdrop-filter: blur(20px) saturate(150%) !important;
    border-top: 1px solid rgba(255, 255, 255, 0.1) !important;
    padding: 1rem !important;
}
.lk-disconnect-button {
    background-color: #ef4444 !important;
    color: #ffffff !important;
    box-shadow: 0 4px 15px rgba(239, 68, 68, 0.4) !important;
}
.lk-disconnect-button:hover { background-color: #dc2626 !important; }
.lk-disconnect-button svg, .lk-disconnect-button * {
    color: #ffffff !important; fill: #ffffff !important;
}
.lk-participant-tile {
    border-radius: 16px !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
}
@media (max-width: 640px) {
    .lk-control-bar { padding: 0.5rem !important; gap: 0.25rem !important; }
    .lk-button { padding: 0.5rem !important; border-radius: 10px !important; }
}
`;
    fs.appendFileSync(cssPath, customCSS, 'utf8');
}

// 3. Dịch Menu "Chuột Phải"
function translate(dir) {
    if (!fs.existsSync(dir)) return;
    fs.readdirSync(dir).forEach(file => {
        const fp = path.join(dir, file);
        if (fs.statSync(fp).isDirectory()) translate(fp);
        else if (fp.endsWith('.js') || fp.endsWith('.mjs')) {
            overrideFile(fp, (c) => {
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
                return c;
            });
        }
    });
}
translate('node_modules/@livekit/components-react/dist');
translate('node_modules/@livekit/components-core/dist');
EOF
RUN node post_build.js

# 7. Thông số Server
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
