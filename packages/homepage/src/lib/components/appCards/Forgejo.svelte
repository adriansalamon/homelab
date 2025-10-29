<script lang="ts">
	import { AppCard } from "../app";
	import { ForgejoIcon } from "../icons";

	interface Props {
		domain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Forgejo"
	description="Self-hosted Git service"
	gradientColours={["#A80C0C", "#D40000", "#A84300"]}
	href="https://forgejo.{domain}"
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<ForgejoIcon />
		</div>
	{/snippet}
</AppCard>
