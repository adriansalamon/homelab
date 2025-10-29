<script lang="ts">
	import { AppCard } from "../app";
	import { SnapcastIcon } from "../icons";

	interface Props {
		domain: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Snapcast"
	description="Multiroom audio player."
	gradientColours={["#fbc42caa", "#fbc42caa", "#fbc42caa"]}
	href="https://snapcast.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="rounded-md bg-white p-1 {className}">
			<SnapcastIcon class="h-full w-full" />
		</div>
	{/snippet}
</AppCard>
