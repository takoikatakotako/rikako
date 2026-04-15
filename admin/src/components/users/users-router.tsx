"use client";

import { useRouteSlug } from "@/hooks/use-route-slug";
import { UserList } from "@/components/users/user-list";
import { UserDetail } from "@/components/users/user-detail";

export function UsersRouter() {
  const { slug, mounted } = useRouteSlug("users");

  if (!mounted) {
    return <p className="text-muted-foreground">読み込み中...</p>;
  }

  if (!slug || slug.length === 0) {
    return <UserList />;
  }

  const id = Number(slug[0]);
  return <UserDetail id={id} />;
}
