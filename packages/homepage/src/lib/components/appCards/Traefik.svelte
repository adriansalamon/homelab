<script lang="ts">
	import { AppCard } from "../app";
	import { TraefikIcon } from "../icons";

	interface Props {
		notInList?: boolean;
		class?: string;
		site: string;
		domain: string;
	}

	const capitalize = (str: string) => str[0].toUpperCase() + str.slice(1);

	const { site, domain, notInList, class: className }: Props = $props();

	const siteName = capitalize(site);
</script>

<AppCard
	name="Traefik {siteName}"
	description="Reverse proxy & load balancer at {siteName}."
	href="https://traefik-{site}.{domain}"
	gradientColours={["#3ca4c4", "#28a4c4", "#28a4c4"]}
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div
			class="align-center jusitfy-center flex aspect-square items-center bg-white p-1 {className}"
		>
			<TraefikIcon class="" />
		</div>
	{/snippet}
</AppCard>
