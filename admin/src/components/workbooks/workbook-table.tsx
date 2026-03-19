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
import type { Workbook } from "@/lib/api/types";

interface WorkbookTableProps {
  workbooks: Workbook[];
}

export function WorkbookTable({ workbooks }: WorkbookTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead>タイトル</TableHead>
          <TableHead>説明</TableHead>
          <TableHead className="w-24">問題数</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {workbooks.map((wb) => (
          <TableRow key={wb.id}>
            <TableCell>{wb.id}</TableCell>
            <TableCell>
              <Link href={`/workbooks/${wb.id}`} className="hover:underline">
                {wb.title}
              </Link>
            </TableCell>
            <TableCell className="text-muted-foreground">
              {wb.description
                ? wb.description.length > 60
                  ? `${wb.description.slice(0, 60)}...`
                  : wb.description
                : "-"}
            </TableCell>
            <TableCell>
              <Badge variant="secondary">{wb.questionCount ?? 0}</Badge>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
