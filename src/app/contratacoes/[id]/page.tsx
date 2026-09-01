import { ContractingDetail } from "@/features/contracting-detail/components/contracting-detail";
import { getDemoContractingDetail } from "@/features/contracting-detail/demo-detail-data";
import { notFound } from "next/navigation";

type ContractingDetailPageProps = {
  params: Promise<{ id: string }>;
};

export default async function ContractingDetailPage({ params }: ContractingDetailPageProps) {
  const { id } = await params;
  const detail = getDemoContractingDetail(id);

  if (!detail) {
    notFound();
  }

  return <ContractingDetail detail={detail} />;
}
