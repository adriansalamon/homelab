<script lang="ts">
	import { Copy, Check } from "lucide-svelte";
	import { Tooltip } from "$lib/components";
	import { fly } from "svelte/transition";

	interface Share {
		name: string;
		path: string;
	}

	interface Props {
		share: Share;
		expanded: boolean;
	}

	const { share, expanded }: Props = $props();

	let isCopied = $state(false);

	async function copyToClipboard() {
		try {
			await navigator.clipboard.writeText(share.path);
			isCopied = true;
			setTimeout(() => {
				isCopied = false;
			}, 2000);
		} catch (err) {
			console.error("Failed to copy to clipboard:", err);
		}
	}
</script>

<li>
	<div class="flex items-center justify-between gap-2">
		<p class="text-sm font-semibold">{share.name}</p>
		<Tooltip.Root>
			<Tooltip.Trigger asChild let:builder>
				<button
					{...builder}
					use:builder.action
					onclick={copyToClipboard}
					class="rounded p-1 transition-colors hover:bg-muted"
				>
					{#if isCopied}
						<Check class="size-3 text-green-500" />
					{:else}
						<Copy class="size-3 text-muted-foreground" />
					{/if}
				</button>
			</Tooltip.Trigger>
			<Tooltip.Content>
				{isCopied ? "Copied!" : "Copy path"}
			</Tooltip.Content>
		</Tooltip.Root>
	</div>
	{#if expanded}
		<p class="text-xs text-muted-foreground" transition:fly={{ y: -5 }}>
			{share.path}
		</p>
	{/if}
</li>
