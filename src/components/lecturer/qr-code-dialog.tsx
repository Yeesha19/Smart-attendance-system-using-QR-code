"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import QRCode from "qrcode";
import { toast } from "sonner";
import { QrCode, Timer, RefreshCw, Download } from "lucide-react";

interface QrCodeDialogProps {
  courseId: string;
}

const EXPIRY_MINUTES = 180;

export function QrCodeDialog({ courseId }: QrCodeDialogProps) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [qrToken, setQrToken] = useState<string | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [expiresAt, setExpiresAt] = useState<Date | null>(null);
  const [timeLeft, setTimeLeft] = useState(0);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const supabase = createClient();

  useEffect(() => {
    if (!expiresAt) return;
    const id = setInterval(() => {
      const left = Math.max(
        0,
        Math.floor((expiresAt.getTime() - Date.now()) / 1000),
      );
      setTimeLeft(left);
      if (left <= 0) clearInterval(id);
    }, 1000);
    return () => clearInterval(id);
  }, [expiresAt]);

  const hours = Math.floor(timeLeft / 3600);
  const minutes = Math.floor((timeLeft % 3600) / 60);
  const seconds = timeLeft % 60;

  const generateQr = useCallback(async () => {
    setLoading(true);
    try {
      const token = crypto.randomUUID();
      const expires = new Date(Date.now() + EXPIRY_MINUTES * 60 * 1000);

      const { error } = await supabase.from("sessions").insert({
        course_id: courseId,
        qr_token: token,
        expires_at: expires.toISOString(),
      });

      if (error) {
        toast.error("Failed to generate QR code");
        return;
      }

      const url = await QRCode.toDataURL(token, {
        width: 400,
        margin: 2,
        color: { dark: "#000000", light: "#ffffff" },
      });

      setQrToken(token);
      setQrDataUrl(url);
      setExpiresAt(expires);
      setTimeLeft(EXPIRY_MINUTES * 60);
    } catch {
      toast.error("Something went wrong");
    } finally {
      setLoading(false);
    }
  }, [courseId, supabase]);

  function handleDownload() {
    if (!qrDataUrl) return;
    const a = document.createElement("a");
    a.href = qrDataUrl;
    a.download = `qr-attendance-${qrToken?.slice(0, 8)}.png`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }

  async function loadActiveSession() {
    const { data: session } = await supabase
      .from("sessions")
      .select("qr_token, expires_at")
      .eq("course_id", courseId)
      .gt("expires_at", new Date().toISOString())
      .order("expires_at", { ascending: false })
      .limit(1)
      .single();

    if (session) {
      const url = await QRCode.toDataURL(session.qr_token, {
        width: 400,
        margin: 2,
        color: { dark: "#000000", light: "#ffffff" },
      });
      setQrToken(session.qr_token);
      setQrDataUrl(url);
      setExpiresAt(new Date(session.expires_at));
      setTimeLeft(
        Math.max(
          0,
          Math.floor(
            (new Date(session.expires_at).getTime() - Date.now()) / 1000,
          ),
        ),
      );
    }
  }

  function handleOpenChange(open: boolean) {
    setOpen(open);
    if (open) {
      setQrToken(null);
      setQrDataUrl(null);
      setExpiresAt(null);
      loadActiveSession();
    } else {
      setQrToken(null);
      setQrDataUrl(null);
      setExpiresAt(null);
    }
  }

  const timeDisplay =
    hours > 0
      ? `${hours}h ${minutes}m ${seconds}s`
      : `${minutes}:${seconds.toString().padStart(2, "0")}`;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger render={<Button />}>
        <QrCode />
        Generate QR Code
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Attendance QR Code</DialogTitle>
          <DialogDescription>
            Students scan this QR to mark attendance. Valid for{" "}
            {EXPIRY_MINUTES / 60} hours.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col items-center py-4 gap-4">
          {!qrToken ? (
            <Button onClick={generateQr} disabled={loading} className="w-full">
              {loading ? <RefreshCw className="animate-spin" /> : <QrCode />}
              {loading ? "Generating..." : "Generate Now"}
            </Button>
          ) : (
            <>
              <canvas ref={canvasRef} className="hidden" />
              <div className="flex items-center justify-center p-4 bg-white border rounded-xl">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={qrDataUrl ?? ""}
                  alt="Attendance QR Code"
                  className="size-50"
                />
              </div>
              <div className="flex items-center text-sm gap-2 text-muted-foreground">
                <Timer className="size-4" />
                <span>Expires in {timeDisplay}</span>
              </div>
              <div className="flex w-full gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleDownload}
                  className="flex-1"
                >
                  <Download />
                  Download
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={generateQr}
                  disabled={loading}
                  className="flex-1"
                >
                  <RefreshCw className={loading ? "animate-spin" : ""} />
                  Regenerate
                </Button>
              </div>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
