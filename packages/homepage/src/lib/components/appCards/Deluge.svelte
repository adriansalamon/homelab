<script lang="ts">
	import { AppCard } from "../app";
	import { DelugeIcon } from "../icons";

	interface Props {
		domain: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Deluge"
	description="Torrent client."
	gradientColours={["#0D475E", "#0D475E", "#0D475E"]}
	href="https://deluge.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<DelugeIcon class="h-full w-full" />
		</div>
	{/snippet}
</AppCard>
