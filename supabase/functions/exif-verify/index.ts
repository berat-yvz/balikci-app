
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import * as exifr from "https://esm.sh/exifr@6";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CHECKIN_EXIF_RADIUS_KM = 1.0;
const TIMESTAMP_TOLERANCE_MINUTES = 30;

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371; // km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function isTimestampValid(exifDate: Date): boolean {
  const diffMs = Math.abs(Date.now() - exifDate.getTime());
  return diffMs <= TIMESTAMP_TOLERANCE_MINUTES * 60 * 1000;
}

function extractCheckinIdFromObjectName(objectName: string): string | null {
  // expected: checkins/{checkinId}/photo.ext
  const parts = objectName.split("/").filter(Boolean);
  if (parts.length < 3) return null;
  if (parts[0] !== "checkins") return null;
  return parts[1] ?? null;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return new Response("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY", { status: 500 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const payload = await req.json().catch(() => null);
    if (!payload) return new Response("Invalid payload", { status: 400 });

    // Storage triggers payload shape can differ slightly; try multiple keys.
    const bucketId =
      payload.bucketId ??
      payload.bucket_id ??
      payload?.record?.bucketId ??
      payload?.record?.bucket_id;

    const objectName =
      payload.name ??
      payload.objectName ??
      payload?.record?.name ??
      payload?.record?.objectName;

    if (!bucketId || !objectName || typeof objectName !== "string") {
      return new Response("Missing bucketId/objectName in payload", { status: 400 });
    }

    const checkinId = extractCheckinIdFromObjectName(objectName);

    if (!checkinId) {
      // Not a check-in photo we care about.
      return new Response("Ignored object", { status: 200 });
    }

    // Load checkin + spot coords for validation.
    const { data: checkin, error: checkinErr } = await supabase
      .from("checkins")
      .select("id, spot_id")
      .eq("id", checkinId)
      .maybeSingle();

    if (checkinErr || !checkin) {
      return new Response(
        `Checkin fetch error: ${checkinErr?.message ?? "not found"}`,
        { status: 200 },
      );
    }

    const { data: spot, error: spotErr } = await supabase
      .from("fishing_spots")
      .select("lat, lng")
      .eq("id", checkin.spot_id)
      .maybeSingle();

    if (spotErr || !spot || spot.lat == null || spot.lng == null) {
      return new Response(
        `Spot fetch error: ${spotErr?.message ?? "missing coords"}`,
        { status: 200 },
      );
    }

    // Download the uploaded image from Storage.
    const { data: downloaded, error: downloadErr } = await supabase
      .storage
      .from(bucketId)
      .download(objectName);

    if (downloadErr || !downloaded) {
      return new Response(
        `Storage download error: ${downloadErr?.message ?? "missing data"}`,
        { status: 200 },
      );
    }

    // exifr can parse from ArrayBuffer/Uint8Array.
    const arrayBuffer = await downloaded.arrayBuffer();

    // Parse EXIF GPS + original datetime.
    const latLong = await exifr.gps(arrayBuffer).catch(() => null);
    const originalDateRaw = await (exifr as any)
      .parseDateTimeOriginal?.(arrayBuffer)
      .catch(() => null);

    let originalDate: Date | null = null;
    if (originalDateRaw instanceof Date) {
      originalDate = originalDateRaw;
    } else if (typeof originalDateRaw === "string") {
      const d = new Date(originalDateRaw);
      originalDate = isNaN(d.getTime()) ? null : d;
    }

    let exifOk = false;
    if (latLong?.latitude != null &&
      latLong?.longitude != null &&
      originalDate != null) {
      const distKmCorrect = haversineKm(
        spot.lat,
        spot.lng,
        latLong.latitude,
        latLong.longitude,
      );

      const locationOk = distKmCorrect <= CHECKIN_EXIF_RADIUS_KM;
      const timestampOk = isTimestampValid(originalDate);

      exifOk = locationOk && timestampOk;
    }

    // Update checkin record.
    await supabase
      .from("checkins")
      .update({ exif_verified: exifOk })
      .eq("id", checkinId);

    return new Response(JSON.stringify({ ok: true, checkinId, exifOk }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response("Internal error", { status: 500 });
  }
});

