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
import type { Category } from "@/lib/api/types";

interface CategoryTableProps {
  categories: Category[];
}

export function CategoryTable({ categories }: CategoryTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead>タイトル</TableHead>
          <TableHead>説明</TableHead>
          <TableHead className="w-24">問題集数</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {categories.map((cat) => (
          <TableRow key={cat.id}>
            <TableCell>{cat.id}</TableCell>
            <TableCell>
              <Link href={`/categories/${cat.id}`} className="hover:underline">
                {cat.title}
              </Link>
            </TableCell>
            <TableCell className="text-muted-foreground">
              {cat.description
                ? cat.description.length > 60
                  ? `${cat.description.slice(0, 60)}...`
                  : cat.description
                : "-"}
            </TableCell>
            <TableCell>
              <Badge variant="secondary">{cat.workbookCount ?? 0}</Badge>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
