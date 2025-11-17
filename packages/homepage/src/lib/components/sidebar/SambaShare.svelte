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
		<Tooltip.Provider>
			<Tooltip.Root>
				<Tooltip.Trigger>
					<button onclick={copyToClipboard} class="hover:bg-muted rounded p-1 transition-colors">
						{#if isCopied}
							<Check class="size-3 text-green-500" />
						{:else}
							<Copy class="text-muted-foreground size-3" />
						{/if}
					</button>
				</Tooltip.Trigger>
				<Tooltip.Content>
					{isCopied ? "Copied!" : "Copy path"}
				</Tooltip.Content>
			</Tooltip.Root>
		</Tooltip.Provider>
	</div>
	{#if expanded}
		<p class="text-muted-foreground text-xs" transition:fly={{ y: -5 }}>
			{share.path}
		</p>
	{/if}
</li>
