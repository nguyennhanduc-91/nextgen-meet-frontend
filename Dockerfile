# Nâng cấp lên Node 20
FROM node:20-alpine AS builder
WORKDIR /app

# 1. Cài đặt công cụ và LFS
RUN apk add --no-cache git bash python3 make g++ git-lfs wget
RUN git clone https://github.com/livekit/meet.git .
RUN git lfs install && git lfs pull

# 2. Tải ảnh SEO Zalo từ GitHub của bạn
RUN wget -qO public/images/livekit-meet-open-graph.png "https://raw.githubusercontent.com/nguyennhanduc-91/nextgen-meet-frontend/main/ivekit-meet-open-graph.png" || true

# 3. Cài đặt thư viện NPM
RUN corepack enable && corepack prepare pnpm@latest --activate
RUN pnpm install

# 4. GHI ĐÈ FILE API (MỞ KHÓA QUYỀN HOST)
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

    // CẤP QUYỀN HOST TẠI ĐÂY (roomAdmin: true)
    const grant: VideoGrant = {
      roomJoin: true,
      room: roomName,
      roomAdmin: true, // <--- Đã mở khóa quyền quản trị!
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

# 5. GHI ĐÈ FILE GIAO DIỆN TRANG CHỦ (THIẾT KẾ ENTERPRISE)
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
    <div className="Home_tabContainer__OWE3m" style={{ backgroundColor: "#18181b", padding: "2rem", borderRadius: "16px", border: "1px solid #27272a" }}>
      <div style={{ display: "flex", gap: "10px", marginBottom: "2rem" }}>
        <button onClick={() => router.push('/?tab=demo')} className="lk-button" aria-pressed={tabIndex === 0} style={{ flex: 1, backgroundColor: tabIndex === 0 ? "#dc2626" : "#27272a" }}>Họp Nhanh</button>
        <button onClick={() => router.push('/?tab=custom')} className="lk-button" aria-pressed={tabIndex === 1} style={{ flex: 1, backgroundColor: tabIndex === 1 ? "#dc2626" : "#27272a" }}>Phòng Riêng</button>
      </div>
      <div className="Home_tabContent__rLu5Q">
        {tabIndex === 0 ? (
          <>
            <p style={{ margin: "0 0 1.5rem 0", color: "#e4e4e7" }}>Khởi tạo phòng họp bảo mật ngay lập tức.</p>
            <button className="lk-button" onClick={startMeeting} style={{ width: "100%", padding: "1rem", fontSize: "1.1rem", backgroundColor: "#ef4444" }}>Bắt Đầu Cuộc Họp</button>
          </>
        ) : (
          <form onSubmit={(e) => { e.preventDefault(); /* Custom logic handled by original if needed */ }}>
             <p style={{ margin: "0 0 1rem 0", color: "#e4e4e7" }}>Kết nối với máy chủ nội bộ của Thanh Nguyen Group.</p>
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
    <>
      <main className="Home_main__VkIEL" data-lk-theme="default" style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "80vh", padding: "2rem" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1rem", marginBottom: "2.5rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
            <div style={{ background: "linear-gradient(135deg, #ef4444 0%, #991b1b 100%)", width: "60px", height: "60px", borderRadius: "16px", display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontWeight: "900", fontSize: "28px", boxShadow: "0 10px 30px -5px rgba(220, 38, 38, 0.6)" }}>TN</div>
            <h1 style={{ fontSize: "48px", fontWeight: "900", color: "white", margin: 0, letterSpacing: "-0.04em" }}>NextGen <span style={{ color: "#ef4444" }}>Meet</span></h1>
          </div>
          <div style={{ textAlign: "center" }}>
            <p style={{ color: "#e4e4e7", fontSize: "1.25rem", fontWeight: "500", margin: "0 0 5px 0" }}>Nền tảng hội nghị trực tuyến bảo mật cấp độ doanh nghiệp.</p>
            <p style={{ color: "#a1a1aa", fontSize: "1rem", margin: 0 }}>Phát triển và vận hành độc quyền bởi <b style={{color: "#ffffff"}}>Thanh Nguyen Group</b>.</p>
          </div>
        </div>
        <Suspense fallback="Đang tải...">
          <Tabs />
        </Suspense>
      </main>
      <footer style={{ padding: "2rem", textAlign: "center", color: "#71717a", fontSize: "0.9rem" }}>
        Bản quyền © 2026 thuộc về <b style={{color:"#fff"}}>Thanh Nguyen Group</b>. Mọi dữ liệu được mã hóa E2EE.
      </footer>
    </>
  );
}
EOF

# 6. SCRIPT DỊCH CÁC NÚT TRONG PHÒNG HỌP (TỪ THƯ VIỆN ĐÃ BIÊN DỊCH)
RUN cat <<'EOF' > patch-vi.js
const fs = require('fs');
const path = require('path');
function patchDir(dir) {
    if (!fs.existsSync(dir)) return;
    for (const file of fs.readdirSync(dir)) {
        const fp = path.join(dir, file);
        if (fs.statSync(fp).isDirectory()) patchDir(fp);
        else if (fp.endsWith('.js') || fp.endsWith('.mjs')) {
            let c = fs.readFileSync(fp, 'utf8');
            let orig = c;
            c = c.split('"Microphone"').join('"Micro"');
            c = c.split('"Camera"').join('"Máy ảnh"');
            c = c.split('"Share screen"').join('"Chia sẻ màn hình"');
            c = c.split('"Stop sharing"').join('"Dừng chia sẻ"');
            c = c.split('"Chat"').join('"Trò chuyện"');
            c = c.split('"Leave"').join('"Rời phòng"');
            c = c.split('"Disable camera"').join('"Tắt máy ảnh"');
            c = c.split('"Enable camera"').join('"Bật máy ảnh"');
            c = c.split('"Mute"').join('"Tắt mic"');
            c = c.split('"Unmute"').join('"Bật mic"');
            c = c.split('"Remove from room"').join('"Mời ra khỏi phòng"');
            if (c !== orig) fs.writeFileSync(fp, c, 'utf8');
        }
    }
}
patchDir('node_modules/@livekit/components-react/dist');
EOF
RUN node patch-vi.js

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
