import { CategoriesRouter } from "@/components/categories/categories-router";

export async function generateStaticParams() {
  return [{ slug: [] }];
}

export default function CategoriesPage() {
  return <CategoriesRouter />;
}
