import { UsersRouter } from "@/components/users/users-router";

export async function generateStaticParams() {
  return [{ slug: [] }];
}

export default function UsersPage() {
  return <UsersRouter />;
}
