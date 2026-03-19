import { QuestionsRouter } from "@/components/questions/questions-router";

export async function generateStaticParams() {
  return [{ slug: [] }];
}

export default function QuestionsPage() {
  return <QuestionsRouter />;
}
