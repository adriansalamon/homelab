<script lang="ts">
	import { AppCard } from "../app";
	import { UniFiNetworkIcon } from "../icons";

	interface Props {
		notInList?: boolean;
		class?: string;
		domain: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="UniFi Network"
	description="Manage your network."
	href="https://unifi.{domain}"
	gradientColours={["#012d66", "#004096", "#0165eb"]}
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div
			class="align-center jusitfy-center flex aspect-square items-center overflow-hidden bg-white {className}"
		>
			<UniFiNetworkIcon class="" />
		</div>
	{/snippet}
</AppCard>
