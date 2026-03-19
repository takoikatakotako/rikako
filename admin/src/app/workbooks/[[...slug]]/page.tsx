import { WorkbooksRouter } from "@/components/workbooks/workbooks-router";

export async function generateStaticParams() {
  return [{ slug: [] }];
}

export default function WorkbooksPage() {
  return <WorkbooksRouter />;
}
