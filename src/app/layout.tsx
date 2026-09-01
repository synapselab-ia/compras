import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import "./prototype-detail.css";

export const metadata: Metadata = {
  title: "Compras — Central do Setor",
  description: "Protótipo demonstrativo da Central do Setor para acompanhamento de contratações.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
