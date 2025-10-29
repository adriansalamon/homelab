import { jellyfinRouter, consulRouter } from "./routers";
import t from "./t";

export const router = t.router({
	jellyfin: jellyfinRouter,
	consul: consulRouter,
	user: t.procedure.query(({ ctx: { user } }) => user),
});

export const createCaller = t.createCallerFactory(router);

export type Router = typeof router;
