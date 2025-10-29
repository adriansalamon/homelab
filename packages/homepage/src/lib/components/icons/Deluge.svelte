<script lang="ts">
	import type { HTMLImgAttributes } from "svelte/elements";

	interface Props extends HTMLImgAttributes {}

	const { ...rest }: Props = $props();
</script>

<img
	{...rest}
	src="https://upload.wikimedia.org/wikipedia/commons/8/85/Deluge-Logo.svg"
	alt="Deluge Logo"
/>
