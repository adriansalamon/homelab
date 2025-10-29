<script lang="ts">
	import SambaShareList from "./SambaShareList.svelte";

	const shares = [
		{ name: "hermes-files", path: "hermes-files.internal" },
		{ name: "orpheus-files", path: "orpheus-files.internal" },
	];
</script>

<div class="flex flex-col">
	<SambaShareList {shares} />
</div>
