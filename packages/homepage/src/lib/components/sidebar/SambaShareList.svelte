<script lang="ts">
	import { ChevronDown } from "lucide-svelte";
	import SambaShare from "./SambaShare.svelte";
	import { cn } from "$lib/utils";
	import { createPress } from "svelte-interactions";

	interface Share {
		name: string;
		path: string;
	}

	interface Props {
		shares: Share[];
	}

	const { shares }: Props = $props();

	let expanded = $state(false);

	const { pressAction } = createPress({
		onPress: () => {
			expanded = !expanded;
		},
	});
</script>

<button class="align-center flex items-center outline-none! ring-0!" use:pressAction>
	<p class="mb-1 text-base font-semibold text-muted-foreground">Samba Shares</p>
	<ChevronDown class={cn("ml-auto h-4 w-4 transition-all", expanded ? "rotate-180" : "")} />
</button>

<ul class="mt-1 flex flex-col gap-2">
	{#each shares as share (share.name)}
		<SambaShare {share} {expanded} />
	{/each}
</ul>
