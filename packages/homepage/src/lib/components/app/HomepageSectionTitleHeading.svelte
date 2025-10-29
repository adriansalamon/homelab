<script lang="ts">
	import { cn } from "$lib/utils";
	import type { Snippet } from "svelte";

	interface Props {
		children: Snippet;
		titleIcon?: Snippet<[string]>;
		class?: string;
	}

	const { children, titleIcon, class: className }: Props = $props();
</script>

<h1
	class={cn(
		"text-lg font-semibold md:text-xl",
		titleIcon ? "align-center flex items-center gap-2" : "",
		className
	)}
>
	{#if titleIcon}
		{@render titleIcon("md:size-5 size-4")}
	{/if}
	{@render children()}
</h1>
