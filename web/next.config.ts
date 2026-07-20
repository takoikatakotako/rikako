import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // 静的エクスポート（S3 + CloudFront 配信）。個別問題ページを実HTMLで生成し SEO を効かせる。
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
