<script lang="ts">
	import { JellyfinLatestCarousel } from "$lib/components/media";
	import type { PageServerData } from "./$types";
	import { Cloud, Popcorn, Sparkles, House, HardDrive } from "lucide-svelte";
	import {
		ImmichAppCard,
		JellyfinAppCard,
		HomeAssistantAppCard,
		UniFiNetworkAppCard,
		PaperlessAppCard,
		OllamaAppCard,
		GrafanaAppCard,
		ForgejoAppCard,
		PrometheusAppCard,
		AutheliaAppCard,
		NomadAppCard,
		LinkwardenAppCard,
	} from "$lib/components/appCards";
	import { AppCardList, HomepageSectionTitle, SeeMoreApps } from "$lib/components/app";
	import { JellyfinIcon } from "$lib/components/icons";

	interface Props {
		data: PageServerData;
		domain: string;
		localDomain: string;
	}

	const { data }: Props = $props();
	const { domain, localDomain } = $derived(data);
</script>

<HomepageSectionTitle
	title="Latest Movies & Shows"
	seeMoreAppName="Jellyfin"
	seeMoreHref={`https://jellyfin.${domain}`}
>
	{#snippet titleIcon(className: string)}
		<Popcorn class={className} />
	{/snippet}

	{#snippet seeMoreIcon(className: string)}
		<JellyfinIcon class={className} />
	{/snippet}
</HomepageSectionTitle>
<JellyfinLatestCarousel {domain} />
<AppCardList title="Entertainment Apps" onHome>
	<JellyfinAppCard {domain} />
	<SeeMoreApps description="See download clients, and more." href="/entertainment" />
</AppCardList>

<AppCardList title="Personal Cloud Apps" onHome>
	<ImmichAppCard {domain} />
	<PaperlessAppCard domain={localDomain} />
	<OllamaAppCard {domain} />
	<ForgejoAppCard {domain} />
	<LinkwardenAppCard {domain} />
	<AutheliaAppCard {domain} />
</AppCardList>

<AppCardList title="Smart Home Apps" onHome>
	<HomeAssistantAppCard domain={localDomain} />
	<UniFiNetworkAppCard {domain} />
</AppCardList>

<AppCardList title="Management Apps" onHome>
	<GrafanaAppCard domain={localDomain} />
	<PrometheusAppCard domain={localDomain} />
	<NomadAppCard domain={localDomain} />
	<SeeMoreApps description="Check metrics, monitor cluster health." href="/serverManagement" />
</AppCardList>
