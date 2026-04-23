import { AnnouncementsRouter } from "@/components/announcements/announcements-router";

export async function generateStaticParams() {
  return [{ slug: [] }];
}

export default function AnnouncementsPage() {
  return <AnnouncementsRouter />;
}
