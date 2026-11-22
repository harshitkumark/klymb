// Edge Function: send-notifications
// B15: Push Sender — processes notification_outbox and sends via APNs
//
// Invoked by pg_cron (every minute) or manually via:
//   supabase functions invoke send-notifications
//
// Environment secrets required:
//   APNS_KEY_ID       — Apple Push key ID (10-char)
//   APNS_TEAM_ID      — Apple Developer Team ID
//   APNS_PRIVATE_KEY  — P8 private key (PEM, ES256)
//   APNS_BUNDLE_ID    — App bundle ID (e.g. com.klymb.app)
//   APNS_ENVIRONMENT  — "production" or "sandbox" (default: production)
//   SUPABASE_URL       — Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY — Service-role key for DB access
//
// Security: Never logs tokens or health data (AGENTS.md Rule 10, ARCHITECTURE.md §7).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.2.3/index.ts";

// ── Types ──────────────────────────────────────────────────────

interface OutboxRow {
  id: number;
  user_id: string;
  type: string;
  title: string;
  body: string;
  payload: Record<string, unknown>;
  status: string;
  scheduled_at: string;
}

interface DeviceToken {
  apns_token: string;
  environment: string;
}

interface SendResult {
  outbox_id: number;
  token: string;
  success: boolean;
  status_code?: number;
  apns_id?: string;
  reason?: string;
}

// ── Constants ──────────────────────────────────────────────────

const BATCH_SIZE = 100;
const MAX_RETRIES = 3;
const BASE_BACKOFF_MS = 500;

const APNS_HOST_PROD = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";

// APNs error reasons that indicate an invalid token — remove from DB
const INVALID_TOKEN_REASONS = new Set([
  "BadDeviceToken",
  "Unregistered",
  "DeviceTokenNotForTopic",
  "ExpiredProviderToken",
]);

// ── APNs JWT ───────────────────────────────────────────────────

let cachedJwt: { token: string; expiresAt: number } | null = null;

async function getApnsJwt(
  keyId: string,
  teamId: string,
  privateKeyPem: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // APNs tokens are valid for 60 minutes; refresh at 50 min
  if (cachedJwt && cachedJwt.expiresAt > now) {
    return cachedJwt.token;
  }

  const privateKey = await importPKCS8(privateKeyPem, "ES256");

  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedJwt = { token: jwt, expiresAt: now + 50 * 60 };
  return jwt;
}

// ── Send single push ──────────────────────────────────────────

async function sendPush(
  apnsHost: string,
  jwt: string,
  bundleId: string,
  token: string,
  title: string,
  body: string,
  payload: Record<string, unknown>,
  notificationType: string,
): Promise<{ statusCode: number; apnsId?: string; reason?: string }> {
  const apnsPayload = {
    aps: {
      alert: { title, body },
      sound: "default",
      "thread-id": notificationType,
      "mutable-content": 1,
    },
    ...payload,
  };

  const url = `${apnsHost}/3/device/${token}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": "0",
      "content-type": "application/json",
    },
    body: JSON.stringify(apnsPayload),
  });

  const statusCode = response.status;
  const apnsId = response.headers.get("apns-id") ?? undefined;

  if (statusCode === 200) {
    return { statusCode, apnsId };
  }

  // Parse error response
  let reason: string | undefined;
  try {
    const errorBody = await response.json();
    reason = errorBody?.reason;
  } catch {
    reason = `HTTP ${statusCode}`;
  }

  return { statusCode, apnsId, reason };
}

// ── Send with retry ──────────────────────────────────────────

async function sendWithRetry(
  apnsHost: string,
  jwt: string,
  bundleId: string,
  token: string,
  title: string,
  body: string,
  payload: Record<string, unknown>,
  notificationType: string,
): Promise<{ statusCode: number; apnsId?: string; reason?: string }> {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    const result = await sendPush(
      apnsHost,
      jwt,
      bundleId,
      token,
      title,
      body,
      payload,
      notificationType,
    );

    // Success or client error (4xx) — don't retry
    if (result.statusCode === 200 || (result.statusCode >= 400 && result.statusCode < 500)) {
      return result;
    }

    // Server error (5xx) or rate limit (429) — retry with backoff
    if (attempt < MAX_RETRIES) {
      const backoff = BASE_BACKOFF_MS * Math.pow(2, attempt);
      await new Promise((resolve) => setTimeout(resolve, backoff));
    }
  }

  return { statusCode: 500, reason: "max_retries_exceeded" };
}

// ── Main handler ──────────────────────────────────────────────

Deno.serve(async (req) => {
  const startTime = Date.now();

  // Only allow POST and OPTIONS
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  try {
    // ── Load config from env ──────────────────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY");
    const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID");
    const apnsEnv = Deno.env.get("APNS_ENVIRONMENT") ?? "production";

    if (!supabaseUrl || !serviceRoleKey) {
      console.error(JSON.stringify({
        level: "error",
        msg: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY",
      }));
      return new Response(
        JSON.stringify({ error: "server_config_error" }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey || !apnsBundleId) {
      console.error(JSON.stringify({
        level: "error",
        msg: "Missing APNs config (APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID)",
      }));
      return new Response(
        JSON.stringify({ error: "apns_config_error" }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    const apnsHost = apnsEnv === "sandbox" ? APNS_HOST_SANDBOX : APNS_HOST_PROD;

    // ── Init Supabase client (service role) ───────────────────
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // ── 1. Fetch pending notifications ────────────────────────
    const { data: pending, error: fetchError } = await supabase
      .from("notification_outbox")
      .select("id, user_id, type, title, body, payload, status, scheduled_at")
      .eq("status", "pending")
      .lte("scheduled_at", new Date().toISOString())
      .order("scheduled_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (fetchError) {
      console.error(JSON.stringify({
        level: "error",
        msg: "Failed to fetch pending notifications",
        error: fetchError.message,
      }));
      return new Response(
        JSON.stringify({ error: "fetch_error", detail: fetchError.message }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    if (!pending || pending.length === 0) {
      console.log(JSON.stringify({
        level: "info",
        msg: "No pending notifications",
        duration_ms: Date.now() - startTime,
      }));
      return new Response(
        JSON.stringify({ processed: 0, sent: 0, failed: 0, skipped: 0 }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }

    const notifications = pending as OutboxRow[];

    console.log(JSON.stringify({
      level: "info",
      msg: "Processing batch",
      count: notifications.length,
    }));

    // ── 2. Get device tokens for all users in this batch ──────
    const userIds = [...new Set(notifications.map((n) => n.user_id))];

    const { data: tokenRows, error: tokenError } = await supabase
      .from("device_tokens")
      .select("user_id, apns_token, environment")
      .in("user_id", userIds);

    if (tokenError) {
      console.error(JSON.stringify({
        level: "error",
        msg: "Failed to fetch device tokens",
        error: tokenError.message,
      }));
      return new Response(
        JSON.stringify({ error: "token_fetch_error" }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    // Build user_id -> tokens map
    const tokensByUser = new Map<string, DeviceToken[]>();
    for (const row of (tokenRows ?? []) as Array<{ user_id: string; apns_token: string; environment: string }>) {
      const existing = tokensByUser.get(row.user_id) ?? [];
      existing.push({ apns_token: row.apns_token, environment: row.environment });
      tokensByUser.set(row.user_id, existing);
    }

    // ── 3. Get APNs JWT ───────────────────────────────────────
    const jwt = await getApnsJwt(apnsKeyId, apnsTeamId, apnsPrivateKey);

    // ── 4. Process each notification ──────────────────────────
    let sent = 0;
    let failed = 0;
    let skipped = 0;
    const tokensToRemove: string[] = [];

    for (const notif of notifications) {
      const userTokens = tokensByUser.get(notif.user_id);

      if (!userTokens || userTokens.length === 0) {
        // No device tokens — mark as failed (no device)
        await supabase
          .from("notification_outbox")
          .update({
            status: "failed",
            error: "no_device_tokens",
            sent_at: new Date().toISOString(),
          })
          .eq("id", notif.id);

        skipped++;

        console.log(JSON.stringify({
          level: "info",
          msg: "Skipped notification — no device tokens",
          outbox_id: notif.id,
          notification_type: notif.type,
        }));
        continue;
      }

      // Send to all user devices
      let anySuccess = false;
      let lastError: string | undefined;

      for (const dt of userTokens) {
        // Use token's environment to pick the right APNs host
        const host = dt.environment === "sandbox" ? APNS_HOST_SANDBOX : apnsHost;

        const result = await sendWithRetry(
          host,
          jwt,
          apnsBundleId,
          dt.apns_token,
          notif.title,
          notif.body,
          notif.payload,
          notif.type,
        );

        if (result.statusCode === 200) {
          anySuccess = true;
          console.log(JSON.stringify({
            level: "info",
            msg: "Push sent",
            outbox_id: notif.id,
            notification_type: notif.type,
            apns_id: result.apnsId,
          }));
        } else {
          lastError = result.reason ?? `HTTP ${result.statusCode}`;

          // Check if token should be removed
          if (
            result.reason && INVALID_TOKEN_REASONS.has(result.reason) ||
            result.statusCode === 410
          ) {
            tokensToRemove.push(dt.apns_token);
            console.log(JSON.stringify({
              level: "warn",
              msg: "Invalid device token — marking for removal",
              outbox_id: notif.id,
              reason: result.reason,
              // Never log the actual token value
            }));
          } else {
            console.log(JSON.stringify({
              level: "warn",
              msg: "Push failed",
              outbox_id: notif.id,
              notification_type: notif.type,
              status_code: result.statusCode,
              reason: result.reason,
            }));
          }
        }
      }

      // Update outbox status
      if (anySuccess) {
        await supabase
          .from("notification_outbox")
          .update({
            status: "sent",
            sent_at: new Date().toISOString(),
            error: null,
          })
          .eq("id", notif.id);
        sent++;
      } else {
        await supabase
          .from("notification_outbox")
          .update({
            status: "failed",
            sent_at: new Date().toISOString(),
            error: lastError ?? "unknown_error",
          })
          .eq("id", notif.id);
        failed++;
      }
    }

    // ── 5. Remove invalid tokens ──────────────────────────────
    if (tokensToRemove.length > 0) {
      const { error: deleteError } = await supabase
        .from("device_tokens")
        .delete()
        .in("apns_token", tokensToRemove);

      if (deleteError) {
        console.error(JSON.stringify({
          level: "error",
          msg: "Failed to remove invalid tokens",
          error: deleteError.message,
          count: tokensToRemove.length,
        }));
      } else {
        console.log(JSON.stringify({
          level: "info",
          msg: "Removed invalid device tokens",
          count: tokensToRemove.length,
        }));
      }
    }

    // ── 6. Summary ────────────────────────────────────────────
    const summary = {
      processed: notifications.length,
      sent,
      failed,
      skipped,
      tokens_removed: tokensToRemove.length,
      duration_ms: Date.now() - startTime,
    };

    console.log(JSON.stringify({
      level: "info",
      msg: "Batch complete",
      ...summary,
    }));

    return new Response(JSON.stringify(summary), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    console.error(JSON.stringify({
      level: "error",
      msg: "Unhandled error in send-notifications",
      error: err instanceof Error ? err.message : String(err),
      stack: err instanceof Error ? err.stack : undefined,
    }));

    return new Response(
      JSON.stringify({ error: "internal_error" }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
});
