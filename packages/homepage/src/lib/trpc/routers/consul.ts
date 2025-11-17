import { env } from "$env/dynamic/private";
import t from "../t";
import { readFileSync } from "fs";
import { resolve } from "path";
import * as TOML from "toml";
import { z } from "zod";

const NodeSchema = z.object({
	name: z.string(),
});

const NodesConfigSchema = z.object({
	nodes: z.array(NodeSchema),
});

interface ConsulMember {
	Name: string;
	Addr: string;
	Port: number;
	Status: number;
	Tags?: Record<string, string>;
}

export const consulRouter = t.router({
	nodes: t.procedure.query(async () => {
		try {
			// Read the TOML configuration file
			let config;
			try {
				const configPath = resolve(env.NODES_FILE);
				const configContent = readFileSync(configPath, "utf-8");
				config = TOML.parse(configContent);
			} catch (e) {
				console.error("Failed to read/parse config file:", (e as Error).message);
				// Return empty array if config unavailable
				return [];
			}

			// Validate the config structure
			const validatedConfig = NodesConfigSchema.parse(config);
			const expectedNodeNames = new Set(validatedConfig.nodes.map((n) => n.name));

			// Query Consul's catalog API with timeout
			const consulUrl = env.CONSUL_HTTP_ADDR || "http://localhost:8500";
			const consulToken = env.CONSUL_HTTP_TOKEN;

			const headers: Record<string, string> = {};
			if (consulToken) {
				headers["X-Consul-Token"] = `${consulToken}`;
			}

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

			let response;
			try {
				response = await fetch(`${consulUrl}/v1/agent/members`, {
					headers,
					signal: controller.signal,
				});
			} catch (e) {
				clearTimeout(timeoutId);
				const error = e as any;
				console.error("Consul connection failed:", error.cause?.code || (e as Error).message);
				// Return all nodes as offline
				return Array.from(expectedNodeNames).map((name) => ({
					name,
					ready: false,
					address: null,
				}));
			}
			clearTimeout(timeoutId);

			if (!response.ok) {
				console.error(`Consul API error: ${response.status} ${response.statusText}`);
				return Array.from(expectedNodeNames).map((name) => ({
					name,
					ready: false,
					address: null,
				}));
			}

			let consulNodes: ConsulMember[];
			try {
				consulNodes = await response.json();
			} catch (e) {
				console.error("Failed to parse Consul response:", (e as Error).message);
				return Array.from(expectedNodeNames).map((name) => ({
					name,
					ready: false,
					address: null,
				}));
			}

			const nodeMap = new Map(consulNodes.map((n) => [n.Name, n]));

			// Combine expected nodes with online status and IP address
			const nodes = Array.from(expectedNodeNames).map((name) => ({
				name,
				ready: nodeMap.has(name) && nodeMap.get(name)?.Status == 1,
				address: nodeMap.get(name)?.Addr ?? null,
			}));

			return nodes;
		} catch (e) {
			console.error("Unexpected error in nodes query:", (e as Error).message);
			return [];
		}
	}),
});
