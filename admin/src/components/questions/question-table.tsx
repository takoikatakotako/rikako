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
import type { Question } from "@/lib/api/types";

interface QuestionTableProps {
  questions: Question[];
}

export function QuestionTable({ questions }: QuestionTableProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-16">ID</TableHead>
          <TableHead>問題文</TableHead>
          <TableHead className="w-24">選択肢数</TableHead>
          <TableHead className="w-24">画像</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {questions.map((q) => (
          <TableRow key={q.id}>
            <TableCell>{q.id}</TableCell>
            <TableCell>
              <Link
                href={`/questions/${q.id}`}
                className="hover:underline"
              >
                {q.text.length > 80 ? `${q.text.slice(0, 80)}...` : q.text}
              </Link>
            </TableCell>
            <TableCell>
              <Badge variant="secondary">{q.choices?.length ?? 0}</Badge>
            </TableCell>
            <TableCell>
              {q.images && q.images.length > 0 ? (
                <Badge variant="outline">{q.images.length}</Badge>
              ) : (
                "-"
              )}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
