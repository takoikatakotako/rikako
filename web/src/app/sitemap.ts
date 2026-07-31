import type { MetadataRoute } from "next";
import { siteConfig } from "@/lib/site";
import { getAllExams } from "@/lib/content";

// 静的エクスポート（output: export）でビルド時に sitemap.xml を生成する。
export const dynamic = "force-static";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = siteConfig.domain;
  const now = new Date();
  const exams = await getAllExams();

  // trailingSlash: true に合わせて URL は末尾スラッシュ付きにする。
  const examUrls: MetadataRoute.Sitemap = exams.map((e) => ({
    url: `${base}/exams/${e.id}/`,
    lastModified: now,
    changeFrequency: "monthly",
    priority: 0.8,
  }));

  const questionUrls: MetadataRoute.Sitemap = exams.flatMap((e) =>
    e.questions.map((q) => ({
      url: `${base}/questions/${q.id}/`,
      lastModified: now,
      changeFrequency: "monthly",
      priority: 0.6,
    })),
  );

  return [
    { url: `${base}/`, lastModified: now, changeFrequency: "weekly", priority: 1 },
    ...examUrls,
    ...questionUrls,
  ];
}
