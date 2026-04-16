"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { App } from "@/lib/api/types";

interface AppTableProps {
  apps: App[];
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function AppTable({ apps }: AppTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead>Slug</TableHead>
          <TableHead>タイトル</TableHead>
          <TableHead className="w-48">作成日</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {apps.map((app) => (
          <TableRow key={app.id}>
            <TableCell>{app.id}</TableCell>
            <TableCell className="font-mono text-sm">{app.slug}</TableCell>
            <TableCell>{app.title}</TableCell>
            <TableCell className="text-muted-foreground">
              {app.createdAt ? formatDate(app.createdAt) : "-"}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
