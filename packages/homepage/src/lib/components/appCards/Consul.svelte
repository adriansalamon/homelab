<script lang="ts">
	import { AppCard } from "../app";
	import { ConsulIcon } from "../icons";

	interface Props {
		domain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Consul"
	description="Serice discovery and configuration."
	gradientColours={["#7D1F1F", "#B33B3B", "#B84437"]}
	href="https://consul.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<ConsulIcon class="h-full w-full" />
		</div>
	{/snippet}
</AppCard>
