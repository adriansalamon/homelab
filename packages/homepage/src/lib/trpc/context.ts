import { env } from "$env/dynamic/private";
import type { RequestEvent } from "@sveltejs/kit";

export async function createContext(event: RequestEvent) {
	let username = event.request.headers.get("Remote-User") ?? "guest";
	const name = event.request.headers.get("Remote-Name") ?? "Guest";
	const email = event.request.headers.get("Remote-Email");

	username = "adrian";

	// Temporarily disabled - will re-enable when authentik API clients are generated
	return {
		event,
		username,
		user: {
			name,
			email,
		},
	};
}

export type Context = Awaited<ReturnType<typeof createContext>>;
