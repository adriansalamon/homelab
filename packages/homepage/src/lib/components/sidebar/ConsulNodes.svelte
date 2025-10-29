<script lang="ts">
	import { trpc } from "$lib/trpc";
	import NodeList from "./NodeList.svelte";
	import NodeListSkeleton from "./NodeListSkeleton.svelte";

	const consulNodes = trpc()?.consul.nodes.createQuery(undefined, {
		refetchInterval: 60 * 1000,
	});
</script>

<div class="flex flex-col">
	{#if $consulNodes?.data}
		<NodeList nodes={$consulNodes.data} />
	{:else}
		<NodeListSkeleton />
	{/if}
</div>
