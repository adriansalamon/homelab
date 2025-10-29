<script lang="ts">
	import { cn } from "$lib/utils";
	import type { Snippet } from "svelte";

	interface Props {
		children: Snippet;
		onHome?: boolean;
		class?: string;
	}

	const { children, onHome, class: className }: Props = $props();
</script>

<h2 class={cn("align-center flex items-center gap-2 text-lg font-medium md:text-xl", className)}>
	{@render children()}
</h2>
