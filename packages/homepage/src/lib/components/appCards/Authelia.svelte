<script lang="ts">
	import { AppCard } from "../app";
	import { AutheliaIcon } from "../icons";

	interface Props {
		domain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Authelia"
	description="Authentication and authorization server"
	gradientColours={["#004c6f", "#2C6AA3", "#589CE9"]}
	href="https://auth.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<AutheliaIcon class="h-full w-full" />
		</div>
	{/snippet}
</AppCard>
