"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useQuestions } from "@/hooks/use-questions";
import { Plus, ChevronLeft, ChevronRight, X } from "lucide-react";
import type { Question } from "@/lib/api/types";

const PAGE_SIZE = 10;

interface QuestionPickerProps {
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  selectedQuestions: Question[];
  onSelectedQuestionsChange: (questions: Question[]) => void;
}

export function QuestionPicker({
  selectedIds,
  onChange,
  selectedQuestions,
  onSelectedQuestionsChange,
}: QuestionPickerProps) {
  const [open, setOpen] = useState(false);
  const [page, setPage] = useState(0);
  const { data } = useQuestions(PAGE_SIZE, page * PAGE_SIZE);

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  function toggleQuestion(question: Question) {
    if (selectedIds.includes(question.id)) {
      onChange(selectedIds.filter((id) => id !== question.id));
      onSelectedQuestionsChange(
        selectedQuestions.filter((q) => q.id !== question.id),
      );
    } else {
      onChange([...selectedIds, question.id]);
      onSelectedQuestionsChange([...selectedQuestions, question]);
    }
  }

  function removeQuestion(id: number) {
    onChange(selectedIds.filter((qid) => qid !== id));
    onSelectedQuestionsChange(selectedQuestions.filter((q) => q.id !== id));
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium">
          選択中の問題 ({selectedIds.length}件)
        </p>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger render={<Button type="button" variant="outline" size="sm" />}>
            <Plus className="mr-1 h-4 w-4" />
            問題を選択
          </DialogTrigger>
          <DialogContent className="max-w-2xl">
            <DialogHeader>
              <DialogTitle>問題を選択</DialogTitle>
            </DialogHeader>
            {data && (
              <>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-12"></TableHead>
                      <TableHead className="w-16">ID</TableHead>
                      <TableHead>問題文</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {data.questions.map((q) => (
                      <TableRow
                        key={q.id}
                        className="cursor-pointer"
                        onClick={() => toggleQuestion(q)}
                      >
                        <TableCell>
                          <input
                            type="checkbox"
                            checked={selectedIds.includes(q.id)}
                            readOnly
                            className="h-4 w-4"
                          />
                        </TableCell>
                        <TableCell>{q.id}</TableCell>
                        <TableCell>
                          {q.text.length > 60
                            ? `${q.text.slice(0, 60)}...`
                            : q.text}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
                {totalPages > 1 && (
                  <div className="flex items-center justify-center gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => setPage((p) => Math.max(0, p - 1))}
                      disabled={page === 0}
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </Button>
                    <span className="text-sm text-muted-foreground">
                      {page + 1} / {totalPages}
                    </span>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        setPage((p) => Math.min(totalPages - 1, p + 1))
                      }
                      disabled={page >= totalPages - 1}
                    >
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                )}
              </>
            )}
          </DialogContent>
        </Dialog>
      </div>

      {selectedQuestions.length > 0 && (
        <ul className="space-y-1 rounded-md border p-2">
          {selectedQuestions.map((q) => (
            <li key={q.id} className="flex items-center justify-between text-sm">
              <span>
                <span className="text-muted-foreground">#{q.id}</span>{" "}
                {q.text.length > 50 ? `${q.text.slice(0, 50)}...` : q.text}
              </span>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="h-6 w-6"
                onClick={() => removeQuestion(q.id)}
              >
                <X className="h-3 w-3" />
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
