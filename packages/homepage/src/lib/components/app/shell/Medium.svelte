<script lang="ts">
	import type { Snippet } from "svelte";
	import UserMenu from "../UserMenu.svelte";

	interface Props {
		children: Snippet;
		domain: string;
	}

	const { children, domain }: Props = $props();
</script>

<div class="relative mx-auto flex h-full w-full max-w-screen-lg flex-col">
	<aside
		class="align-center fixed left-0 top-0 z-[45] flex w-full items-center justify-center border-b p-2 px-4 backdrop-blur-xl dark:backdrop-brightness-50 dark:backdrop-saturate-150"
	>
		<div
			class="align-center mx-auto flex w-full items-center justify-end md:max-w-[85%] lg:max-w-[869px]"
		>
			<UserMenu {domain} />
		</div>
	</aside>
	<main
		class="mt-2 h-full w-full overflow-y-auto overflow-x-hidden px-5 py-4 pt-20 md:px-20 xl:mt-0"
	>
		{@render children()}
	</main>
</div>
