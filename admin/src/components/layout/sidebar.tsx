"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, FileQuestion, FolderOpen, Upload, Loader2, Users, AppWindow } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { apiPost } from "@/lib/api/client";
import type { PublishResponse } from "@/lib/api/types";

const navigation = [
  { name: "カテゴリ", href: "/categories", icon: FolderOpen },
  { name: "問題集", href: "/workbooks", icon: BookOpen },
  { name: "問題", href: "/questions", icon: FileQuestion },
  { name: "ユーザー", href: "/users", icon: Users },
  { name: "アプリ", href: "/apps", icon: AppWindow },
];

export function Sidebar() {
  const pathname = usePathname();
  const [publishing, setPublishing] = useState(false);

  const handlePublish = async () => {
    setPublishing(true);
    try {
      const result = await apiPost<PublishResponse>("/publish", {});
      toast.success(
        `出力完了: カテゴリ ${result.categoriesCount}件、問題集 ${result.workbooksCount}件`,
      );
    } catch {
      toast.error("出力に失敗しました");
    } finally {
      setPublishing(false);
    }
  };

  return (
    <aside className="flex h-screen w-60 flex-col border-r bg-background">
      <div className="flex h-14 items-center border-b px-4">
        <Link href="/" className="text-lg font-bold">
          Rikako Admin
        </Link>
      </div>
      <nav className="flex-1 space-y-1 p-2">
        {navigation.map((item) => {
          const isActive = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                isActive
                  ? "bg-accent text-accent-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
              )}
            >
              <item.icon className="h-4 w-4" />
              {item.name}
            </Link>
          );
        })}
      </nav>
      <div className="border-t p-2">
        <button
          onClick={handlePublish}
          disabled={publishing}
          className={cn(
            "flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
            "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
            "disabled:pointer-events-none disabled:opacity-50",
          )}
        >
          {publishing ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Upload className="h-4 w-4" />
          )}
          {publishing ? "出力中..." : "コンテンツ出力"}
        </button>
      </div>
    </aside>
  );
}
