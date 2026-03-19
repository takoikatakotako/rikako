"use client";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Plus, Trash2 } from "lucide-react";
import type { Choice } from "@/lib/api/types";

interface ChoiceEditorProps {
  choices: Choice[];
  onChange: (choices: Choice[]) => void;
}

export function ChoiceEditor({ choices, onChange }: ChoiceEditorProps) {
  const correctIndex = choices.findIndex((c) => c.isCorrect);

  function addChoice() {
    onChange([...choices, { text: "", isCorrect: false }]);
  }

  function removeChoice(index: number) {
    if (choices.length <= 2) return;
    const next = choices.filter((_, i) => i !== index);
    if (choices[index].isCorrect && next.length > 0) {
      next[0].isCorrect = true;
    }
    onChange(next);
  }

  function updateText(index: number, text: string) {
    const next = choices.map((c, i) => (i === index ? { ...c, text } : c));
    onChange(next);
  }

  function setCorrect(index: number) {
    const next = choices.map((c, i) => ({
      ...c,
      isCorrect: i === index,
    }));
    onChange(next);
  }

  return (
    <div className="space-y-3">
      <Label>選択肢</Label>
      <RadioGroup
        value={String(correctIndex)}
        onValueChange={(v) => setCorrect(Number(v))}
      >
        {choices.map((choice, index) => (
          <div key={index} className="flex items-center gap-2">
            <RadioGroupItem value={String(index)} id={`choice-${index}`} />
            <Input
              value={choice.text}
              onChange={(e) => updateText(index, e.target.value)}
              placeholder={`選択肢 ${index + 1}`}
              className="flex-1"
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              onClick={() => removeChoice(index)}
              disabled={choices.length <= 2}
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        ))}
      </RadioGroup>
      <Button type="button" variant="outline" size="sm" onClick={addChoice}>
        <Plus className="mr-1 h-4 w-4" />
        選択肢を追加
      </Button>
      <p className="text-xs text-muted-foreground">
        ラジオボタンで正解を選択してください
      </p>
    </div>
  );
}
