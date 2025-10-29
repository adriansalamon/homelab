<script lang="ts">
	import { ChevronDown } from "lucide-svelte";
	import Node from "./Node.svelte";
	import { cn } from "$lib/utils";
	import { createPress } from "svelte-interactions";

	interface INode {
		name: string;
		ready: boolean;
		cpu: number;
		memory: number;
	}

	interface Props {
		nodes: INode[];
	}

	const { nodes }: Props = $props();

	let expanded = $state(false);

	const { pressAction } = createPress({
		onPress: () => {
			expanded = !expanded;
		},
	});
</script>

<button class="align-center flex items-center !outline-none !ring-0" use:pressAction>
	<p class="mb-1 text-base font-semibold text-muted-foreground">Nodes</p>
	<ChevronDown class={cn("ml-auto h-4 w-4 transition-all", expanded ? "rotate-180" : "")} />
</button>
<ul class="mt-1 mt-2 flex flex-col gap-2">
	{#each nodes as node (node.name)}
		<Node {node} {expanded} />
	{/each}
</ul>
