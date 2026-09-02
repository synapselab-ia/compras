function rejectDirectAuthApi(): Response {
  return new Response(null, {
    status: 404,
    headers: {
      "cache-control": "no-store",
    },
  });
}

/**
 * Deliberately does not delegate to auth.handler(). F14 supports authentication
 * only through narrow server actions, so sign-up and every lateral Better Auth
 * endpoint remain unavailable on the application's HTTP surface.
 */
export const GET = rejectDirectAuthApi;
export const POST = rejectDirectAuthApi;
export const PUT = rejectDirectAuthApi;
export const PATCH = rejectDirectAuthApi;
export const DELETE = rejectDirectAuthApi;
