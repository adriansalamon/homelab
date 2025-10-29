<script lang="ts">
	import { AppCard } from "../app";
	import { NomadIcon } from "../icons";

	interface Props {
		domain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Nomad"
	description="Orchestration service, runs docker containers."
	gradientColours={["#208B7C", "#39A99A", "#4CCF96"]}
	href="https://nomad.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<NomadIcon class="h-full w-full" />
		</div>
	{/snippet}
</AppCard>
