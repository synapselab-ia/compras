"use server";

import { redirect } from "next/navigation";

import {
  signInExistingIdentity,
  signOutCurrentIdentity,
} from "../../server/auth/private-admission";

function readStringField(formData: FormData, name: string): string | null {
  const value = formData.get(name);
  return typeof value === "string" ? value : null;
}

export async function signInAction(formData: FormData): Promise<never> {
  const email = readStringField(formData, "email");
  const password = readStringField(formData, "password");

  if (email === null || password === null) {
    redirect("/auth/sign-in?state=rejected");
  }

  const result = await signInExistingIdentity({ email, password });

  if (result === "signed-in") {
    redirect("/");
  }

  if (result === "unavailable") {
    redirect("/auth/sign-in?state=unavailable");
  }

  redirect("/auth/sign-in?state=rejected");
}

export async function signOutAction(): Promise<never> {
  const result = await signOutCurrentIdentity();

  if (result === "signed-out") {
    redirect("/auth/sign-in?state=signed-out");
  }

  redirect("/auth/sign-in?state=unavailable");
}
