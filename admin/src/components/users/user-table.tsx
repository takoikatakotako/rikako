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
import type { User } from "@/lib/api/types";

interface UserTableProps {
  users: User[];
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

export function UserTable({ users }: UserTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead>Identity ID</TableHead>
          <TableHead>表示名</TableHead>
          <TableHead className="w-48">登録日</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {users.map((user) => (
          <TableRow key={user.id}>
            <TableCell>{user.id}</TableCell>
            <TableCell>
              <Link
                href={`/users/${user.id}`}
                className="font-mono text-sm text-primary hover:underline"
              >
                {user.identityId}
              </Link>
            </TableCell>
            <TableCell className="text-muted-foreground">
              {user.displayName || "-"}
            </TableCell>
            <TableCell className="text-muted-foreground">
              {formatDate(user.createdAt)}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
