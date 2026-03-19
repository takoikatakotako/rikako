import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";

const adminApiUrl =
  process.env.NEXT_PUBLIC_ADMIN_API_URL ||
  "http://localhost:8081";

const nextConfig: NextConfig = {
  output: isProd ? "export" : undefined,
  trailingSlash: true,
  // dev時のみ有効（output: 'export' のビルドでは無視される）
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${adminApiUrl}/:path*`,
      },
    ];
  },
};

export default nextConfig;
