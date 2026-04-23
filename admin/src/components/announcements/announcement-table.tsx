"use client";

import Link from "next/link";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import type { Announcement } from "@/lib/api/types";

interface AnnouncementTableProps {
  announcements: Announcement[];
}

function formatDateTime(iso: string) {
  const d = new Date(iso);
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function categoryLabel(value: string): string {
  switch (value) {
    case "release":
      return "リリース";
    case "maintenance":
      return "メンテナンス";
    case "info":
      return "お知らせ";
    default:
      return value;
  }
}

export function AnnouncementTable({ announcements }: AnnouncementTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead className="w-28">種別</TableHead>
          <TableHead>タイトル</TableHead>
          <TableHead className="w-40">公開日時</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {announcements.map((a) => (
          <TableRow key={a.id}>
            <TableCell>{a.id}</TableCell>
            <TableCell>
              <Badge variant="secondary">{categoryLabel(a.category)}</Badge>
            </TableCell>
            <TableCell>
              <Link
                href={`/announcements/${a.id}`}
                className="hover:underline"
              >
                {a.title}
              </Link>
            </TableCell>
            <TableCell className="text-muted-foreground">
              {formatDateTime(a.publishedAt)}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
