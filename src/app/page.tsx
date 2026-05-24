import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function Home() {
  const supabase = await createClient();
  const { data: user } = await supabase.auth.getUser();

  if (!user.user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role")
    .eq("id", user.user.id)
    .single();

  if (profile?.role === "lecturer") {
    redirect("/lecturer/dashboard");
  }

  if (profile?.role === "student") {
    redirect("/student/dashboard");
  }

  redirect("/login");
}
