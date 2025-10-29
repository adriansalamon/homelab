<script lang="ts">
	import { AppCard } from "../app";
	import { PrometheusIcon } from "../icons";

	interface Props {
		domain?: string;
		localDomain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="Prometheus"
	description="Metrics collection and monitoring"
	gradientColours={["#e6522c", "#ff6b3d", "#ff8c4a"]}
	href={`https://prometheus.${domain}`}
	class={className}
	{notInList}
>
	{#snippet icon(className: string)}
		<div class="aspect-square bg-white p-1 {className}">
			<PrometheusIcon />
		</div>
	{/snippet}
</AppCard>
