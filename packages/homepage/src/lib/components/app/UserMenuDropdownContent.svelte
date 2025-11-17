<script lang="ts">
	import { Dropdown } from "$lib/components/ui";
	import { LogOut, KeyRound, Fingerprint, Aperture, Cable, BookOpenText } from "lucide-svelte";
	import { onDestroy } from "svelte";
	import { createMediaStore } from "svelte-media-queries";

	interface Props {
		domain: string;
	}

	const { domain }: Props = $props();

	const matches = createMediaStore("(max-width: 1280px)");
	onDestroy(() => matches.destroy());
</script>

<Dropdown.Content class="z-49 min-w-56">
	{#if $matches}
		<Dropdown.Item
			href="https://grafana.local.salamon.xyz/public-dashboards/b1adb135338b4807b3a9ed5971c11a9c"
			class="p-3 md:px-2 md:py-1.5"
		>
			<Cable class="mr-2 h-4 w-4" />
			<span>Uptime status</span>
		</Dropdown.Item>
		<Dropdown.Item href="/docs" class="p-3 md:px-2 md:py-1.5">
			<BookOpenText class="mr-2 h-4 w-4" />
			<span>Documentation</span>
		</Dropdown.Item>
		<Dropdown.Separator />
	{/if}
	<Dropdown.Item href="https://auth.{domain}/logout" class="p-3 md:px-2 md:py-1.5">
		<LogOut class="mr-2 h-4 w-4" />
		<span>Sign out</span>
	</Dropdown.Item>
</Dropdown.Content>
