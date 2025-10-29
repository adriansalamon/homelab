<script lang="ts">
	import { SidebarLink, ConsulNodes, SambaShares } from "$lib/components/sidebar";
	import { BookOpenText, Cable } from "lucide-svelte";
	import type { Snippet } from "svelte";
	import UserMenu from "../UserMenu.svelte";
	import { Separator } from "$lib/components/ui";

	interface Props {
		children: Snippet;
		domain: string;
	}

	const { children, domain }: Props = $props();
</script>

<div class="mx-auto flex h-full w-full max-w-screen-xl">
	<div class="my-6 flex pl-4">
		<aside class="flex w-full min-w-72 flex-col overflow-y-auto py-4 pl-4 pr-4 xl:pl-0">
			<div class="align-center mb-4 flex items-center">
				<h1 class="text-2xl font-semibold">Salamon</h1>
			</div>
			<ul class="flex flex-col gap-1">
				<SidebarLink
					href="https://grafana.local.salamon.xyz/public-dashboards/b1adb135338b4807b3a9ed5971c11a9c"
				>
					{#snippet icon(className: string)}
						<Cable class={className} />
					{/snippet}
					Uptime status
				</SidebarLink>
				<SidebarLink href="/docs">
					{#snippet icon(className: string)}
						<BookOpenText class={className} />
					{/snippet}
					Documentation
				</SidebarLink>
			</ul>

			<ul class="mt-2 flex flex-col gap-3">
				<ConsulNodes />
				<SambaShares />
			</ul>

			<div class="mt-auto">
				<UserMenu {domain} />
			</div>
		</aside>
		<Separator orientation="vertical" />
	</div>

	<main class="h-full w-full overflow-y-auto overflow-x-hidden px-20 py-8">
		{@render children()}
	</main>
</div>
